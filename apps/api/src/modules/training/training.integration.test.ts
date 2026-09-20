/**
 * Programmes through the HTTP surface on real Postgres with the real seed.
 * §31 Phase 4 acceptance: the generator handles 2–6 days for every goal and
 * level from a real profile, and a custom programme persists and remains
 * adaptive (the same planned_exercises rows the progression engine reads).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program } from '@fitos/contracts';
import { MUSCLE_GROUPS as CORE_MUSCLES, MOVEMENT_PATTERNS as CORE_PATTERNS, EQUIPMENT as CORE_EQUIPMENT, BODY_PARTS as CORE_BODY_PARTS } from '@fitos/core/training/generator';
import { MUSCLE_GROUPS, MOVEMENT_PATTERNS, EQUIPMENT, bodyPartSchema } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describe('core and contracts agree on the training vocabularies', () => {
  // packages/core is dependency-free, so it carries its own copies. The API
  // depends on both; this is where drift would show.
  it('muscle groups, patterns, equipment and body parts are identical lists', () => {
    expect([...CORE_MUSCLES]).toEqual([...MUSCLE_GROUPS]);
    expect([...CORE_PATTERNS]).toEqual([...MOVEMENT_PATTERNS]);
    expect([...CORE_EQUIPMENT]).toEqual([...EQUIPMENT]);
    expect([...CORE_BODY_PARTS]).toEqual([...bodyPartSchema.options]);
  });
});

describeIfDb('/v1/training/program (real Postgres, real seed)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'tr-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  // Each user has its own IP on EVERY request: the default limit is
  // 120/min per client (§10) and this suite makes far more than that.
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.113.250' });

  /** A signed-in user who has completed onboarding with the given training facts. */
  async function onboarded(opts: {
    goal?: string;
    experience?: string;
    days?: number;
    equipment?: string[];
    minutes?: number;
  } = {}): Promise<string> {
    n += 1;
    const token = `tr-tok-${n}`;
    ipOf.set(token, `203.0.${Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `tr-uid-${n}`, email: `tr${n}@vit.ac.in` });
    const session = await app.inject({
      method: 'POST',
      url: '/v1/auth/session',
      headers: auth(token),
      payload: {},
    });
    expect(session.statusCode).toBe(200);
    const steps = [
      { step: 'goal', goalType: opts.goal ?? 'muscle-gain' },
      { step: 'about', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: opts.experience ?? 'intermediate', trainingDaysPerWeek: opts.days ?? 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: opts.equipment ?? ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ];
    for (const body of steps) {
      const r = await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(token), payload: body });
      expect(r.statusCode, r.body).toBe(200);
    }
    const done = await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(token), payload: {} });
    expect(done.statusCode, done.body).toBe(200);
    if (opts.minutes !== undefined) {
      const r = await app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: auth(token), payload: { preferredSessionMinutes: opts.minutes } });
      expect(r.statusCode).toBe(200);
    }
    return token;
  }

  const generate = (token: string, body?: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth(token), payload: body ?? {} });
  const get = (token: string) => app.inject({ method: 'GET', url: '/v1/training/program', headers: auth(token) });

  it('no programme yet → 404 with a next step', async () => {
    const token = await onboarded();
    const r = await get(token);
    expect(r.statusCode).toBe(404);
    expect(r.json().error.message).toMatch(/Generate one/);
  });

  it('generate before onboarding → 409 naming what is missing', async () => {
    n += 1;
    const token = `tr-tok-${n}`;
    ipOf.set(token, `203.0.${Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `tr-uid-${n}` });
    await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} });
    const r = await generate(token);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.details.map((d: { path: string }) => d.path).sort()).toEqual(['experienceLevel', 'goal', 'trainingDaysPerWeek']);
  });

  it('generates from the profile: 4 days intermediate muscle-gain → upper/lower with reasons on every exercise', async () => {
    const token = await onboarded();
    const r = await generate(token);
    expect(r.statusCode, r.body).toBe(200);
    const p: Program = r.json();
    expect(p.source).toBe('generated');
    expect(p.splitType).toBe('upper-lower');
    expect(p.daysPerWeek).toBe(4);
    expect(p.mesocycleWeek).toBe(1);
    expect(p.active).toBe(true);
    expect(p.days.length).toBe(7);
    expect(p.days.map((d) => d.dayOfWeek)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    const sessions = p.days.filter((d) => !d.isRest);
    expect(sessions.length).toBe(4);
    for (const d of sessions) {
      expect(d.exercises.length).toBeGreaterThanOrEqual(3);
      expect(d.estimatedMinutes).toBeLessThanOrEqual(69);
      for (const x of d.exercises) {
        expect(x.reason).toBeTruthy();
        expect(x.repMin).toBe(6);
        expect(x.repMax).toBe(12);
        expect(x.targetRir).toBe(1);
        // Only the equipment this user said they have.
        for (const q of x.equipment) expect(['barbell', 'dumbbell', 'machine', 'cable', 'bodyweight']).toContain(q);
      }
    }
    expect(p.rationale.length).toBeGreaterThan(1);
    expect(p.weeklyVolume.chest).toBeGreaterThanOrEqual(10);
    // GET returns the same programme.
    const again = await get(token);
    expect(again.statusCode).toBe(200);
    expect(again.json()).toEqual(p);
  });

  it('handles 2–6 days for every goal and level from a real profile (acceptance)', async () => {
    // One user; overrides on the request for days, the profile for goal/level.
    const goals = ['muscle-gain', 'fat-loss', 'recomposition', 'strength', 'general', 'maintenance'];
    const levels = ['beginner', 'intermediate', 'advanced'];
    for (const goal of goals) {
      for (const experience of levels) {
        const token = await onboarded({ goal, experience, days: 3 });
        for (const days of [2, 3, 4, 5, 6]) {
          const r = await generate(token, { daysPerWeek: days });
          expect(r.statusCode, `${goal} ${experience} ${days}: ${r.body}`).toBe(200);
          const p: Program = r.json();
          expect(p.days.filter((d) => !d.isRest).length).toBe(days);
          for (const d of p.days.filter((x) => !x.isRest)) expect(d.exercises.length, `${goal} ${experience} ${days} ${d.sessionName}`).toBeGreaterThanOrEqual(3);
        }
      }
    }
    // 18 users × 5 generations; only one programme per user is active.
    const [{ active }] = await sql<{ active: string }[]>`
      select count(*)::text as active from programs where active and user_id in (select id from users where firebase_uid like 'tr-%')`;
    const [{ users }] = await sql<{ users: string }[]>`
      select count(distinct user_id)::text as users from programs where user_id in (select id from users where firebase_uid like 'tr-%')`;
    expect(Number(active)).toBe(Number(users));
  }, 60_000);

  it('a limitation on file excludes contraindicated lifts and the rationale says so', async () => {
    const token = await onboarded();
    const [{ id }] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`tr-uid-${n}`}`;
    await sql`insert into user_limitations (user_id, body_part, note) values (${id}, 'knee', 'meniscus')`;
    const r = await generate(token);
    expect(r.statusCode).toBe(200);
    const p: Program = r.json();
    const slugs = p.days.flatMap((d) => d.exercises.map((x) => x.slug));
    expect(slugs).not.toContain('barbell-back-squat');
    expect(slugs).not.toContain('leg-press');
    expect(p.rationale.join(' ')).toMatch(/knee limitation/);
    expect(p.shortfalls.some((s) => s.muscle === 'quads' && s.reason === 'limitation')).toBe(true);
  });

  it('regenerating replaces the active programme; the old one is kept inactive, not deleted', async () => {
    const token = await onboarded();
    const first: Program = (await generate(token)).json();
    const second: Program = (await generate(token, { daysPerWeek: 3 })).json();
    expect(second.id).not.toBe(first.id);
    expect(second.daysPerWeek).toBe(3);
    const rows = await sql<{ id: string; active: boolean }[]>`
      select p.id, p.active from programs p join users u on u.id = p.user_id where u.firebase_uid = ${`tr-uid-${n}`} order by p.created_at`;
    expect(rows.map((r) => [r.id, r.active])).toEqual([[first.id, false], [second.id, true]]);
  });

  it('a custom programme persists and remains adaptive (acceptance)', async () => {
    const token = await onboarded();
    const ex = await sql<{ id: string; slug: string; default_increment_kg: string }[]>`
      select id, slug, default_increment_kg from exercises where slug in ('barbell-back-squat', 'barbell-bench-press', 'barbell-row', 'lat-pulldown') order by slug`;
    const byId = new Map(ex.map((e) => [e.slug, e]));
    const body = {
      name: 'My 2-day',
      days: [
        { dayOfWeek: 1, sessionName: 'A', exercises: [
          { exerciseId: byId.get('barbell-back-squat')!.id, setCount: 5, repMin: 5, repMax: 5, targetRir: 2 },
          { exerciseId: byId.get('barbell-bench-press')!.id, setCount: 3, repMin: 8, repMax: 10, targetRir: 2, incrementKg: 1.25 },
        ] },
        { dayOfWeek: 4, sessionName: 'B', exercises: [
          { exerciseId: byId.get('barbell-row')!.id, setCount: 4, repMin: 6, repMax: 10, targetRir: 2 },
          { exerciseId: byId.get('lat-pulldown')!.id, setCount: 3, repMin: 10, repMax: 12, targetRir: 1 },
        ] },
      ],
    };
    const r = await app.inject({ method: 'PUT', url: '/v1/training/program', headers: auth(token), payload: body });
    expect(r.statusCode, r.body).toBe(200);
    const p: Program = r.json();
    expect(p.source).toBe('custom');
    expect(p.splitType).toBe('custom');
    expect(p.name).toBe('My 2-day');
    expect(p.daysPerWeek).toBe(2);
    expect(p.days.filter((d) => !d.isRest).map((d) => d.dayOfWeek)).toEqual([1, 4]);
    expect(p.days.filter((d) => d.isRest).length).toBe(5);
    const a = p.days.find((d) => d.dayOfWeek === 1)!;
    expect(a.focus).toEqual(expect.arrayContaining(['quads', 'chest']));
    expect(a.estimatedMinutes).toBe(28);
    // Increment defaults to the exercise's own unless given.
    expect(a.exercises[0]!.incrementKg).toBe(Number(byId.get('barbell-back-squat')!.default_increment_kg));
    expect(a.exercises[1]!.incrementKg).toBe(1.25);
    expect(a.exercises[0]!.reason).toBeNull();
    expect(p.rationale).toEqual([]);
    // "Remains adaptive": the rows are the same planned_exercises the
    // progression engine reads, with mesocycle_week advancing like any other.
    expect(p.mesocycleWeek).toBe(1);
    const [row] = await sql<{ set_count: number; rep_min: number; rep_max: number; target_rir: number; increment_kg: string }[]>`
      select pe.set_count, pe.rep_min, pe.rep_max, pe.target_rir, pe.increment_kg
      from planned_exercises pe join program_days d on d.id = pe.program_day_id
      where d.program_id = ${p.id} and d.day_of_week = 1 and pe.order_index = 0`;
    expect(row).toEqual({ set_count: 5, rep_min: 5, rep_max: 5, target_rir: 2, increment_kg: '5.00' });
    // Survives a re-read.
    expect((await get(token)).json()).toEqual(p);
  });

  it('a custom programme with an unknown exercise is 422 with the id named', async () => {
    const token = await onboarded();
    const r = await app.inject({
      method: 'PUT',
      url: '/v1/training/program',
      headers: auth(token),
      payload: {
        name: 'x',
        days: [
          { dayOfWeek: 1, sessionName: 'A', exercises: [{ exerciseId: '00000000-0000-4000-8000-000000000000', setCount: 3, repMin: 8, repMax: 12, targetRir: 2 }] },
          { dayOfWeek: 2, sessionName: 'B', exercises: [{ exerciseId: '00000000-0000-4000-8000-000000000000', setCount: 3, repMin: 8, repMax: 12, targetRir: 2 }] },
        ],
      },
    });
    expect(r.statusCode).toBe(422);
    expect(r.json().error.details[0].path).toMatch(/exerciseId:00000000/);
  });

  it('PATCH a day: rename, replace exercises, and it is the user\'s own day only', async () => {
    const token = await onboarded();
    const p: Program = (await generate(token)).json();
    const day = p.days.find((d) => !d.isRest)!;
    const [{ id: curlId }] = await sql<{ id: string }[]>`select id from exercises where slug = 'dumbbell-curl'`;

    const renamed = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { sessionName: 'Arms day' } });
    expect(renamed.statusCode, renamed.body).toBe(200);
    expect(renamed.json().days.find((d: { id: string }) => d.id === day.id).sessionName).toBe('Arms day');
    expect(renamed.json().days.find((d: { id: string }) => d.id === day.id).exercises.length).toBe(day.exercises.length);

    const replaced = await app.inject({
      method: 'PATCH',
      url: `/v1/training/program/days/${day.id}`,
      headers: auth(token),
      payload: { exercises: [{ exerciseId: curlId, setCount: 3, repMin: 10, repMax: 15, targetRir: 2 }] },
    });
    expect(replaced.statusCode, replaced.body).toBe(200);
    const edited = replaced.json().days.find((d: { id: string }) => d.id === day.id);
    expect(edited.exercises.length).toBe(1);
    expect(edited.exercises[0].slug).toBe('dumbbell-curl');
    expect(edited.exercises[0].reason).toBeNull();
    expect(edited.sessionName).toBe('Arms day');
    expect(replaced.json().source).toBe('generated'); // still the generated programme, edited

    // Somebody else's day → 404, not 403 (no existence leak).
    const other = await onboarded();
    const r = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(other), payload: { sessionName: 'x' } });
    expect(r.statusCode).toBe(404);
    // Unknown keys and an empty patch are 422.
    expect((await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: {} })).statusCode).toBe(422);
    expect((await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { isRest: true } })).statusCode).toBe(422);
  });
});
