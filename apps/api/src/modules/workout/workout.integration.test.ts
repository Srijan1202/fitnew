/**
 * Sessions through the HTTP surface on real Postgres with the real seed.
 * §31 Phase 5: replaying the same clientSetId creates one row; conflict
 * resolution (§33 merge); completion computes records and the mesocycle
 * week; history is the user's own. Every idempotency claim is exercised by
 * sending the same request twice.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type TodayResponse, type WorkoutSession } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { isoDayOfWeek, localDate } from './service.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describe('local dates', () => {
  it('localDate follows the zone; isoDayOfWeek is ISO', () => {
    // 2026-09-21T19:30Z is already the 22nd in Kolkata (UTC+5:30).
    expect(localDate(new Date('2026-09-21T19:30:00Z'), 'Asia/Kolkata')).toBe('2026-09-22');
    expect(localDate(new Date('2026-09-21T19:30:00Z'), 'UTC')).toBe('2026-09-21');
    expect(isoDayOfWeek('2026-09-21')).toBe(1);
    expect(isoDayOfWeek('2026-09-27')).toBe(7);
  });

  it('Phase 6.6 Gate 7: every weekday of the S24 week maps to ISO 1..7 — Wednesday 23 September 2026 is 3, in Kolkata too', () => {
    const week = ['2026-09-21', '2026-09-22', '2026-09-23', '2026-09-24', '2026-09-25', '2026-09-26', '2026-09-27'];
    expect(week.map(isoDayOfWeek)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    // 01:09 UTC on the 23rd (the S24 failure) is 06:39 IST, still Wednesday.
    expect(isoDayOfWeek(localDate(new Date('2026-09-23T01:09:04Z'), 'Asia/Kolkata'))).toBe(3);
    // Late on Tuesday UTC is already Wednesday in Kolkata.
    expect(isoDayOfWeek(localDate(new Date('2026-09-22T20:00:00Z'), 'Asia/Kolkata'))).toBe(3);
  });
});

describeIfDb('/v1/training/sessions (real Postgres, real seed)', () => {
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
    await sql`delete from users where firebase_uid like 'wo-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.114.250' });

  async function onboarded(): Promise<string> {
    n += 1;
    const token = `wo-tok-${n}`;
    ipOf.set(token, `203.0.${100 + Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `wo-uid-${n}`, email: `wo${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Persona', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
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

  const at = (minutes: number) => new Date(Date.UTC(2026, 8, 21, 10, minutes)).toISOString();
  const start = (token: string, body: Record<string, unknown>) =>
    app.inject({ method: 'POST', url: '/v1/training/sessions', headers: auth(token), payload: body });
  const log = (token: string, id: string, sets: Record<string, unknown>[], merge = false) =>
    app.inject({ method: 'POST', url: `/v1/training/sessions/${id}/sets`, headers: auth(token), payload: { sets, merge } });
  const complete = (token: string, id: string, minutes = 55) =>
    app.inject({ method: 'POST', url: `/v1/training/sessions/${id}/complete`, headers: auth(token), payload: { completedAt: at(minutes) } });
  const get = (token: string, id: string) => app.inject({ method: 'GET', url: `/v1/training/sessions/${id}`, headers: auth(token) });

  /** Log the day's first exercise: `weights` kg for `reps` on every planned set. */
  async function logFirst(token: string, s: WorkoutSession, weight: number, reps: number, rir = 2) {
    const x = s.exercises[0]!;
    const sets = x.targets.map((t) => ({
      clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: t.setIndex, weightKg: weight, reps, rir, loggedAt: at(10 + t.setIndex), plannedSetId: undefined,
    }));
    const r = await log(token, s.id, sets);
    expect(r.statusCode, r.body).toBe(200);
    return r.json() as WorkoutSession;
  }

  it('start from a programme day seeds the exercises with targets; the same clientSessionId returns the same session', async () => {
    const { token, program, day } = await withProgram();
    const clientSessionId = randomUUID();
    const r1 = await start(token, { clientSessionId, programDayId: day.id, startedAt: at(0) });
    expect(r1.statusCode, r1.body).toBe(201);
    const s: WorkoutSession = r1.json();
    expect(s.status).toBe('active');
    expect(s.name).toBe(day.sessionName);
    expect(s.programId).toBe(program.id);
    expect(s.exercises.map((x) => x.exerciseId)).toEqual(day.exercises.map((x) => x.exerciseId));
    expect(s.exercises[0]!.plannedExerciseId).toBe(day.exercises[0]!.id);
    expect(s.exercises[0]!.targets.length).toBe(day.exercises[0]!.setCount);
    expect(s.exercises[0]!.targets[0]).toMatchObject({ repsMin: 6, repsMax: 12, weightKg: null });
    expect(s.exercises[0]!.lastPerformance).toBeNull();
    expect(s.exercises.every((x) => x.sets.length === 0)).toBe(true);
    expect(s.summary).toBeNull();

    // Replay (the offline queue sending it again): same session, 200 not 201.
    const r2 = await start(token, { clientSessionId, programDayId: day.id, startedAt: at(0) });
    expect(r2.statusCode).toBe(200);
    expect((r2.json() as WorkoutSession).id).toBe(s.id);
    expect((await sql`select count(*)::int as c from workout_sessions where client_session_id = ${clientSessionId}`)[0]!.c).toBe(1);
  });

  it('a client that seeded the session offline gets its own exercise ids adopted', async () => {
    const { token, day } = await withProgram();
    const mine = day.exercises.map((x, i) => ({ clientExerciseId: randomUUID(), exerciseId: x.exerciseId, plannedExerciseId: x.id, orderIndex: i }));
    const r = await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0), exercises: mine });
    expect(r.statusCode, r.body).toBe(201);
    const s: WorkoutSession = r.json();
    expect(s.exercises.map((x) => x.clientExerciseId)).toEqual(mine.map((x) => x.clientExerciseId));
    expect(s.exercises[0]!.targets.length).toBe(day.exercises[0]!.setCount);
    const bad = await start(token, { clientSessionId: randomUUID(), startedAt: at(0), exercises: [{ clientExerciseId: randomUUID(), exerciseId: randomUUID(), orderIndex: 0 }] });
    expect(bad.statusCode).toBe(422);
  });

  it('a second active session is 409 naming the active one; abandoning frees the slot', async () => {
    const { token, day } = await withProgram();
    const first: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    const r = await start(token, { clientSessionId: randomUUID(), startedAt: at(1) });
    expect(r.statusCode).toBe(409);
    expect(r.json().error.details[0]).toEqual({ path: 'activeSessionId', issue: first.id });
    const ab = await app.inject({ method: 'POST', url: `/v1/training/sessions/${first.id}/abandon`, headers: auth(token) });
    expect(ab.statusCode).toBe(200);
    expect((ab.json() as WorkoutSession).status).toBe('abandoned');
    expect((await start(token, { clientSessionId: randomUUID(), startedAt: at(2) })).statusCode).toBe(201);
  });

  it('Phase 6.6 Gate 7 — a session left active by a phone that lost it: new starts are refused with its id, /today names it with its sets, the user finishing it frees the slot, and the blocked start then replays idempotently', async () => {
    const { token, day } = await withProgram();
    // The phone that owned it signed out before its end was sent.
    const orphan: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    await logFirst(token, orphan, 50, 10);
    // The phone, knowing nothing of it, starts a new session (queued, replayed by Retry).
    const next = { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(30) };
    for (let i = 0; i < 3; i++) {
      const refused = await start(token, next);
      expect(refused.statusCode).toBe(409);
      expect(refused.json().error.details[0]).toEqual({ path: 'activeSessionId', issue: orphan.id });
    }
    // The guard never let a second session in, however often it was retried.
    expect((await sql`select count(*)::int as c from workout_sessions where client_session_id = ${next.clientSessionId}`)[0]!.c).toBe(0);
    // /today tells the phone what is holding the slot, with its sets.
    const today = (await app.inject({ method: 'GET', url: '/v1/training/today', headers: auth(token) })).json();
    expect(today.activeSession.id).toBe(orphan.id);
    expect(today.activeSession.clientSessionId).toBe(orphan.clientSessionId);
    expect(today.activeSession.exercises[0].sets.length).toBeGreaterThan(0);
    // The user explicitly finishes it (at its last set, as the app sends).
    const done = await complete(token, orphan.id, 25);
    expect(done.statusCode, done.body).toBe(200);
    expect((done.json() as WorkoutSession).status).toBe('completed');
    // The same queued start now succeeds once, and replays return it.
    const created = await start(token, next);
    expect(created.statusCode, created.body).toBe(201);
    const replay = await start(token, next);
    expect(replay.statusCode).toBe(200);
    expect((replay.json() as WorkoutSession).id).toBe((created.json() as WorkoutSession).id);
    // History has the finished one; exactly one session is active.
    const history = (await app.inject({ method: 'GET', url: '/v1/training/sessions?limit=20', headers: auth(token) })).json();
    expect(history.items.map((i: { id: string }) => i.id)).toContain(orphan.id);
    expect((await sql`select count(*)::int as c from workout_sessions where status = 'active' and user_id = (select user_id from workout_sessions where id = ${orphan.id})`)[0]!.c).toBe(1);
  });

  it('Phase 6.6 Gate 7: each ISO weekday 1..7 — /today?dayOfWeek=d names the programme day, and a session started from it is accepted', async () => {
    const { token, program } = await withProgram();
    // A 4-day programme: training on some weekdays, rest on the others ("only selected days").
    expect(program.days.map((d) => d.dayOfWeek)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(program.days.some((d) => d.isRest)).toBe(true);
    for (const d of [1, 2, 3, 4, 5, 6, 7]) {
      const t = (await app.inject({ method: 'GET', url: `/v1/training/today?dayOfWeek=${d}`, headers: auth(token) })).json();
      const planned = program.days.find((x) => x.dayOfWeek === d)!;
      expect(t.dayOfWeek, `day ${d}`).toBe(d);
      expect(t.programDayId, `day ${d}`).toBe(planned.id);
      expect(t.isRest).toBe(planned.isRest);
      const r = await start(token, { clientSessionId: randomUUID(), programDayId: t.programDayId, startedAt: at(d) });
      expect(r.statusCode, `start on day ${d}: ${r.body}`).toBe(201);
      const s = r.json() as WorkoutSession;
      expect(s.exercises.length).toBe(planned.exercises.length);
      // One active at a time: end it before the next weekday.
      expect((await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/abandon`, headers: auth(token) })).statusCode).toBe(200);
    }
  });

  it('Phase 6.6 Gate 7: a day of a REPLACED programme is still refused (404, validation intact); the same workout as an ad-hoc session with its own exercises is accepted and its sets replay', async () => {
    const { token, day: oldDay } = await withProgram();
    // The phone seeds its session from the day and queues it…
    const mine = oldDay.exercises.map((x, i) => ({ clientExerciseId: randomUUID(), exerciseId: x.exerciseId, plannedExerciseId: x.id, orderIndex: i }));
    const body = { clientSessionId: randomUUID(), programDayId: oldDay.id, startedAt: at(0), exercises: mine };
    // …then the user applies another programme before it syncs.
    expect((await app.inject({ method: 'POST', url: '/v1/training/program/from-template/bro-split', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const stale = await start(token, body);
    expect(stale.statusCode).toBe(404);
    expect(stale.json().error.message).toBe('That day is not in your active programme.');
    // A day id that never existed: 404 too.
    expect((await start(token, { ...body, clientSessionId: randomUUID(), programDayId: randomUUID() })).statusCode).toBe(404);
    // What the phone now sends once: the same session, no programme day.
    const adHoc = { clientSessionId: body.clientSessionId, startedAt: body.startedAt, exercises: body.exercises };
    const created = await start(token, adHoc);
    expect(created.statusCode, created.body).toBe(201);
    const s = created.json() as WorkoutSession;
    expect(s.programId).toBeNull();
    expect(s.exercises.map((x) => x.clientExerciseId)).toEqual(mine.map((x) => x.clientExerciseId));
    const logged = await log(token, s.id, [{ clientSetId: randomUUID(), clientExerciseId: mine[0]!.clientExerciseId, setIndex: 1, weightKg: 40, reps: 10, rir: 2, loggedAt: at(5) }]);
    expect(logged.statusCode, logged.body).toBe(200);
    expect((await complete(token, s.id, 20)).statusCode).toBe(200);
    const history = (await app.inject({ method: 'GET', url: '/v1/training/sessions?limit=20', headers: auth(token) })).json();
    expect(history.items.map((i: { id: string }) => i.id)).toContain(s.id);
    // Replay of the ad-hoc start: the same session, not a second one.
    const again = await start(token, adHoc);
    expect(again.statusCode).toBe(200);
    expect((again.json() as WorkoutSession).id).toBe(s.id);
  });

  it('an ad-hoc session has no exercises until one is added, and uses the same set logging', async () => {
    const token = await onboarded();
    const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), startedAt: at(0) })).json();
    expect(s.name).toBe('Session');
    expect(s.programDayId).toBeNull();
    expect(s.exercises).toEqual([]);
    const [bench] = await sql<{ id: string }[]>`select id from exercises where slug = 'barbell-bench-press'`;
    const clientExerciseId = randomUUID();
    const add = await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/exercises`, headers: auth(token), payload: { clientExerciseId, exerciseId: bench!.id } });
    expect(add.statusCode, add.body).toBe(200);
    // Replay is a no-op.
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/exercises`, headers: auth(token), payload: { clientExerciseId, exerciseId: bench!.id } });
    const withOne: WorkoutSession = (await get(token, s.id)).json();
    expect(withOne.exercises.length).toBe(1);
    expect(withOne.exercises[0]!.targets).toEqual([]);
    // Sets may name the exercise by its client id (the client may not have the server id yet).
    const r = await log(token, s.id, [{ clientSetId: randomUUID(), clientExerciseId, setIndex: 1, weightKg: 60, reps: 10, rir: 2, loggedAt: at(5) }]);
    expect(r.statusCode, r.body).toBe(200);
    expect((r.json() as WorkoutSession).exercises[0]!.sets[0]).toMatchObject({ setIndex: 1, weightKg: 60, reps: 10, setType: 'working' });
  });

  it('replaying a batch creates one row per clientSetId; out-of-order and partial replays are safe', async () => {
    const { token, day } = await withProgram();
    const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    const x = s.exercises[0]!;
    const sets = [1, 2, 3].map((i) => ({ clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: i, weightKg: 60, reps: 10, rir: 2, loggedAt: at(i) }));
    expect((await log(token, s.id, sets)).statusCode).toBe(200);
    expect((await log(token, s.id, sets)).statusCode).toBe(200); // full replay
    expect((await log(token, s.id, [sets[2]!, sets[0]!])).statusCode).toBe(200); // partial, reordered
    const fourth = { clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: 4, weightKg: 60, reps: 8, rir: 1, loggedAt: at(4) };
    expect((await log(token, s.id, [sets[1]!, fourth])).statusCode).toBe(200); // replay next to a new set
    const after: WorkoutSession = (await get(token, s.id)).json();
    expect(after.exercises[0]!.sets.map((t) => t.setIndex)).toEqual([1, 2, 3, 4]);
    expect((await sql`select count(*)::int as c from set_logs sl join session_exercises se on se.id = sl.session_exercise_id where se.session_id = ${s.id}`)[0]!.c).toBe(4);
    // A different clientSetId at a taken position is a conflict, not a duplicate.
    const clash = await log(token, s.id, [{ ...fourth, clientSetId: randomUUID() }]);
    expect(clash.statusCode).toBe(409);
    // An exercise from another session is rejected.
    const bad = await log(token, s.id, [{ clientSetId: randomUUID(), sessionExerciseId: randomUUID(), setIndex: 5, reps: 8, loggedAt: at(5) }]);
    expect(bad.statusCode).toBe(422);
  });

  it('a set can be corrected and soft-deleted; a deleted position can be re-logged', async () => {
    const { token, day } = await withProgram();
    const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    const logged = await logFirst(token, s, 60, 10);
    const set = logged.exercises[0]!.sets[0]!;
    const p = await app.inject({ method: 'PATCH', url: `/v1/training/sessions/${s.id}/sets/${set.id}`, headers: auth(token), payload: { reps: 11, weightKg: 62.5 } });
    expect(p.statusCode, p.body).toBe(200);
    expect((p.json() as WorkoutSession).exercises[0]!.sets[0]).toMatchObject({ reps: 11, weightKg: 62.5 });
    expect((await app.inject({ method: 'PATCH', url: `/v1/training/sessions/${s.id}/sets/${set.id}`, headers: auth(token), payload: {} })).statusCode).toBe(422);
    const d = await app.inject({ method: 'DELETE', url: `/v1/training/sessions/${s.id}/sets/${set.id}`, headers: auth(token) });
    expect(d.statusCode).toBe(200);
    expect((d.json() as WorkoutSession).exercises[0]!.sets.map((t) => t.setIndex)).not.toContain(1);
    const again = await log(token, s.id, [{ clientSetId: randomUUID(), sessionExerciseId: logged.exercises[0]!.id, setIndex: 1, weightKg: 60, reps: 9, loggedAt: at(9) }]);
    expect(again.statusCode, again.body).toBe(200);
    expect((await app.inject({ method: 'DELETE', url: `/v1/training/sessions/${s.id}/sets/${randomUUID()}`, headers: auth(token) })).statusCode).toBe(404);
  });

  it('exercises: reorder, superset, replace (no load carries over), remove', async () => {
    const { token, day } = await withProgram();
    const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    const [a, b] = s.exercises as [WorkoutSession['exercises'][number], WorkoutSession['exercises'][number]];
    const patch = (exerciseId: string, body: Record<string, unknown>) =>
      app.inject({ method: 'PATCH', url: `/v1/training/sessions/${s.id}/exercises/${exerciseId}`, headers: auth(token), payload: body });
    // Move the second to the front.
    expect((await patch(b.id, { orderIndex: 0 })).statusCode).toBe(200);
    let now: WorkoutSession = (await get(token, s.id)).json();
    expect(now.exercises.slice(0, 2).map((x) => x.id)).toEqual([b.id, a.id]);
    expect(now.exercises.map((x) => x.orderIndex)).toEqual(now.exercises.map((_, i) => i));
    // Superset the first two.
    await patch(b.id, { supersetGroup: 1 });
    await patch(a.id, { supersetGroup: 1 });
    now = (await get(token, s.id)).json();
    expect(now.exercises.filter((x) => x.supersetGroup === 1).length).toBe(2);
    // Replace the movement: same row, new exercise, targets kept (they belong to the plan row).
    const [other] = await sql<{ id: string }[]>`select id from exercises where slug = 'face-pull'`;
    expect((await patch(a.id, { exerciseId: other!.id })).statusCode).toBe(200);
    now = (await get(token, s.id)).json();
    expect(now.exercises.find((x) => x.id === a.id)!.slug).toBe('face-pull');
    // Remove.
    expect((await patch(b.id, { removed: true })).statusCode).toBe(200);
    now = (await get(token, s.id)).json();
    expect(now.exercises.some((x) => x.id === b.id)).toBe(false);
    expect(now.exercises.map((x) => x.orderIndex)).toEqual(now.exercises.map((_, i) => i));
    expect((await patch(randomUUID(), { removed: true })).statusCode).toBe(404);
  });

  it('complete: summary, no records on a baseline, replay returns the same; a later heavier session earns records once', async () => {
    const { token, day } = await withProgram();
    // Session 1: baseline.
    const s1: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    await logFirst(token, s1, 60, 10);
    const c1 = await complete(token, s1.id);
    expect(c1.statusCode, c1.body).toBe(200);
    const done1: WorkoutSession = c1.json();
    expect(done1.status).toBe('completed');
    expect(done1.durationSeconds).toBe(55 * 60);
    expect(done1.summary).not.toBeNull();
    expect(done1.summary!.prs).toEqual([]);
    expect(done1.summary!.workingSets).toBe(s1.exercises[0]!.targets.length);
    expect(done1.summary!.tonnageKg).toBe(60 * 10 * s1.exercises[0]!.targets.length);
    expect(done1.summary!.exercisesSkipped).toBe(s1.exercises.length - 1);
    // Completing again is the same answer.
    const c1b = await complete(token, s1.id, 99);
    expect(c1b.statusCode).toBe(200);
    expect((c1b.json() as WorkoutSession).durationSeconds).toBe(55 * 60);
    // Logging to it now is refused unless merging.
    const x = s1.exercises[0]!;
    // (A back-off set: stored, shown, never part of records or last performance.)
    const late = { clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: 9, setType: 'backoff', weightKg: 60, reps: 5, loggedAt: at(50) };
    expect((await log(token, s1.id, [late])).statusCode).toBe(409);
    expect((await log(token, s1.id, [late], true)).statusCode).toBe(200);

    // Session 2: last performance is session 1; heavier → records.
    const s2: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    expect(s2.exercises[0]!.lastPerformance).not.toBeNull();
    expect(s2.exercises[0]!.lastPerformance!.sessionId).toBe(s1.id);
    expect(s2.exercises[0]!.lastPerformance!.sets[0]).toMatchObject({ weightKg: 60, reps: 10 });
    expect(s2.exercises[0]!.lastPerformance!.sets.some((t) => t.setIndex === 9)).toBe(false);
    // The rows open with last time's weight and the plan's target reps — since
    // Phase 6 the source is the engine's recommendation (add-reps at 60 kg).
    expect(s2.exercises[0]!.prefill[0]).toEqual({ setIndex: 1, reps: 12, weightKg: 60, rir: 1, weightSource: 'recommendation' });
    expect(s2.exercises[0]!.recommendation).toMatchObject({ action: 'add-reps', weightKg: 60 });
    expect(s1.exercises[0]!.prefill[0]).toEqual({ setIndex: 1, reps: 12, weightKg: null, rir: 1, weightSource: 'none' });
    await logFirst(token, s2, 65, 10);
    const done2: WorkoutSession = (await complete(token, s2.id)).json();
    const types = done2.summary!.prs.map((p) => p.prType).sort();
    expect(types).toEqual(['1rm_est', 'volume', 'weight']);
    for (const pr of done2.summary!.prs) {
      expect(pr.exerciseId).toBe(x.exerciseId);
      expect(pr.reason.length).toBeGreaterThan(10);
    }
    expect(done2.exercises[0]!.sets.some((t) => t.isPr)).toBe(true);
    expect((await sql`select count(*)::int as c from exercise_prs where set_log_id in (select id from set_logs where session_exercise_id = ${done2.exercises[0]!.id})`)[0]!.c).toBe(3);
    // Replay of complete does not double the records.
    await complete(token, s2.id);
    expect((await sql`select count(*)::int as c from exercise_prs where user_id = (select user_id from workout_sessions where id = ${s2.id})`)[0]!.c).toBe(3);
    // Session 3: same as 2 → no records (ties are not records).
    const s3: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    await logFirst(token, s3, 65, 10);
    expect(((await complete(token, s3.id)).json() as WorkoutSession).summary!.prs).toEqual([]);
  });

  it('an abandoned session never counts as last performance or toward records', async () => {
    const { token, day } = await withProgram();
    const s1: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    await logFirst(token, s1, 100, 10);
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s1.id}/abandon`, headers: auth(token) });
    const s2: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(0) })).json();
    expect(s2.exercises[0]!.lastPerformance).toBeNull();
    await logFirst(token, s2, 60, 10);
    expect(((await complete(token, s2.id)).json() as WorkoutSession).summary!.prs).toEqual([]);
    expect((await complete(token, s1.id)).statusCode).toBe(409);
  });

  it('mesocycle week: first completed session of a new ISO week advances it, same week does not, capped at 8', async () => {
    const { token, program, day } = await withProgram();
    const week = async () => (await sql<{ w: number }[]>`select mesocycle_week as w from programs where id = ${program.id}`)[0]!.w;
    const finishOn = async (iso: string) => {
      const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: iso })).json();
      const r = await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(token), payload: { completedAt: iso } });
      expect(r.statusCode, r.body).toBe(200);
    };
    expect(await week()).toBe(1);
    await finishOn('2026-09-21T10:00:00.000Z'); // Mon W39
    expect(await week()).toBe(1);
    await finishOn('2026-09-24T10:00:00.000Z'); // Thu W39
    expect(await week()).toBe(1);
    await finishOn('2026-09-28T10:00:00.000Z'); // Mon W40
    expect(await week()).toBe(2);
    // 2026-10-04T19:00Z is Sunday in UTC but already Monday 00:30 in Kolkata → W41.
    await finishOn('2026-10-04T19:00:00.000Z');
    expect(await week()).toBe(3);
    for (let i = 0; i < 8; i++) await finishOn(new Date(Date.UTC(2026, 9, 12 + 7 * i, 10)).toISOString());
    expect(await week()).toBe(8);
  });

  it('history: newest first, paginated, the user\'s own only; a single session is fetchable', async () => {
    const { token, day } = await withProgram();
    for (let i = 0; i < 3; i++) {
      const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: at(i * 100) })).json();
      await complete(token, s.id, i * 100 + 40);
    }
    const p1 = await app.inject({ method: 'GET', url: '/v1/training/sessions?limit=2', headers: auth(token) });
    expect(p1.statusCode).toBe(200);
    const page1 = p1.json();
    expect(page1.items.length).toBe(2);
    expect(page1.items[0].startedAt > page1.items[1].startedAt).toBe(true);
    expect(page1.items[0]).toMatchObject({ status: 'completed', name: day.sessionName, exerciseCount: day.exercises.length, workingSets: 0, prCount: 0 });
    expect(page1.nextBefore).toBe(page1.items[1].startedAt);
    const p2 = await app.inject({ method: 'GET', url: `/v1/training/sessions?limit=2&before=${encodeURIComponent(page1.nextBefore)}`, headers: auth(token) });
    expect(p2.json().items.length).toBe(1);
    expect(p2.json().nextBefore).toBeNull();
    // Another user sees nothing of it.
    const stranger = await onboarded();
    expect((await app.inject({ method: 'GET', url: '/v1/training/sessions', headers: auth(stranger) })).json().items).toEqual([]);
    expect((await get(stranger, page1.items[0].id)).statusCode).toBe(404);
  });

  it('GET /training/today: the day with targets and last performance, rest days, the active session, done today', async () => {
    const { token, day } = await withProgram();
    const dow = day.dayOfWeek;
    const t1: TodayResponse = (await app.inject({ method: 'GET', url: `/v1/training/today?dayOfWeek=${dow}`, headers: auth(token) })).json();
    expect(t1.isRest).toBe(false);
    expect(t1.programDayId).toBe(day.id);
    expect(t1.sessionName).toBe(day.sessionName);
    expect(t1.exercises.map((x) => x.plannedExerciseId)).toEqual(day.exercises.map((x) => x.id));
    expect(t1.exercises[0]!.targets.length).toBe(day.exercises[0]!.setCount);
    expect(t1.exercises[0]!.lastPerformance).toBeNull();
    expect(t1.activeSession).toBeNull();
    expect(t1.completedSessionId).toBeNull();
    const rest = (await import('@fitos/contracts')).todayResponseSchema.parse(
      (await app.inject({ method: 'GET', url: `/v1/training/today?dayOfWeek=7`, headers: auth(token) })).json(),
    );
    expect(rest.isRest).toBe(true);
    expect(rest.exercises).toEqual([]);

    const s: WorkoutSession = (await start(token, { clientSessionId: randomUUID(), programDayId: day.id, startedAt: new Date().toISOString() })).json();
    const t2: TodayResponse = (await app.inject({ method: 'GET', url: `/v1/training/today?dayOfWeek=${dow}`, headers: auth(token) })).json();
    expect(t2.activeSession?.id).toBe(s.id);
    await logFirst(token, s, 60, 10);
    await app.inject({ method: 'POST', url: `/v1/training/sessions/${s.id}/complete`, headers: auth(token), payload: { completedAt: new Date().toISOString() } });
    const t3: TodayResponse = (await app.inject({ method: 'GET', url: `/v1/training/today?dayOfWeek=${dow}`, headers: auth(token) })).json();
    expect(t3.activeSession).toBeNull();
    expect(t3.completedSessionId).toBe(s.id);
    expect(t3.exercises[0]!.lastPerformance?.sets[0]).toMatchObject({ weightKg: 60, reps: 10 });
    // Without a programme: a rest day with nothing planned, no error.
    const fresh = await onboarded();
    const t4: TodayResponse = (await app.inject({ method: 'GET', url: '/v1/training/today', headers: auth(fresh) })).json();
    expect(t4.programId).toBeNull();
    expect(t4.isRest).toBe(true);
    expect(t4.dayOfWeek).toBeGreaterThanOrEqual(1);
  });

  it('every session route is default-deny', async () => {
    const id = randomUUID();
    for (const [method, url] of [
      ['GET', '/v1/training/today'], ['POST', '/v1/training/sessions'], ['GET', '/v1/training/sessions'], ['GET', `/v1/training/sessions/${id}`],
      ['POST', `/v1/training/sessions/${id}/sets`], ['PATCH', `/v1/training/sessions/${id}/sets/${id}`], ['DELETE', `/v1/training/sessions/${id}/sets/${id}`],
      ['POST', `/v1/training/sessions/${id}/exercises`], ['PATCH', `/v1/training/sessions/${id}/exercises/${id}`],
      ['POST', `/v1/training/sessions/${id}/complete`], ['POST', `/v1/training/sessions/${id}/abandon`],
    ] as [ 'GET' | 'POST' | 'PATCH' | 'DELETE', string][]) {
      const r = await app.inject({ method, url, headers: { 'x-forwarded-for': '203.0.113.1' }, ...(method === 'GET' || method === 'DELETE' ? {} : { payload: {} }) });
      expect(r.statusCode, `${method} ${url}`).toBe(401);
    }
  });
});
