/**
 * Beta 6.1 (F2) on real Postgres: weekdays and a rolling cycle, day ids and
 * exercises kept; today by the cycle; Skip today moves the cycle's start; a
 * shared cycle is used as the same cycle; the reminders follow the dates.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type SharedProgramme, type TodayResponse } from '@fitos/contracts';
import { localDateOf } from '@fitos/core/nutrition/log';
import { plusDays } from '@fitos/core/training/schedule';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/training/program/schedule (beta 6.1, real Postgres)', { timeout: 60_000 }, () => {
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
    await sql`delete from users where firebase_uid like 'cyc-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.150.250' });

  async function withProgram(): Promise<{ token: string; program: Program }> {
    n += 1;
    const token = `cyc-tok-${n}`;
    ipOf.set(token, `203.0.151.${n}`);
    verifier.accept(token, { uid: `cyc-uid-${n}`, email: `cyc${n}@vit.ac.in` });
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
  void next;
  void weekdays;
  const schedule = (token: string, payload: Record<string, unknown>) =>
    app.inject({ method: 'PUT', url: '/v1/training/program/schedule', headers: auth(token), payload });
  const localToday = () => localDateOf(new Date(), 'Asia/Kolkata');
  const sessionsInOrder = (p: Program) => [...p.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).filter((d) => !d.isRest);

  it('weekdays to "4 on, 1 off" and back: the sessions keep their ids and order; today is day 1', async () => {
    const { token, program } = await withProgram();
    const sessions = sessionsInOrder(program);
    expect(sessions).toHaveLength(4);

    const r = await schedule(token, { kind: 'cycle', on: 4, off: 1 });
    expect(r.statusCode, r.body).toBe(200);
    const cycle = r.json() as Program;
    expect(cycle).toMatchObject({ schedule: 'cycle', cycleLength: 5, cycleStart: localToday(), skippedOn: null });
    const ordered = [...cycle.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek);
    expect(ordered.map((d) => d.dayOfWeek)).toEqual([1, 2, 3, 4, 5]);
    expect(ordered.slice(0, 4).map((d) => d.id)).toEqual(sessions.map((s) => s.id));
    expect(ordered[4]!.isRest).toBe(true);
    // The exercises came along.
    expect(ordered[0]!.exercises.map((x) => x.exerciseId)).toEqual(sessions[0]!.exercises.map((x) => x.exerciseId));
    // Volume is averaged over seven days: 4 sessions in 5 days is more a week than 4 in 7.
    const chest = (p: Program) => p.weeklyVolume.chest ?? 0;
    expect(chest(cycle)).toBeCloseTo(Math.round(((chest(program) * 7) / 5) * 10) / 10, 1);

    const t = await today(token);
    expect(t).toMatchObject({ dayOfWeek: 1, programDayId: sessions[0]!.id, isRest: false });
    expect((await today(token, 5)).isRest).toBe(true);

    // Not a cycle of 2–14 days: 4 sessions, 1 on and 7 off would be 32.
    expect((await schedule(token, { kind: 'cycle', on: 1, off: 7 })).statusCode).toBe(422);

    // Back to weekdays: the usual days for four sessions, the same ids.
    const back = (await schedule(token, { kind: 'week' })).json() as Program;
    expect(back).toMatchObject({ schedule: 'week', cycleStart: null, cycleLength: null });
    expect(back.days).toHaveLength(7);
    expect(sessionsInOrder(back).map((d) => [d.id, d.dayOfWeek])).toEqual(sessions.map((s, i) => [s.id, [1, 2, 4, 5][i]]));
    // Weekdays again changes nothing.
    expect(((await schedule(token, { kind: 'week' })).json() as Program).days).toHaveLength(7);
  });

  it('Skip today on a cycle moves its start a day; the days stay; undo moves it back', async () => {
    const { token } = await withProgram();
    const cycle = (await schedule(token, { kind: 'cycle', on: 2, off: 1 })).json() as Program;
    expect(cycle.cycleLength).toBe(6);
    const places = Object.fromEntries(cycle.days.map((d) => [d.id, d.dayOfWeek]));
    const skipped = await skip(token);
    expect(skipped.statusCode, skipped.body).toBe(200);
    const after = skipped.json() as Program;
    expect(after.cycleStart).toBe(plusDays(localToday(), 1));
    expect(Object.fromEntries(after.days.map((d) => [d.id, d.dayOfWeek]))).toEqual(places);
    expect((await today(token)).skipped).toBe(true);
    const undone = (await undo(token)).json() as Program;
    expect(undone.cycleStart).toBe(localToday());
    expect((await today(token)).skipped).toBe(false);
  });

  it('a shared cycle is used as the same cycle, from today; the preview says it is one', async () => {
    const { token } = await withProgram();
    await schedule(token, { kind: 'cycle', on: 4, off: 1 });
    const share = await app.inject({ method: 'POST', url: '/v1/training/program/share', headers: auth(token), payload: {} });
    expect(share.statusCode, share.body).toBe(201);
    const code = (share.json() as { code: string }).code;
    const other = await withProgram();
    const preview = (await app.inject({ method: 'GET', url: `/v1/training/shared/${code}`, headers: auth(other.token) })).json() as SharedProgramme;
    expect(preview).toMatchObject({ schedule: 'cycle', cycleLength: 5, daysPerWeek: 4 });
    expect(preview.days.map((d) => d.dayOfWeek)).toEqual([1, 2, 3, 4, 5]);
    const used = await app.inject({ method: 'POST', url: `/v1/training/shared/${code}/use`, headers: auth(other.token), payload: {} });
    expect(used.statusCode, used.body).toBe(200);
    expect(used.json()).toMatchObject({ schedule: 'cycle', cycleLength: 5, cycleStart: localToday() });
  });

  it('the reminders follow the cycle by date, never on its rest day', async () => {
    const { token } = await withProgram();
    const cycle = (await schedule(token, { kind: 'cycle', on: 4, off: 1 })).json() as Program;
    const names = Object.fromEntries(cycle.days.map((d) => [d.dayOfWeek, d.sessionName]));
    const patched = await app.inject({ method: 'PATCH', url: '/v1/notifications/settings', headers: auth(token), payload: { enabled: true, kinds: { 'workout-reminder': true } } });
    expect(patched.statusCode, patched.body).toBe(200);
    const plan = (await app.inject({ method: 'POST', url: '/v1/notifications/plan', headers: auth(token), payload: { events: [] } })).json() as {
      items: { kind: string; localDate: string; title: string; body: string }[];
    };
    const reminders = plan.items.filter((i) => i.kind === 'workout-reminder');
    expect(reminders.length).toBeGreaterThan(0);
    for (const r of reminders) {
      const offset = Math.round((Date.parse(r.localDate) - Date.parse(localToday())) / 86_400_000);
      const n = (((offset % 5) + 5) % 5) + 1;
      expect(n).not.toBe(5);
      expect(`${r.title} ${r.body}`).toContain(names[n]!);
    }
  });

  it('audit 2026-11-10: rest days edited into sessions — 7 go on every weekday, 8 are refused; such a code cannot be copied', async () => {
    const { token, program } = await withProgram();
    const cycle = (await schedule(token, { kind: 'cycle', on: 1, off: 1 })).json() as Program;
    expect(cycle.cycleLength).toBe(8);
    const someExercise = program.days.find((d) => !d.isRest)!.exercises[0]!;
    const fill = async (d: Program['days'][number]) => {
      const r = await app.inject({
        method: 'PATCH',
        url: `/v1/training/program/days/${d.id}`,
        headers: auth(token),
        payload: { exercises: [{ exerciseId: someExercise.exerciseId, setCount: 3, repMin: 8, repMax: 12, targetRir: 2 }] },
      });
      expect(r.statusCode, r.body).toBe(200);
    };
    const rests = [...cycle.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).filter((d) => d.isRest);
    await fill(rests[0]!);
    await fill(rests[1]!);
    await fill(rests[2]!);
    // 7 sessions: every weekday.
    const seven = await schedule(token, { kind: 'week' });
    expect(seven.statusCode, seven.body).toBe(200);
    expect((seven.json() as Program).days.filter((d) => !d.isRest).map((d) => d.dayOfWeek).sort()).toEqual([1, 2, 3, 4, 5, 6, 7]);
    // Back to a cycle, one more session: 8 do not fit in a week.
    const again = (await schedule(token, { kind: 'cycle', on: 7, off: 1 })).json() as Program;
    await fill(again.days.find((d) => d.isRest)!);
    const eight = await schedule(token, { kind: 'week' });
    expect(eight.statusCode).toBe(422);
    expect(JSON.stringify(eight.json())).toContain('too-many-sessions');
    // Shared, it cannot become someone else's programme (2–6 sessions).
    const code = ((await app.inject({ method: 'POST', url: '/v1/training/program/share', headers: auth(token), payload: {} })).json() as { code: string }).code;
    const other = await withProgram();
    const used = await app.inject({ method: 'POST', url: `/v1/training/shared/${code}/use`, headers: auth(other.token), payload: {} });
    expect(used.statusCode).toBe(422);
  });

  it('audit 2026-11-10: a shared cycle keeps its exact layout, an edited rest day included', async () => {
    const { token, program } = await withProgram();
    const cycle = (await schedule(token, { kind: 'cycle', on: 2, off: 1 })).json() as Program;
    const ordered = [...cycle.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek);
    expect(ordered.map((d) => d.isRest)).toEqual([false, false, true, false, false, true]);
    // The first rest day becomes a session: S S S S S R.
    const someExercise = program.days.find((d) => !d.isRest)!.exercises[0]!;
    await app.inject({
      method: 'PATCH',
      url: `/v1/training/program/days/${ordered[2]!.id}`,
      headers: auth(token),
      payload: { exercises: [{ exerciseId: someExercise.exerciseId, setCount: 3, repMin: 8, repMax: 12, targetRir: 2 }] },
    });
    const code = ((await app.inject({ method: 'POST', url: '/v1/training/program/share', headers: auth(token), payload: {} })).json() as { code: string }).code;
    const other = await withProgram();
    const used = (await app.inject({ method: 'POST', url: `/v1/training/shared/${code}/use`, headers: auth(other.token), payload: {} })).json() as Program;
    expect([...used.days].sort((a, b) => a.dayOfWeek - b.dayOfWeek).map((d) => d.isRest)).toEqual([false, false, false, false, false, true]);
  });
});
