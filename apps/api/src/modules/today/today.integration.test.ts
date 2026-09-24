/**
 * GET /v1/today and POST /v1/today/actions/{id}/event on real Postgres with
 * the real exercise seed (Phase 11, ADR-017).
 *
 * The engine reads the user's LOCAL hour, so each user gets an `Etc/GMT±N`
 * zone chosen to put their local clock at a known hour whenever CI runs.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  CURRENT_POLICY_VERSION,
  TODAY_ACTION_KINDS,
  TODAY_EVENTS,
  TODAY_REASON_CODES,
  todayActionsResponseSchema,
  todayEventResponseSchema,
  type Program,
  type TodayAction,
  type TodayActionsResponse,
  type TodayResponse,
  type WorkoutSession,
} from '@fitos/contracts';
import { ACTION_KINDS, MAX_ACTIONS, REASON_CODES } from '@fitos/core/recommend/engine';
import { TODAY_EVENTS as CORE_EVENTS } from '@fitos/core/recommend/events';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';

import { migrateUp } from '../../db/migrate.js';
import { actionBasisEnum, actionTargetEnum, recommendationEventEnum, todayActionKindEnum } from '../../db/schema.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { isoDayOfWeek } from '../workout/service.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

/** A fixed-offset zone whose local hour is `hour` right now. */
function zoneAt(hour: number): string {
  let o = hour - new Date().getUTCHours();
  if (o > 14) o -= 24;
  if (o < -12) o += 24;
  return o === 0 ? 'Etc/GMT' : o > 0 ? `Etc/GMT-${o}` : `Etc/GMT+${-o}`;
}

/** Never start a clock-sensitive test in the last 20 s of an hour (the local hour must not flip mid-test). */
async function settleClock(): Promise<void> {
  const now = new Date();
  const left = 3_600_000 - ((now.getUTCMinutes() * 60 + now.getUTCSeconds()) * 1000 + now.getUTCMilliseconds());
  if (left < 20_000) await new Promise((r) => setTimeout(r, left + 500));
}

