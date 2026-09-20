/**
 * /v1/auth/session against a real Postgres (§26.1: routes are integration
 * tested against ephemeral Postgres). Skipped without DATABASE_URL.
 *
 * Runs the migration first so it is self-sufficient in CI.
 */
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('POST /v1/auth/session (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterEach(async () => {
    await sql`delete from users where firebase_uid like 'it-%'`;
  });

  afterAll(async () => {
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const post = (token: string, body: Record<string, unknown> = {}) =>
    app.inject({
      method: 'POST',
      url: '/v1/auth/session',
      headers: { authorization: `Bearer ${token}` },
      payload: body,
    });

  it('creates the user on first sign-in only', async () => {
    verifier.accept('t1', { uid: 'it-first', email: 'first@vit.ac.in' });

    const a = await post('t1');
    expect(a.statusCode).toBe(200);
    expect(a.json().isNewUser).toBe(true);
    const id = a.json().user.id as string;

    const b = await post('t1');
    expect(b.statusCode).toBe(200);
    expect(b.json().isNewUser).toBe(false);
    expect(b.json().user.id).toBe(id);

    const rows = await sql<{ n: number }[]>`
      select count(*)::int as n from users where firebase_uid = 'it-first'
    `;
    expect(rows[0]?.n).toBe(1);
  });

  it('never stores a password and never returns the firebase uid', async () => {
    verifier.accept('t2', { uid: 'it-cols' });
    const r = await post('t2');
    expect(JSON.stringify(r.json())).not.toMatch(/it-cols|password/);
  });

  it('applies defaults, then keeps the user zone on later sign-ins', async () => {
    verifier.accept('t3', { uid: 'it-tz' });
    const first = await post('t3');
    expect(first.json().user.timezone).toBe('Asia/Kolkata');

    // The user (or a second device) now says London. The first device signs
    // in again sending nothing — London must survive. A fresh device must not
    // clobber an existing setting.
    await sql`update users set timezone = 'Europe/London' where firebase_uid = 'it-tz'`;
    const again = await post('t3');
    expect(again.json().user.timezone).toBe('Europe/London');
    expect(again.json().isNewUser).toBe(false);
  });

  it('refreshes email from Firebase on every sign-in, and echoes whatever Firebase accepted', async () => {
    // `a@b.c` is rejected by Zod's .email() but accepted by Firebase. Firebase
    // is the authority on addresses; a valid account must never be unable to
    // sign in because of a regex disagreement.
    verifier.accept('t4a', { uid: 'it-mail', email: 'a@b.c' });
    const first = await post('t4a');
    expect(first.statusCode).toBe(200);
    expect(first.json().user.email).toBe('a@b.c');

    verifier.accept('t4b', { uid: 'it-mail', email: 'new@example.com' });
    const r = await post('t4b');
    expect(r.json().user.email).toBe('new@example.com');
  });

  it('422 with the envelope for a bad time zone', async () => {
    verifier.accept('t5', { uid: 'it-badtz' });
    const r = await post('t5', { timezone: 'IST' });
    expect(r.statusCode).toBe(422);
    expect(r.json().error.code).toBe('VALIDATION_FAILED');
    expect(r.json().error.details[0].path).toBe('timezone');
  });

  it('422 for a client-supplied userId — identity is never taken from the body', async () => {
    verifier.accept('t6', { uid: 'it-body' });
    const r = await post('t6', { userId: 'someone-else' });
    expect(r.statusCode).toBe(422);
    const rows = await sql<{ n: number }[]>`
      select count(*)::int as n from users where firebase_uid = 'it-body'
    `;
    expect(rows[0]?.n).toBe(0);
  });

  it('401 with no token', async () => {
    const r = await app.inject({ method: 'POST', url: '/v1/auth/session', payload: {} });
    expect(r.statusCode).toBe(401);
  });

  it('DELETE revokes refresh tokens for the caller and returns 204', async () => {
    verifier.accept('t7', { uid: 'it-out' });
    const r = await app.inject({
      method: 'DELETE',
      url: '/v1/auth/session',
      headers: { authorization: 'Bearer t7' },
    });
    expect(r.statusCode).toBe(204);
    expect(verifier.revoked).toContain('it-out');
  });

  it('rate-limits /auth/session at 10/min per IP', async () => {
    verifier.accept('t8', { uid: 'it-rl' });
    let limited = 0;
    for (let i = 0; i < 12; i += 1) {
      const r = await app.inject({
        method: 'POST',
        url: '/v1/auth/session',
        headers: { authorization: 'Bearer t8', 'x-forwarded-for': '203.0.113.9' },
        payload: {},
      });
      if (r.statusCode === 429) {
        limited += 1;
        expect(r.json().error.code).toBe('RATE_LIMITED');
      }
    }
    expect(limited).toBeGreaterThan(0);
  });
});
