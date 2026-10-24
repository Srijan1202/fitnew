/**
 * Beta 3.5 on real Postgres: an admin tells every phone with notifications
 * on that the website's latest beta is out — once per build, audited; tokens
 * FCM no longer knows are removed; nobody else may send.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { migrateUp } from '../../db/migrate.js';
import type { RecordingPushSender, ScriptedReleaseFeed } from '../../lib/push.js';
import { releaseLabel } from '../../lib/push.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/admin/push/update (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  interface U {
    token: string;
    id: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.71.${n % 250}.${(n * 3) % 250}` });

  async function user(admin = false): Promise<U> {
    n += 1;
    const token = `up-tok-${n}`;
    verifier.accept(token, { uid: `up-uid-${n}`, email: `up${n}@example.com`, claims: admin ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`up-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST', payload?: Record<string, unknown>) =>
    app.inject({ method, url: '/v1/admin/push/update', headers: headers(u.token), ...(payload !== undefined ? { payload } : {}) });

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from audit_logs where action = 'push.update'`;
    await sql`delete from users where firebase_uid like 'up-uid-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('labels a version as the app does', () => {
    expect(releaseLabel('1.0.0-beta.3.5')).toBe('beta 3.5');
    expect(releaseLabel('2.0.0')).toBe('2.0.0');
  });

  it('status, then one send to every phone, gone tokens removed, audited; a second send for the build is refused', async () => {
    const admin = await user(true);
    const plain = await user();
    const push = app.push as RecordingPushSender;
    const feed = app.releaseFeed as ScriptedReleaseFeed;
    await sql`delete from push_tokens`;
    await sql`delete from audit_logs where action = 'push.update'`;
    for (const [u, t] of [[admin, 'tok-a'], [plain, 'tok-b'], [plain, 'tok-gone']] as const) {
      await sql`insert into push_tokens (user_id, token, platform) values (${u.id}, ${t}, 'android')`;
    }
    push.gone.add('tok-gone');

    expect((await call(plain, 'GET')).statusCode).toBe(403);
    expect((await call(plain, 'POST')).statusCode).toBe(403);

    feed.release = null;
    expect((await call(admin, 'GET')).json()).toEqual({ latest: null, devices: 3, sentAt: null });
    expect((await call(admin, 'POST')).statusCode).toBe(404);

    feed.release = { version: '1.0.0-beta.3.5', build: 11 };
    expect((await call(admin, 'GET')).json()).toEqual({ latest: { version: '1.0.0-beta.3.5', build: 11, label: 'beta 3.5' }, devices: 3, sentAt: null });

    const sent = await call(admin, 'POST');
    expect(sent.statusCode, sent.body).toBe(200);
    expect(sent.json()).toEqual({ build: 11, label: 'beta 3.5', devices: 3, sent: 2, removed: 1 });
    expect(push.sends).toHaveLength(1);
    expect(push.sends[0]!.message).toMatchObject({
      title: 'FITOS beta 3.5 is out',
      data: { type: 'update', build: '11', url: 'https://tryfitos.me/download/' },
    });
    expect([...push.sends[0]!.tokens].sort()).toEqual(['tok-a', 'tok-b', 'tok-gone']);
    expect((await sql`select token from push_tokens order by token`).map((r) => r['token'])).toEqual(['tok-a', 'tok-b']);

    const status = (await call(admin, 'GET')).json() as { sentAt: string | null; devices: number };
    expect(status.sentAt).not.toBeNull();
    expect(status.devices).toBe(2);
    const again = await call(admin, 'POST');
    expect(again.statusCode).toBe(409);
    expect(push.sends).toHaveLength(1);

    const [audit] = await sql<{ actor_user_id: string; entity_id: string; metadata: Record<string, unknown> }[]>`
      select actor_user_id, entity_id, metadata from audit_logs where action = 'push.update'`;
    expect(audit).toEqual({ actor_user_id: admin.id, entity_id: '11', metadata: { version: '1.0.0-beta.3.5', devices: 3, sent: 2, removed: 1 } });

    // The next build can be announced.
    feed.release = { version: '1.0.0-beta.3.6', build: 12 };
    expect((await call(admin, 'POST')).statusCode).toBe(200);
  });
});
