/**
 * Beta 4.1 (ADR-039) on real Postgres: running plans (made by core, one
 * active, the old one's future runs gone), skipping and moving a planned run,
 * a run doing the day's planned run (and undoing it when deleted), workouts
 * and laps on a run, the ready-made sessions, today's planned run in TODAY,
 * running load in readiness (the sixth part only for builds that know it),
 * and runs in the streak and the weekly ring.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  currentPlanSchema,
  recoveryTodaySchema,
  runDetailSchema,
  runningPlanSchema,
  streakSchema,
  todayActionsResponseSchema,
  workoutPresetsSchema,
  type CreatePlanRequest,
  type CreateRunRequest,
  type RunningPlan,
} from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';
import { generatePlan } from '@fitos/core/running/plan';
import { type EncodedTrack } from '@fitos/core/running/track';
import { vdotFromRace, zones } from '@fitos/core/running/vdot';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;
const TZ = 'Asia/Kolkata';

const fixtures = join(dirname(fileURLToPath(import.meta.url)), '../../../../../packages/core/test/fixtures/running');
const fixture = (name: string) =>
  JSON.parse(readFileSync(join(fixtures, `${name}.json`), 'utf8')) as { track: EncodedTrack; durationSeconds: number };

describeIfDb('/v1/running plans (beta 4.1, real Postgres)', { timeout: 120_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    await sql`delete from feature_flags where key = 'running'`;
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'rp-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const headers = (u: U, build?: number) => ({
    authorization: `Bearer ${u.token}`,
    'x-forwarded-for': `203.0.191.${n % 250}`,
    ...(build === undefined ? {} : { 'x-fitos-build': String(build) }),
  });

  async function user(): Promise<U> {
    n += 1;
    const token = `rp-tok-${n}`;
    verifier.accept(token, { uid: `rp-uid-${n}`, email: `rp${n}@vit.ac.in` });
    const u = { token, id: '' };
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(u), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`rp-uid-${n}`}`;
    await sql`update users set timezone = ${TZ} where id = ${row!.id}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PATCH' | 'DELETE', path: string, payload?: unknown, build?: number) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u, build), ...(payload === undefined ? {} : { payload: payload as object }) });

  const today = () => localDateOf(new Date(), TZ);
  /** Three running days that include today, the long run another of them. */
  const daysWithToday = () => {
    const d = isoWeekday(today());
    const days = [d, (d % 7) + 1, ((d + 2) % 7) + 1].sort((a, b) => a - b);
    return { weekdays: days, longRunWeekday: days.find((x) => x !== d)! };
  };
  const tenK = (over: Partial<CreatePlanRequest> = {}): CreatePlanRequest => ({
    goal: '10k',
    level: 'runner',
    race: { distance: '5k', seconds: 1500 },
    goalSeconds: null,
    daysPerWeek: 3,
    ...daysWithToday(),
    ...over,
  });

  function outdoorRun(startedAt: Date, over: Partial<CreateRunRequest> = {}): CreateRunRequest {
    const f = fixture('easy-loop');
    return {
      clientRunId: randomUUID(),
      kind: 'outdoor',
      name: 'Run',
      startedAt: startedAt.toISOString(),
      endedAt: new Date(startedAt.getTime() + (f.durationSeconds + 60) * 1000).toISOString(),
      durationSeconds: f.durationSeconds,
      goal: { kind: 'free', value: null },
      track: { ...f.track, breaks: [...f.track.breaks] },
      ...over,
    };
  }

  it('makes a plan with core’s runs and zones; a second plan stops the first and drops its runs to come', async () => {
    const u = await user();
    expect(currentPlanSchema.parse((await call(u, 'GET', '/running/plans/current')).json()).plan).toBeNull();
    const res = await call(u, 'POST', '/running/plans', tenK());
    expect(res.statusCode).toBe(201);
    const plan = runningPlanSchema.parse(res.json());
    const vdot = vdotFromRace(5000, 1500);
    const core = generatePlan({ goal: '10k', level: 'runner', vdot, daysPerWeek: 3, ...daysWithToday(), startDate: today() });
    expect(plan).toMatchObject({ goal: '10k', level: 'runner', status: 'active', weeks: 8, startDate: today(), predictedSeconds: core.predictedSeconds });
    expect(plan.zones).toEqual(zones(vdot));
    expect(plan.runs.map((r) => [r.date, r.kind, r.title])).toEqual(core.runs.map((r) => [r.date, r.kind, r.title]));
    expect(plan.runs.every((r) => r.status === 'planned')).toBe(true);
    expect(plan.gymOverlap).toEqual([]);

    const again = runningPlanSchema.parse((await call(u, 'POST', '/running/plans', tenK({ goal: 'half' }))).json());
    expect(again.goal).toBe('half');
    const [old] = await sql<{ status: string }[]>`select status::text from running_plans where id = ${plan.id}`;
    expect(old!.status).toBe('stopped');
    const [left] = await sql<{ n: number }[]>`select count(*)::int as n from planned_runs where plan_id = ${plan.id}`;
    expect(left!.n).toBe(0);
    expect(currentPlanSchema.parse((await call(u, 'GET', '/running/plans/current')).json()).plan!.id).toBe(again.id);

    expect((await call(u, 'DELETE', '/running/plans/current')).statusCode).toBe(204);
    expect((await call(u, 'DELETE', '/running/plans/current')).statusCode).toBe(404);
    expect(currentPlanSchema.parse((await call(u, 'GET', '/running/plans/current')).json()).plan).toBeNull();
  });

  it('a beginner 5K from a goal-less start; plans that cannot be made are refused', async () => {
    const u = await user();
    const beginner = await call(u, 'POST', '/running/plans', { ...tenK({ goal: '5k', level: 'beginner', race: null }) });
    expect(beginner.statusCode).toBe(201);
    expect(beginner.json()).toMatchObject({ level: 'beginner', zones: null, predictedSeconds: null });
    expect((await call(u, 'POST', '/running/plans', tenK({ level: 'beginner', race: null }))).statusCode).toBe(422);
    expect((await call(u, 'POST', '/running/plans', tenK({ race: null }))).statusCode).toBe(422);
    expect((await call(u, 'POST', '/running/plans', tenK({ startDate: addDays(today(), -1) }))).statusCode).toBe(422);
    const goal = await call(u, 'POST', '/running/plans', tenK({ race: null, goalSeconds: 2700 }));
    expect(goal.statusCode).toBe(201);
    expect(goal.json<RunningPlan>().zones!.vdot).toBe(vdotFromRace(10_000, 2700));
  });

  it('skips, un-skips and moves a planned run within its week; a done run stays put', async () => {
    const u = await user();
    const plan = (await call(u, 'POST', '/running/plans', tenK())).json<RunningPlan>();
    const later = plan.runs.find((r) => r.week === 2)!;
    expect((await call(u, 'PATCH', `/running/planned/${later.id}`, { action: 'skip' })).json()).toMatchObject({ status: 'skipped' });
    expect((await call(u, 'PATCH', `/running/planned/${later.id}`, { action: 'unskip' })).json()).toMatchObject({ status: 'planned' });
    const monday = addDays(later.date, 1 - isoWeekday(later.date));
    const target = addDays(monday, 6) === later.date ? monday : addDays(monday, 6);
    const moved = (await call(u, 'PATCH', `/running/planned/${later.id}`, { action: 'move', date: target })).json();
    expect(moved).toMatchObject({ date: target, movedFrom: later.date, status: 'planned' });
    expect((await call(u, 'PATCH', `/running/planned/${later.id}`, { action: 'move', date: addDays(monday, 7) })).statusCode).toBe(422);
    expect((await call(u, 'PATCH', `/running/planned/${later.id}`, { action: 'move' })).statusCode).toBe(422);
    expect((await call(await user(), 'PATCH', `/running/planned/${later.id}`, { action: 'skip' })).statusCode).toBe(404);

    // Today's run is done by a run today; then it can be neither skipped nor moved.
    const todays = plan.runs.find((r) => r.date === today())!;
    const run = runDetailSchema.parse((await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - 3_600_000)))).json());
    expect(run.plannedRunId).toBe(todays.id);
    expect((await call(u, 'PATCH', `/running/planned/${todays.id}`, { action: 'skip' })).statusCode).toBe(409);
  });

  it('a run does the day’s planned run once; deleting it plans it again; a named planned run must be the user’s', async () => {
    const u = await user();
    const plan = (await call(u, 'POST', '/running/plans', tenK())).json<RunningPlan>();
    const todays = plan.runs.find((r) => r.date === today())!;
    const first = runDetailSchema.parse((await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - 7_200_000)))).json());
    const second = runDetailSchema.parse((await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - 3_600_000)))).json());
    expect(first.plannedRunId).toBe(todays.id);
    expect(second.plannedRunId).toBeNull();
    expect(runDetailSchema.parse((await call(u, 'GET', `/running/runs/${first.id}`)).json()).plannedRunId).toBe(todays.id);
    const [done] = await sql<{ status: string }[]>`select status::text from planned_runs where id = ${todays.id}`;
    expect(done!.status).toBe('done');

    expect((await call(u, 'DELETE', `/running/runs/${first.id}`)).statusCode).toBe(204);
    const [back] = await sql<{ status: string; run_id: string | null }[]>`select status::text, run_id from planned_runs where id = ${todays.id}`;
    expect(back).toEqual({ status: 'planned', run_id: null });

    // Naming it links it, even another day's run.
    const week2 = plan.runs.find((r) => r.week === 2)!;
    const named = runDetailSchema.parse((await call(u, 'POST', '/running/runs', outdoorRun(new Date(), { plannedRunId: week2.id }))).json());
    expect(named.plannedRunId).toBe(week2.id);
    expect((await call(u, 'POST', '/running/runs', outdoorRun(new Date(), { plannedRunId: randomUUID() }))).statusCode).toBe(404);
  });

  it('a structured run keeps its workout; its laps are measured on the track', async () => {
    const u = await user();
    const steps = [
      { kind: 'warmup', distanceM: null, seconds: 300, pace: null, effort: 'easy', rep: null },
      { kind: 'work', distanceM: 1000, seconds: null, pace: { fast: 280, slow: 290 }, effort: 'hard', rep: { index: 1, of: 1 } },
    ] as const;
    const req = outdoorRun(new Date(Date.now() - 3_600_000), {
      workout: { name: 'Test reps', steps: [...steps] },
      laps: [
        { step: 0, startT: 0, endT: 300 },
        { step: 1, startT: 300, endT: 640 },
      ],
    });
    const run = runDetailSchema.parse((await call(u, 'POST', '/running/runs', req)).json());
    expect(run.workout!.name).toBe('Test reps');
    expect(run.laps.map((l) => l.step)).toEqual([0, 1]);
    expect(run.laps[0]!.seconds).toBeGreaterThan(290);
    expect(run.laps[1]!.distanceM).toBeGreaterThan(0);
    const noWorkout: Partial<CreateRunRequest> = { ...req, clientRunId: randomUUID() };
    delete noWorkout.workout;
    expect((await call(u, 'POST', '/running/runs', noWorkout)).statusCode).toBe(422);
    const badLaps = { ...req, clientRunId: randomUUID(), laps: [{ step: 5, startT: 0, endT: 10 }] };
    const refused = await call(u, 'POST', '/running/runs', badLaps);
    expect(refused.statusCode).toBe(422);
    expect(refused.json().error.details[0].path).toBe('laps');
  });

  it('the ready-made sessions: effort words without a plan, paces with one', async () => {
    const u = await user();
    const bare = workoutPresetsSchema.parse((await call(u, 'GET', '/running/workouts')).json());
    expect(bare.zones).toBeNull();
    expect(bare.presets.map((p) => p.id)).toEqual(['6x400', '5x1k', '8x200-strides', '10x1min', '3x2k-tempo']);
    await call(u, 'POST', '/running/plans', tenK());
    const paced = workoutPresetsSchema.parse((await call(u, 'GET', '/running/workouts')).json());
    expect(paced.zones).toEqual(zones(vdotFromRace(5000, 1500)));
    expect(paced.presets[1]!.steps.find((s) => s.kind === 'work')!.pace).not.toBeNull();
  });

  it('TODAY: the plan’s run for today, not a rest day; done once a run does it', async () => {
    const u = await user();
    const plan = (await call(u, 'POST', '/running/plans', tenK())).json<RunningPlan>();
    const todays = plan.runs.find((r) => r.date === today())!;
    const got = await call(u, 'GET', '/today');
    expect(got.statusCode, got.body).toBe(200);
    const before = todayActionsResponseSchema.parse(got.json());
    const action = before.actions.find((a) => a.kind === 'start-run')!;
    expect(action).toMatchObject({ headline: todays.title, target: 'train' });
    expect(action.detail).toContain('From your running plan.');
    expect(before.actions.some((a) => a.kind === 'rest-day')).toBe(false);

    // Completed is proven by the server's own records: refused before the run, recorded after.
    const ev = (name: string) =>
      call(u, 'POST', `/today/actions/${action.id}/event`, { clientEventId: randomUUID(), event: name, occurredAt: new Date().toISOString() });
    expect((await ev('shown')).statusCode).toBe(201);
    expect((await ev('accepted')).statusCode).toBe(201);
    expect((await ev('completed')).statusCode).toBe(422);
    await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - 3_600_000)));
    expect((await ev('completed')).statusCode).toBe(201);
    const after = todayActionsResponseSchema.parse((await call(u, 'GET', '/today')).json());
    expect(after.actions.some((a) => a.kind === 'start-run')).toBe(false);
    expect(after.actions.some((a) => a.kind === 'rest-day')).toBe(false);
  });

  it('readiness: running load counts for everyone; the sixth part goes only to builds that know it', async () => {
    const u = await user();
    expect((await call(u, 'POST', '/recovery/log', { sleepHours: 8, soreness: 1, energy: 5 })).statusCode).toBe(201);
    // Three easy weeks, then a big week: a sharp jump.
    for (const daysAgo of [25, 18, 11]) await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - daysAgo * 86_400_000)));
    for (const daysAgo of [1, 2, 3, 4]) {
      const f = fixture('easy-loop');
      await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - daysAgo * 86_400_000), { durationSeconds: f.durationSeconds, effort: 9 }));
    }
    const old = recoveryTodaySchema.parse((await call(u, 'GET', '/recovery/today')).json());
    const fresh = recoveryTodaySchema.parse((await call(u, 'GET', '/recovery/today', undefined, 18)).json());
    expect(old.readiness!.components.map((c) => c.key)).toEqual(['sleep', 'soreness', 'energy', 'performance', 'adherence']);
    expect(fresh.readiness!.components.map((c) => c.key)).toContain('running');
    const running = fresh.readiness!.components.find((c) => c.key === 'running')!;
    expect(running).toMatchObject({ max: 10, available: true });
    expect(running.penalty).toBeGreaterThan(0);
    // The score is the same either way.
    expect(old.readiness!.score).toBe(fresh.readiness!.score);
    expect(fresh.readiness!.score).toBe(100 - running.penalty);
    expect(recoveryTodaySchema.parse((await call(u, 'GET', '/recovery/today', undefined, 17)).json()).readiness!.components).toHaveLength(5);
  });

  it('the streak counts a day with a run; the ring counts the plan’s runs this week', async () => {
    const u = await user();
    const plan = (await call(u, 'POST', '/running/plans', tenK())).json<RunningPlan>();
    const weekFrom = addDays(today(), 1 - isoWeekday(today()));
    const thisWeek = plan.runs.filter((r) => r.date >= weekFrom && r.date <= addDays(weekFrom, 6));
    const before = streakSchema.parse((await call(u, 'GET', '/progress/streak')).json());
    expect(before.todayCounted).toBe(false);
    expect(before.week).toEqual({ done: 0, planned: thisWeek.length });
    await call(u, 'POST', '/running/runs', outdoorRun(new Date(Date.now() - 600_000)));
    const after = streakSchema.parse((await call(u, 'GET', '/progress/streak')).json());
    expect(after.todayCounted).toBe(true);
    expect(after.week).toEqual({ done: 1, planned: thisWeek.length });
  });
});
