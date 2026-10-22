/**
 * Phase 19 (ADR-026): feedback from the app on real Postgres — sent by any
 * signed-in user (validated, rate-limited per user), read and marked by an
 * admin only (audited), deleted with the user; and the app's minimum build
 * served by the public /meta/config (E1).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { FEEDBACK_MAX_LENGTH, FEEDBACK_PER_HOUR, adminFeedbackListSchema, type AdminFeedbackList } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/feedback and /v1/admin/feedback (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  interface U {
    token: string;
    id: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.22.${n % 250}.${(n * 11) % 250}` });

  async function user(admin = false): Promise<U> {
    n += 1;
    const token = `fb-tok-${n}`;
    verifier.accept(token, { uid: `fb-uid-${n}`, email: `fb${n}@vit.ac.in`, claims: admin ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`fb-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U | null, method: 'GET' | 'POST' | 'PATCH', path: string, payload?: unknown) =>
    app.inject({
      method,
      url: `/v1${path}`,
      headers: u === null ? { 'x-forwarded-for': '198.23.0.1' } : headers(u.token),
      ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}),
    });
  const send = (u: U, message: string, category = 'bug') => call(u, 'POST', '/feedback', { category, message, appVersion: '1.0.0-beta.1+4' });

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await sql`delete from feedback`;
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'fb-uid-%'`;
    await sql`delete from audit_logs where action in ('feedback.status', 'feedback.priority')`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('a signed-in user sends feedback: 201, stored as sent (trimmed); signed out is 401', async () => {
    const u = await user();
    expect((await call(null, 'POST', '/feedback', { category: 'bug', message: 'x', appVersion: '1' })).statusCode).toBe(401);
    const r = await send(u, '  The rest timer froze after the third set.  ');
    expect(r.statusCode, r.body).toBe(201);
    const body = r.json() as { id: string; createdAt: string };
    const [row] = await sql<{ user_id: string; category: string; message: string; app_version: string; status: string }[]>`
      select user_id, category, message, app_version, status from feedback where id = ${body.id}`;
    expect(row).toEqual({ user_id: u.id, category: 'bug', message: 'The rest timer froze after the third set.', app_version: '1.0.0-beta.1+4', status: 'new' });
  });

  it('refuses an empty or too-long message, an unknown category and extra fields (422)', async () => {
    const u = await user();
    expect((await send(u, '   ')).statusCode).toBe(422);
    expect((await send(u, 'x'.repeat(FEEDBACK_MAX_LENGTH + 1))).statusCode).toBe(422);
    expect((await send(u, 'ok', 'rant')).statusCode).toBe(422);
    expect((await call(u, 'POST', '/feedback', { category: 'idea', message: 'ok', appVersion: '1', device: 'S24' })).statusCode).toBe(422);
    expect((await send(u, 'x'.repeat(FEEDBACK_MAX_LENGTH))).statusCode).toBe(201);
  });

  it(`${FEEDBACK_PER_HOUR} an hour per user; another user is unaffected`, async () => {
    const u = await user();
    for (let i = 0; i < FEEDBACK_PER_HOUR; i++) expect((await send(u, `note ${i}`)).statusCode).toBe(201);
    expect((await send(u, 'one too many')).statusCode).toBe(429);
    expect((await send(await user(), 'mine')).statusCode).toBe(201);
  });

  it('only an admin reads it (403 before validation for anyone else); newest first, filtered by status, paged', async () => {
    const plain = await user();
    const admin = await user(true);
    expect((await call(plain, 'GET', '/admin/feedback')).statusCode).toBe(403);
    expect((await call(plain, 'GET', '/admin/feedback?limit=nonsense')).statusCode).toBe(403);
    expect((await call(null, 'GET', '/admin/feedback')).statusCode).toBe(401);

    await sql`delete from feedback`;
    for (const m of ['first', 'second', 'third']) {
      expect((await send(plain, m, 'idea')).statusCode).toBe(201);
      await new Promise((r) => setTimeout(r, 5));
    }
    const page1 = adminFeedbackListSchema.parse((await call(admin, 'GET', '/admin/feedback?limit=2')).json());
    expect(page1.items.map((i) => i.message)).toEqual(['third', 'second']);
    expect(page1.items[0]).toMatchObject({ userId: plain.id, category: 'idea', status: 'new', appVersion: '1.0.0-beta.1+4' });
    const page2 = (await call(admin, 'GET', `/admin/feedback?limit=2&before=${encodeURIComponent(page1.next!)}`)).json() as AdminFeedbackList;
    expect(page2.items.map((i) => i.message)).toEqual(['first']);
    expect(page2.next).toBeNull();
  });

  it('an admin marks it read or done, audited; an unknown id is 404; a plain user cannot', async () => {
    const plain = await user();
    const admin = await user(true);
    const { id } = (await send(plain, 'Please add paneer tikka')).json() as { id: string };
    expect((await call(plain, 'PATCH', `/admin/feedback/${id}`, { status: 'done' })).statusCode).toBe(403);
    const r = await call(admin, 'PATCH', `/admin/feedback/${id}`, { status: 'done' });
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json()).toMatchObject({ id, status: 'done' });
    expect((await call(admin, 'GET', '/admin/feedback?status=done')).json()).toMatchObject({ items: [expect.objectContaining({ id })] });
    const audit = await sql<{ actor_user_id: string; metadata: Record<string, unknown> }[]>`
      select actor_user_id, metadata from audit_logs where action = 'feedback.status' and entity_id = ${id}`;
    expect(audit).toEqual([{ actor_user_id: admin.id, metadata: { status: 'done' } }]);
    expect((await call(admin, 'PATCH', '/admin/feedback/00000000-0000-4000-8000-000000000000', { status: 'read' })).statusCode).toBe(404);
    expect((await call(admin, 'PATCH', `/admin/feedback/${id}`, { status: 'lost' })).statusCode).toBe(422);
  });

  it('an admin tags it red, yellow or green (null clears), with a status in the same call or alone; each change audited once; filtered by tag', async () => {
    const plain = await user();
    const admin = await user(true);
    const { id } = (await send(plain, 'The app crashes when I save a workout')).json() as { id: string };
    const { id: other } = (await send(plain, 'Dark mode on the widget', 'idea')).json() as { id: string };
    const priorityAudit = async (fid: string) =>
      sql<{ actor_user_id: string; metadata: Record<string, unknown> }[]>`
        select actor_user_id, metadata from audit_logs where action = 'feedback.priority' and entity_id = ${fid} order by occurred_at`;

    // New feedback is untagged.
    const fresh = (await call(admin, 'GET', '/admin/feedback?priority=none')).json() as { items: { id: string; priority: string | null }[] };
    expect(fresh.items.find((i) => i.id === id)?.priority).toBeNull();

    expect((await call(plain, 'PATCH', `/admin/feedback/${id}`, { priority: 'red' })).statusCode).toBe(403);
    const red = await call(admin, 'PATCH', `/admin/feedback/${id}`, { priority: 'red' });
    expect(red.statusCode, red.body).toBe(200);
    expect(red.json()).toMatchObject({ id, priority: 'red', status: 'new' });

    // The same tag again changes and records nothing.
    expect((await call(admin, 'PATCH', `/admin/feedback/${id}`, { priority: 'red' })).statusCode).toBe(200);
    expect(await priorityAudit(id)).toEqual([{ actor_user_id: admin.id, metadata: { priority: 'red', from: null } }]);

    // Status and tag together: one row each.
    const both = await call(admin, 'PATCH', `/admin/feedback/${id}`, { status: 'read', priority: 'yellow' });
    expect(both.json()).toMatchObject({ status: 'read', priority: 'yellow' });
    expect((await priorityAudit(id)).at(-1)).toEqual({ actor_user_id: admin.id, metadata: { priority: 'yellow', from: 'red' } });
    expect((await sql`select 1 from audit_logs where action = 'feedback.status' and entity_id = ${id}`).length).toBe(1);

    await call(admin, 'PATCH', `/admin/feedback/${other}`, { priority: 'green' });
    const yellow = (await call(admin, 'GET', '/admin/feedback?priority=yellow')).json() as { items: { id: string }[] };
    expect(yellow.items.map((i) => i.id)).toContain(id);
    expect(yellow.items.map((i) => i.id)).not.toContain(other);
    const green = (await call(admin, 'GET', '/admin/feedback?priority=green&status=new')).json() as { items: { id: string }[] };
    expect(green.items.map((i) => i.id)).toEqual([other]);

    // null clears it.
    const cleared = await call(admin, 'PATCH', `/admin/feedback/${id}`, { priority: null });
    expect(cleared.json()).toMatchObject({ priority: null });
    expect((await priorityAudit(id)).at(-1)).toEqual({ actor_user_id: admin.id, metadata: { priority: null, from: 'yellow' } });

    // Nothing, an unknown tag or an extra field: 422.
    for (const body of [{}, { priority: 'blue' }, { priority: 'red', note: 'x' }]) {
      expect((await call(admin, 'PATCH', `/admin/feedback/${id}`, body)).statusCode, JSON.stringify(body)).toBe(422);
    }
    expect((await call(admin, 'GET', '/admin/feedback?priority=blue')).statusCode).toBe(422);
  });

  it('feedback is the sender\'s data: deleting the account removes it', async () => {
    const u = await user();
    expect((await send(u, 'bye')).statusCode).toBe(201);
    const del = await call(u, 'POST', '/feedback', { category: 'other', message: 'still here', appVersion: '1' });
    expect(del.statusCode).toBe(201);
    const r = await app.inject({ method: 'DELETE', url: '/v1/user', headers: headers(u.token), payload: { confirm: 'DELETE' } });
    expect(r.statusCode, r.body).toBe(200);
    expect((await sql`select 1 from feedback where user_id = ${u.id}`).length).toBe(0);
  });

  it('E1: /meta/config serves the minimum build, 0 unless configured', async () => {
    expect((await call(null, 'GET', '/meta/config')).json()).toMatchObject({ minimumBuild: 0 });
    const strict = await buildDbApp(url, { MIN_APP_BUILD: 7 });
    try {
      const r = await strict.app.inject({ method: 'GET', url: '/v1/meta/config', headers: { 'x-forwarded-for': '198.23.0.2' } });
      expect(r.json()).toMatchObject({ minimumBuild: 7 });
    } finally {
      await strict.app.close();
    }
  });
});
