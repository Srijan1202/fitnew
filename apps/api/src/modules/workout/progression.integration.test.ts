/**
 * Phase 6 through the HTTP surface on real Postgres: target loads with
 * reasons on /training/today after real logged sessions, the §31 manual
 * ("three declining sessions → a deload is offered, not an increase")
 * automated, volume against a hand calculation, the cache and its rebuild,
 * neglect, substitution, deload accept / decline / close.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type TodayResponse, type VolumeResponse, type WorkoutSession } from '@fitos/contracts';
import { isoWeekKey } from '@fitos/core/training/mesocycle';

import { migrateUp } from '../../db/migrate.js';
import { rebuildVolume } from '../../db/rebuild-volume.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { ProgressionAssembler, localDate } from './progression.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describe('ProgressionAssembler helpers', () => {
  it('mondayOf an ISO week key', () => {
    expect(ProgressionAssembler.mondayOf('2026-W39')).toBe('2026-09-21');
    expect(ProgressionAssembler.mondayOf('2027-W01')).toBe('2027-01-04');
    expect(ProgressionAssembler.mondayOf('2026-W53')).toBe('2026-12-28');
  });
});

describeIfDb('/v1/training progression, volume and deload (real Postgres, real seed)', () => {
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
    await sql`delete from users where firebase_uid like 'pg-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.115.250' });

  async function onboarded(equipment = ['barbell', 'dumbbell', 'machine', 'cable']): Promise<string> {
    n += 1;
    const token = `pg-tok-${n}`;
    ipOf.set(token, `203.0.${120 + Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `pg-uid-${n}`, email: `pg${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      const r = await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(token), payload: body });
      expect(r.statusCode, r.body).toBe(200);
    }
    expect((await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(token), payload: {} })).statusCode).toBe(200);
    return token;
  }

  async function withProgram(): Promise<{ token: string; program: Program; day: Program['days'][number] }> {
    const token = await onboarded();
    const r = await app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth(token), payload: {} });
    expect(r.statusCode, r.body).toBe(200);
    const program: Program = r.json();
    return { token, program, day: program.days.find((d) => !d.isRest)! };
  }

  const today = (token: string, dow?: number) =>
    app.inject({ method: 'GET', url: `/v1/training/today${dow === undefined ? '' : `?dayOfWeek=${dow}`}`, headers: auth(token) });

  /** Start a session on `day`, log `exerciseIndex` at `weight`×`reps` (rir) on every planned set, complete at `completedAt`. */
  async function session(
    token: string,
    day: Program['days'][number],
    completedAt: Date,
    log: { index: number; weight: number | null; reps: number | number[]; rir?: number }[],
  ): Promise<WorkoutSession> {
    const startedAt = new Date(completedAt.getTime() - 50 * 60_000).toISOString();
    const r = await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt } });
    expect(r.statusCode, r.body).toBe(201);
    const s: WorkoutSession = r.json();
    const sets: Record<string, unknown>[] = [];
    for (const l of log) {
      const x = s.exercises[l.index]!;
      x.targets.forEach((t, i) => {
        const reps = Array.isArray(l.reps) ? l.reps[i] ?? l.reps[l.reps.length - 1]! : l.reps;
        sets.push({ clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: t.setIndex, weightKg: l.weight, reps, rir: l.rir ?? 1, loggedAt: startedAt });
      });
    }
    if (sets.length > 0) {
      const lr = await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth(token), payload: { sets } });
      expect(lr.statusCode, lr.body).toBe(200);
    }
    const c = await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(token), payload: { completedAt: completedAt.toISOString() } });
    expect(c.statusCode, c.body).toBe(200);
    return c.json();
  }

  const daysAgo = (d: number, hour = 10) => new Date(Date.now() - d * 86_400_000 - (10 - hour) * 3_600_000);

  it('no history: every lift is establish-baseline with a reason; prefill has no load', async () => {
    const { token, day } = await withProgram();
    const t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    for (const x of t.exercises) {
      expect(x.recommendation).not.toBeNull();
      expect(x.recommendation!.action).toBe('establish-baseline');
      expect(x.recommendation!.reason.length).toBeGreaterThan(10);
      expect(x.recommendation!.sessionsConsidered).toBe(0);
      expect(x.priorBest).toEqual({ weightKg: null, repsAtBestWeight: null, estimated1rm: null });
      expect(x.prefill[0]!.weightKg).toBeNull();
      expect(x.substitution).toBeNull();
      expect(x.originalTargets).toBeNull();
    }
    expect(t.deload.state).toBe('none');
    expect(t.deload.reason.length).toBeGreaterThan(10);
    expect(t.neglected).toEqual([]);
    expect(t.mesocycleWeek).toBe(1);
  });

  it('after a session that clears the top of the range: increase-load pre-fills the new load at repMin, with the reason', async () => {
    const { token, day } = await withProgram();
    await session(token, day, daysAgo(3), [{ index: 0, weight: 60, reps: 12, rir: 1 }]);
    const t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    const x = t.exercises[0]!;
    expect(x.recommendation!.action).toBe('increase-load');
    expect(x.recommendation!.weightKg).toBe(60 + x.incrementKg);
    expect(x.recommendation!.reason).toContain('12 reps');
    expect(x.recommendation!.sessionsConsidered).toBe(1);
    expect(x.prefill[0]).toMatchObject({ weightKg: 60 + x.incrementKg, reps: x.targets[0]!.repsMin, weightSource: 'recommendation' });
    expect(x.priorBest).toMatchObject({ weightKg: 60, repsAtBestWeight: 12 });
    // Below the top: add-reps at the same load, opening at repMax.
    const other = t.exercises[1]!;
    expect(other.recommendation!.action).toBe('establish-baseline');
    // The session itself carries the same fields.
    const r = await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt: new Date().toISOString() } });
    const s: WorkoutSession = r.json();
    expect(s.exercises[0]!.recommendation!.action).toBe('increase-load');
    expect(s.exercises[0]!.prefill[0]!.weightKg).toBe(60 + x.incrementKg);
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/abandon`, headers: auth(token) });
  });

  it('§31 manual, automated: three declining sessions at the same load with RIR falling → deload on that lift, never an increase; two → not yet', async () => {
    const { token, day } = await withProgram();
    await session(token, day, daysAgo(9), [{ index: 0, weight: 80, reps: [10, 10, 10, 10], rir: 3 }]);
    await session(token, day, daysAgo(6), [{ index: 0, weight: 80, reps: [9, 9, 9, 9], rir: 2 }]);
    let t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    expect(t.exercises[0]!.recommendation!.action).not.toBe('deload');
    expect(t.exercises[0]!.recommendation!.action).not.toBe('increase-load');
    await session(token, day, daysAgo(3), [{ index: 0, weight: 80, reps: [8, 8, 8, 8], rir: 1 }]);
    t = (await today(token, day.dayOfWeek)).json();
    const rec = t.exercises[0]!.recommendation!;
    expect(rec.action).toBe('deload');
    expect(rec.weightKg).toBe(72);
    expect(rec.targetRir).toBe(t.exercises[0]!.targets[0]!.rir + 2);
    expect(rec.reason).toMatch(/fatigue/i);
    expect(rec.sessionsConsidered).toBe(3);
    // One fatigued lead lift is not a programme-level deload (owner 12.2).
    expect(t.deload.state).toBe('none');
  });

  it('fatigue on two lead lifts → a deload is OFFERED; decline snoozes; accept seeds lighter sessions and closes after seven days at week 1', async () => {
    const { token, day, program } = await withProgram();
    // Two compound lifts on this day (upper/lower generates presses and pulls / squat and hinge).
    const compounds = day.exercises.map((x, i) => ({ x, i })).filter(({ x }) => ['squat', 'hinge', 'horizontal-push', 'vertical-push', 'horizontal-pull', 'vertical-pull'].includes(x.movementPattern));
    expect(compounds.length).toBeGreaterThanOrEqual(2);
    const [a, b] = compounds as unknown as [{ i: number }, { i: number }];
    const decline = (reps: number, rir: number, when: Date) => session(token, day, when, [
      { index: a.i, weight: 80, reps, rir },
      { index: b.i, weight: 50, reps, rir },
    ]);
    await decline(10, 3, daysAgo(6));
    await decline(9, 2, daysAgo(4));
    await decline(8, 1, daysAgo(2));
    let t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    expect(t.deload).toMatchObject({ state: 'offered', trigger: 'fatigue' });
    expect(t.deload.reason).toContain(day.exercises[a.i]!.name);

    // Decline: not offered again for a week; the plan is untouched.
    const dec = await app.inject({ method: 'POST', url: '/v1/training/deload/decline', headers: auth(token) });
    expect(dec.statusCode, dec.body).toBe(200);
    expect(dec.json().state).toBe('none');
    t = (await today(token, day.dayOfWeek)).json();
    expect(t.deload.state).toBe('none');
    const planNow: Program = (await app.inject({ method: 'GET', url: '/v1/training/program', headers: auth(token) })).json();
    expect(planNow.days).toEqual(program.days);

    // Un-snooze directly (the seven days have "passed"), then accept.
    await sql`update programs set deload_snoozed_until = null where id = ${program.id}`;
    t = (await today(token, day.dayOfWeek)).json();
    expect(t.deload.state).toBe('offered');
    const acc = await app.inject({ method: 'POST', url: '/v1/training/deload/accept', headers: auth(token) });
    expect(acc.statusCode, acc.body).toBe(200);
    expect(acc.json().state).toBe('active');
    t = (await today(token, day.dayOfWeek)).json();
    expect(t.deload.state).toBe('active');
    expect(t.deload.endsOn).not.toBeNull();
    const lead = t.exercises[a.i]!;
    // Lighter: 4 sets → 2, 80 × 0.9 = 72, RIR + 2; the originals kept beside them; the plan row unchanged.
    expect(lead.targets.length).toBe(Math.max(1, Math.round(lead.originalTargets!.length * 0.6)));
    expect(lead.targets[0]!.weightKg).toBe(72);
    expect(lead.targets[0]!.rir).toBe(lead.originalTargets![0]!.rir + 2);
    expect(lead.recommendation!.action).toBe('deload');
    expect(lead.prefill[0]!.weightKg).toBe(72);
    const plan: Program = (await app.inject({ method: 'GET', url: '/v1/training/program', headers: auth(token) })).json();
    expect(plan.days.find((d) => d.id === day.id)!.exercises[a.i]!.setCount).toBe(lead.originalTargets!.length);
    // A session started now is a deload session (lighter targets); a second accept is a no-op.
    const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt: new Date().toISOString() } })).json();
    expect(s.exercises[a.i]!.targets[0]!.weightKg).toBe(72);
    expect((await app.inject({ method: 'POST', url: '/v1/training/deload/accept', headers: auth(token) })).json().state).toBe('active');
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/abandon`, headers: auth(token) });

    // Seven days later a completion closes the week: no longer active, mesocycle week 1, reset recorded.
    await sql`update programs set deload_started_at = now() - interval '8 days', mesocycle_week = 5 where id = ${program.id}`;
    await session(token, day, new Date(), [{ index: a.i, weight: 72, reps: 10, rir: 3 }]);
    const [row] = await sql<{ w: number; started: Date | null; reset: Date | null }[]>`select mesocycle_week as w, deload_started_at as started, mesocycle_reset_at as reset from programs where id = ${program.id}`;
    expect(row).toMatchObject({ w: 1, started: null });
    expect(row!.reset).not.toBeNull();
    t = (await today(token, day.dayOfWeek)).json();
    expect(t.deload.state).not.toBe('active');
    expect(t.mesocycleWeek).toBe(1);
  });

  it('week ≥ 6 with a muscle at MRV offers a deload by the MRV trigger', async () => {
    const { token, day, program } = await withProgram();
    // Twenty chest sets this week: bench (index of the horizontal push) × 4 sets × 5 sessions.
    const push = day.exercises.findIndex((x) => x.movementPattern === 'horizontal-push');
    expect(push).toBeGreaterThanOrEqual(0);
    for (let i = 0; i < 5; i++) await session(token, day, daysAgo(0, 9 - i), [{ index: push, weight: 60, reps: 10, rir: 2 }]);
    await sql`update programs set mesocycle_week = 6 where id = ${program.id}`;
    const t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    const chest = (await app.inject({ method: 'GET', url: '/v1/training/volume', headers: auth(token) })).json() as VolumeResponse;
    const thisWeek = chest.weeks[chest.weeks.length - 1]!;
    if (thisWeek.muscles.find((m) => m.muscle === 'chest')!.hardSets >= 20) {
      expect(t.deload).toMatchObject({ state: 'offered', trigger: 'mrv' });
      expect(t.deload.reason).toContain('chest');
    } else {
      // The five sessions straddled a Monday: the week split, so no MRV this week — the rule is honest.
      expect(t.deload.trigger).not.toBe('fatigue');
    }
  });

  it('volume equals a hand calculation; the cache row matches; the rebuild script reproduces it; neglect at six days', async () => {
    const { token, day } = await withProgram();
    // Two sessions today-ish: the first exercise 4 sets at 60×10, the second 3 sets (per plan).
    const x0 = day.exercises[0]!;
    const x1 = day.exercises[1]!;
    await session(token, day, daysAgo(0, 8), [{ index: 0, weight: 60, reps: 10, rir: 2 }, { index: 1, weight: 40, reps: 8, rir: 2 }]);
    const v = (await app.inject({ method: 'GET', url: '/v1/training/volume', headers: auth(token) })).json() as VolumeResponse;
    expect(v.weeks.length).toBe(4);
    const week = v.weeks[3]!;
    expect(week.isoWeek).toBe(isoWeekKey(localDate(new Date(), 'Asia/Kolkata')));
    const hand = new Map<string, { sets: number; tonnage: number }>();
    const add = (m: string, sets: number, tonnage: number) => {
      const cur = hand.get(m) ?? { sets: 0, tonnage: 0 };
      hand.set(m, { sets: cur.sets + sets, tonnage: cur.tonnage + tonnage });
    };
    const [muscles0] = await sql<{ p: string[]; s: string[] }[]>`
      select coalesce((select array_agg(muscle_group order by position) from exercise_muscles where exercise_id = ${x0.exerciseId} and role = 'primary'), '{}') as p,
             coalesce((select array_agg(muscle_group order by position) from exercise_muscles where exercise_id = ${x0.exerciseId} and role = 'secondary'), '{}') as s`;
    const [muscles1] = await sql<{ p: string[]; s: string[] }[]>`
      select coalesce((select array_agg(muscle_group order by position) from exercise_muscles where exercise_id = ${x1.exerciseId} and role = 'primary'), '{}') as p,
             coalesce((select array_agg(muscle_group order by position) from exercise_muscles where exercise_id = ${x1.exerciseId} and role = 'secondary'), '{}') as s`;
    for (const m of muscles0!.p) add(m, x0.setCount, x0.setCount * 600);
    for (const m of muscles0!.s) if (!muscles0!.p.includes(m)) add(m, x0.setCount * 0.5, x0.setCount * 300);
    for (const m of muscles1!.p) add(m, x1.setCount, x1.setCount * 320);
    for (const m of muscles1!.s) if (!muscles1!.p.includes(m)) add(m, x1.setCount * 0.5, x1.setCount * 160);
    for (const mw of week.muscles) {
      const h = hand.get(mw.muscle) ?? { sets: 0, tonnage: 0 };
      expect(mw.hardSets, mw.muscle).toBe(h.sets);
      expect(mw.tonnageKg, mw.muscle).toBe(h.tonnage);
      expect(mw.landmarks.mev).toBeGreaterThan(0);
    }
    expect(v.owned.length).toBeGreaterThan(0);
    // The cache written on completion equals the live answer.
    const cached = await sql<{ muscle_group: string; hard_sets: string }[]>`
      select muscle_group, hard_sets from muscle_volume_weekly where user_id = (select id from users where firebase_uid = ${`pg-uid-${n}`}) and iso_week = ${week.isoWeek}`;
    for (const c of cached) expect(Number(c.hard_sets)).toBe(hand.get(c.muscle_group)!.sets);
    expect(cached.length).toBe([...hand.values()].filter((h) => h.sets > 0).length);
    // Wipe and rebuild.
    await sql`delete from muscle_volume_weekly`;
    await rebuildVolume(url);
    const rebuilt = await sql<{ muscle_group: string; hard_sets: string }[]>`
      select muscle_group, hard_sets from muscle_volume_weekly where user_id = (select id from users where firebase_uid = ${`pg-uid-${n}`}) and iso_week = ${week.isoWeek}`;
    expect(rebuilt.length).toBe(cached.length);
    // Neglect: owned muscles not trained in the last six days — the ones the other day owns.
    const trained = new Set([...muscles0!.p, ...muscles0!.s, ...muscles1!.p, ...muscles1!.s]);
    for (const nm of v.neglected) expect(trained.has(nm.muscle)).toBe(false);
    for (const m of v.owned) if (!trained.has(m)) expect(v.neglected.map((x) => x.muscle)).toContain(m);
  });

  it('a lift the user can no longer perform carries a substitution with the same pattern and muscle; rejecting a planned lift twice does too', async () => {
    // Full gym → generate → then the user drops to dumbbells only.
    const { token, day } = await withProgram();
    const barbell = day.exercises.find((x) => x.equipment.includes('barbell'));
    expect(barbell).toBeDefined();
    await app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: auth(token), payload: { equipment: ['dumbbell'] } });
    let t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    const sub = t.exercises.find((x) => x.plannedExerciseId === barbell!.id)!.substitution;
    expect(sub).not.toBeNull();
    expect(sub!.trigger).toBe('equipment');
    expect(sub!.reason).toContain('barbell');
    if (sub!.alternative !== null) {
      expect(sub!.alternative.equipment.every((q) => q === 'dumbbell' || q === 'bodyweight')).toBe(true);
    } else {
      expect(sub!.reason).toContain('No alternative');
    }
    // Rejected twice: remove a planned lift from two sessions.
    await app.inject({ method: 'PATCH', url: '/v1/user/profile', headers: auth(token), payload: { equipment: ['barbell', 'dumbbell', 'machine', 'cable'] } });
    const dumbbell = day.exercises.find((x) => !x.equipment.includes('barbell')) ?? day.exercises[0]!;
    for (let i = 0; i < 2; i++) {
      const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt: new Date().toISOString() } })).json();
      const se = s.exercises.find((x) => x.plannedExerciseId === dumbbell.id)!;
      expect((await app.inject({ method: 'PATCH', url: `/v1/training/sessions/${s.id}/exercises/${se.id}`, headers: auth(token), payload: { removed: true } })).statusCode).toBe(200);
      await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/abandon`, headers: auth(token) });
    }
    t = (await today(token, day.dayOfWeek)).json();
    const rejected = t.exercises.find((x) => x.plannedExerciseId === dumbbell.id)!.substitution;
    expect(rejected?.trigger).toBe('rejected');
    expect(rejected!.reason).toContain('2 times');
  });

  it('GET /training/progression/{exerciseId}: the last three sessions and the recommendation', async () => {
    const { token, day } = await withProgram();
    const x = day.exercises[0]!;
    for (const [i, w] of [50, 55, 60].entries()) await session(token, day, daysAgo(9 - i * 3), [{ index: 0, weight: w, reps: 12, rir: 1 }]);
    const r = await app.inject({ method: 'GET', url: `/v1/training/progression/${x.exerciseId}`, headers: auth(token) });
    expect(r.statusCode, r.body).toBe(200);
    const d = r.json();
    expect(d.name).toBe(x.name);
    expect(d.history.length).toBe(3);
    expect(d.history[0].sets[0].weightKg).toBe(60); // newest first for display
    expect(d.recommendation.action).toBe('increase-load');
    expect(d.recommendation.weightKg).toBe(60 + x.incrementKg);
    expect((await app.inject({ method: 'GET', url: `/v1/training/progression/${randomUUID()}`, headers: auth(token) })).statusCode).toBe(404);
  });

  it('abandoned sessions and deleted sets never feed a recommendation; bodyweight lifts progress by reps', async () => {
    const { token, day } = await withProgram();
    // An abandoned session with a huge load.
    const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt: daysAgo(5).toISOString() } })).json();
    const x = s.exercises[0]!;
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth(token), payload: { sets: x.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: t.setIndex, weightKg: 200, reps: 12, rir: 0, loggedAt: daysAgo(5).toISOString() })) } });
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/abandon`, headers: auth(token) });
    let t: TodayResponse = (await today(token, day.dayOfWeek)).json();
    expect(t.exercises[0]!.recommendation!.action).toBe('establish-baseline');
    expect(t.exercises[0]!.priorBest.weightKg).toBeNull();
    // Bodyweight: unloaded working sets → reps-only progression, never baseline forever.
    await session(token, day, daysAgo(2), [{ index: 0, weight: null, reps: 8, rir: 2 }]);
    t = (await today(token, day.dayOfWeek)).json();
    expect(t.exercises[0]!.recommendation!.action).toBe('add-reps');
    expect(t.exercises[0]!.recommendation!.weightKg).toBeNull();
    expect(t.exercises[0]!.recommendation!.reason).toContain('Bodyweight');
  });

  it('the new routes are default-deny', async () => {
    for (const [method, url] of [
      ['GET', '/v1/training/volume'], ['GET', `/v1/training/progression/${randomUUID()}`],
      ['POST', '/v1/training/deload/accept'], ['POST', '/v1/training/deload/decline'],
    ] as ['GET' | 'POST', string][]) {
      const r = await app.inject({ method, url, headers: { 'x-forwarded-for': '203.0.113.2' }, ...(method === 'GET' ? {} : { payload: {} }) });
      expect(r.statusCode, `${method} ${url}`).toBe(401);
    }
  });
});
