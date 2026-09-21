/**
 * Programmes through the HTTP surface on real Postgres with the real seed.
 * §31 Phase 4 acceptance: the generator handles 2–6 days for every goal and
 * level from a real profile, and a custom programme persists and remains
 * adaptive (the same planned_exercises rows the progression engine reads).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type TemplatePreview } from '@fitos/contracts';
import { PROGRAM_TEMPLATES } from '@fitos/core/training/templates';
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
        // Per-set targets: one per set, the prescription, NO invented weight.
        expect(x.sets.length).toBe(x.setCount);
        x.sets.forEach((set, i) => {
          expect(set.setIndex).toBe(i + 1);
          expect([set.repsMin, set.repsMax, set.rir]).toEqual([6, 12, 1]);
          expect(set.weightKg).toBeNull();
        });
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
    const [activeRow] = await sql<{ active: string }[]>`
      select count(*)::text as active from programs where active and user_id in (select id from users where firebase_uid like 'tr-%')`;
    const [usersRow] = await sql<{ users: string }[]>`
      select count(distinct user_id)::text as users from programs where user_id in (select id from users where firebase_uid like 'tr-%')`;
    expect(Number(activeRow!.active)).toBe(Number(usersRow!.users));
  }, 60_000);

  it('a limitation on file excludes contraindicated lifts and the rationale says so', async () => {
    const token = await onboarded();
    const [user] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`tr-uid-${n}`}`;
    await sql`insert into user_limitations (user_id, body_part, note) values (${user!.id}, 'knee', 'meniscus')`;
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
        { dayOfWeek: 1, sessionName: 'A', focus: ['quads', 'chest'], exercises: [
          { exerciseId: byId.get('barbell-back-squat')!.id, setCount: 5, repMin: 5, repMax: 5, targetRir: 2, startingWeightKg: 60 },
          { exerciseId: byId.get('barbell-bench-press')!.id, setCount: 3, repMin: 8, repMax: 10, targetRir: 2, incrementKg: 1.25, sets: [
            { repsMin: 10, repsMax: 10, weightKg: 40, rir: 2 },
            { repsMin: 10, repsMax: 10, weightKg: 40, rir: 2 },
            { repsMin: 8, repsMax: 8, weightKg: 42.5, rir: 1 },
          ] },
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
    // startingWeightKg spreads to every set; explicit sets are stored per set.
    expect(a.exercises[0]!.sets.map((x) => [x.repsMin, x.repsMax, x.weightKg, x.rir])).toEqual([
      [5, 5, 60, 2], [5, 5, 60, 2], [5, 5, 60, 2], [5, 5, 60, 2], [5, 5, 60, 2],
    ]);
    expect(a.exercises[1]!.sets.map((x) => [x.repsMin, x.repsMax, x.weightKg, x.rir])).toEqual([
      [10, 10, 40, 2], [10, 10, 40, 2], [8, 8, 42.5, 1],
    ]);
    expect(a.focus).toEqual(['quads', 'chest']); // the user's order, kept
    expect(p.rationale).toEqual([]);
    // "Remains adaptive": the rows are the same planned_exercises the
    // progression engine reads, with mesocycle_week advancing like any other.
    expect(p.mesocycleWeek).toBe(1);
    const [row] = await sql<{ set_count: number; rep_min: number; rep_max: number; target_rir: number; increment_kg: string }[]>`
      select pe.set_count, pe.rep_min, pe.rep_max, pe.target_rir, pe.increment_kg
      from planned_exercises pe join program_days d on d.id = pe.program_day_id
      where d.program_id = ${p.id} and d.day_of_week = 1 and pe.order_index = 0`;
    expect(row).toEqual({ set_count: 5, rep_min: 5, rep_max: 5, target_rir: 2, increment_kg: '5.00' });
    const setRows = await sql<{ set_index: number; weight_kg: string | null }[]>`
      select ps.set_index, ps.weight_kg from planned_sets ps
      join planned_exercises pe on pe.id = ps.planned_exercise_id
      join program_days d on d.id = pe.program_day_id
      where d.program_id = ${p.id} and d.day_of_week = 1 and pe.order_index = 1 order by ps.set_index`;
    expect(setRows).toEqual([{ set_index: 1, weight_kg: '40.00' }, { set_index: 2, weight_kg: '40.00' }, { set_index: 3, weight_kg: '42.50' }]);
    // Survives a re-read.
    expect((await get(token)).json()).toEqual(p);
  });

  it('editing one set of one exercise on the day screen persists exactly that (the auto-save path)', async () => {
    const token = await onboarded();
    const p: Program = (await generate(token)).json();
    const day = p.days.find((d) => !d.isRest)!;
    // The client sends the whole day back with the edited set; everything else unchanged.
    const edited = day.exercises.map((x) => ({
      exerciseId: x.exerciseId,
      setCount: x.setCount,
      repMin: x.repMin,
      repMax: x.repMax,
      targetRir: x.targetRir,
      incrementKg: x.incrementKg,
      sets: x.sets.map((s, i) =>
        x.orderIndex === 0 && i === 2
          ? { repsMin: 8, repsMax: 8, weightKg: 42.5, rir: 1 }
          : { repsMin: s.repsMin, repsMax: s.repsMax, weightKg: s.weightKg, rir: s.rir },
      ),
    }));
    const r = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { exercises: edited } });
    expect(r.statusCode, r.body).toBe(200);
    const after: Program = r.json();
    const d2 = after.days.find((d) => d.id === day.id)!;
    expect(d2.exercises.length).toBe(day.exercises.length);
    expect(d2.exercises[0]!.sets[2]).toMatchObject({ setIndex: 3, repsMin: 8, repsMax: 8, weightKg: 42.5, rir: 1 });
    expect(d2.exercises[0]!.sets[0]!.weightKg).toBeNull();
    // Sent without ids (a pre-Phase-5 client): rows are re-created, so
    // the set ids are new but every target is what it was.
    const noId = (sets: Program['days'][number]['exercises'][number]['sets']) => sets.map(({ id: _id, ...rest }) => rest);
    expect(noId(d2.exercises[1]!.sets)).toEqual(noId(day.exercises[1]!.sets));
    expect(d2.exercises[0]!.reason).toBeNull(); // the user re-prescribed it
    // Leaving and reopening: the same.
    expect((await get(token)).json()).toEqual(after);
  });

  it('auto-save keeps every planned exercise id and set id it continues (the expanded card survives a save)', async () => {
    const token = await onboarded();
    const p: Program = (await generate(token)).json();
    const day = p.days.find((d) => !d.isRest)!;
    const before = day.exercises;
    const setIdsBefore = (await sql<{ id: string; planned_exercise_id: string; set_index: number }[]>`
      select id, planned_exercise_id, set_index from planned_sets where planned_exercise_id in ${sql(before.map((x) => x.id))}`);
    const asCustom = (x: Program['days'][number]['exercises'][number]) => ({
      id: x.id,
      exerciseId: x.exerciseId,
      setCount: x.setCount,
      repMin: x.repMin,
      repMax: x.repMax,
      targetRir: x.targetRir,
      incrementKg: x.incrementKg,
      sets: x.sets.map((s) => ({ repsMin: s.repsMin, repsMax: s.repsMax, weightKg: s.weightKg, rir: s.rir })),
    });
    // 1. Edit one set on the first exercise: ids unchanged everywhere.
    const edited = before.map((x, i) => (i === 0 ? { ...asCustom(x), sets: asCustom(x).sets.map((s, j) => (j === 0 ? { ...s, repsMin: 12, repsMax: 12, weightKg: 40 } : s)) } : asCustom(x)));
    const r1 = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { exercises: edited } });
    expect(r1.statusCode, r1.body).toBe(200);
    const d1 = (r1.json() as Program).days.find((d) => d.id === day.id)!;
    expect(d1.exercises.map((x) => x.id)).toEqual(before.map((x) => x.id));
    expect(d1.exercises[0]!.sets[0]).toMatchObject({ setIndex: 1, repsMin: 12, repsMax: 12, weightKg: 40, rir: before[0]!.sets[0]!.rir });
    const setIdsAfter = (await sql<{ id: string; planned_exercise_id: string; set_index: number }[]>`
      select id, planned_exercise_id, set_index from planned_sets where planned_exercise_id in ${sql(before.map((x) => x.id))}`);
    expect(new Set(setIdsAfter.map((s) => s.id))).toEqual(new Set(setIdsBefore.map((s) => s.id)));

    // 2. Reorder (last first) and remove the second: kept rows keep ids, the removed one is gone.
    const reordered = [asCustom(d1.exercises[d1.exercises.length - 1]!), ...d1.exercises.slice(0, -1).filter((_, i) => i !== 1).map(asCustom)];
    const r2 = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { exercises: reordered } });
    expect(r2.statusCode, r2.body).toBe(200);
    const d2 = (r2.json() as Program).days.find((d) => d.id === day.id)!;
    expect(d2.exercises.map((x) => x.id)).toEqual(reordered.map((x) => x.id));
    expect(d2.exercises.map((x) => x.orderIndex)).toEqual(d2.exercises.map((_, i) => i));
    expect((await sql`select 1 from planned_exercises where id = ${before[1]!.id}`).length).toBe(0);

    // 3. Replace the movement on a kept row and add a row without an id: the
    //    kept id stays (weights cleared by the client), the new row gets a fresh id.
    const [other] = await sql<{ id: string }[]>`select id from exercises where slug = 'face-pull'`;
    const replaced = d2.exercises.map((x, i) => (i === 0 ? { ...asCustom(x), exerciseId: other!.id, sets: asCustom(x).sets.map((s) => ({ ...s, weightKg: null })) } : asCustom(x)));
    const added = { ...asCustom(d2.exercises[0]!), id: undefined, exerciseId: other!.id };
    const r3 = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { exercises: [...replaced, { ...added, id: undefined }] } });
    expect(r3.statusCode, r3.body).toBe(200);
    const d3 = (r3.json() as Program).days.find((d) => d.id === day.id)!;
    expect(d3.exercises[0]!.id).toBe(d2.exercises[0]!.id);
    expect(d3.exercises[0]!.slug).toBe('face-pull');
    expect(d3.exercises.at(-1)!.id).not.toBe(d2.exercises[0]!.id);
    expect(d3.exercises.length).toBe(d2.exercises.length + 1);

    // 4. An id from someone else's programme is ignored, never adopted.
    const stranger = await onboarded();
    const sp: Program = (await generate(stranger)).json();
    const foreign = sp.days.find((d) => !d.isRest)!.exercises[0]!.id;
    const r4 = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { exercises: [{ ...asCustom(d3.exercises[0]!), id: foreign }] } });
    expect(r4.statusCode, r4.body).toBe(200);
    const d4 = (r4.json() as Program).days.find((d) => d.id === day.id)!;
    expect(d4.exercises.length).toBe(1);
    expect(d4.exercises[0]!.id).not.toBe(foreign);
    expect((await sql`select 1 from planned_exercises where id = ${foreign}`).length).toBe(1);
  });

  it('the catalogue the generator sees keeps the seed order of primary muscles (0005)', async () => {
    const rows = await sql<{ slug: string; primaries: string[] }[]>`
      select e.slug, coalesce((select array_agg(m.muscle_group order by m.position, m.muscle_group) from exercise_muscles m where m.exercise_id = e.id and m.role = 'primary'), '{}') as primaries
      from exercises e where e.slug in ('close-grip-bench-press', 'bird-dog', 'conventional-deadlift', 'sumo-deadlift')`;
    const bySlug = new Map(rows.map((r) => [r.slug, r.primaries]));
    expect(bySlug.get('close-grip-bench-press')).toEqual(['triceps', 'chest']);
    expect(bySlug.get('bird-dog')).toEqual(['abs', 'back']);
    expect(bySlug.get('conventional-deadlift')).toEqual(['hamstrings', 'glutes']);
    expect(bySlug.get('sumo-deadlift')).toEqual(['glutes', 'hamstrings']);
  });

  it("the owner's profile — intermediate, 6 days, campus gym, recomposition, 75 min — never gets a three-movement push or pull", async () => {
    const token = await onboarded({ experience: 'intermediate', days: 6, goal: 'recomposition', equipment: ['barbell', 'dumbbell', 'machine', 'cable', 'pull-up-bar'], minutes: 75 });
    const p: Program = (await generate(token)).json();
    expect(p.splitType).toBe('push-pull-legs');
    for (const d of p.days.filter((x) => !x.isRest)) {
      expect(d.exercises.length, `${d.sessionName}: ${d.exercises.map((x) => x.slug).join(', ')}`).toBeGreaterThanOrEqual(4);
      if (d.sessionName === 'Push') {
        expect(d.exercises[0]!.primaryMuscles[0]).toBe('chest');
        expect(d.exercises.some((x) => x.primaryMuscles.includes('triceps'))).toBe(true);
      }
      if (d.sessionName === 'Pull') {
        expect(d.exercises.some((x) => x.movementPattern === 'vertical-pull')).toBe(true);
        expect(d.exercises.some((x) => x.movementPattern === 'horizontal-pull')).toBe(true);
        expect(d.exercises.some((x) => x.primaryMuscles.includes('biceps'))).toBe(true);
        expect(d.exercises.some((x) => x.primaryMuscles.includes('shoulders'))).toBe(true);
      }
    }
  });

  it('rename persists', async () => {
    const token = await onboarded();
    await generate(token);
    const r = await app.inject({ method: 'PATCH', url: '/v1/training/program', headers: auth(token), payload: { name: 'Winter block' } });
    expect(r.statusCode).toBe(200);
    expect((await get(token)).json().name).toBe('Winter block');
    expect((await app.inject({ method: 'PATCH', url: '/v1/training/program', headers: auth(token), payload: { name: '' } })).statusCode).toBe(422);
  });

  it('templates: the library lists every structure; preview materialises for the profile; apply persists it', async () => {
    const token = await onboarded({ equipment: ['dumbbell', 'pull-up-bar'] });
    const list = await app.inject({ method: 'GET', url: '/v1/training/templates', headers: auth(token) });
    expect(list.statusCode).toBe(200);
    const items = list.json().items as { slug: string; daysPerWeek: number; days: { sessionName: string }[] }[];
    expect(items.map((i) => i.slug).sort()).toEqual(PROGRAM_TEMPLATES.map((t) => t.slug).sort());
    for (const item of items) expect(item.days.length).toBe(item.daysPerWeek);

    const preview = await app.inject({ method: 'GET', url: '/v1/training/templates/bro-split?preferredSessionMinutes=45', headers: auth(token) });
    expect(preview.statusCode, preview.body).toBe(200);
    const pv: TemplatePreview = preview.json();
    expect(pv.template.slug).toBe('bro-split');
    expect(pv.days.length).toBe(7);
    const sessions = pv.days.filter((d) => !d.isRest);
    expect(sessions.map((d) => d.sessionName)).toEqual(['Chest', 'Back', 'Shoulders', 'Legs', 'Arms']);
    for (const d of sessions) {
      expect(d.exercises.length).toBeGreaterThanOrEqual(3);
      expect(d.estimatedMinutes).toBeLessThanOrEqual(45 * 1.15);
      for (const x of d.exercises) {
        for (const q of x.equipment) expect(['dumbbell', 'pull-up-bar', 'bodyweight'], x.slug).toContain(q);
        expect(x.sets.length).toBe(x.setCount);
        for (const set of x.sets) expect(set.weightKg).toBeNull();
      }
    }
    // Nothing stored by a preview.
    expect((await get(token)).statusCode).toBe(404);

    const applied = await app.inject({ method: 'POST', url: '/v1/training/program/from-template/bro-split', headers: auth(token), payload: { preferredSessionMinutes: 45 } });
    expect(applied.statusCode, applied.body).toBe(200);
    const p: Program = applied.json();
    expect(p.source).toBe('template');
    expect(p.templateSlug).toBe('bro-split');
    expect(p.splitType).toBe('bro-split');
    expect(p.name).toBe('Bro Split');
    expect(p.days.filter((d) => !d.isRest).map((d) => d.sessionName)).toEqual(sessions.map((d) => d.sessionName));
    // Same materialisation as the preview.
    expect(p.days.map((d) => d.exercises.map((x) => [x.slug, x.setCount]))).toEqual(pv.days.map((d) => d.exercises.map((x) => [x.slug, x.setCount])));
    expect((await get(token)).json()).toEqual(p);
    // And it is editable like any other programme.
    const day = p.days.find((d) => !d.isRest)!;
    const renamed = await app.inject({ method: 'PATCH', url: `/v1/training/program/days/${day.id}`, headers: auth(token), payload: { sessionName: 'Chest (heavy)' } });
    expect(renamed.statusCode).toBe(200);
    expect(renamed.json().source).toBe('template');

    expect((await app.inject({ method: 'GET', url: '/v1/training/templates/nope', headers: auth(token) })).statusCode).toBe(404);
    expect((await app.inject({ method: 'POST', url: '/v1/training/program/from-template/nope', headers: auth(token), payload: {} })).statusCode).toBe(404);
  });

  it('every template applies for a real profile with a knee limitation and never plans a knee-contraindicated lift', async () => {
    const token = await onboarded();
    const [user] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`tr-uid-${n}`}`;
    await sql`insert into user_limitations (user_id, body_part, note) values (${user!.id}, 'knee', 'meniscus')`;
    const contraindicated = new Set(
      (await sql<{ slug: string }[]>`select e.slug from exercises e join exercise_contraindications c on c.exercise_id = e.id where c.body_part = 'knee'`).map((r) => r.slug),
    );
    for (const t of PROGRAM_TEMPLATES) {
      const r = await app.inject({ method: 'POST', url: `/v1/training/program/from-template/${t.slug}`, headers: auth(token), payload: {} });
      expect(r.statusCode, `${t.slug}: ${r.body}`).toBe(200);
      const p: Program = r.json();
      expect(p.days.filter((d) => !d.isRest).length).toBe(t.daysPerWeek);
      for (const d of p.days) for (const x of d.exercises) expect(contraindicated.has(x.slug), `${t.slug} ${x.slug}`).toBe(false);
    }
  }, 60_000);

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
    const [curl] = await sql<{ id: string }[]>`select id from exercises where slug = 'dumbbell-curl'`;
    const curlId = curl!.id;

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
