/**
 * /v1/recovery on real Postgres with the real exercise seed (Phase 13,
 * ADR-019): the check-in upsert and its rules, readiness computed on read
 * (equal to core, only from available inputs), the three-day escalation into
 * the Phase 6 deload OFFER, TODAY's advisory low-readiness action — and the
 * §31 test that low readiness never silently mutates the plan.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  CURRENT_POLICY_VERSION,
  recoveryTodaySchema,
  todayActionsResponseSchema,
  type Program,
  type RecoveryToday,
  type TodayActionsResponse,
  type TodayResponse,
  type WorkoutSession,
} from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { readinessOn } from '@fitos/core/recovery/readiness';
import { COMPOUND, type CatalogueExercise } from '@fitos/core/training/generator';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { isoDayOfWeek } from '../workout/service.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

/** A fixed-offset zone whose local hour is `hour` right now (as the TODAY suite does). */
function zoneAt(hour: number): string {
  let o = hour - new Date().getUTCHours();
  if (o > 14) o -= 24;
  if (o < -12) o += 24;
  return o === 0 ? 'Etc/GMT' : o > 0 ? `Etc/GMT-${o}` : `Etc/GMT+${-o}`;
}

describeIfDb('/v1/recovery (real Postgres, real seed)', { timeout: 90_000 }, () => {
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
    await sql`delete from users where firebase_uid like 'rc-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
    tz: string;
  }
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.180.250' });

  async function bare(tz = zoneAt(12)): Promise<U> {
    n += 1;
    const token = `rc-tok-${n}`;
    ipOf.set(token, `203.0.${180 + Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `rc-uid-${n}`, email: `rc${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`rc-uid-${n}`}`;
    await sql`update users set timezone = ${tz} where id = ${row!.id}`;
    return { token, id: row!.id, tz };
  }

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  /** Onboarded (full gym), programme generated, its first training day moved onto today's weekday. */
  async function training(tz = zoneAt(12)): Promise<U & { day: Program['days'][number] }> {
    const u = await bare(tz);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Recovery', sex: 'female', birthDate: '2004-06-01', heightCm: 165, weightKg: 60, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: 'non-vegetarian', allergies: [] },
    ]) {
      const r = await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(u.token), payload: body });
      expect(r.statusCode, r.body).toBe(200);
    }
    expect((await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(u.token), payload: {} })).statusCode).toBe(200);
    const g = await app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth(u.token), payload: {} });
    expect(g.statusCode, g.body).toBe(200);
    const program: Program = g.json();
    const day = program.days.find((d) => !d.isRest)!;
    const dow = isoDayOfWeek(localDateOf(new Date(), tz));
    if (day.dayOfWeek !== dow) {
      await sql`delete from program_days where program_id = ${program.id} and day_of_week = ${dow}`;
      await sql`update program_days set day_of_week = ${dow} where id = ${day.id}`;
    }
    return { ...u, day: { ...day, dayOfWeek: dow } };
  }

  const today = (u: U) => localDateOf(new Date(), u.tz);
  const log = (u: U, body: Record<string, unknown>) => app.inject({ method: 'POST', url: '/v1/recovery/log', headers: auth(u.token), payload: body });
  const recovery = async (u: U): Promise<RecoveryToday> => {
    const r = await app.inject({ method: 'GET', url: '/v1/recovery/today', headers: auth(u.token) });
    expect(r.statusCode, r.body).toBe(200);
    return recoveryTodaySchema.parse(r.json());
  };
  const workoutToday = async (u: U): Promise<TodayResponse> =>
    (await app.inject({ method: 'GET', url: '/v1/training/today', headers: auth(u.token) })).json();
  const todayActions = async (u: U): Promise<TodayActionsResponse> => {
    const r = await app.inject({ method: 'GET', url: '/v1/today', headers: auth(u.token) });
    expect(r.statusCode, r.body).toBe(200);
    return todayActionsResponseSchema.parse(r.json());
  };
  const ev = (u: U, id: string, event: string) =>
    app.inject({ method: 'POST', url: `/v1/today/actions/${id}/event`, headers: auth(u.token), payload: { clientEventId: randomUUID(), event, occurredAt: new Date().toISOString() } });
  const issue = (r: { json: () => unknown }) => (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  /** A poor day: 3 h sleep (25), very sore (20), drained (20). */
  const POOR = { sleepHours: 3, soreness: 5, energy: 1 };

  /** Missed nutrition on the days before `through` (both marks), against an old target — the adherence gap is 10. */
  async function missedFood(u: U, days: number): Promise<void> {
    await sql`
      insert into nutrition_targets (user_id, effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale, reason)
      values (${u.id}, '2026-01-01', 2200, 120, 250, 70, 30, 1500, 2300, ${sql.json(['test'])}, 'onboarding')
      on conflict do nothing`;
    for (let i = 1; i <= days; i++) {
      await sql`insert into daily_nutrition (user_id, local_date, kcal_low, kcal_high, protein_low, protein_high, item_count)
        values (${u.id}, ${addDays(today(u), -i)}, 500, 600, 10, 20, 3) on conflict do nothing`;
    }
  }

  /* ------------------------------------------------------------ access -- */

  it('401 without a session on both endpoints; /recovery/health-sync is not built (V2)', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/recovery/today' })).statusCode).toBe(401);
    expect((await app.inject({ method: 'POST', url: '/v1/recovery/log', payload: { soreness: 2 } })).statusCode).toBe(401);
    const u = await bare();
    expect((await app.inject({ method: 'POST', url: '/v1/recovery/health-sync', headers: auth(u.token), payload: {} })).statusCode).toBe(404);
  });

  it('nothing logged: today\'s date, no log, no readiness (nothing guessed)', async () => {
    const u = await bare();
    expect(await recovery(u)).toEqual({ date: today(u), log: null, readiness: null });
  });

  /* ------------------------------------------------------------ writes -- */

  it('upsert on the local date: 201 new, 200 replaced — the day\'s check-in is replaced by what is sent', async () => {
    const u = await bare();
    const first = await log(u, { sleepHours: 7.46, sleepQuality: 4, soreness: 2, energy: 4, stress: 2 });
    expect(first.statusCode, first.body).toBe(201);
    expect(first.json()).toEqual({ log: { date: today(u), sleepHours: 7.5, sleepQuality: 4, soreness: 2, energy: 4, stress: 2, source: 'manual' } });
    const again = await log(u, { soreness: 4 });
    expect(again.statusCode).toBe(200);
    expect(again.json().log).toEqual({ date: today(u), sleepHours: null, sleepQuality: null, soreness: 4, energy: null, stress: null, source: 'manual' });
    const rows = await sql`select 1 from recovery_logs where user_id = ${u.id}`;
    expect(rows.length).toBe(1);
    expect((await recovery(u)).log?.soreness).toBe(4);
  });

  it('validation: at least one value; the scales 1–5; sleep 0–24; strict body', async () => {
    const u = await bare();
    const none = await log(u, {});
    expect(none.statusCode).toBe(422);
    expect(issue(none)).toBe('at least one value');
    expect((await log(u, { soreness: null, energy: null })).statusCode).toBe(422);
    for (const bad of [{ soreness: 0 }, { energy: 6 }, { stress: 1.5 }, { sleepHours: 25 }, { sleepHours: -1 }, { mood: 2 }, { readiness: 90 }]) {
      expect((await log(u, bad)).statusCode, JSON.stringify(bad)).toBe(422);
    }
    expect((await sql`select 1 from recovery_logs where user_id = ${u.id}`).length).toBe(0);
  });

  it('dates: up to 7 days back, never ahead, a real date', async () => {
    const u = await bare();
    expect((await log(u, { date: addDays(today(u), -7), soreness: 2 })).statusCode).toBe(201);
    const old = await log(u, { date: addDays(today(u), -8), soreness: 2 });
    expect(old.statusCode).toBe(422);
    expect(issue(old)).toBe('more than 7 days ago');
    const ahead = await log(u, { date: addDays(today(u), 1), soreness: 2 });
    expect(ahead.statusCode).toBe(422);
    expect(issue(ahead)).toBe('in the future');
    expect(issue(await log(u, { date: '2026-02-30', soreness: 2 }))).toBe('not a date');
  });

  it('the stored timezone decides "today", either side of the date line', async () => {
    const east = await bare('Pacific/Kiritimati'); // UTC+14
    const west = await bare('Etc/GMT+11'); // UTC−11
    expect((await log(east, { soreness: 2 })).json().log.date).toBe(localDateOf(new Date(), 'Pacific/Kiritimati'));
    expect((await log(west, { soreness: 2 })).json().log.date).toBe(localDateOf(new Date(), 'Etc/GMT+11'));
    expect((await recovery(east)).date).toBe(localDateOf(new Date(), 'Pacific/Kiritimati'));
    expect((await recovery(west)).date).toBe(localDateOf(new Date(), 'Etc/GMT+11'));
  });

  it('isolation: one user never sees another\'s check-in or readiness', async () => {
    const a = await bare();
    const b = await bare();
    expect((await log(a, POOR)).statusCode).toBe(201);
    expect(await recovery(b)).toEqual({ date: today(b), log: null, readiness: null });
    expect((await sql`select 1 from recovery_logs where user_id = ${b.id}`).length).toBe(0);
  });

  /* --------------------------------------------------------- readiness -- */

  it('readiness equals core over the same records; only available inputs count', async () => {
    const u = await bare();
    await log(u, { date: addDays(today(u), -1), sleepHours: 5 });
    await log(u, { sleepHours: 6, soreness: 3, energy: 3, stress: 5, sleepQuality: 1 });
    const r = (await recovery(u)).readiness!;
    // (1.5 + 2.5) / 2 h short → 20; soreness 10; energy 10; no training or food → not available.
    expect(r).toMatchObject({ score: 60, band: 'advisory', lowDays: 0 });
    expect(r.components).toEqual([
      { key: 'sleep', penalty: 20, max: 25, available: true },
      { key: 'soreness', penalty: 10, max: 20, available: true },
      { key: 'energy', penalty: 10, max: 20, available: true },
      { key: 'performance', penalty: 0, max: 25, available: false },
      { key: 'adherence', penalty: 0, max: 10, available: false },
    ]);
    const core = readinessOn({
      day: today(u),
      checkIns: [
        { date: addDays(today(u), -1), sleepHours: 5, sleepQuality: null, soreness: null, energy: null, stress: null },
        { date: today(u), sleepHours: 6, sleepQuality: 1, soreness: 3, energy: 3, stress: 5 },
      ],
      lifts: [],
      nutritionDays: [],
      targets: [],
    })!;
    expect(r.score).toBe(core.score);
    expect(r.advice).toBe(core.advice);
  });

  it('missing data degrades gracefully: one answer gives a readiness from that answer alone', async () => {
    const u = await bare();
    await log(u, { energy: 2 });
    const r = (await recovery(u)).readiness!;
    expect(r.score).toBe(85);
    expect(r.components.filter((c) => c.available).map((c) => c.key)).toEqual(['energy']);
    // Yesterday's check-in alone is not today's readiness.
    const v = await bare();
    await log(v, { date: addDays(today(v), -1), ...POOR });
    expect((await recovery(v)).readiness).toBeNull();
  });

  it('the nutrition gap counts the 7 days before today, from logged days only', async () => {
    const u = await bare();
    await missedFood(u, 3);
    await log(u, { soreness: 1 });
    const r = (await recovery(u)).readiness!;
    expect(r.components.find((c) => c.key === 'adherence')).toEqual({ key: 'adherence', penalty: 10, max: 10, available: true });
    expect(r.score).toBe(90);
  });

  /* -------------------------------------------------------- escalation -- */

  async function poorDays(u: U, days: number, endingDaysAgo = 0): Promise<void> {
    await missedFood(u, 10 + endingDaysAgo);
    for (let i = endingDaysAgo + days - 1; i >= endingDaysAgo; i--) {
      const r = await log(u, { date: addDays(today(u), -i), ...POOR });
      expect(r.statusCode, r.body).toBe(201);
    }
  }

  const plannedSets = async (u: U) =>
    sql`select ps.id, pe.set_count, pe.rep_min, pe.rep_max, ps.set_index, ps.reps_min, ps.reps_max, ps.rir, ps.weight_kg from planned_sets ps
        join planned_exercises pe on pe.id = ps.planned_exercise_id
        join program_days pd on pd.id = pe.program_day_id
        join programs p on p.id = pd.program_id
        where p.user_id = ${u.id} order by ps.id`;
  const deloadColumns = async (u: U) =>
    sql`select deload_started_at, deload_snoozed_until from programs where user_id = ${u.id} and active`;

  it('§31: three poor days running → the deload is OFFERED (trigger readiness) and resting is suggested — the plan itself never changes', async () => {
    const u = await training();
    const before = { exercises: (await workoutToday(u)).exercises, sets: await plannedSets(u), deload: await deloadColumns(u) };
    expect((await workoutToday(u)).deload.state).toBe('none');

    await poorDays(u, 3);
    const rec = await recovery(u);
    expect(rec.readiness).toMatchObject({ score: 25, band: 'rest', lowDays: 3 });

    const day = await workoutToday(u);
    expect(day.deload).toMatchObject({ state: 'offered', trigger: 'readiness' });
    expect(day.deload.reason).toContain('under 35 for 3 days running');
    // The same offer wherever the deload state is read.
    const vol = (await app.inject({ method: 'GET', url: '/v1/training/volume', headers: auth(u.token) })).json();
    expect(vol.deload).toMatchObject({ state: 'offered', trigger: 'readiness' });

    const t = await todayActions(u);
    const deload = t.actions.find((a) => a.kind === 'deload')!;
    expect(deload).toMatchObject({ rank: 1, priority: 95, reason: { code: 'deload-offered', values: { trigger: 'readiness' } } });
    const low = t.actions.find((a) => a.kind === 'low-readiness')!;
    expect(low).toMatchObject({ priority: 89, subjectKey: 'rest', target: 'train', reason: { code: 'readiness-low', values: { readiness: 25, band: 'rest', accessories: [], lowDays: 3 } } });

    // Advice only: shown, accepted — and still nothing in the plan moved; low-readiness is never "completed".
    expect((await ev(u, low.id, 'shown')).statusCode).toBe(201);
    expect((await ev(u, low.id, 'accepted')).statusCode).toBe(201);
    const done = await ev(u, low.id, 'completed');
    expect(done.statusCode).toBe(422);
    expect(issue(done)).toBe('not-completable');
    expect({ exercises: (await workoutToday(u)).exercises, sets: await plannedSets(u), deload: await deloadColumns(u) }).toEqual(before);

    // Only the user's own accept starts the lighter week (Phase 6, unchanged).
    const accept = await app.inject({ method: 'POST', url: '/v1/training/deload/accept', headers: auth(u.token) });
    expect(accept.statusCode, accept.body).toBe(200);
    expect(accept.json()).toMatchObject({ state: 'active' });
  });

  it('two poor days are not enough; a better day breaks the run; the declined offer stays snoozed', async () => {
    const two = await training();
    await poorDays(two, 2);
    expect((await recovery(two)).readiness?.lowDays).toBe(2);
    expect((await workoutToday(two)).deload.state).toBe('none');

    const broken = await training();
    await poorDays(broken, 2, 1); // yesterday and the day before
    await log(broken, { date: addDays(today(broken), -3), sleepHours: 8, soreness: 1, energy: 5 });
    await log(broken, { sleepHours: 8, soreness: 1, energy: 5 }); // today is fine
    expect((await recovery(broken)).readiness).toMatchObject({ lowDays: 0 });
    expect((await workoutToday(broken)).deload.state).toBe('none');

    const declined = await training();
    await poorDays(declined, 3);
    expect((await workoutToday(declined)).deload.state).toBe('offered');
    expect((await app.inject({ method: 'POST', url: '/v1/training/deload/decline', headers: auth(declined.token) })).statusCode).toBe(200);
    expect((await workoutToday(declined)).deload.state).toBe('none');
  });

  it('before today\'s check-in, a run ending yesterday still offers the deload', async () => {
    const u = await training();
    await poorDays(u, 3, 1);
    expect((await recovery(u)).readiness).toBeNull();
    expect((await workoutToday(u)).deload).toMatchObject({ state: 'offered', trigger: 'readiness' });
  });

  /* ------------------------------------------------------------- TODAY -- */

  it('TODAY: the reduce band names today\'s accessories; dismissing hides it for the day', async () => {
    const u = await training();
    await log(u, { sleepHours: 3, soreness: 5, energy: 3 }); // 25 + 20 + 10 → 45
    expect((await recovery(u)).readiness).toMatchObject({ score: 45, band: 'reduce' });
    const plan = await workoutToday(u);
    const accessories = [...new Set(plan.exercises.filter((x) => !COMPOUND.has(x.movementPattern as CatalogueExercise['movementPattern'])).map((x) => x.name))];
    expect(accessories.length).toBeGreaterThan(0);
    const low = (await todayActions(u)).actions.find((a) => a.kind === 'low-readiness')!;
    expect(low).toMatchObject({ subjectKey: 'fewer-sets', reason: { values: { readiness: 45, band: 'reduce', accessories, lowDays: 0 } } });
    expect(low.headline).toBe('Readiness 45: one fewer set on accessories');
    expect((await ev(u, low.id, 'shown')).statusCode).toBe(201);
    expect((await ev(u, low.id, 'dismissed')).statusCode).toBe(201);
    expect((await todayActions(u)).actions.some((a) => a.kind === 'low-readiness')).toBe(false);
    expect((await workoutToday(u)).exercises).toEqual(plan.exercises);
  });

  it('TODAY: no action for the ready or advisory bands; the rest day carries readiness (§16.2)', async () => {
    const u = await training();
    await log(u, { sleepHours: 6.5, soreness: 2, energy: 4 }); // 10 + 5 + 5 → 80
    expect((await todayActions(u)).actions.some((a) => a.kind === 'low-readiness')).toBe(false);
    const rest = await bare();
    await log(rest, { soreness: 3 });
    const action = (await todayActions(rest)).actions.find((a) => a.kind === 'rest-day')!;
    expect(action.reason.values).toMatchObject({ readiness: 90 });
    expect(action.detail).toContain('Readiness today: 90.');
  });

  /* ------------------------------------------------------- performance -- */

  it('p95 of GET /recovery/today under 300 ms with two weeks of check-ins, training history and food', async () => {
    const u = await training();
    await missedFood(u, 14);
    for (let i = 7; i >= 0; i--) await log(u, { date: addDays(today(u), -i), sleepHours: 6 + (i % 3), soreness: 1 + (i % 5), energy: 5 - (i % 4) });
    const plan = await workoutToday(u);
    for (const ago of [9, 6, 3]) {
      const completedAt = new Date(Date.now() - ago * 86_400_000);
      const startedAt = new Date(completedAt.getTime() - 50 * 60_000).toISOString();
      const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(u.token), payload: { clientSessionId: randomUUID(), programDayId: u.day.id, startedAt } })).json();
      const sets = s.exercises.slice(0, 3).flatMap((x) => x.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: t.setIndex, weightKg: 50, reps: 10 - Math.floor(ago / 3), rir: 2, loggedAt: startedAt })));
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth(u.token), payload: { sets } })).statusCode).toBe(200);
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(u.token), payload: { completedAt: completedAt.toISOString() } })).statusCode).toBe(200);
    }
    expect(plan.exercises.length).toBeGreaterThan(0);
    expect((await recovery(u)).readiness?.components.find((c) => c.key === 'performance')?.available).toBe(true);
    const times: number[] = [];
    for (let i = 0; i < 40; i++) {
      const t0 = performance.now();
      const r = await app.inject({ method: 'GET', url: '/v1/recovery/today', headers: auth(u.token) });
      times.push(performance.now() - t0);
      expect(r.statusCode).toBe(200);
    }
    times.sort((a, b) => a - b);
    const p50 = times[Math.floor(times.length * 0.5)]!;
    const p95 = times[Math.floor(times.length * 0.95)]!;
    console.log(`GET /v1/recovery/today p50 ${p50.toFixed(1)} ms, p95 ${p95.toFixed(1)} ms (n=40)`);
    expect(p95).toBeLessThan(300);
  });
});
