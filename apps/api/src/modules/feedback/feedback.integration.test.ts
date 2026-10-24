/**
 * Phase 19 (ADR-026): feedback from the app on real Postgres — sent by any
 * signed-in user (validated, rate-limited per user), read and marked by an
 * admin only (audited), deleted with the user; and the app's minimum build
 * served by the public /meta/config (E1).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  FEEDBACK_MAX_LENGTH,
  FEEDBACK_PER_HOUR,
  adminFeedbackCountsSchema,
  adminFeedbackListSchema,
  myFeedbackListSchema,
  type AdminFeedbackList,
  type MyFeedbackList,
} from '@fitos/contracts';

import { createDatabase } from '../../db/client.js';
import { migrateUp } from '../../db/migrate.js';
import type { RecordingPushSender } from '../../lib/push.js';
import { FeedbackRepository } from './repository.js';
import { FeedbackService } from './service.js';
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

  const call = (u: U | null, method: 'GET' | 'POST' | 'PATCH' | 'DELETE', path: string, payload?: unknown) =>
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
    await sql`delete from audit_logs where action in ('feedback.status', 'feedback.priority', 'feedback.reply')`;
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

  it('an admin is not limited (the owner tests feedback freely)', async () => {
    const admin = await user(true);
    for (let i = 0; i < FEEDBACK_PER_HOUR + 3; i++) expect((await send(admin, `admin note ${i}`)).statusCode).toBe(201);
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

  it('the owner flow: new (untagged), then tagged, to do (open), then done; counts per tab; only an admin', async () => {
    const plain = await user();
    const admin = await user(true);
    await sql`delete from feedback`;
    const ids: string[] = [];
    for (const m of ['crash on save', 'add water tracking', 'typo on Home', 'already fixed']) {
      ids.push(((await send(plain, m)).json() as { id: string }).id);
    }
    const [crash, water, typo, fixed] = ids as [string, string, string, string];
    const counts = async () => adminFeedbackCountsSchema.parse((await call(admin, 'GET', '/admin/feedback/counts')).json());
    const open = async (q = '') => ((await call(admin, 'GET', `/admin/feedback?status=open${q}`)).json() as AdminFeedbackList).items.map((i) => i.id);

    expect((await call(plain, 'GET', '/admin/feedback/counts')).statusCode).toBe(403);
    expect(await counts()).toEqual({ untagged: 4, red: 0, yellow: 0, green: 0, done: 0 });

    await call(admin, 'PATCH', `/admin/feedback/${crash}`, { priority: 'red', status: 'read' });
    await call(admin, 'PATCH', `/admin/feedback/${water}`, { priority: 'green', status: 'read' });
    await call(admin, 'PATCH', `/admin/feedback/${typo}`, { priority: 'yellow' });
    await call(admin, 'PATCH', `/admin/feedback/${fixed}`, { status: 'done' });
    expect(await counts()).toEqual({ untagged: 0, red: 1, yellow: 1, green: 1, done: 1 });

    // To do is everything not done, new or read; New is what is open and untagged.
    expect((await open()).sort()).toEqual([crash, typo, water].sort());
    expect(await open('&priority=none')).toEqual([]);

    await call(admin, 'PATCH', `/admin/feedback/${crash}`, { status: 'done' });
    expect(await counts()).toEqual({ untagged: 0, red: 0, yellow: 1, green: 1, done: 2 });
    expect(await open()).not.toContain(crash);
    expect((await call(admin, 'GET', '/admin/feedback?status=closed')).statusCode).toBe(422);
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

  /* ------------------------------------------------------------ beta 3.6 -- */

  const jpeg = (size = 64) => {
    const b = Buffer.alloc(size, 7);
    b[0] = 0xff;
    b[1] = 0xd8;
    b[2] = 0xff;
    return b.toString('base64');
  };
  const png = () => Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(20, 1)]).toString('base64');
  const device = { model: 'Samsung SM-S921B', os: 'Android 15', screen: '/plan/session' };
  const sendWith = (u: U, extra: Record<string, unknown>) =>
    call(u, 'POST', '/feedback', { category: 'bug', message: 'With a picture', appVersion: '1.0.0-beta.3.6+12', ...extra });

  it('beta 3.6: up to 3 pictures and the phone; the admin sees them (and only an admin fetches a picture, uncached)', async () => {
    const u = await user();
    const admin = await user(true);
    const r = await sendWith(u, { device, pictures: [{ type: 'image/jpeg', data: jpeg() }, { type: 'image/png', data: png() }] });
    expect(r.statusCode, r.body).toBe(201);
    const id = (r.json() as { id: string }).id;

    const list = adminFeedbackListSchema.parse((await call(admin, 'GET', '/admin/feedback?limit=200')).json());
    const it = list.items.find((x) => x.id === id)!;
    expect(it.device).toEqual(device);
    expect(it.pictures.map((p) => [p.type, p.bytes])).toEqual([
      ['image/jpeg', 64],
      ['image/png', 28],
    ]);
    expect(it.replies).toEqual([]);

    const pic = await call(admin, 'GET', `/admin/feedback/${id}/pictures/${it.pictures[0]!.id}`);
    expect(pic.statusCode).toBe(200);
    expect(pic.headers['content-type']).toBe('image/jpeg');
    expect(pic.headers['cache-control']).toBe('private, no-store');
    expect(pic.rawPayload.subarray(0, 3)).toEqual(Buffer.from([0xff, 0xd8, 0xff]));
    expect(pic.rawPayload.length).toBe(64);
    expect((await call(u, 'GET', `/admin/feedback/${id}/pictures/${it.pictures[0]!.id}`)).statusCode).toBe(403);
    expect((await call(admin, 'GET', `/admin/feedback/${id}/pictures/00000000-0000-4000-8000-000000000000`)).statusCode).toBe(404);

    // Left out: no phone details.
    const plain = await sendWith(u, { device: null });
    const again = adminFeedbackListSchema.parse((await call(admin, 'GET', '/admin/feedback?limit=200')).json());
    expect(again.items.find((x) => x.id === (plain.json() as { id: string }).id)!.device).toBeNull();
  });

  it('beta 3.6: a 4th picture, one over 1 MB, or one that is not an image is refused (422), and nothing is stored', async () => {
    const u = await user();
    const before = (await sql<{ n: number }[]>`select count(*)::int as n from feedback where user_id = ${u.id}`)[0]!.n;
    const four = await sendWith(u, { pictures: Array.from({ length: 4 }, () => ({ type: 'image/jpeg', data: jpeg() })) });
    expect(four.statusCode).toBe(422);
    const big = await sendWith(u, { pictures: [{ type: 'image/jpeg', data: jpeg(1_000_001) }] });
    expect(big.statusCode).toBe(422);
    const fake = await sendWith(u, { pictures: [{ type: 'image/jpeg', data: Buffer.from('not a picture at all').toString('base64') }] });
    expect(fake.statusCode).toBe(422);
    expect((fake.json() as { error: { details: { path: string; issue: string }[] } }).error.details[0]).toEqual({ path: 'pictures.0', issue: 'not-an-image' });
    const gif = await sendWith(u, { pictures: [{ type: 'image/gif', data: jpeg() }] });
    expect(gif.statusCode).toBe(422);
    expect((await sql<{ n: number }[]>`select count(*)::int as n from feedback where user_id = ${u.id}`)[0]!.n).toBe(before);
    // Three near-1 MB pictures fit the route's body limit.
    const three = await sendWith(u, { pictures: Array.from({ length: 3 }, () => ({ type: 'image/jpeg', data: jpeg(990_000) })) });
    expect(three.statusCode, three.body).toBe(201);
  });

  it('beta 3.6: an admin replies (audited, the sender\'s phones told once); the sender reads it under their messages, unread until opened', async () => {
    const u = await user();
    const other = await user();
    const admin = await user(true);
    const push = app.push as RecordingPushSender;
    await sql`insert into push_tokens (user_id, token, platform) values (${u.id}, ${`reply-tok-${u.id}`}, 'android')`;
    const id = ((await send(u, 'The timer froze')).json() as { id: string }).id;
    await send(other, 'Not mine');

    expect((await call(u, 'POST', `/admin/feedback/${id}/replies`, { message: 'x' })).statusCode).toBe(403);
    expect((await call(admin, 'POST', `/admin/feedback/00000000-0000-4000-8000-000000000000/replies`, { message: 'x' })).statusCode).toBe(404);
    expect((await call(admin, 'POST', `/admin/feedback/${id}/replies`, { message: '   ' })).statusCode).toBe(422);

    const sendsBefore = push.sends.length;
    const r = await call(admin, 'POST', `/admin/feedback/${id}/replies`, { message: ' Fixed in 3.7, thank you! ' });
    expect(r.statusCode, r.body).toBe(201);
    expect(r.json()).toMatchObject({ message: 'Fixed in 3.7, thank you!', readAt: null });
    expect(push.sends.length).toBe(sendsBefore + 1);
    expect(push.sends.at(-1)).toMatchObject({
      tokens: [`reply-tok-${u.id}`],
      message: { title: 'FITOS replied to your feedback', body: 'Fixed in 3.7, thank you!', data: { type: 'feedback-reply', feedbackId: id } },
    });
    const [audit] = await sql<{ actor_user_id: string; entity_id: string }[]>`
      select actor_user_id, entity_id from audit_logs where action = 'feedback.reply' and entity_id = ${id}`;
    expect(audit).toEqual({ actor_user_id: admin.id, entity_id: id });

    const mine = myFeedbackListSchema.parse((await call(u, 'GET', '/feedback/mine')).json()) as MyFeedbackList;
    expect(mine.unread).toBe(1);
    expect(mine.items.map((x) => x.message)).toEqual(['The timer froze']);
    expect(mine.items[0]!.replies.map((x) => x.message)).toEqual(['Fixed in 3.7, thank you!']);
    expect(myFeedbackListSchema.parse((await call(other, 'GET', '/feedback/mine')).json()).unread).toBe(0);

    expect((await call(u, 'POST', '/feedback/mine/read')).json()).toEqual({ unread: 0 });
    const read = myFeedbackListSchema.parse((await call(u, 'GET', '/feedback/mine')).json());
    expect(read.unread).toBe(0);
    expect(read.items[0]!.replies[0]!.readAt).not.toBeNull();
    // The admin list shows the reply too.
    const list = adminFeedbackListSchema.parse((await call(admin, 'GET', '/admin/feedback?limit=200')).json());
    expect(list.items.find((x) => x.id === id)!.replies).toHaveLength(1);
    expect((await call(null, 'GET', '/feedback/mine')).statusCode).toBe(401);
  });

  it('beta 3.6: the admin filters by type', async () => {
    const u = await user();
    const admin = await user(true);
    await send(u, 'An idea', 'idea');
    await send(u, 'A food', 'food');
    const ideas = adminFeedbackListSchema.parse((await call(admin, 'GET', '/admin/feedback?category=idea&limit=200')).json());
    expect(ideas.items.length).toBeGreaterThan(0);
    expect(ideas.items.every((x) => x.category === 'idea')).toBe(true);
  });

  it('beta 3.6: pictures older than six months are deleted, the message stays; all of it goes with the account', async () => {
    const u = await user();
    const id = ((await sendWith(u, { pictures: [{ type: 'image/jpeg', data: jpeg() }] })).json() as { id: string }).id;
    await sql`update feedback_pictures set created_at = now() - interval '181 days' where feedback_id = ${id}`;
    const db = createDatabase(url);
    try {
      const service = new FeedbackService(new FeedbackRepository(db.db), app.push);
      expect(await service.purgeOldPictures()).toBeGreaterThanOrEqual(1);
    } finally {
      await db.client.end({ timeout: 5 });
    }
    expect((await sql`select id from feedback_pictures where feedback_id = ${id}`).length).toBe(0);
    expect((await sql`select id from feedback where id = ${id}`).length).toBe(1);

    const id2 = ((await sendWith(u, { pictures: [{ type: 'image/jpeg', data: jpeg() }] })).json() as { id: string }).id;
    const admin = await user(true);
    await call(admin, 'POST', `/admin/feedback/${id2}/replies`, { message: 'Thanks' });
    await sql`delete from users where id = ${u.id}`;
    expect((await sql`select id from feedback_pictures where feedback_id = ${id2}`).length).toBe(0);
    expect((await sql`select id from feedback_replies where feedback_id = ${id2}`).length).toBe(0);
  });
});
