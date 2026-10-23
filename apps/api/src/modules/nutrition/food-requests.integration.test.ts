/**
 * Beta 3.2 (ADR-032) on real Postgres with the real food seed: an empty
 * search is counted once per person a day and once per person, "Ask us"
 * once per person; text that finds a food is never counted; no user id is
 * stored; the admin list is most-wanted first and its status is audited.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { seedFoods } from '../../db/food-seed/load.js';
import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/nutrition/foods/requests (real Postgres, real seed)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  interface U {
    token: string;
    uid: string;
    id: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.40.${n % 250}.${(n * 3) % 250}` });

  async function user(admin = false): Promise<U> {
    n += 1;
    const token = `fr-tok-${n}`;
    const uid = `fr-uid-${n}`;
    verifier.accept(token, { uid, email: `fr${n}@example.com`, claims: admin ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${uid}`;
    return { token, uid, id: row!.id };
  }

  const report = (u: U, query: string, asked?: boolean) =>
    app.inject({
      method: 'POST',
      url: '/v1/nutrition/foods/requests',
      headers: headers(u.token),
      payload: asked === undefined ? { query } : { query, asked },
    });
  const call = (u: U, method: 'GET' | 'PATCH', path: string, payload?: Record<string, unknown>) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u.token), ...(payload !== undefined ? { payload } : {}) });
  const row = async (query: string) =>
    (await sql<{ searches: number; people: number; asked: number; status: string }[]>`
      select searches, people, asked, status from food_requests where query = ${query}`)[0];

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await seedFoods(url);
    await sql`delete from food_requests`;
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from food_requests`;
    await sql`delete from audit_logs where action = 'food-request.status'`;
    await sql`delete from users where firebase_uid like 'fr-uid-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('an empty search is counted once per person a day and once per person; "Ask us" once per person', async () => {
    const a = await user();
    const b = await user();
    expect((await report(a, '  KOMBUCHA  ')).statusCode).toBe(204);
    expect(await row('kombucha')).toEqual({ searches: 1, people: 1, asked: 0, status: 'open' });
    // The same person again today: nothing more.
    await report(a, 'kombucha');
    expect(await row('kombucha')).toMatchObject({ searches: 1, people: 1 });
    // They ask for it: once.
    await report(a, 'Kombucha', true);
    await report(a, 'Kombucha', true);
    expect(await row('kombucha')).toMatchObject({ searches: 1, people: 1, asked: 1 });
    // Someone else.
    await report(b, 'kombucha');
    expect(await row('kombucha')).toMatchObject({ searches: 2, people: 2, asked: 1 });
  });

  it('text that does find a food is never counted', async () => {
    const a = await user();
    expect((await report(a, 'Aloo paratha')).statusCode).toBe(204);
    expect(await row('aloo paratha')).toBeUndefined();
  });

  it('no user id is stored: the marks are hashes, the tally has no user column', async () => {
    const a = await user();
    await report(a, 'jalebi rabri special', true);
    const marks = await sql<{ mark: string }[]>`
      select m.mark from food_request_marks m join food_requests r on r.id = m.request_id where r.query = 'jalebi rabri special'`;
    expect(marks).toHaveLength(3);
    for (const m of marks) {
      expect(m.mark).toMatch(/^[0-9a-f]{64}$/);
      expect(m.mark).not.toContain(a.id);
      expect(m.mark).not.toContain(a.uid);
    }
    const columns = await sql<{ column_name: string }[]>`
      select column_name from information_schema.columns where table_name = 'food_requests'`;
    expect(columns.map((c) => c.column_name)).not.toContain('user_id');
  });

  it('too short, too long or an extra field is refused (422)', async () => {
    const a = await user();
    expect((await report(a, 'a')).statusCode).toBe(422);
    expect((await report(a, '?!')).statusCode).toBe(422); // nothing left after normalising
    expect((await report(a, 'x'.repeat(121))).statusCode).toBe(422);
    const extra = await app.inject({ method: 'POST', url: '/v1/nutrition/foods/requests', headers: headers(a.token), payload: { query: 'idli', who: 'me' } });
    expect(extra.statusCode).toBe(422);
  });

  it('the admin list: most-wanted first; status marked and audited; only admins', async () => {
    const admin = await user(true);
    const plain = await user();
    const people = [await user(), await user(), await user()];
    for (const p of people) await report(p, 'tempeh');
    await report(people[0]!, 'natto');

    expect((await call(plain, 'GET', '/admin/foods/requests')).statusCode).toBe(403);
    const list = await call(admin, 'GET', '/admin/foods/requests');
    expect(list.statusCode, list.body).toBe(200);
    const items = (list.json() as { items: { id: string; query: string; people: number }[] }).items;
    const order = items.map((i) => i.query);
    expect(order.indexOf('tempeh')).toBeLessThan(order.indexOf('natto'));
    const kothu = items.find((i) => i.query === 'tempeh')!;
    expect(kothu.people).toBe(3);

    expect((await call(plain, 'PATCH', `/admin/foods/requests/${kothu.id}`, { status: 'added' })).statusCode).toBe(403);
    const done = await call(admin, 'PATCH', `/admin/foods/requests/${kothu.id}`, { status: 'added' });
    expect(done.statusCode, done.body).toBe(200);
    expect(done.json()).toMatchObject({ status: 'added', resolvedAt: expect.any(String) });
    const [audit] = await sql<{ actor_user_id: string; metadata: Record<string, unknown> }[]>`
      select actor_user_id, metadata from audit_logs where action = 'food-request.status' and entity_id = ${kothu.id}`;
    expect(audit).toEqual({ actor_user_id: admin.id, metadata: { status: 'added', query: 'tempeh' } });

    const open = (await call(admin, 'GET', '/admin/foods/requests?status=open')).json() as { items: { query: string }[] };
    expect(open.items.map((i) => i.query)).not.toContain('tempeh');
    const added = (await call(admin, 'GET', '/admin/foods/requests?status=added')).json() as { items: { query: string }[] };
    expect(added.items.map((i) => i.query)).toEqual(['tempeh']);
    expect((await call(admin, 'PATCH', '/admin/foods/requests/00000000-0000-4000-8000-000000000000', { status: 'ignored' })).statusCode).toBe(404);
    expect((await call(admin, 'PATCH', `/admin/foods/requests/${kothu.id}`, { status: 'maybe' })).statusCode).toBe(422);
  });
});
