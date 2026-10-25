/**
 * Beta 3.2 (ADR-032) on real Postgres with the real food seed: a custom food
 * shared with everyone is found by others after FITOS's own foods, marked
 * community; sharing is refused for an implausible or copied food; others
 * report wrong numbers once each; the admin panel hides or shows it again
 * (audited) and never says who added it; the owner's export leaves other
 * people's reports out; deleting the account deletes the food.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION } from '@fitos/contracts';

import { seedFoods } from '../../db/food-seed/load.js';
import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('community foods (real Postgres, real seed)', () => {
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

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.41.${n % 250}.${(n * 5) % 250}` });

  async function user(admin = false): Promise<U> {
    n += 1;
    const token = `cf-tok-${n}`;
    const uid = `cf-uid-${n}`;
    verifier.accept(token, { uid, email: `cf${n}@example.com`, claims: admin ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${uid}`;
    return { token, uid, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PATCH' | 'DELETE', path: string, payload?: Record<string, unknown>) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u.token), ...(payload !== undefined ? { payload } : {}) });

  /** A protein bar from its label: 200 kcal = 4×20 + 4×21 + 9×4 = 200. */
  const bar = (name: string, share: boolean, overrides: Record<string, unknown> = {}) => ({
    clientFoodId: randomUUID(),
    name,
    brand: 'Local',
    basis: 'per_serving',
    servingLabel: '1 bar (50 g)',
    servingGrams: 50,
    kcal: 200,
    proteinG: 20,
    carbG: 21,
    fatG: 4,
    ...(share ? { shareWithCommunity: true } : {}),
    ...overrides,
  });

  type Item = { id: string; name: string; isCustom: boolean; community: boolean; source: string };
  // Beta 3.7: 1,800 foods — the community one can sit beyond the default 20, so ask for 50.
  const search = async (u: U, q: string) =>
    ((await call(u, 'GET', `/nutrition/foods/search?q=${encodeURIComponent(q)}&limit=50`)).json() as { items: Item[] }).items;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await seedFoods(url);
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from audit_logs where action = 'community-food.visibility'`;
    await sql`delete from users where firebase_uid like 'cf-uid-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('a shared food is found by everyone, marked community, after FITOS foods; a private one stays private', async () => {
    const owner = await user();
    const other = await user();
    const shared = await call(owner, 'POST', '/nutrition/foods', bar('Kolkata kathi roll bar', true));
    expect(shared.statusCode, shared.body).toBe(201);
    expect(shared.json()).toMatchObject({ community: true, isCustom: true, isVerified: false });
    const mine = await call(owner, 'POST', '/nutrition/foods', bar('Grandma protein bar', false));
    expect(mine.json()).toMatchObject({ community: false });

    const found = await search(other, 'kathi roll bar');
    const hit = found.find((f) => f.name === 'Kolkata kathi roll bar');
    expect(hit).toMatchObject({ community: true, isCustom: false });
    expect((await search(other, 'grandma protein bar')).map((f) => f.name)).not.toContain('Grandma protein bar');

    // Someone else's shared food comes after FITOS's own for the same text.
    const paratha = await call(owner, 'POST', '/nutrition/foods', bar('Paratha protein bar', true));
    expect(paratha.statusCode, paratha.body).toBe(201);
    const order = (await search(other, 'paratha')).map((f) => f.community);
    const firstCommunity = order.indexOf(true);
    expect(firstCommunity).toBeGreaterThan(0);
    expect(order.slice(firstCommunity).every((c) => c)).toBe(true);
  });

  it('sharing needs a real name, calories that add up and no copy of a FITOS food; keeping it private needs neither', async () => {
    const owner = await user();
    const issue = async (body: Record<string, unknown>) => {
      const r = await call(owner, 'POST', '/nutrition/foods', body);
      return [r.statusCode, (r.json() as { error?: { details?: { path: string; issue: string }[] } }).error?.details?.[0]] as const;
    };
    expect(await issue(bar('Ab', true))).toEqual([422, { path: 'name', issue: 'too-short' }]);
    // 400 kcal for macros that make 200.
    expect(await issue(bar('Odd bar', true, { kcal: 400 }))).toEqual([422, { path: 'kcal', issue: 'does-not-add-up' }]);
    const [code, detail] = await issue(bar('Aloo paratha', true));
    expect(code).toBe(409);
    expect(detail!.issue).toMatch(/^exists:[0-9a-f-]{36}$/);
    // Private: the user's own business.
    expect((await call(owner, 'POST', '/nutrition/foods', bar('Ab', false))).statusCode).toBe(201);
    expect((await call(owner, 'POST', '/nutrition/foods', bar('Aloo paratha', false))).statusCode).toBe(201);
  });

  it('others report wrong numbers once each; not your own food, not a private one', async () => {
    const owner = await user();
    const a = await user();
    const b = await user();
    const food = (await call(owner, 'POST', '/nutrition/foods', bar('Millet crunch bar', true))).json() as { id: string };
    const priv = (await call(owner, 'POST', '/nutrition/foods', bar('Secret bar', false))).json() as { id: string };
    expect((await call(a, 'POST', `/nutrition/foods/${food.id}/report`, { note: 'This is 150 kcal on the pack' })).statusCode).toBe(204);
    expect((await call(a, 'POST', `/nutrition/foods/${food.id}/report`, {})).statusCode).toBe(204);
    expect((await call(b, 'POST', `/nutrition/foods/${food.id}/report`, {})).statusCode).toBe(204);
    const [count] = await sql<{ n: number }[]>`select count(*)::int as n from food_reports where food_id = ${food.id}`;
    expect(count!.n).toBe(2);
    expect((await call(owner, 'POST', `/nutrition/foods/${food.id}/report`, {})).statusCode).toBe(404);
    expect((await call(a, 'POST', `/nutrition/foods/${priv.id}/report`, {})).statusCode).toBe(404);
    expect((await call(a, 'POST', `/nutrition/foods/${food.id}/report`, { note: 'x'.repeat(301) })).statusCode).toBe(422);
  });

  it('the admin panel: most-reported first, no owner; hide takes it back to its owner only; show again; audited', async () => {
    const admin = await user(true);
    const owner = await user();
    const other = await user();
    const food = (await call(owner, 'POST', '/nutrition/foods', bar('Ragi choco bar', true))).json() as { id: string };
    await call(other, 'POST', `/nutrition/foods/${food.id}/report`, { note: 'Carbs look low' });

    expect((await call(other, 'GET', '/admin/foods/community')).statusCode).toBe(403);
    const list = await call(admin, 'GET', '/admin/foods/community');
    expect(list.statusCode, list.body).toBe(200);
    const row = (list.json() as { items: Record<string, unknown>[] }).items.find((i) => i['id'] === food.id)!;
    expect(row).toMatchObject({ name: 'Ragi choco bar', visibility: 'community', reports: 1, notes: ['Carbs look low'], kcal: 200, proteinG: 20 });
    expect(JSON.stringify(row)).not.toContain(owner.id);
    // Never the owner's sign-in id or email (not just "cf": random hex ids contain it).
    expect(JSON.stringify(row)).not.toMatch(/cf-uid-|cf\d+@example\.com/);

    const hid = await call(admin, 'PATCH', `/admin/foods/community/${food.id}`, { visibility: 'hidden' });
    expect(hid.statusCode, hid.body).toBe(200);
    expect(hid.json()).toMatchObject({ visibility: 'hidden' });
    expect((await search(other, 'ragi choco bar')).map((f) => f.name)).not.toContain('Ragi choco bar');
    expect((await search(owner, 'ragi choco bar')).find((f) => f.name === 'Ragi choco bar')).toMatchObject({ isCustom: true, community: false });

    await call(admin, 'PATCH', `/admin/foods/community/${food.id}`, { visibility: 'community' });
    expect((await search(other, 'ragi choco bar')).map((f) => f.name)).toContain('Ragi choco bar');
    const audits = await sql<{ metadata: Record<string, unknown> }[]>`
      select metadata from audit_logs where action = 'community-food.visibility' and entity_id = ${food.id} order by occurred_at`;
    expect(audits.map((a) => a.metadata['visibility'])).toEqual(['hidden', 'community']);
    // A private food is not the panel's to share.
    const priv = (await call(owner, 'POST', '/nutrition/foods', bar('Private ragi bar', false))).json() as { id: string };
    expect((await call(admin, 'PATCH', `/admin/foods/community/${priv.id}`, { visibility: 'community' })).statusCode).toBe(404);
  });

  it('the owner’s export has their food, not other people’s reports on it; deleting the account deletes the food', async () => {
    const owner = await user();
    const other = await user();
    const food = (await call(owner, 'POST', '/nutrition/foods', bar('Jowar puff bar', true))).json() as { id: string };
    await call(other, 'POST', `/nutrition/foods/${food.id}/report`, { note: 'Someone else wrote this' });
    const exp = await call(owner, 'POST', '/user/export', {});
    expect(exp.statusCode, exp.body).toBe(200);
    const tables = (exp.json() as { tables: Record<string, Record<string, unknown>[]> }).tables;
    expect((tables['foods'] ?? []).map((f) => f['id'])).toContain(food.id);
    expect(tables['food_reports']).toBeUndefined();
    expect(exp.body).not.toContain('Someone else wrote this');

    const del = await app.inject({ method: 'DELETE', url: '/v1/user', headers: headers(owner.token), payload: { confirm: 'DELETE' } });
    expect(del.statusCode, del.body).toBe(200);
    expect((await sql`select 1 from foods where id = ${food.id}`).length).toBe(0);
    expect((await sql`select 1 from food_reports where food_id = ${food.id}`).length).toBe(0);
  });

  it('the policy version the tests rely on exists', () => {
    expect(CURRENT_POLICY_VERSION.length).toBeGreaterThan(0);
  });
});
