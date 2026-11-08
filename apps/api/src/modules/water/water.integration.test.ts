/**
 * Beta 6.0 (ADR-059): /v1/water on real Postgres — today's total and its
 * target from the latest weigh-in, the PUT that replaces a day's total (so a
 * repeat changes nothing), the date rules, and the admin's switch.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { waterDaySchema } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/water (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let admin: U;

  interface U {
    token: string;
    id: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.41.${n % 250}.${(n * 7) % 250}` });

  async function user(opts: { admin?: boolean } = {}): Promise<U> {
    n += 1;
    const token = `wt-tok-${n}`;
    verifier.accept(token, { uid: `wt-uid-${n}`, email: `wt${n}@example.com`, claims: opts.admin === true ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`wt-uid-${n}`}`;
    await sql`update users set timezone = 'Asia/Kolkata' where id = ${row!.id}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'PUT', path: string, payload?: unknown) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u.token), ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}) });
  const issue = (r: { json: () => unknown }): string | undefined => (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;
  const today = (): string => localDateOf(new Date(), 'Asia/Kolkata');

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
    admin = await user({ admin: true });
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'wt-uid-%'`;
    await sql`delete from feature_flags where key = 'water'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('today starts at 0 against 2.5 L; a weigh-in sets 35 ml a kg; PUT replaces the total, and a repeat changes nothing', async () => {
    const u = await user();
    const first = waterDaySchema.parse((await call(u, 'GET', '/water/today')).json());
    expect(first).toEqual({ date: today(), ml: 0, targetMl: 2500, fromWeight: false });

    await sql`insert into body_metrics (user_id, measured_on, weight_kg, source) values (${u.id}, ${addDays(today(), -3)}, 80, 'manual')`;
    const put = await call(u, 'PUT', `/water/days/${today()}`, { ml: 750 });
    expect(put.statusCode, put.body).toBe(201);
    expect(waterDaySchema.parse(put.json())).toEqual({ date: today(), ml: 750, targetMl: 2750, fromWeight: true });
    const again = await call(u, 'PUT', `/water/days/${today()}`, { ml: 750 });
    expect(again.statusCode).toBe(200);
    expect((await call(u, 'PUT', `/water/days/${today()}`, { ml: 500 })).statusCode).toBe(200);
    expect(waterDaySchema.parse((await call(u, 'GET', '/water/today')).json()).ml).toBe(500);
    const rows = await sql`select ml from water_logs where user_id = ${u.id}`;
    expect(rows).toEqual([{ ml: 500 }]);

    // Yesterday is its own day, and only this user's.
    expect((await call(u, 'PUT', `/water/days/${addDays(today(), -1)}`, { ml: 2000 })).statusCode).toBe(201);
    const other = await user();
    expect(waterDaySchema.parse((await call(other, 'GET', '/water/today')).json()).ml).toBe(0);
  });

  it('a day ahead, more than 7 days back, a non-date and more than 10 L are refused', async () => {
    const u = await user();
    const ahead = await call(u, 'PUT', `/water/days/${addDays(today(), 1)}`, { ml: 250 });
    expect(ahead.statusCode).toBe(422);
    expect(issue(ahead)).toBe('in the future');
    const old = await call(u, 'PUT', `/water/days/${addDays(today(), -8)}`, { ml: 250 });
    expect(old.statusCode).toBe(422);
    expect(issue(old)).toBe('more than 7 days ago');
    expect((await call(u, 'PUT', `/water/days/${addDays(today(), -7)}`, { ml: 250 })).statusCode).toBe(201);
    expect((await call(u, 'PUT', '/water/days/2026-02-30', { ml: 250 })).statusCode).toBe(422);
    expect((await call(u, 'PUT', `/water/days/${today()}`, { ml: 10_001 })).statusCode).toBe(422);
    expect((await call(u, 'PUT', `/water/days/${today()}`, { ml: 12.5 })).statusCode).toBe(422);
  });

  it("the admin's water switch refuses it, and it comes back on", async () => {
    const u = await user();
    expect((await call(admin, 'PUT', '/admin/flags/water', { enabled: false })).statusCode).toBe(200);
    try {
      const off = await call(u, 'GET', '/water/today');
      expect(off.statusCode).toBe(403);
      expect(issue(off)).toBe('feature-off');
      expect((await call(u, 'PUT', `/water/days/${today()}`, { ml: 250 })).statusCode).toBe(403);
    } finally {
      expect((await call(admin, 'PUT', '/admin/flags/water', { enabled: true })).statusCode).toBe(200);
    }
    expect((await call(u, 'GET', '/water/today')).statusCode).toBe(200);
  });
});
