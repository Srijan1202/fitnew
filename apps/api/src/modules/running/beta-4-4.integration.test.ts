/**
 * Beta 4.4 (owner 2026-10-29) on real Postgres: your own sessions kept with
 * the account (E28), plans with 1 or 2 runs a week, and the streak's last 4
 * weeks for the Streak & rewards page.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  MAX_MY_WORKOUTS,
  myWorkoutListSchema,
  myWorkoutSchema,
  runningPlanSchema,
  streakSchema,
  type CreatePlanRequest,
  type RunWorkout,
} from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

const session = (name = 'Hills'): RunWorkout => ({
  name,
  steps: [
    { kind: 'warmup', distanceM: null, seconds: 300, pace: null, effort: 'easy', rep: null },
    { kind: 'work', distanceM: 400, seconds: null, pace: null, effort: 'hard', rep: { of: 1, index: 1 } },
    { kind: 'cooldown', distanceM: null, seconds: 300, pace: null, effort: 'easy', rep: null },
  ],
});

describeIfDb('beta 4.4 (real Postgres)', { timeout: 90_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await sql`delete from feature_flags where key = 'running'`;
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'b44-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const headers = (u: U) => ({ authorization: `Bearer ${u.token}`, 'x-forwarded-for': `203.0.192.${n % 250}` });

  async function user(): Promise<U> {
    n += 1;
    const token = `b44-tok-${n}`;
    verifier.accept(token, { uid: `b44-uid-${n}`, email: `b44-${n}@vit.ac.in` });
    const u = { token, id: '' };
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(u), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`b44-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PUT' | 'DELETE', path: string, payload?: unknown) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u), ...(payload === undefined ? {} : { payload: payload as object }) });

  describe('your own sessions (E28)', () => {
    it('kept with the account: created, replaced by the same id, listed newest first, deleted (twice is fine)', async () => {
      const u = await user();
      const a = randomUUID();
      const b = randomUUID();
      const first = await call(u, 'PUT', `/running/my-workouts/${a}`, session('Hills'));
      expect(first.statusCode).toBe(201);
      expect(myWorkoutSchema.parse(first.json())).toMatchObject({ id: a, name: 'Hills' });
      expect((await call(u, 'PUT', `/running/my-workouts/${b}`, session('Strides'))).statusCode).toBe(201);
      const again = await call(u, 'PUT', `/running/my-workouts/${a}`, session('Hills, longer'));
      expect(again.statusCode).toBe(200);
      const list = myWorkoutListSchema.parse((await call(u, 'GET', '/running/my-workouts')).json());
      expect(list.workouts.map((w) => w.name)).toEqual(['Hills, longer', 'Strides']);
      expect(list.workouts[0]!.steps).toHaveLength(3);

      expect((await call(u, 'DELETE', `/running/my-workouts/${b}`)).statusCode).toBe(204);
      expect((await call(u, 'DELETE', `/running/my-workouts/${b}`)).statusCode).toBe(204);
      expect(myWorkoutListSchema.parse((await call(u, 'GET', '/running/my-workouts')).json()).workouts).toHaveLength(1);
    });

    it('another user never sees them; a bad session is 422; past the limit is 409', async () => {
      const u = await user();
      const other = await user();
      const id = randomUUID();
      await call(u, 'PUT', `/running/my-workouts/${id}`, session());
      expect(myWorkoutListSchema.parse((await call(other, 'GET', '/running/my-workouts')).json()).workouts).toEqual([]);
      // The same phone id under another account is that account's own.
      expect((await call(other, 'PUT', `/running/my-workouts/${id}`, session('Theirs'))).statusCode).toBe(201);
      expect(myWorkoutListSchema.parse((await call(u, 'GET', '/running/my-workouts')).json()).workouts[0]!.name).toBe('Hills');

      expect((await call(u, 'PUT', `/running/my-workouts/${randomUUID()}`, { name: '', steps: [] })).statusCode).toBe(422);
      expect((await call(u, 'PUT', '/running/my-workouts/not-a-uuid', session())).statusCode).toBe(422);

      await sql`insert into running_workouts (user_id, client_id, name, steps)
        select ${u.id}, gen_random_uuid(), 'Filler', '[]'::jsonb from generate_series(2, ${MAX_MY_WORKOUTS})`;
      expect((await call(u, 'PUT', `/running/my-workouts/${randomUUID()}`, session('One too many'))).statusCode).toBe(409);
      // Replacing one at the limit is fine.
      expect((await call(u, 'PUT', `/running/my-workouts/${id}`, session('Still mine'))).statusCode).toBe(200);
    });
  });

  it('a plan of 1 or 2 runs a week, for any distance', async () => {
    const u = await user();
    const today = new Date();
    const weekday = ((today.getUTCDay() + 6) % 7) + 1;
    const plan = (over: Partial<CreatePlanRequest>): CreatePlanRequest => ({
      goal: 'marathon',
      level: 'runner',
      race: { distance: '10k', seconds: 3000 },
      goalSeconds: null,
      daysPerWeek: 1,
      weekdays: [weekday],
      longRunWeekday: weekday,
      ...over,
    });
    const one = await call(u, 'POST', '/running/plans', plan({}));
    expect(one.statusCode).toBe(201);
    const p1 = runningPlanSchema.parse(one.json());
    expect(p1.daysPerWeek).toBe(1);
    expect(p1.runs.slice(0, -1).every((r) => r.kind === 'long')).toBe(true);

    const other = weekday === 7 ? 3 : 7;
    const two = await call(u, 'POST', '/running/plans', plan({ goal: '5k', daysPerWeek: 2, weekdays: [weekday, other].sort(), longRunWeekday: weekday }));
    expect(two.statusCode).toBe(201);
    expect(runningPlanSchema.parse(two.json()).daysPerWeek).toBe(2);

    expect((await call(u, 'POST', '/running/plans', plan({ daysPerWeek: 0 as never, weekdays: [] }))).statusCode).toBe(422);
  });

  it('the streak carries the last 28 days, oldest first, ending today', async () => {
    const u = await user();
    const s = streakSchema.parse((await call(u, 'GET', '/progress/streak')).json());
    expect(s.days).toHaveLength(28);
    const last = s.days.at(-1)!;
    expect(last.status === 'today' || last.status === 'rest').toBe(true);
    // A new account: the days before it are "before".
    expect(s.days[0]!.status).toBe('before');
    // Beta 4.8 (owner): the month calendar, from the first of this month
    // (the joining month) to today.
    expect(s.calendar[0]!.date.slice(8)).toBe('01');
    expect(s.calendar.at(-1)!.date).toBe(last.date);
    expect(s.calendar).toHaveLength(Number(last.date.slice(8)));
  });
});
