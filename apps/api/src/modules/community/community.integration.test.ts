/**
 * Beta 5.8 (ADR-057): Community on real Postgres — joining is the
 * `community` consent; handles; friends with their pushes; blocks; clubs;
 * the three boards and what counts on them; reports and the admin; the
 * admin's switch; leaving.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, boardSchema, communityMeSchema, friendsResponseSchema, type Board } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import type { RecordingPushSender } from '../../lib/push.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/community (real Postgres)', { timeout: 120_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;
  let admin: U;
  let exerciseId: string;

  interface U {
    token: string;
    id: string;
  }

  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.31.${n % 250}.${(n * 7) % 250}` });

  async function user(opts: { admin?: boolean } = {}): Promise<U> {
    n += 1;
    const token = `cm-tok-${n}`;
    verifier.accept(token, { uid: `cm-uid-${n}`, email: `cm${n}@example.com`, claims: opts.admin === true ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`cm-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PATCH' | 'DELETE' | 'PUT', path: string, payload?: unknown) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u.token), ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}) });
  const issue = (r: { json: () => unknown }): string | undefined => (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  async function member(handle: string, extra: { country?: string | null; onWorld?: boolean } = {}): Promise<U> {
    const u = await user();
    const r = await call(u, 'POST', '/community/me', { handle, country: extra.country ?? null, onWorld: extra.onWorld ?? false, policyVersion: CURRENT_POLICY_VERSION });
    expect(r.statusCode, r.body).toBe(201);
    return u;
  }

  /** A completed session today: `sets` sets over `minutes`. */
  async function session(u: U, sets: number, minutes: number, daysAgo = 0): Promise<void> {
    const end = new Date(Date.now() - daysAgo * 86_400_000);
    const start = new Date(end.getTime() - minutes * 60_000);
    const [s] = await sql<{ id: string }[]>`insert into workout_sessions (user_id, name, status, started_at, completed_at, duration_seconds, client_session_id)
      values (${u.id}, 'Push', 'completed', ${start}, ${end}, ${minutes * 60}, gen_random_uuid()) returning id`;
    const [e] = await sql<{ id: string }[]>`insert into session_exercises (session_id, exercise_id, order_index, client_exercise_id) values (${s!.id}, ${exerciseId}, 0, gen_random_uuid()) returning id`;
    for (let i = 0; i < sets; i++) {
      await sql`insert into set_logs (session_exercise_id, set_index, reps, weight_kg, logged_at, client_set_id) values (${e!.id}, ${i + 1}, 8, 60, ${end}, gen_random_uuid())`;
    }
  }

  /** A run today. */
  async function run(u: U, metres: number, seconds: number, opts: { source?: 'phone' | 'watch'; kind?: 'outdoor' | 'treadmill'; gps?: boolean } = {}): Promise<void> {
    const end = new Date();
    const start = new Date(end.getTime() - seconds * 1000);
    const source = opts.source ?? 'phone';
    const gps = opts.gps !== false;
    await sql`insert into runs (user_id, client_run_id, kind, name, started_at, ended_at, duration_seconds, goal_kind, distance_m, avg_pace_sec_per_km,
                                track_points, track_breaks, track_elevation, source, external_id)
      values (${u.id}, gen_random_uuid(), ${opts.kind ?? 'outdoor'}, 'Run', ${start}, ${end}, ${seconds}, 'free', ${metres}, ${seconds / (metres / 1000)},
              ${gps ? 'abc' : null}, ${gps ? sql.json([]) : null}, ${gps ? false : null}, ${source}, ${source === 'watch' ? `w-${Math.random()}` : null})`;
  }

  const board = async (u: U, path: string): Promise<Board> => {
    const r = await call(u, 'GET', path);
    expect(r.statusCode, r.body).toBe(200);
    return boardSchema.parse(r.json());
  };

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
    admin = await user({ admin: true });
    const [x] = await sql<{ id: string }[]>`insert into exercises (slug, name, movement_pattern, equipment, difficulty, default_increment_kg, instructions)
      values ('cm-bench', 'CM bench', 'horizontal-push', '{barbell}', 'beginner', 2.5, '{"a"}')
      on conflict (slug) do update set name = excluded.name returning id`;
    exerciseId = x!.id;
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'cm-uid-%'`;
    await sql`delete from exercises where slug = 'cm-bench'`;
    await sql`delete from audit_logs where action like 'community.%'`;
    await sql`delete from feature_flags where key = 'community'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('joining is the community consent to the current policy; handles are checked; nothing works before joining', async () => {
    const u = await user();
    expect(communityMeSchema.parse((await call(u, 'GET', '/community/me')).json())).toEqual({ profile: null, incoming: 0 });
    const before = await call(u, 'GET', '/community/friends');
    expect(before.statusCode).toBe(403);
    expect(issue(before)).toBe('not-joined');
    const old = await call(u, 'POST', '/community/me', { handle: 'cm_one', country: 'IN', onWorld: false, policyVersion: '2026-11-04' });
    expect(old.statusCode).toBe(409);
    expect(issue(old)).toBe('outdated');
    for (const [handle, why] of [['fitos_official', 'reserved'], ['admin', 'reserved'], ['sh1t_lifter', 'word']] as const) {
      const r = await call(u, 'POST', '/community/me', { handle, country: null, onWorld: false, policyVersion: CURRENT_POLICY_VERSION });
      expect(r.statusCode, handle).toBe(422);
      expect(issue(r)).toBe(why);
    }
    expect((await call(u, 'POST', '/community/me', { handle: 'a b', country: null, onWorld: false, policyVersion: CURRENT_POLICY_VERSION })).statusCode).toBe(422);
    expect((await call(u, 'POST', '/community/me', { handle: 'cm_one', country: 'XX', onWorld: false, policyVersion: CURRENT_POLICY_VERSION })).statusCode).toBe(422);
    const ok = await call(u, 'POST', '/community/me', { handle: '@CM_One', country: 'IN', onWorld: false, policyVersion: CURRENT_POLICY_VERSION });
    expect(ok.statusCode, ok.body).toBe(201);
    expect(communityMeSchema.parse(ok.json()).profile).toMatchObject({ handle: 'cm_one', country: 'IN', onWorld: false });
    const [consent] = await sql<{ granted: boolean; policy_version: string }[]>`select granted, policy_version from consent_records where user_id = ${u.id} and consent_type = 'community'`;
    expect(consent).toEqual({ granted: true, policy_version: CURRENT_POLICY_VERSION });
    // The Privacy list never shows the purpose (an older app could not read it).
    const privacy = (await call(u, 'GET', '/user/consents')).json() as { items: { type: string }[] };
    expect(privacy.items.map((i) => i.type)).not.toContain('community');
    expect((await call(u, 'POST', '/community/me', { handle: 'cm_one_b', country: null, onWorld: false, policyVersion: CURRENT_POLICY_VERSION })).statusCode).toBe(409);
    const other = await user();
    const taken = await call(other, 'POST', '/community/me', { handle: 'cm_one', country: null, onWorld: false, policyVersion: CURRENT_POLICY_VERSION });
    expect(taken.statusCode).toBe(409);
    expect(issue(taken)).toBe('taken');
    const changed = await call(u, 'PATCH', '/community/me', { onWorld: true, country: 'DE' });
    expect(communityMeSchema.parse(changed.json()).profile).toMatchObject({ onWorld: true, country: 'DE' });
  });

  it('friends: ask by handle (a push), answer, see each other; asking back accepts; unfriend', async () => {
    const push = app.push as RecordingPushSender;
    const a = await member('cm_ana');
    const b = await member('cm_ben');
    await sql`insert into push_tokens (user_id, token, platform) values (${b.id}, ${`cm-push-${b.id}`}, 'android')`;
    await sql`insert into push_tokens (user_id, token, platform) values (${a.id}, ${`cm-push-${a.id}`}, 'android')`;
    const sent = push.sends.length;
    expect((await call(a, 'POST', '/community/friends', { handle: '@cm_ben' })).json()).toEqual({ status: 'requested' });
    expect(push.sends.slice(sent)).toEqual([
      { tokens: [`cm-push-${b.id}`], message: { title: 'New friend request', body: '@cm_ana wants to be friends on FITOS.', data: { type: 'community', screen: 'friends' } } },
    ]);
    expect((await call(a, 'POST', '/community/friends', { handle: 'cm_ben' })).json()).toEqual({ status: 'requested' });
    expect((await call(a, 'POST', '/community/friends', { handle: 'cm_nobody' })).statusCode).toBe(404);
    expect(communityMeSchema.parse((await call(b, 'GET', '/community/me')).json()).incoming).toBe(1);
    const lists = friendsResponseSchema.parse((await call(b, 'GET', '/community/friends')).json());
    expect(lists.incoming.map((p) => p.handle)).toEqual(['cm_ana']);
    expect(Object.keys(lists.incoming[0]!).sort()).toEqual(['avatarId', 'country', 'handle', 'userId']);
    // Asking back is accepting.
    expect((await call(b, 'POST', '/community/friends', { handle: 'cm_ana' })).json()).toEqual({ status: 'friends' });
    expect(push.sends.at(-1)!.message.title).toBe('Friend request accepted');
    expect(friendsResponseSchema.parse((await call(a, 'GET', '/community/friends')).json()).friends.map((p) => p.handle)).toEqual(['cm_ben']);
    expect((await board(a, '/community/boards/friends')).rows.map((r) => r.handle).sort()).toEqual(['cm_ana', 'cm_ben']);
    expect((await call(b, 'DELETE', `/community/friends/${a.id}`)).statusCode).toBe(204);
    expect((await board(a, '/community/boards/friends')).rows.map((r) => r.handle)).toEqual(['cm_ana']);
  });

  it('search finds handles by their start; a block hides both ways, ends the friendship and stops requests', async () => {
    const a = await member('cm_search_a');
    const b = await member('cm_search_b');
    const people = async (u: U, q: string) => ((await call(u, 'GET', `/community/people?q=${q}`)).json() as { items: { handle: string }[] }).items.map((p) => p.handle);
    expect(await people(a, 'cm_search')).toEqual(['cm_search_b']);
    await call(a, 'POST', '/community/friends', { handle: 'cm_search_b' });
    await call(b, 'POST', `/community/friends/${a.id}/accept`);
    expect((await call(b, 'POST', '/community/blocks', { userId: a.id })).statusCode).toBe(204);
    expect(await people(a, 'cm_search')).toEqual([]);
    expect(await people(b, 'cm_search')).toEqual([]);
    expect(friendsResponseSchema.parse((await call(a, 'GET', '/community/friends')).json()).friends).toEqual([]);
    expect((await call(a, 'POST', '/community/friends', { handle: 'cm_search_b' })).statusCode).toBe(404);
    expect(((await call(b, 'GET', '/community/blocks')).json() as { items: { handle: string }[] }).items.map((p) => p.handle)).toEqual(['cm_search_a']);
    expect((await call(b, 'DELETE', `/community/blocks/${a.id}`)).statusCode).toBe(204);
    expect(await people(a, 'cm_search')).toEqual(['cm_search_b']);
  });

  it('what counts: 6 sets and 15 minutes, one a day; GPS or watch runs at a human pace; never typed in', async () => {
    const u = await member('cm_counter');
    await session(u, 6, 20);
    await session(u, 8, 30); // a second session the same day: still one day
    await session(u, 5, 40, 1); // too few sets
    await session(u, 10, 10, 2); // too short
    await run(u, 5000, 1800); // 6:00 / km, GPS
    await run(u, 3000, 900, { source: 'watch', gps: false }); // the watch
    await run(u, 5000, 1500, { kind: 'treadmill', gps: false }); // typed in on the phone
    await run(u, 5000, 600); // 2:00 / km: not a human pace
    await run(u, 300, 120); // under 500 m
    // Two sessions today make one day; the thin and the short ones never count.
    const me = (await board(u, '/community/boards/friends')).rows[0]!;
    expect(me).toMatchObject({ handle: 'cm_counter', sessions: 1, runM: 8000, me: true });
  });

  it('the world board: only who chose it, best first, ties share a rank, a country filter, and your own place', async () => {
    const world = async (u: U, q = '') => board(u, `/community/boards/world${q}`);
    const top = await member('cm_w_top', { country: 'IN', onWorld: true });
    const mid = await member('cm_w_mid', { country: 'DE', onWorld: true });
    const tie = await member('cm_w_tie', { country: 'IN', onWorld: true });
    const shy = await member('cm_w_shy', { country: 'IN', onWorld: false });
    for (const [u, days] of [[top, 3], [mid, 2], [tie, 2], [shy, 4]] as const) {
      for (let d = 0; d < days; d++) await session(u, 6, 20, d);
    }
    // Days spread over the week may cross Monday: count what this week holds.
    const b = await world(top);
    const mine = b.rows.filter((r) => r.handle.startsWith('cm_w_'));
    expect(mine.map((r) => r.handle)).not.toContain('cm_w_shy');
    const ranked = [...mine].sort((x, y) => x.rank - y.rank);
    expect(ranked).toEqual(mine);
    const midRow = mine.find((r) => r.handle === 'cm_w_mid');
    const tieRow = mine.find((r) => r.handle === 'cm_w_tie');
    if (midRow !== undefined && tieRow !== undefined) expect(midRow.rank).toBe(tieRow.rank);
    const de = await world(top, '?country=DE');
    expect(de.rows.every((r) => r.country === 'DE')).toBe(true);
    // Not on the world board: no row of your own.
    expect((await world(shy)).me).toBeNull();
    expect((await world(shy)).rows.some((r) => r.me)).toBe(false);
    expect((await call(top, 'GET', '/community/boards/world?country=XX')).statusCode).toBe(422);
  });

  it('clubs: make one (a code), join with it, a club board, the maker leaving passes it on', async () => {
    const owner = await member('cm_club_owner');
    const joiner = await member('cm_club_joiner');
    const made = await call(owner, 'POST', '/community/clubs', { name: "VIT Men's Hostel" });
    expect(made.statusCode, made.body).toBe(201);
    const club = made.json() as { id: string; code: string; members: number; mine: boolean };
    expect(club).toMatchObject({ members: 1, mine: true });
    expect(club.code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    expect((await call(owner, 'POST', '/community/clubs', { name: 'Sh1t Club' })).statusCode).toBe(422);
    expect((await call(joiner, 'POST', '/community/clubs/join', { code: 'ZZZZ2222' })).statusCode).toBe(404);
    const joined = await call(joiner, 'POST', '/community/clubs/join', { code: `${club.code.slice(0, 4).toLowerCase()}-${club.code.slice(4)}` });
    expect(joined.json()).toMatchObject({ id: club.id, members: 2, mine: false });
    expect((await board(joiner, `/community/boards/clubs/${club.id}`)).rows.map((r) => r.handle).sort()).toEqual(['cm_club_joiner', 'cm_club_owner']);
    const stranger = await member('cm_club_stranger');
    expect((await call(stranger, 'GET', `/community/boards/clubs/${club.id}`)).statusCode).toBe(404);
    expect((await call(owner, 'DELETE', `/community/clubs/${club.id}/membership`)).statusCode).toBe(204);
    const after = (await call(joiner, 'GET', '/community/clubs')).json() as { items: { id: string; mine: boolean; members: number }[] };
    expect(after.items).toEqual([expect.objectContaining({ id: club.id, mine: true, members: 1 })]);
    expect((await call(joiner, 'DELETE', `/community/clubs/${club.id}/membership`)).statusCode).toBe(204);
    expect((await sql`select 1 from clubs where id = ${club.id}`).length).toBe(0);
  });

  it('reports reach the admin; hiding takes a member off boards and search; renaming; deleting a club; all audited', async () => {
    const bad = await member('cm_rude_one', { onWorld: true });
    const reporter = await member('cm_reporter');
    await session(bad, 6, 20);
    expect((await call(reporter, 'POST', '/community/reports', { userId: bad.id, reason: 'handle', note: 'Rude.' })).statusCode).toBe(204);
    expect((await call(reporter, 'POST', '/community/reports', { reason: 'handle' })).statusCode).toBe(422);
    expect((await call(reporter, 'GET', '/admin/community/reports')).statusCode).toBe(403);
    const list = (await call(admin, 'GET', '/admin/community/reports')).json() as { items: { id: string; reporterHandle: string; target: { handle: string } }[] };
    const mine = list.items.find((r) => r.target.handle === 'cm_rude_one')!;
    expect(mine.reporterHandle).toBe('cm_reporter');
    expect((await call(admin, 'PATCH', `/admin/community/members/${bad.id}`, { hidden: true, handle: 'cm_renamed' })).statusCode).toBe(204);
    expect(((await call(reporter, 'GET', '/community/people?q=cm_re')).json() as { items: { handle: string }[] }).items.map((p) => p.handle)).toEqual([]);
    expect((await board(reporter, '/community/boards/world')).rows.some((r) => r.userId === bad.id)).toBe(false);
    expect(communityMeSchema.parse((await call(bad, 'GET', '/community/me')).json()).profile!.handle).toBe('cm_renamed');
    expect((await call(admin, 'POST', `/admin/community/reports/${mine.id}/close`)).statusCode).toBe(204);
    expect((await call(admin, 'POST', `/admin/community/reports/${mine.id}/close`)).statusCode).toBe(404);
    const club = (await call(bad, 'POST', '/community/clubs', { name: 'Rude Club' })).json() as { id: string };
    expect(((await call(admin, 'GET', '/admin/community/clubs')).json() as { items: { id: string }[] }).items.map((c) => c.id)).toContain(club.id);
    expect((await call(admin, 'DELETE', `/admin/community/clubs/${club.id}`)).statusCode).toBe(204);
    const actions = (await sql<{ action: string }[]>`select action from audit_logs where action like 'community.%' order by occurred_at`).map((r) => r.action);
    expect(actions).toEqual(expect.arrayContaining(['community.member.update', 'community.report.close', 'community.club.delete']));
  });

  it("the admin's switch off: Community is refused, but anyone can still leave; leaving withdraws the consent and removes everything", async () => {
    const a = await member('cm_leaver');
    const b = await member('cm_stayer');
    await call(a, 'POST', '/community/friends', { handle: 'cm_stayer' });
    await call(b, 'POST', `/community/friends/${a.id}/accept`);
    expect((await call(admin, 'PUT', '/admin/flags/community', { enabled: false })).statusCode).toBe(200);
    try {
      const off = await call(a, 'GET', '/community/me');
      expect(off.statusCode).toBe(403);
      expect(issue(off)).toBe('feature-off');
      expect((await call(a, 'DELETE', '/community/me')).statusCode).toBe(204);
    } finally {
      expect((await call(admin, 'PUT', '/admin/flags/community', { enabled: true })).statusCode).toBe(200);
    }
    expect(communityMeSchema.parse((await call(a, 'GET', '/community/me')).json()).profile).toBeNull();
    expect(friendsResponseSchema.parse((await call(b, 'GET', '/community/friends')).json()).friends).toEqual([]);
    const consents = await sql<{ granted: boolean }[]>`select granted from consent_records where user_id = ${a.id} and consent_type = 'community' order by granted_at`;
    expect(consents.map((c) => c.granted)).toEqual([true, false]);
  });
});
