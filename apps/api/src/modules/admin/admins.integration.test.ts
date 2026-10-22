/**
 * ADR-022 D2 amendment on real Postgres: one administrator makes another
 * account an administrator in the panel, or takes it away. The claim lives in
 * Firebase (here an in-memory directory); every change is audited; a removal
 * ends the account's sessions at once; nobody removes themselves.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import type { InMemoryAdminDirectory } from '../../lib/admin-directory.js';
import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/admin/admins (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let directory: InMemoryAdminDirectory;
  let n = 0;

  interface U {
    token: string;
    uid: string;
    id: string;
    email: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.30.${n % 250}.${(n * 7) % 250}` });

  /** An account in Firebase (the directory) that has signed in to FITOS. */
  async function account(opts: { admin?: boolean } = {}): Promise<U> {
    n += 1;
    const token = `adms-tok-${n}`;
    const uid = `adms-uid-${n}`;
    const email = `adms${n}@example.com`;
    verifier.accept(token, { uid, email, claims: opts.admin === true ? { role: 'admin' } : {} });
    directory.add(uid, email, opts.admin === true);
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${uid}`;
    return { token, uid, id: row!.id, email };
  }

  const call = (u: U | null, method: 'GET' | 'POST' | 'DELETE', path: string, payload?: unknown) =>
    app.inject({
      method,
      url: `/v1${path}`,
      headers: u === null ? { 'x-forwarded-for': '198.31.0.1' } : headers(u.token),
      ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}),
    });
  const audits = async (action: string) =>
    sql<{ actor_user_id: string | null; entity: string; entity_id: string | null; metadata: Record<string, unknown> }[]>`
      select actor_user_id, entity, entity_id, metadata from audit_logs where action = ${action} order by occurred_at`;

  let admin: U;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await sql`delete from audit_logs where action like 'admin.%'`;
    ({ app, verifier } = await buildDbApp(url));
    directory = app.adminDirectory as InMemoryAdminDirectory;
    admin = await account({ admin: true });
  });

  afterAll(async () => {
    await sql`delete from audit_logs where action like 'admin.%'`;
    await sql`delete from users where firebase_uid like 'adms-uid-%'`;
    await app.close();
    await sql.end();
  });

  it('only an administrator may list, grant or remove: 401 without a session, 403 without the claim, nothing written', async () => {
    const plain = await account();
    const routes: ['GET' | 'POST' | 'DELETE', string, unknown?][] = [
      ['GET', '/admin/admins'],
      ['POST', '/admin/admins', { email: plain.email }],
      ['DELETE', `/admin/admins/${admin.uid}`],
    ];
    for (const [method, path, body] of routes) {
      expect((await call(null, method, path, body)).statusCode, `${method} ${path} anon`).toBe(401);
      const r = await call(plain, method, path, body);
      expect(r.statusCode, `${method} ${path} non-admin`).toBe(403);
    }
    expect((await directory.findByUid(plain.uid))?.admin).toBe(false);
    expect((await directory.findByUid(admin.uid))?.admin).toBe(true);
    expect(await audits('admin.grant')).toHaveLength(0);
    expect(await audits('admin.revoke')).toHaveLength(0);
  });

  it('an administrator makes another account an administrator by email (any case); listed, audited; twice is a conflict', async () => {
    const friend = await account();
    const r = await call(admin, 'POST', '/admin/admins', { email: `  ${friend.email.toUpperCase()} ` });
    expect(r.statusCode, r.body).toBe(201);
    expect(r.json()).toEqual({ firebaseUid: friend.uid, email: friend.email, userId: friend.id, lastSignInAt: null, isYou: false });
    expect((await directory.findByUid(friend.uid))?.admin).toBe(true);

    const [a] = await audits('admin.grant');
    expect(a).toEqual({ actor_user_id: admin.id, entity: 'account', entity_id: friend.uid, metadata: { email: friend.email } });

    const list = await call(admin, 'GET', '/admin/admins');
    expect(list.statusCode).toBe(200);
    const items = (list.json() as { items: { email: string; isYou: boolean }[] }).items;
    expect(items.map((i) => i.email)).toEqual(expect.arrayContaining([admin.email, friend.email]));
    expect(items.find((i) => i.email === admin.email)?.isYou).toBe(true);
    expect(items.find((i) => i.email === friend.email)?.isYou).toBe(false);

    const again = await call(admin, 'POST', '/admin/admins', { email: friend.email });
    expect(again.statusCode).toBe(409);
    expect(await audits('admin.grant')).toHaveLength(1);
  });

  it('an email with no FITOS account is refused (404) and a malformed one is a validation error; nothing granted', async () => {
    const none = await call(admin, 'POST', '/admin/admins', { email: 'nobody-here@example.com' });
    expect(none.statusCode).toBe(404);
    expect((none.json() as { error: { message: string } }).error.message).toMatch(/sign in to FITOS once/);
    expect((await call(admin, 'POST', '/admin/admins', { email: 'not an email' })).statusCode).toBe(422);
    expect((await call(admin, 'POST', '/admin/admins', { email: 'a@b.co', extra: 1 })).statusCode).toBe(422);
  });

  it('removing an administrator takes the role away, ends their sessions at once and is audited; it can be granted again', async () => {
    const other = await account({ admin: true });
    const r = await call(admin, 'DELETE', `/admin/admins/${other.uid}`);
    expect(r.statusCode, r.body).toBe(204);
    expect((await directory.findByUid(other.uid))?.admin).toBe(false);
    expect(directory.revoked).toContain(other.uid);
    const rows = await audits('admin.revoke');
    expect(rows.at(-1)).toEqual({ actor_user_id: admin.id, entity: 'account', entity_id: other.uid, metadata: { email: other.email } });

    // Not an administrator any more: removing again is 404.
    expect((await call(admin, 'DELETE', `/admin/admins/${other.uid}`)).statusCode).toBe(404);
    expect((await call(admin, 'POST', '/admin/admins', { email: other.email })).statusCode).toBe(201);
  });

  it('nobody removes themselves (so one administrator always remains); unknown and malformed ids are refused', async () => {
    const self = await call(admin, 'DELETE', `/admin/admins/${admin.uid}`);
    expect(self.statusCode).toBe(409);
    expect((self.json() as { error: { message: string } }).error.message).toMatch(/cannot remove yourself/);
    expect((await directory.findByUid(admin.uid))?.admin).toBe(true);
    expect(directory.revoked).not.toContain(admin.uid);

    expect((await call(admin, 'DELETE', '/admin/admins/no-such-uid')).statusCode).toBe(404);
    expect((await call(admin, 'DELETE', '/admin/admins/bad%20uid')).statusCode).toBe(422);
  });

  it('a failure in Firebase leaves no audit row (the change and its record commit together)', async () => {
    const friend = await account();
    const before = (await audits('admin.grant')).length;
    const setAdmin = directory.setAdmin.bind(directory);
    directory.setAdmin = async () => {
      throw new Error('firebase down');
    };
    try {
      expect((await call(admin, 'POST', '/admin/admins', { email: friend.email })).statusCode).toBe(500);
    } finally {
      directory.setAdmin = setAdmin;
    }
    expect(await audits('admin.grant')).toHaveLength(before);
    expect((await directory.findByUid(friend.uid))?.admin).toBe(false);
  });
});