describeIfDb('/v1/today (real Postgres, real seed)', { timeout: 60_000 }, () => {
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
    await sql`delete from users where firebase_uid like 'td-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }

  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.140.250' });

  /** A signed-in user with nothing on file (no onboarding). */
  async function bare(timeZone: string): Promise<U> {
    n += 1;
    const token = `td-tok-${n}`;
    ipOf.set(token, `203.0.${140 + Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `td-uid-${n}`, email: `td${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`td-uid-${n}`}`;
    await sql`update users set timezone = ${timeZone} where id = ${row!.id}`;
    return { token, id: row!.id };
  }

  async function targets(u: U, kcal = 2400, protein = 140): Promise<void> {
    await sql`delete from nutrition_targets where user_id = ${u.id}`;
    await sql`
      insert into nutrition_targets (user_id, effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale, reason)
      values (${u.id}, '2026-01-01', ${kcal}, ${protein}, 290, 70, 30, 1700, 2500, ${sql.json(['test'])}, 'onboarding')`;
  }

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  /** Onboarded (full gym), programme generated, its first training day moved onto TODAY's weekday in `timeZone`. */
  async function training(timeZone: string): Promise<U & { day: Program['days'][number] }> {
    const u = await bare(timeZone);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Persona', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
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
    const dow = isoDayOfWeek(localDateOf(new Date(), timeZone));
    if (day.dayOfWeek !== dow) {
      await sql`delete from program_days where program_id = ${program.id} and day_of_week = ${dow}`;
      await sql`update program_days set day_of_week = ${dow} where id = ${day.id}`;
    }
    return { ...u, day: { ...day, dayOfWeek: dow } };
  }

  /** A completed session on `day` at `completedAt`, every planned set of exercise `index` at the top of its range. */
  async function session(u: U, day: Program['days'][number], completedAt: Date, index: number | null): Promise<WorkoutSession> {
    const startedAt = new Date(completedAt.getTime() - 50 * 60_000).toISOString();
    const r = await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(u.token), payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt } });
    expect(r.statusCode, r.body).toBe(201);
    const s: WorkoutSession = r.json();
    const targetEx = index === null ? null : s.exercises[index]!;
    const sets = targetEx === null
      ? []
      : targetEx.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: targetEx.id, setIndex: t.setIndex, weightKg: 60, reps: t.repsMax, rir: 1, loggedAt: startedAt }));
    if (sets.length > 0) {
      const lr = await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth(u.token), payload: { sets } });
      expect(lr.statusCode, lr.body).toBe(200);
    }
    const c = await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(u.token), payload: { completedAt: completedAt.toISOString() } });
    expect(c.statusCode, c.body).toBe(200);
    return c.json();
  }

  const workoutToday = async (u: U): Promise<TodayResponse> =>
    (await app.inject({ method: 'GET', url: '/v1/training/today', headers: auth(u.token) })).json();

  const getToday = (u: U) => app.inject({ method: 'GET', url: '/v1/today', headers: auth(u.token) });
  async function today(u: U): Promise<TodayActionsResponse> {
    const r = await getToday(u);
    expect(r.statusCode, r.body).toBe(200);
    const body = todayActionsResponseSchema.parse(r.json());
    return body;
  }
  const kinds = (t: TodayActionsResponse): string[] => t.actions.map((a) => a.kind);
  const find = (t: TodayActionsResponse, kind: string): TodayAction | undefined => t.actions.find((a) => a.kind === kind);

  const event = (u: U, id: string, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: `/v1/today/actions/${id}/event`, headers: auth(u.token), payload: body });
  const ev = (u: U, id: string, name: string, occurredAt = new Date()) =>
    event(u, id, { clientEventId: randomUUID(), event: name, occurredAt: occurredAt.toISOString() });
  const issue = (r: { json: () => unknown }): string | undefined =>
    (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  const rows = async (u: U) =>
    sql<{ id: string; kind: string; subject_key: string; rank: number; generated_for: string; content_hash: string }[]>`
      select id, kind, subject_key, rank, generated_for::text, content_hash from recommendations where user_id = ${u.id} order by created_at, id`;

  /* ------------------------------------------------------------ access -- */

  it('401 without a session, on both endpoints', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/today' })).statusCode).toBe(401);
    const r = await app.inject({
      method: 'POST', url: `/v1/today/actions/${randomUUID()}/event`,
      payload: { clientEventId: randomUUID(), event: 'shown', occurredAt: new Date().toISOString() },
    });
    expect(r.statusCode).toBe(401);
  });

  it('the vocabularies are identical in contracts, core and the database', () => {
    expect([...TODAY_ACTION_KINDS]).toEqual([...ACTION_KINDS]);
    expect([...TODAY_ACTION_KINDS]).toEqual(todayActionKindEnum.enumValues);
    expect([...TODAY_REASON_CODES]).toEqual([...REASON_CODES]);
    expect([...TODAY_EVENTS]).toEqual([...CORE_EVENTS]);
    expect([...TODAY_EVENTS]).toEqual(recommendationEventEnum.enumValues);
    expect(actionBasisEnum.enumValues).toEqual(['logged', 'calculated', 'estimated']);
    expect(actionTargetEnum.enumValues).toEqual(['train', 'eat', 'progress', 'today']);
  });

  /* ---------------------------------------------------------- identity -- */

  it('a first-day user with nothing on file: 200, a valid response, rest-day and log-weight; nothing else invented', async () => {
    await settleClock();
    const tz = zoneAt(12);
    const u = await bare(tz);
    const t = await today(u);
    expect(t.date).toBe(localDateOf(new Date(), tz));
    expect(t.engineVersion).toBe('today-1');
    expect(kinds(t)).toEqual(['rest-day', 'log-weight']);
    expect(find(t, 'rest-day')!.reason).toEqual({
      code: 'rest-day', values: { hasProgramme: false, nextSessionName: null, nextSessionDate: null, kcalTarget: null, proteinTarget: null },
    });
    expect(find(t, 'log-weight')).toMatchObject({ subjectKey: '', basis: 'calculated', target: 'progress', reason: { code: 'weigh-in-due', values: { daysSinceWeighIn: null } } });
  });

  it('repeated GETs return the same ids and store nothing twice', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const a = await today(u);
    const b = await today(u);
    const c = await today(u);
    expect(b.actions.map((x) => x.id)).toEqual(a.actions.map((x) => x.id));
    expect(c.actions.map((x) => x.id)).toEqual(a.actions.map((x) => x.id));
    expect((await rows(u)).map((r) => r.id).sort()).toEqual(a.actions.map((x) => x.id).sort());
  });

  it('the response carries the CURRENT rank; the stored row keeps the rank it was first generated at', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const before = await today(u);
    const weight = find(before, 'log-weight')!;
    expect(weight.rank).toBe(2);
    // Targets appear: an eat action outranks it (and rest-day's content changes); log-weight's content does not.
    await targets(u);
    const after = await today(u);
    const moved = find(after, 'log-weight')!;
    expect(moved.id).toBe(weight.id);
    expect(moved.rank).toBe(3);
    expect(kinds(after)).toEqual(['eat-protein', 'rest-day', 'log-weight']);
    const [stored] = await sql<{ rank: number }[]>`select rank from recommendations where id = ${weight.id}`;
    expect(stored!.rank).toBe(2);
    // rest-day changed content (it now states the targets): a new row, the old one kept.
    const rest = await sql<{ id: string }[]>`select id from recommendations where user_id = ${u.id} and kind = 'rest-day'`;
    expect(rest).toHaveLength(2);
    expect(find(after, 'rest-day')!.id).not.toBe(find(before, 'rest-day')!.id);
  });

  it('changed content is a new row beside the old one: a food log moves the eat action', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    await targets(u);
    const before = await today(u);
    const eat = find(before, 'eat-protein')!;
    expect(eat.subjectKey).toBe('lunch');
    const log = await app.inject({
      method: 'POST', url: '/v1/nutrition/logs', headers: auth(u.token),
      payload: { clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'quick-add', quickAdd: { kcal: 700, proteinG: 30, carbG: 90, fatG: 20 } },
    });
    expect(log.statusCode, log.body).toBe(201);
    const after = await today(u);
    const next = after.actions.find((a) => a.target === 'eat')!;
    expect(next.id).not.toBe(eat.id);
    expect(next.subjectKey).toBe('snacks');
    const stored = await rows(u);
    expect(stored.some((r) => r.id === eat.id)).toBe(true);
    expect(stored.filter((r) => r.kind === 'eat-protein' || r.kind === 'eat-meal')).toHaveLength(2);
  });

  it('a dismissed action is omitted for the rest of the day; its row is kept', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const t = await today(u);
    const weight = find(t, 'log-weight')!;
    expect((await ev(u, weight.id, 'shown')).statusCode).toBe(201);
    expect((await ev(u, weight.id, 'dismissed')).statusCode).toBe(201);
    const after = await today(u);
    expect(kinds(after)).toEqual(['rest-day']);
    expect((await rows(u)).some((r) => r.id === weight.id)).toBe(true);
  });

  /* -------------------------------------------------- training assembly -- */

  /**
   * A training user whose `index`-th exercise today is due a load increase.
   * With `limitation`, it picks an exercise that a body part contraindicates
   * AND that has a safer library swap, so every precondition is real.
   */
  async function progressing(tz: string, opts: { withSwap: boolean }): Promise<U & { day: Program['days'][number]; exerciseId: string; bodyPart: string | null }> {
    const u = await training(tz);
    const plan = await workoutToday(u);
    let index = 0;
    let bodyPart: string | null = null;
    if (opts.withSwap) {
      const ids = plan.exercises.map((x) => x.exerciseId);
      const candidates = await sql<{ exercise_id: string; body_part: string }[]>`
        select distinct c.exercise_id, c.body_part::text as body_part
        from exercise_contraindications c
        join exercise_alternatives a on a.exercise_id = c.exercise_id
        join exercises alt on alt.id = a.alternative_id
        where c.exercise_id = any(${ids}::uuid[])
          and not exists (select 1 from exercise_contraindications c2 where c2.exercise_id = a.alternative_id and c2.body_part = c.body_part)
          and alt.equipment <@ array['barbell','dumbbell','machine','cable','bodyweight']::equipment[]
        order by 2, 1`;
      const pick = candidates.find((c) => !plan.exercises.find((x) => x.exerciseId === c.exercise_id)!.equipment.includes('bodyweight'));
      expect(pick, 'the seed must hold a contraindicated lift with a safer swap on this day').toBeDefined();
      index = plan.exercises.findIndex((x) => x.exerciseId === pick!.exercise_id);
      bodyPart = pick!.body_part;
    }
    await session(u, u.day, new Date(Date.now() - 3 * 86_400_000), index);
    const exerciseId = plan.exercises[index]!.exerciseId;
    const after = await workoutToday(u);
    expect(after.exercises.find((x) => x.exerciseId === exerciseId)!.recommendation!.action).toBe('increase-load');
    return { ...u, exerciseId, bodyPart };
  }

  it('owner Q1 at the API: ruled-out lift + load increase due + valid swap ⇒ injured-limitation present, progress-load absent', async () => {
    await settleClock();
    const u = await progressing(zoneAt(12), { withSwap: true });
    await sql`delete from nutrition_targets where user_id = ${u.id}`; // no eat actions competing for the four places

    // Control: without the limitation the increase is on the surface.
    const control = await today(u);
    expect(find(control, 'progress-load')).toMatchObject({ subjectKey: u.exerciseId, reason: { code: 'load-increase-due' } });
    expect(find(control, 'injured-limitation')).toBeUndefined();

    await sql`insert into user_limitations (user_id, body_part, note) values (${u.id}, ${u.bodyPart}, 'test')`;
    const plan = await workoutToday(u);
    const ruled = plan.exercises.find((x) => x.exerciseId === u.exerciseId)!;
    // Preconditions, from the same records TODAY reads: still due an increase, and a valid swap exists.
    expect(ruled.recommendation!.action).toBe('increase-load');
    expect(ruled.substitution?.alternative).not.toBeNull();

    const t = await today(u);
    const injured = find(t, 'injured-limitation')!;
    expect(injured).toBeDefined();
    expect(injured.priority).toBe(91);
    expect(injured.basis).toBe('logged');
    expect(injured.reason.code).toBe('exercise-contraindicated');
    const values = injured.reason.values as { exerciseId: string; bodyParts: string[]; alternativeId: string; affectedCount: number };
    expect(values.bodyParts).toContain(u.bodyPart);
    expect(injured.subjectKey).toBe(`${values.exerciseId}>${values.alternativeId}`);
    // The limited lift is never also a progress-load (and no other lift was due one).
    expect(find(t, 'progress-load')).toBeUndefined();
    expect(t.actions.length).toBeLessThanOrEqual(MAX_ACTIONS);
  });

  it('at most four actions when more are justified: the lowest band (log-weight) is cut', async () => {
    await settleClock();
    const u = await progressing(zoneAt(12), { withSwap: false });
    await targets(u);
    await sql`delete from body_metrics where user_id = ${u.id}`;
    const plan = await workoutToday(u);
    expect(plan.neglected.length).toBeGreaterThan(0);
    const t = await today(u);
    expect(kinds(t)).toEqual(['start-workout', 'eat-protein', 'progress-load', 'muscle-neglected']);
    expect(t.actions.map((a) => a.rank)).toEqual([1, 2, 3, 4]);
    expect(await rows(u)).toHaveLength(4);
  });

  /* ------------------------------------------------ clock and timezone -- */

  it('the local date comes from the stored timezone, not UTC or the server', async () => {
    const east = await bare('Etc/GMT-14');
    const west = await bare('Etc/GMT+12');
    const [e, w] = [await today(east), await today(west)];
    expect(e.date).toBe(localDateOf(new Date(), 'Etc/GMT-14'));
    expect(w.date).toBe(localDateOf(new Date(), 'Etc/GMT+12'));
    expect(e.date).not.toBe(w.date);
    expect((await rows(east)).every((r) => r.generated_for === e.date)).toBe(true);
    expect((await rows(west)).every((r) => r.generated_for === w.date)).toBe(true);
  });

  it('P7: an eat action at 21:59 local, none from 22:00', async () => {
    await settleClock();
    const late = await bare(zoneAt(21));
    await targets(late);
    const t21 = await today(late);
    expect(find(t21, 'eat-protein')).toMatchObject({ subjectKey: 'dinner', priority: 88 });

    const night = await bare(zoneAt(22));
    await targets(night);
    const t22 = await today(night);
    expect(t22.actions.some((a) => a.target === 'eat')).toBe(false);
  });

  /* ------------------------------------------------------------ events -- */

  it('201 when stored, 200 on a replay of the client id, 200 with the stored event on a repeat; both times kept', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const id = find(await today(u), 'log-weight')!.id;
    const occurredAt = new Date(Date.now() - 60_000);
    const body = { clientEventId: randomUUID(), event: 'shown', occurredAt: occurredAt.toISOString() };
    const first = await event(u, id, body);
    expect(first.statusCode, first.body).toBe(201);
    const stored = todayEventResponseSchema.parse(first.json()).event;
    expect(stored).toMatchObject({ recommendationId: id, event: 'shown', clientEventId: body.clientEventId });
    expect(new Date(stored.occurredAt).getTime()).toBe(occurredAt.getTime());
    expect(Math.abs(new Date(stored.receivedAt).getTime() - Date.now())).toBeLessThan(10_000);

    const replay = await event(u, id, body);
    expect(replay.statusCode).toBe(200);
    expect(replay.json().event.id).toBe(stored.id);

    const repeat = await ev(u, id, 'shown');
    expect(repeat.statusCode).toBe(200);
    expect(repeat.json().event.id).toBe(stored.id);
    const [row] = await sql<{ n: number }[]>`select count(*)::int as n from recommendation_events where recommendation_id = ${id}`;
    expect(row!.n).toBe(1);
  });

  it('404 for another user\'s action and for one that does not exist; 422 for a malformed id or body', async () => {
    await settleClock();
    const owner = await bare(zoneAt(12));
    const other = await bare(zoneAt(12));
    const id = find(await today(owner), 'log-weight')!.id;
    expect((await ev(other, id, 'shown')).statusCode).toBe(404);
    expect((await ev(owner, randomUUID(), 'shown')).statusCode).toBe(404);
    expect((await ev(owner, 'not-a-uuid', 'shown')).statusCode).toBe(422);
    const ok = { clientEventId: randomUUID(), event: 'shown', occurredAt: new Date().toISOString() };
    expect((await event(owner, id, { ...ok, event: 'liked' })).statusCode).toBe(422);
    expect((await event(owner, id, { ...ok, clientEventId: 'abc' })).statusCode).toBe(422);
    expect((await event(owner, id, { ...ok, occurredAt: 'now' })).statusCode).toBe(422);
    expect((await event(owner, id, { ...ok, extra: true })).statusCode).toBe(422);
    // The other user's attempt stored nothing.
    const [row] = await sql<{ n: number }[]>`select count(*)::int as n from recommendation_events where recommendation_id = ${id}`;
    expect(row!.n).toBe(0);
  });

  it('the Q2 transition matrix: every impossible transition is 422 with its code', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const t = await today(u);
    const weight = find(t, 'log-weight')!.id;
    const rest = find(t, 'rest-day')!.id;

    const not = async (id: string, name: string, code: string) => {
      const r = await ev(u, id, name);
      expect(r.statusCode, `${name}: ${r.body}`).toBe(422);
      expect(issue(r)).toBe(code);
    };
    for (const e of ['opened', 'accepted', 'dismissed', 'completed']) await not(weight, e, 'not-shown');
    expect((await ev(u, weight, 'shown')).statusCode).toBe(201);
    await not(weight, 'completed', 'not-accepted'); // owner Q2: opened is not enough, accepted is required
    expect((await ev(u, weight, 'opened')).statusCode).toBe(201);
    await not(weight, 'completed', 'not-accepted');
    expect((await ev(u, weight, 'accepted')).statusCode).toBe(201);
    await not(weight, 'dismissed', 'accepted-and-dismissed');
    // Completion needs evidence on the server: no weight yet …
    await not(weight, 'completed', 'no-evidence');
    await sql`insert into body_metrics (user_id, measured_on, weight_kg, source) values (${u.id}, ${t.date}, 70, 'manual')`;
    expect((await ev(u, weight, 'completed')).statusCode).toBe(201);
    // Since owner Q2 a completed action is always accepted, so core rejects this as accepted-and-dismissed
    // (checked first); after-completed can no longer be reached. Still 422 either way.
    await not(weight, 'dismissed', 'accepted-and-dismissed');

    // Informational: never completable; dismissed shuts every later step.
    expect((await ev(u, rest, 'shown')).statusCode).toBe(201);
    expect((await ev(u, rest, 'accepted')).statusCode).toBe(201);
    await not(rest, 'completed', 'not-completable');
    const rest2 = find(await today(u), 'rest-day');
    expect(rest2?.id).toBe(rest); // accepted is not dismissed: still on the surface
  });

  it('dismissed excludes accepted, opened and completed', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const id = find(await today(u), 'log-weight')!.id;
    expect((await ev(u, id, 'shown')).statusCode).toBe(201);
    expect((await ev(u, id, 'dismissed')).statusCode).toBe(201);
    for (const [e, code] of [['accepted', 'accepted-and-dismissed'], ['opened', 'after-dismissed'], ['completed', 'after-dismissed']] as const) {
      const r = await ev(u, id, e);
      expect(r.statusCode).toBe(422);
      expect(issue(r)).toBe(code);
    }
  });

  it('completion evidence: eat needs a log in that meal on that day; start-workout a session completed that day', async () => {
    await settleClock();
    const u = await progressing(zoneAt(12), { withSwap: false });
    await targets(u);
    const t = await today(u);
    const eat = find(t, 'eat-protein')!;
    const start = find(t, 'start-workout')!;
    for (const id of [eat.id, start.id]) {
      expect((await ev(u, id, 'shown')).statusCode).toBe(201);
      expect((await ev(u, id, 'accepted')).statusCode).toBe(201);
      const r = await ev(u, id, 'completed');
      expect(r.statusCode).toBe(422);
      expect(issue(r)).toBe('no-evidence');
    }
    // A dinner log does not complete a lunch action.
    const log = (slot: string) => app.inject({
      method: 'POST', url: '/v1/nutrition/logs', headers: auth(u.token),
      payload: { clientLogId: randomUUID(), mealSlot: slot, entryMethod: 'quick-add', quickAdd: { kcal: 500, proteinG: 30, carbG: 50, fatG: 15 } },
    });
    expect((await log('dinner')).statusCode).toBe(201);
    expect(issue(await ev(u, eat.id, 'completed'))).toBe('no-evidence');
    expect((await log(eat.subjectKey)).statusCode).toBe(201);
    expect((await ev(u, eat.id, 'completed')).statusCode).toBe(201);

    await session(u, u.day, new Date(), null);
    expect((await ev(u, start.id, 'completed')).statusCode).toBe(201);
  });

  it('P3 timing: 5-minute skew, the day through 03:00 local next day, delivery within 7 days', async () => {
    await settleClock();
    const tz = zoneAt(10);
    const u = await bare(tz);
    const t = await today(u);
    const weight = find(t, 'log-weight')!.id;
    const rest = find(t, 'rest-day')!.id;
    const at = (ms: number) => ({ clientEventId: randomUUID(), event: 'shown', occurredAt: new Date(ms).toISOString() });
    const code = async (id: string, body: Record<string, unknown>) => {
      const r = await event(u, id, body);
      return r.statusCode === 422 ? issue(r) : r.statusCode;
    };
    expect(await code(weight, at(Date.now() + 10 * 60_000))).toBe('in-future');
    expect(await code(weight, at(Date.now() - 10 * 60_000))).toBe('before-recommendation');
    expect(await code(weight, at(Date.now() + 2 * 60_000))).toBe(201); // inside the skew

    // Yesterday's action: 02:30 today local is still its day (grace); 03:00 is not.
    const now = new Date();
    const [h, m, s] = new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
      .format(now)
      .split(':')
      .map(Number) as [number, number, number];
    const localMidnight = now.getTime() - (((h * 60 + m) * 60 + s) * 1000 + now.getMilliseconds());
    const yesterday = addDays(t.date, -1);
    await sql`update recommendations set generated_for = ${yesterday}, created_at = ${new Date(localMidnight - 6 * 3_600_000)} where id = ${rest}`;
    expect(await code(rest, at(localMidnight + 3 * 3_600_000))).toBe('outside-day');
    expect(await code(rest, at(localMidnight + 2.5 * 3_600_000))).toBe(201);

    // Eight days late: delivered outside the 7-day window.
    const owner = await bare(tz);
    const old = find(await today(owner), 'log-weight')!;
    const eightDaysAgo = Date.now() - 8 * 86_400_000;
    await sql`update recommendations set generated_for = ${localDateOf(new Date(eightDaysAgo), tz)}, created_at = ${new Date(eightDaysAgo - 60_000)} where id = ${old.id}`;
    const late = await event(owner, old.id, at(eightDaysAgo));
    expect(late.statusCode).toBe(422);
    expect(issue(late)).toBe('delivered-too-late');
  });

  /* ------------------------------------------- client event id rules -- */

  it('clientEventId: an exact replay is 200 with the original; reuse for another action, event or time is 409; nothing unrelated is returned', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const t = await today(u);
    const weight = find(t, 'log-weight')!.id;
    const rest = find(t, 'rest-day')!.id;
    const occurredAt = new Date(Date.now() - 60_000);
    const body = { clientEventId: randomUUID(), event: 'shown', occurredAt: occurredAt.toISOString() };
    const first = await event(u, weight, body);
    expect(first.statusCode).toBe(201);
    const original = first.json().event;

    // Exact replay — also when the same instant is written with another offset.
    const replay = await event(u, weight, body);
    expect(replay.statusCode).toBe(200);
    expect(replay.json().event).toEqual(original);
    const ist = new Date(occurredAt.getTime() + 5.5 * 3_600_000).toISOString().replace('Z', '+05:30');
    const sameInstant = await event(u, weight, { ...body, occurredAt: ist });
    expect(sameInstant.statusCode).toBe(200);
    expect(sameInstant.json().event.id).toBe(original.id);

    const conflict = async (id: string, over: Record<string, unknown>, issues: string[]) => {
      const r = await event(u, id, { ...body, ...over });
      expect(r.statusCode, r.body).toBe(409);
      expect((r.json() as { error: { code: string; details: { issue: string }[] } }).error.details.map((d) => d.issue)).toEqual(issues);
      expect(r.body).not.toContain(original.id);
    };
    await conflict(rest, {}, ['different-action']);
    await conflict(weight, { event: 'opened' }, ['different-event']);
    await conflict(weight, { occurredAt: new Date(occurredAt.getTime() + 1000).toISOString() }, ['different-occurred-at']);
    await conflict(rest, { event: 'dismissed' }, ['different-action', 'different-event']);

    // Nothing was stored by the collisions; the rest-day action has no events.
    const stored = await sql<{ recommendation_id: string; event: string }[]>`select recommendation_id, event from recommendation_events where user_id = ${u.id}`;
    expect(stored).toEqual([{ recommendation_id: weight, event: 'shown' }]);

    // Client ids are per user: another user may use the same value for their own event.
    const other = await bare(zoneAt(12));
    const theirs = find(await today(other), 'log-weight')!.id;
    expect((await event(other, theirs, body)).statusCode).toBe(201);
  });

  it('order: replay/collision before ownership, ownership before timing, timing before transition, transition before evidence', async () => {
    await settleClock();
    const u = await bare(zoneAt(12));
    const other = await bare(zoneAt(12));
    const mine = find(await today(u), 'log-weight')!.id;
    const theirs = find(await today(other), 'log-weight')!.id;
    const used = { clientEventId: randomUUID(), event: 'shown', occurredAt: new Date().toISOString() };
    expect((await event(u, mine, used)).statusCode).toBe(201);

    // 2–4 before 5: a used client id on any other id is a collision, whether or not that action exists or is ours.
    expect((await event(u, randomUUID(), used)).statusCode).toBe(409);
    expect((await event(u, theirs, used)).statusCode).toBe(409);
    // 5 before 6: another user's action with an out-of-window time is still 404.
    const future = new Date(Date.now() + 60 * 60_000).toISOString();
    expect((await event(u, theirs, { clientEventId: randomUUID(), event: 'shown', occurredAt: future })).statusCode).toBe(404);
    // 6 before 7: a new event that is both badly timed and an impossible transition fails on timing.
    const fresh = find(await today(other), 'rest-day')!.id;
    const r = await event(other, fresh, { clientEventId: randomUUID(), event: 'opened', occurredAt: future });
    expect(r.statusCode).toBe(422);
    expect(issue(r)).toBe('in-future');
    // 7 before 8: completed before shown is a transition error, not missing evidence.
    const c = await ev(other, fresh, 'completed');
    expect(issue(c)).toBe('not-shown');
  });

  it('an exact replay stays idempotent after the timing window; a NEW event at the same time is still rejected', async () => {
    await settleClock();
    const tz = zoneAt(12);
    const u = await bare(tz);
    const id = find(await today(u), 'log-weight')!.id;
    const body = { clientEventId: randomUUID(), event: 'shown', occurredAt: new Date().toISOString() };
    const stored = (await event(u, id, body)).json().event;
    // Nine days pass (the action, its event and the phone's time all move back together).
    const nineDaysAgo = new Date(Date.now() - 9 * 86_400_000);
    await sql`update recommendations set generated_for = ${localDateOf(nineDaysAgo, tz)}, created_at = ${new Date(nineDaysAgo.getTime() - 60_000)} where id = ${id}`;
    await sql`update recommendation_events set occurred_at = ${nineDaysAgo} where id = ${stored.id}`;
    const late = { ...body, occurredAt: nineDaysAgo.toISOString() };

    const replay = await event(u, id, late);
    expect(replay.statusCode).toBe(200);
    expect(replay.json().event.id).toBe(stored.id);

    const fresh = await event(u, id, { ...late, clientEventId: randomUUID(), event: 'opened' });
    expect(fresh.statusCode).toBe(422);
    expect(issue(fresh)).toBe('delivered-too-late');
  });

  /* ---------------------------------------------------- deload evidence -- */

  /** A training user with fatigue on two lead lifts: the programme offers a deload today (Phase 6). */
  async function deloadOffered(tz: string): Promise<U & { deloadId: string; programId: string }> {
    const u = await training(tz);
    const plan = await workoutToday(u);
    const compounds = plan.exercises
      .map((x, i) => ({ x, i }))
      .filter(({ x }) => ['squat', 'hinge', 'horizontal-push', 'vertical-push', 'horizontal-pull', 'vertical-pull'].includes(x.movementPattern));
    expect(compounds.length).toBeGreaterThanOrEqual(2);
    const [a, b] = compounds as unknown as [{ i: number }, { i: number }];
    for (const [ago, reps, rir] of [[6, 10, 3], [4, 9, 2], [2, 8, 1]] as const) {
      const completedAt = new Date(Date.now() - ago * 86_400_000);
      const startedAt = new Date(completedAt.getTime() - 50 * 60_000).toISOString();
      const s: WorkoutSession = (await app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(u.token), payload: { clientSessionId: randomUUID(), programDayId: u.day.id, startedAt } })).json();
      const sets = [[a.i, 80], [b.i, 50]].flatMap(([i, weight]) =>
        s.exercises[i!]!.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: s.exercises[i!]!.id, setIndex: t.setIndex, weightKg: weight, reps, rir, loggedAt: startedAt })),
      );
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/sets`, headers: auth(u.token), payload: { sets } })).statusCode).toBe(200);
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(u.token), payload: { completedAt: completedAt.toISOString() } })).statusCode).toBe(200);
    }
    expect((await workoutToday(u)).deload).toMatchObject({ state: 'offered', trigger: 'fatigue' });
    const deload = find(await today(u), 'deload')!;
    expect(deload).toMatchObject({ rank: 1, priority: 95, reason: { code: 'deload-offered', values: { trigger: 'fatigue' } } });
    const [p] = await sql<{ id: string }[]>`select id from programs where user_id = ${u.id} and active`;
    return { ...u, deloadId: deload.id, programId: p!.id };
  }

  const acceptDeload = (u: U) => app.inject({ method: 'POST', url: '/v1/training/deload/accept', headers: auth(u.token) });

  it('deload: accepted, then the offer activated (Phase 6 accept) → completed 201; accepted without activation → 422 no-evidence', async () => {
    await settleClock();
    const u = await deloadOffered(zoneAt(12));
    expect((await ev(u, u.deloadId, 'shown')).statusCode).toBe(201);
    expect((await ev(u, u.deloadId, 'accepted')).statusCode).toBe(201);
    // Accepted on the card, but the offer was never activated: not completed.
    const early = await ev(u, u.deloadId, 'completed');
    expect(early.statusCode).toBe(422);
    expect(issue(early)).toBe('no-evidence');
    // The user activates the offered week in Training.
    const acc = await acceptDeload(u);
    expect(acc.statusCode, acc.body).toBe(200);
    expect(acc.json().state).toBe('active');
    expect((await ev(u, u.deloadId, 'completed')).statusCode).toBe(201);
  });

  it('deload: an activation from BEFORE this action was accepted is not its evidence', async () => {
    await settleClock();
    const u = await deloadOffered(zoneAt(12));
    // The action appeared 30 minutes ago; the week was activated 20 minutes ago, outside TODAY …
    await sql`update recommendations set created_at = now() - interval '30 minutes' where id = ${u.deloadId}`;
    expect((await acceptDeload(u)).statusCode).toBe(200);
    await sql`update programs set deload_started_at = now() - interval '20 minutes' where id = ${u.programId}`;
    // … and only now is the card accepted: that acceptance did not lead to the activation.
    expect((await ev(u, u.deloadId, 'shown')).statusCode).toBe(201);
    expect((await ev(u, u.deloadId, 'accepted')).statusCode).toBe(201);
    const r = await ev(u, u.deloadId, 'completed');
    expect(r.statusCode).toBe(422);
    expect(issue(r)).toBe('no-evidence');
  });

  /* ------------------------------------------------------- performance -- */

  it('p95 of GET /today under 300 ms for a training user with history, targets and logs', async () => {
    await settleClock();
    const u = await progressing(zoneAt(12), { withSwap: false });
    await targets(u);
    await today(u); // warm
    const times: number[] = [];
    for (let i = 0; i < 40; i++) {
      const t0 = performance.now();
      const r = await getToday(u);
      times.push(performance.now() - t0);
      expect(r.statusCode).toBe(200);
    }
    times.sort((a, b) => a - b);
    const p95 = times[Math.ceil(0.95 * times.length) - 1]!;
    console.info(`GET /v1/today p50 ${times[Math.floor(times.length / 2)]!.toFixed(1)} ms, p95 ${p95.toFixed(1)} ms (n=${times.length})`);
    expect(p95).toBeLessThan(300);
  });
});
