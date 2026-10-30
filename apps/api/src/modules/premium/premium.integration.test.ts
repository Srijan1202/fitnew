/**
 * Phase 19 (ADR-027): premium on real Postgres — the request, the owner's
 * decision (audited), the lock on FITOS AI and on three pictures, admins
 * premium by role, revoking, and premium's higher AI limits.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { premiumStatusSchema, rewardsResponseSchema, weeklyReportSchema, type PremiumStatus } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/premium (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let admin: U;

  interface U {
    token: string;
    id: string;
    email: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.24.${n % 250}.${(n * 13) % 250}` });

  async function user(opts: { admin?: boolean; ai?: boolean } = {}, rig = { app, verifier }): Promise<U> {
    n += 1;
    const token = `pm-tok-${n}`;
    const email = `pm${n}@vit.ac.in`;
    rig.verifier.accept(token, { uid: `pm-uid-${n}`, email, claims: opts.admin === true ? { role: 'admin' } : {} });
    expect((await rig.app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`pm-uid-${n}`}`;
    if (opts.ai === true) {
      expect((await rig.app.inject({ method: 'POST', url: '/v1/user/consents', headers: headers(token), payload: { type: 'ai-processing', granted: true } })).statusCode).toBe(200);
    }
    return { token, id: row!.id, email };
  }

  const call = (u: U | null, method: 'GET' | 'POST' | 'PUT', path: string, payload?: unknown) =>
    app.inject({
      method,
      url: `/v1${path}`,
      headers: u === null ? { 'x-forwarded-for': '198.25.0.1' } : headers(u.token),
      ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}),
    });
  const status = async (u: U): Promise<PremiumStatus> => premiumStatusSchema.parse((await call(u, 'GET', '/premium')).json());
  const issue = (r: { json: () => unknown }): string | undefined => (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
    admin = await user({ admin: true });
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'pm-uid-%'`;
    await sql`delete from audit_logs where action like 'premium.%' or action like 'rewards.%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('a new user is free; asks once (a second pending request is 409); the request shows as pending', async () => {
    const u = await user();
    expect(await status(u)).toEqual({ premium: false, source: null, since: null, request: null });
    expect((await call(null, 'POST', '/premium/request', {})).statusCode).toBe(401);
    const r = await call(u, 'POST', '/premium/request', { message: '  I train 5 days a week  ' });
    expect(r.statusCode, r.body).toBe(201);
    expect(r.json()).toMatchObject({ status: 'pending', message: 'I train 5 days a week', note: null, decidedAt: null });
    expect((await call(u, 'POST', '/premium/request', {})).statusCode).toBe(409);
    expect((await call(u, 'POST', '/premium/request', { message: 'x'.repeat(501) })).statusCode).toBe(422);
    expect((await status(u)).request).toMatchObject({ status: 'pending' });
  });

  it('FITOS AI is premium: a free user is refused before consent or any model call (403 premium-required)', async () => {
    const u = await user({ ai: true });
    for (const [path, body] of [['/ai/chat', { message: 'hi' }], ['/nutrition/parse', { text: '2 rotis' }], ['/ai/explain', { actionId: '00000000-0000-4000-8000-000000000000' }]] as const) {
      const r = await call(u, 'POST', path, body);
      expect(r.statusCode, `${path} ${r.body}`).toBe(403);
      expect(issue(r)).toBe('premium-required');
    }
    expect(await sql`select 1 from ai_usage where user_id = ${u.id}`).toHaveLength(0);
  });

  it('only an admin sees requests (403 before validation for anyone else); approving makes the user premium until revoked, audited', async () => {
    const u = await user({ ai: true });
    const req = (await call(u, 'POST', '/premium/request', {})).json() as { id: string };
    const plain = await user();
    expect((await call(plain, 'GET', '/admin/premium/requests')).statusCode).toBe(403);
    expect((await call(plain, 'POST', `/admin/premium/requests/${req.id}/decision`, { decision: 'nonsense' })).statusCode).toBe(403);

    const list = (await call(admin, 'GET', '/admin/premium/requests?status=pending')).json() as { items: { id: string; email: string; userPremium: boolean }[] };
    expect(list.items.find((i) => i.id === req.id)).toMatchObject({ email: u.email, userPremium: false });

    const d = await call(admin, 'POST', `/admin/premium/requests/${req.id}/decision`, { decision: 'approve', note: 'Welcome' });
    expect(d.statusCode, d.body).toBe(200);
    expect(d.json()).toMatchObject({ status: 'approved', note: 'Welcome' });
    expect((await call(admin, 'POST', `/admin/premium/requests/${req.id}/decision`, { decision: 'deny' })).statusCode).toBe(409);
    expect((await call(admin, 'POST', '/admin/premium/requests/00000000-0000-4000-8000-000000000000/decision', { decision: 'approve' })).statusCode).toBe(404);

    const s = await status(u);
    expect(s).toMatchObject({ premium: true, source: 'granted', request: { status: 'approved', note: 'Welcome' } });
    expect(s.since).not.toBeNull();
    // Past the premium gate (no model on this server: 503, not 403).
    expect((await call(u, 'POST', '/ai/chat', { message: 'hi' })).statusCode).not.toBe(403);
    expect((await call(u, 'POST', '/premium/request', {})).statusCode).toBe(409);

    const members = (await call(admin, 'GET', '/admin/premium/members')).json() as { items: { userId: string; grantedBy: string | null }[] };
    expect(members.items.find((m) => m.userId === u.id)).toMatchObject({ grantedBy: admin.email });
    const audit = await sql<{ actor_user_id: string; entity_id: string }[]>`select actor_user_id, entity_id from audit_logs where action = 'premium.approve' and entity_id = ${u.id}`;
    expect(audit).toEqual([{ actor_user_id: admin.id, entity_id: u.id }]);
  });

  it('a denial carries the owner\'s note; the user may ask again', async () => {
    const u = await user();
    const req = (await call(u, 'POST', '/premium/request', {})).json() as { id: string };
    expect((await call(admin, 'POST', `/admin/premium/requests/${req.id}/decision`, { decision: 'deny', note: 'Beta is full this week' })).statusCode).toBe(200);
    expect(await status(u)).toMatchObject({ premium: false, request: { status: 'denied', note: 'Beta is full this week' } });
    expect((await call(u, 'POST', '/premium/request', {})).statusCode).toBe(201);
  });

  it('pictures: free ones for anyone, the three premium ones only for premium; revoking takes a premium picture back', async () => {
    const u = await user();
    expect((await call(u, 'PUT', '/user/avatar', { avatarId: 'runner' })).json()).toEqual({ avatarId: 'runner' });
    const locked = await call(u, 'PUT', '/user/avatar', { avatarId: 'crown' });
    expect(locked.statusCode).toBe(403);
    expect(issue(locked)).toBe('premium-required');
    expect((await call(u, 'PUT', '/user/avatar', { avatarId: 'unicorn' })).statusCode).toBe(422);
    expect(((await call(u, 'GET', '/user/profile')).json() as { avatarId: string }).avatarId).toBe('runner');

    const req = (await call(u, 'POST', '/premium/request', {})).json() as { id: string };
    await call(admin, 'POST', `/admin/premium/requests/${req.id}/decision`, { decision: 'approve' });
    expect((await call(u, 'PUT', '/user/avatar', { avatarId: 'crown' })).statusCode).toBe(200);

    expect((await call(admin, 'POST', `/admin/premium/members/${u.id}/revoke`)).statusCode).toBe(204);
    expect((await status(u)).premium).toBe(false);
    expect(((await call(u, 'GET', '/user/profile')).json() as { avatarId: string | null }).avatarId).toBeNull();
    expect((await call(admin, 'POST', `/admin/premium/members/${u.id}/revoke`)).statusCode).toBe(404);
    expect(await sql`select 1 from audit_logs where action = 'premium.revoke' and entity_id = ${u.id}`).toHaveLength(1);
    expect((await call(u, 'PUT', '/user/avatar', { avatarId: null })).json()).toEqual({ avatarId: null });
  });

  it('an admin is premium by role: nothing to ask, premium pictures allowed', async () => {
    expect(await status(admin)).toMatchObject({ premium: true, source: 'admin', since: null });
    expect((await call(admin, 'POST', '/premium/request', {})).statusCode).toBe(409);
    expect((await call(admin, 'PUT', '/user/avatar', { avatarId: 'trophy' })).statusCode).toBe(200);
  });

  it('premium AI limits are the base limits times AI_PREMIUM_LIMIT_MULTIPLIER', async () => {
    const doubled = await buildDbApp(url, { AI_PARSE_PER_HOUR: 2, AI_PREMIUM_LIMIT_MULTIPLIER: 2 });
    const single = await buildDbApp(url, { AI_PARSE_PER_HOUR: 2, AI_PREMIUM_LIMIT_MULTIPLIER: 1 });
    try {
      const u = await user({ ai: true }, doubled);
      await sql`update users set premium_since = now() where id = ${u.id}`;
      single.verifier.accept(u.token, { uid: `pm-uid-${n}`, email: u.email });
      await sql`insert into ai_usage (user_id, route, model, input_tokens, output_tokens, outcome) values (${u.id}, 'parse', 'm', 1, 1, 'ok'), (${u.id}, 'parse', 'm', 1, 1, 'ok')`;
      const body = { text: '2 rotis and dal' };
      const one = await single.app.inject({ method: 'POST', url: '/v1/nutrition/parse', headers: headers(u.token), payload: body });
      expect(one.statusCode, one.body).toBe(429);
      const two = await doubled.app.inject({ method: 'POST', url: '/v1/nutrition/parse', headers: headers(u.token), payload: body });
      expect(two.statusCode, two.body).not.toBe(429);
    } finally {
      await doubled.app.close();
      await single.app.close();
    }
  });

  it('the weekly report is premium: free users are refused; premium users get this week or one of the three before it', async () => {
    const u = await user();
    const free = await call(u, 'GET', '/progress/weekly');
    expect(free.statusCode).toBe(403);
    expect(issue(free)).toBe('premium-required');

    await sql`update users set premium_since = now() where id = ${u.id}`;
    const r = await call(u, 'GET', '/progress/weekly');
    expect(r.statusCode, r.body).toBe(200);
    const report = weeklyReportSchema.parse(r.json());
    expect(report.weeks).toHaveLength(4);
    expect(report.isoWeek).toBe(report.weeks.at(-1));
    expect(report.complete).toBe(false);
    expect(report.highlights).toContain('No sessions logged this week.');
    const earlier = (await call(u, 'GET', `/progress/weekly?week=${report.weeks[0]}`)).json() as { isoWeek: string; complete: boolean };
    expect(earlier).toMatchObject({ isoWeek: report.weeks[0], complete: true });
    expect((await call(u, 'GET', '/progress/weekly?week=2020-W01')).statusCode).toBe(422);
    expect((await call(u, 'GET', '/progress/weekly?week=nonsense')).statusCode).toBe(422);
  });

  it('the admin unlock-all switch (owner 2026-10-30): only an admin sets it; the rewards say unlockAll and keep what was earned; streak pictures allowed; off again, an unearned streak picture goes back to none; audited', async () => {
    const u = await user();
    const rewards = async () => rewardsResponseSchema.parse((await call(u, 'GET', '/user/rewards')).json());
    expect(await rewards()).toEqual({ earned: [], unlockAll: false });
    expect((await call(u, 'PUT', '/user/avatar', { avatarId: 'spark' })).statusCode).toBe(403);
    // Not for anyone else; checked against the account.
    expect((await call(u, 'PUT', `/admin/users/${u.id}/rewards-unlocked`, { on: true })).statusCode).toBe(403);
    expect((await call(admin, 'PUT', `/admin/users/${randomUUID()}/rewards-unlocked`, { on: true })).statusCode).toBe(404);

    const on = await call(admin, 'PUT', `/admin/users/${u.id}/rewards-unlocked`, { on: true });
    expect(on.json()).toEqual({ userId: u.id, rewardsUnlocked: true });
    expect(await rewards()).toEqual({ earned: [], unlockAll: true });
    expect((await call(u, 'PUT', '/user/avatar', { avatarId: 'spark' })).json()).toEqual({ avatarId: 'spark' });
    const lookup = (await call(admin, 'GET', `/admin/users?id=${u.id}`)).json() as { rewardsUnlocked: boolean; premium: boolean };
    expect(lookup).toMatchObject({ rewardsUnlocked: true, premium: false });

    expect((await call(admin, 'PUT', `/admin/users/${u.id}/rewards-unlocked`, { on: false })).json()).toEqual({ userId: u.id, rewardsUnlocked: false });
    expect((await rewards()).unlockAll).toBe(false);
    const [row] = await sql<{ avatar: string | null }[]>`select avatar_id as avatar from users where id = ${u.id}`;
    expect(row!.avatar).toBeNull();
    const audited = await sql<{ action: string }[]>`select action from audit_logs where entity_id = ${u.id} and action like 'rewards.%' order by occurred_at`;
    expect(audited.map((a) => a.action)).toEqual(['rewards.unlock-all', 'rewards.lock']);
  });

  it('premium requests are the user\'s data: deleted with the account', async () => {
    const u = await user();
    await call(u, 'POST', '/premium/request', { message: 'please' });
    const r = await app.inject({ method: 'DELETE', url: '/v1/user', headers: headers(u.token), payload: { confirm: 'DELETE' } });
    expect(r.statusCode, r.body).toBe(200);
    expect(await sql`select 1 from premium_requests where user_id = ${u.id}`).toHaveLength(0);
  });
});
