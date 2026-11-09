/**
 * Beta 3.3 (ADR-033) on real Postgres: each server-side feature the admin
 * switches off answers 403 `feature-off` (so an old APK cannot use it either),
 * other people's shared foods leave search, and switching back on restores
 * everything. A switch with no row is on.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import type { AppFeature } from '@fitos/contracts';

import { seedFoods } from '../db/food-seed/load.js';
import { migrateUp } from '../db/migrate.js';
import type { FakeTokenVerifier } from '../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../test/build-test-app.js';
import { FeatureSwitches } from './feature-switches.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('feature switches (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  interface U {
    token: string;
    id: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.51.${n % 250}.${(n * 3) % 250}` });

  async function user(admin = false): Promise<U> {
    n += 1;
    const token = `fs-tok-${n}`;
    verifier.accept(token, { uid: `fs-uid-${n}`, email: `fs${n}@example.com`, claims: admin ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`fs-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PUT', path: string, payload?: Record<string, unknown>) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u.token), ...(payload !== undefined ? { payload } : {}) });
  const issue = (r: { json(): unknown }) => (r.json() as { error: { details: { issue: string }[] } }).error.details[0]?.issue;

  /** A plausible label: 200 kcal = 4×20 + 4×21 + 9×4. */
  const bar = (name: string, share: boolean) => ({
    clientFoodId: randomUUID(),
    name,
    basis: 'per_serving',
    servingLabel: '1 bar (50 g)',
    servingGrams: 50,
    kcal: 200,
    proteinG: 20,
    carbG: 21,
    fatG: 4,
    ...(share ? { shareWithCommunity: true } : {}),
  });

  let admin: U;
  const set = async (feature: AppFeature, enabled: boolean) => {
    expect((await call(admin, 'PUT', `/admin/flags/${feature}`, { enabled })).statusCode).toBe(200);
  };

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await seedFoods(url);
    await sql`delete from feature_flags`;
    ({ app, verifier } = await buildDbApp(url));
    admin = await user(true);
  });

  afterAll(async () => {
    await sql`delete from feature_flags`;
    await sql`delete from audit_logs where action = 'flag.set'`;
    await sql`delete from users where firebase_uid like 'fs-uid-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('a switch without a row is on; the cache serves repeated reads and clears on change', async () => {
    let reads = 0;
    let t = 0;
    const switches = new FeatureSwitches(() => {
      reads += 1;
      return app.database.db;
    }, undefined, () => t);
    expect(await switches.state('streaks')).toBe('everyone');
    expect(await switches.state('mess-ratings')).toBe('everyone');
    expect(reads).toBe(1);
    t = 10_001;
    await switches.state('streaks');
    expect(reads).toBe(2);
    switches.invalidate();
    await switches.state('streaks');
    expect(reads).toBe(3);
  });

  it('beta 6.1 early access: a premium switch is on for premium accounts and admins, refused for others, off in the public config', async () => {
    // Running: no other test file switches it, so files running side by side are not disturbed.
    const plain = await user();
    const granted = await user();
    await sql`update users set premium_since = now() where id = ${granted.id}`;
    const put = await call(admin, 'PUT', '/admin/flags/running', { enabled: true, audience: 'premium' });
    expect(put.statusCode, put.body).toBe(200);
    expect(put.json()).toMatchObject({ key: 'running', enabled: true, audience: 'premium' });

    // The server decides per account: past the switch, an unknown run is 404.
    const patch = (u: U) =>
      app.inject({ method: 'PATCH', url: `/v1/running/runs/${randomUUID()}`, headers: headers(u.token), payload: { name: 'Probe' } });
    const refused = await patch(plain);
    expect(refused.statusCode).toBe(403);
    expect(issue(refused)).toBe('early-access');
    expect((await patch(granted)).statusCode).toBe(404);
    expect((await patch(admin)).statusCode).toBe(404);

    // Before sign-in it reads off; signed in, each account sees its own.
    expect(((await app.inject({ method: 'GET', url: '/v1/meta/config', headers: { 'x-forwarded-for': '198.51.0.9' } })).json() as { flags: Record<string, boolean> }).flags.running).toBe(false);
    expect((await call(plain, 'GET', '/me/features')).json()).toMatchObject({ flags: { running: false }, earlyAccess: [] });
    expect((await call(granted, 'GET', '/me/features')).json()).toMatchObject({ flags: { running: true }, earlyAccess: ['running'] });
    expect((await app.inject({ method: 'GET', url: '/v1/me/features', headers: { 'x-forwarded-for': '198.51.0.9' } })).statusCode).toBe(401);

    // Switching it off keeps the audience for next time; off is off for everyone.
    expect((await call(admin, 'PUT', '/admin/flags/running', { enabled: false })).json()).toMatchObject({ enabled: false, audience: 'premium' });
    expect(issue(await patch(granted))).toBe('feature-off');
    expect((await call(admin, 'PUT', '/admin/flags/running', { enabled: true, audience: 'everyone' })).statusCode).toBe(200);
    expect((await patch(plain)).statusCode).toBe(404);
    const [audit] = await sql<{ metadata: Record<string, unknown> }[]>`select metadata from audit_logs where action = 'flag.set' and entity_id = 'running' and actor_user_id = ${admin.id} order by occurred_at limit 1`;
    expect(audit!.metadata).toMatchObject({ enabled: true, audience: 'premium' });
    expect((await call(admin, 'PUT', '/admin/flags/running', { enabled: true, audience: 'friends' })).statusCode).toBe(422);
  });

  it('missing-food requests: refused while off, counted again when back on', async () => {
    const u = await user();
    await set('food-requests', false);
    const off = await call(u, 'POST', '/nutrition/foods/requests', { query: 'jicama', asked: true });
    expect(off.statusCode).toBe(403);
    expect(issue(off)).toBe('feature-off');
    await set('food-requests', true);
    expect((await call(u, 'POST', '/nutrition/foods/requests', { query: 'jicama', asked: true })).statusCode).toBe(204);
  });

  it("community foods: no new sharing or reports while off, and other people's shared foods leave search", async () => {
    const owner = await user();
    const other = await user();
    const shared = await call(owner, 'POST', '/nutrition/foods', bar('Zorbex protein bar', true));
    expect(shared.statusCode, shared.body).toBe(201);
    const id = (shared.json() as { id: string }).id;
    const found = async (u: U) =>
      ((await call(u, 'GET', '/nutrition/foods/search?q=zorbex')).json() as { items: { id: string }[] }).items.map((i) => i.id);
    expect(await found(other)).toContain(id);

    await set('community-foods', false);
    expect(await found(other)).not.toContain(id);
    expect(await found(owner)).toContain(id); // your own food is always yours
    const share = await call(other, 'POST', '/nutrition/foods', bar('Quarnox protein bar', true));
    expect(share.statusCode).toBe(403);
    expect(issue(share)).toBe('feature-off');
    expect((await call(other, 'POST', '/nutrition/foods', bar('Quarnox protein bar', false))).statusCode).toBe(201);
    const report = await call(other, 'POST', `/nutrition/foods/${id}/report`, { note: 'wrong' });
    expect(issue(report)).toBe('feature-off');

    await set('community-foods', true);
    expect(await found(other)).toContain(id);
    expect((await call(other, 'POST', `/nutrition/foods/${id}/report`, { note: 'wrong' })).statusCode).toBe(204);
  });

  it('the weekly report: switched off answers feature-off even before premium', async () => {
    const u = await user();
    await set('weekly-report', false);
    const r = await call(u, 'GET', '/progress/weekly');
    expect(r.statusCode).toBe(403);
    expect(issue(r)).toBe('feature-off');
    await set('weekly-report', true);
    expect(issue(await call(u, 'GET', '/progress/weekly'))).toBe('premium-required');
  });
});
