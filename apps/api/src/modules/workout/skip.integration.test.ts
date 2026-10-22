/**
 * ADR-030 through the HTTP surface on real Postgres: skipping today moves
 * every day of the programme one weekday later (ids kept, order kept), today
 * shows as skipped, tomorrow brings today's session; undo moves it back; the
 * refusals (already skipped, a session open, trained today, nothing to undo).
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type TodayResponse } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/training/today/skip (ADR-030, real Postgres)', () => {
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
    await sql`delete from users where firebase_uid like 'skip-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.140.250' });

  async function withProgram(): Promise<{ token: string; program: Program }> {
    n += 1;
    const token = `skip-tok-${n}`;
    ipOf.set(token, `203.0.141.${n}`);
    verifier.accept(token, { uid: `skip-uid-${n}`, email: `skip${n}@vit.ac.in` });
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
    const r = await app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth(token), payload: {} });
    expect(r.statusCode, r.body).toBe(200);
    return { token, program: r.json() };
  }

  const today = async (token: string, dayOfWeek?: number): Promise<TodayResponse> => {
    const r = await app.inject({
      method: 'GET',
      url: `/v1/training/today${dayOfWeek === undefined ? '' : `?dayOfWeek=${dayOfWeek}`}`,
      headers: auth(token),
    });
    expect(r.statusCode, r.body).toBe(200);
    return r.json();
  };
  const skip = (token: string) => app.inject({ method: 'POST', url: '/v1/training/today/skip', headers: auth(token) });
  const undo = (token: string) => app.inject({ method: 'DELETE', url: '/v1/training/today/skip', headers: auth(token) });
  const next = (dow: number) => (dow % 7) + 1;
  /** Each day by id → its weekday. */
  const weekdays = (p: Program) => Object.fromEntries(p.days.map((d) => [d.id, d.dayOfWeek]));

  it('skip: every day one weekday later (same ids, same order), today skipped, tomorrow brings today’s session; undo moves it back', async () => {
    const { token, program } = await withProgram();
    expect(program.skippedOn).toBeNull();
    const before = await today(token);
    expect(before.skipped).toBe(false);
    const dow = before.dayOfWeek;
    const todays = program.days.find((d) => d.dayOfWeek === dow)!;

    const r = await skip(token);
    expect(r.statusCode, r.body).toBe(200);
    const skipped: Program = r.json();
    expect(skipped.skippedOn).toBe(before.date);
    expect(skipped.days).toHaveLength(7);
    const was = weekdays(program);
    for (const [id, d] of Object.entries(weekdays(skipped))) expect(d).toBe(next(was[id]!));
    // Monday first, as ever.
    expect(skipped.days.map((d) => d.dayOfWeek)).toEqual([1, 2, 3, 4, 5, 6, 7]);

    const now = await today(token);
    expect(now).toMatchObject({ date: before.date, skipped: true, isRest: true, sessionName: null, programDayId: null, exercises: [] });
    // Tomorrow is today's day, exercises and all.
    const tomorrow = await today(token, next(dow));
    expect(tomorrow.skipped).toBe(false);
    expect(tomorrow.programDayId).toBe(todays.id);
    expect(tomorrow.sessionName).toBe(todays.isRest ? null : todays.sessionName);

    // Once a day.
    const again = await skip(token);
    expect(again.statusCode).toBe(409);
    expect(again.json().error.details).toEqual([{ path: 'date', issue: 'already-skipped' }]);

    const u = await undo(token);
    expect(u.statusCode, u.body).toBe(200);
    const back: Program = u.json();
    expect(back.skippedOn).toBeNull();
    expect(weekdays(back)).toEqual(was);
    expect((await today(token)).skipped).toBe(false);
    const none = await undo(token);
    expect(none.statusCode).toBe(409);
    expect(none.json().error.details).toEqual([{ path: 'date', issue: 'not-skipped' }]);
  });

  it('refused while a session is open, and after training today', async () => {
    const { token, program } = await withProgram();
    const day = program.days.find((d) => !d.isRest)!;
    const started = await app.inject({
      method: 'POST',
      url: '/v1/training/sessions',
      headers: auth(token),
      payload: { clientSessionId: randomUUID(), programDayId: day.id, startedAt: new Date().toISOString() },
    });
    expect(started.statusCode, started.body).toBe(201);
    const open = await skip(token);
    expect(open.statusCode).toBe(409);
    expect(open.json().error.details).toEqual([{ path: 'session', issue: 'session-open' }]);

    const id = started.json().id as string;
    const done = await app.inject({
      method: 'POST',
      url: `/v1/training/sessions/${id}/complete`,
      headers: auth(token),
      payload: { completedAt: new Date().toISOString() },
    });
    expect(done.statusCode, done.body).toBe(200);
    const trained = await skip(token);
    expect(trained.statusCode).toBe(409);
    expect(trained.json().error.details).toEqual([{ path: 'date', issue: 'trained-today' }]);
  });

  it('no programme: 404', async () => {
    n += 1;
    const token = `skip-tok-${n}`;
    ipOf.set(token, `203.0.141.${n}`);
    verifier.accept(token, { uid: `skip-uid-${n}`, email: `skip${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    expect((await skip(token)).statusCode).toBe(404);
    expect((await undo(token)).statusCode).toBe(404);
  });
});
