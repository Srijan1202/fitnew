/**
 * Beta 5.8 (ADR-057): Community on real Postgres — joining is the
 * `community` consent; handles; friends with their pushes; blocks; clubs;
 * the three boards and what counts on them; reports and the admin; the
 * admin's switch; leaving.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  CURRENT_POLICY_VERSION,
  boardSchema,
  clubSchema,
  communityMeSchema,
  feedSchema,
  friendsResponseSchema,
  kudosResultSchema,
  personListSchema,
  personProfileSchema,
  suggestionListSchema,
  type Board,
  type Feed,
} from '@fitos/contracts';
import { keptPlanPct } from '@fitos/core/community/board';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import type { RecordingPushSender } from '../../lib/push.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { CommunityRepository } from './repository.js';
import { CommunityService } from './service.js';

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

  /* ---------------------------------------------------------- beta 6.2 -- */

  const today = () => localDateOf(new Date(), 'Asia/Kolkata');
  const monday = () => addDays(today(), 1 - isoWeekday(today()));

  async function friends(a: U, b: U, bHandle: string): Promise<void> {
    await call(a, 'POST', '/community/friends', { handle: bHandle });
    expect((await call(b, 'POST', `/community/friends/${a.id}/accept`)).statusCode).toBe(200);
  }

  /** An active programme training on these weekdays. */
  async function programme(u: U, weekdays: number[]): Promise<void> {
    const [p] = await sql<{ id: string }[]>`insert into programs (user_id, name, split_type, days_per_week, source) values (${u.id}, 'C62', 'full-body', ${Math.min(6, weekdays.length)}, 'custom') returning id`;
    for (const d of weekdays) await sql`insert into program_days (program_id, day_of_week, session_name) values (${p!.id}, ${d}, ${`Day ${d}`})`;
  }

  it('beta 6.2 (C11): boards by streak, active days and the plan kept; no plan, not on the plan board', async () => {
    const a = await member('c62_planner');
    const b = await member('c62_freeform');
    await friends(a, b, 'c62_freeform');
    await programme(a, [1, 2, 3, 4, 5, 6, 7]);
    await session(a, 6, 20);
    await run(a, 3000, 1000);
    await session(b, 6, 20);
    // b's week is recounted when they sync or look (the timer is off in tests).
    await board(b, '/community/boards/friends');

    const plan = await board(a, '/community/boards/friends?metric=plan');
    expect(plan.rows.map((r) => r.handle)).toEqual(['c62_planner']);
    expect(plan.rows[0]).toMatchObject({ sessions: 1, activeDays: 1, keptPct: keptPlanPct(1, isoWeekday(today())) });
    const days = await board(a, '/community/boards/friends?metric=active-days');
    expect(days.rows.map((r) => [r.handle, r.activeDays, r.keptPct])).toEqual([
      ['c62_planner', 1, keptPlanPct(1, isoWeekday(today()))],
      ['c62_freeform', 1, null],
    ]);
    expect((await board(a, '/community/boards/friends?metric=streak')).metric).toBe('streak');
    expect((await call(a, 'GET', '/community/boards/friends?metric=calories')).statusCode).toBe(422);
  });

  it('beta 6.2 (C12): a rolled-over week is recounted and kept; last week’s podium, my place and the places moved', async () => {
    const a = await member('c62_climber', { onWorld: true, country: 'IN' });
    const b = await member('c62_leader');
    await friends(a, b, 'c62_leader');
    const last = addDays(monday(), -7);
    const before = addDays(monday(), -14);
    // A week ago: a trained once (counted from the records when the week rolls over).
    await session(a, 6, 20, 7);
    await sql`insert into community_week_stats (user_id, week_from, sessions, run_m, streak) values (${a.id}, ${last}, 0, 0, 3)
      on conflict (user_id) do update set week_from = excluded.week_from, sessions = 0, streak = 3`;
    // The week before: b was ahead.
    await sql`insert into community_week_history (user_id, week_from, sessions, run_m, streak, active_days, planned) values
      (${a.id}, ${before}, 1, 0, 1, 1, null), (${b.id}, ${before}, 3, 0, 3, 3, null)`;

    const f = await board(a, '/community/boards/friends?metric=sessions');
    const [kept] = await sql<{ sessions: number; streak: number }[]>`select sessions, streak from community_week_history where user_id = ${a.id} and week_from = ${last}`;
    expect(kept).toEqual({ sessions: 1, streak: 3 });
    expect(f.lastWeek).toMatchObject({ weekFrom: last, myRank: 1, moved: 1 });
    expect(f.lastWeek!.podium.map((r) => [r.handle, r.rank, r.me])).toEqual([['c62_climber', 1, true]]);
    // The world board's last week: those who chose it.
    const w = await board(a, '/community/boards/world?metric=sessions&country=IN');
    expect(w.lastWeek!.podium.some((r) => r.handle === 'c62_climber')).toBe(true);
    // Nothing counted last week: no podium.
    expect((await board(b, '/community/boards/friends?metric=distance')).lastWeek).toBeNull();
  });

  it('beta 6.2 (C4): a friend’s or club-mate’s profile is board data only; anyone else is 404', async () => {
    const a = await member('c62_viewer');
    const b = await member('c62_friend');
    const c = await member('c62_clubmate');
    const d = await member('c62_stranger');
    await friends(a, b, 'c62_friend');
    const club = clubSchema.parse((await call(c, 'POST', '/community/clubs', { name: 'C62 Lifters' })).json());
    expect((await call(a, 'POST', '/community/clubs/join', { code: club.code })).statusCode).toBe(200);
    await session(b, 6, 20);
    await sql`insert into community_week_history (user_id, week_from, sessions, run_m, streak, active_days, planned) values (${b.id}, ${addDays(monday(), -7)}, 4, 2500, 6, 5, 4)`;

    const p = personProfileSchema.parse((await call(a, 'GET', `/community/people/${b.id}`)).json());
    expect(p).toMatchObject({ relation: 'friend', person: { handle: 'c62_friend' }, thisWeek: { weekFrom: monday(), sessions: 1, activeDays: 1, keptPct: null }, clubsInCommon: [] });
    expect(p.friendsSince).not.toBeNull();
    expect(p.weeks.map((x) => x.weekFrom)).toEqual([-28, -21, -14, -7].map((n) => addDays(monday(), n)));
    expect(p.weeks[3]).toEqual({ weekFrom: addDays(monday(), -7), sessions: 4, runM: 2500, activeDays: 5, keptPct: 100 });
    expect(p.weeks[0]).toMatchObject({ sessions: 0, runM: 0, keptPct: null });
    // Nothing else about them: no name, email, weights or food.
    expect(JSON.stringify(p)).not.toMatch(/@example\.com|weightKg|kcal/);

    const mate = personProfileSchema.parse((await call(a, 'GET', `/community/people/${c.id}`)).json());
    expect(mate).toMatchObject({ relation: 'club-mate', friendsSince: null, clubsInCommon: [{ id: club.id, name: 'C62 Lifters' }] });
    expect((await call(a, 'GET', `/community/people/${d.id}`)).statusCode).toBe(404);
    expect((await call(a, 'GET', `/community/people/${a.id}`)).statusCode).toBe(404);
    await call(b, 'POST', '/community/blocks', { userId: a.id });
    expect((await call(a, 'GET', `/community/people/${b.id}`)).statusCode).toBe(404);
  });

  it('beta 6.2 (C5): the owner renames, makes a new code, removes (kept out until let back) and passes the club', async () => {
    const push = app.push as RecordingPushSender;
    const owner = await member('c62_owner');
    const m = await member('c62_member');
    const other = await member('c62_other');
    await sql`insert into push_tokens (user_id, token, platform) values (${m.id}, ${`cm-push-${m.id}`}, 'android')`;
    const club = clubSchema.parse((await call(owner, 'POST', '/community/clubs', { name: 'C62 Run Club' })).json());
    expect((await call(m, 'POST', '/community/clubs/join', { code: club.code })).statusCode).toBe(200);

    // Only the owner; a stranger does not even learn the club exists.
    const notOwner = await call(m, 'PATCH', `/community/clubs/${club.id}`, { name: 'Mine now' });
    expect(notOwner.statusCode).toBe(403);
    expect(issue(notOwner)).toBe('not-owner');
    expect((await call(other, 'GET', `/community/clubs/${club.id}/removed`)).statusCode).toBe(404);
    expect(clubSchema.parse((await call(owner, 'PATCH', `/community/clubs/${club.id}`, { name: 'C62 Runners' })).json()).name).toBe('C62 Runners');
    expect((await call(owner, 'PATCH', `/community/clubs/${club.id}`, { name: 'x' })).statusCode).toBe(422);

    // A new code: the old one stops working.
    const recoded = clubSchema.parse((await call(owner, 'POST', `/community/clubs/${club.id}/code`)).json());
    expect(recoded.code).not.toBe(club.code);
    expect((await call(other, 'POST', '/community/clubs/join', { code: club.code })).statusCode).toBe(404);

    // Removed: off the board, and the new code does not let them back in.
    expect((await call(owner, 'DELETE', `/community/clubs/${club.id}/members/${owner.id}`)).statusCode).toBe(422);
    expect((await call(owner, 'DELETE', `/community/clubs/${club.id}/members/${m.id}`)).statusCode).toBe(204);
    expect((await board(owner, `/community/boards/clubs/${club.id}`)).rows.map((r) => r.handle)).toEqual(['c62_owner']);
    const back = await call(m, 'POST', '/community/clubs/join', { code: recoded.code });
    expect(back.statusCode).toBe(403);
    expect(issue(back)).toBe('removed');
    expect(personListSchema.parse((await call(owner, 'GET', `/community/clubs/${club.id}/removed`)).json()).items.map((p) => p.handle)).toEqual(['c62_member']);
    expect((await call(owner, 'DELETE', `/community/clubs/${club.id}/removed/${m.id}`)).statusCode).toBe(204);
    expect((await call(owner, 'DELETE', `/community/clubs/${club.id}/removed/${m.id}`)).statusCode).toBe(404);
    expect((await call(m, 'POST', '/community/clubs/join', { code: recoded.code })).statusCode).toBe(200);

    // Passed on: the new owner is told; the old one is an ordinary member.
    expect((await call(owner, 'POST', `/community/clubs/${club.id}/owner`, { userId: other.id })).statusCode).toBe(404);
    const sent = push.sends.length;
    const passed = clubSchema.parse((await call(owner, 'POST', `/community/clubs/${club.id}/owner`, { userId: m.id })).json());
    expect(passed.mine).toBe(false);
    expect(push.sends.slice(sent).map((s) => s.message.title)).toEqual(['A club is yours']);
    expect(clubSchema.array().parse((await call(m, 'GET', '/community/clubs')).json().items).find((c) => c.id === club.id)!.mine).toBe(true);
    expect((await call(owner, 'POST', `/community/clubs/${club.id}/code`)).statusCode).toBe(403);
  });

  it('beta 6.2 (S7): after a decline, asking again looks sent for 7 days but is not; then it goes through', async () => {
    const push = app.push as RecordingPushSender;
    const a = await member('c62_asker');
    const b = await member('c62_decliner');
    await sql`insert into push_tokens (user_id, token, platform) values (${b.id}, ${`cm-push-${b.id}`}, 'android')`;
    await call(a, 'POST', '/community/friends', { handle: 'c62_decliner' });
    expect((await call(b, 'DELETE', `/community/friends/${a.id}`)).statusCode).toBe(204);
    const sent = push.sends.length;
    expect((await call(a, 'POST', '/community/friends', { handle: 'c62_decliner' })).json()).toEqual({ status: 'requested' });
    expect(push.sends.length).toBe(sent);
    expect(friendsResponseSchema.parse((await call(b, 'GET', '/community/friends')).json()).incoming).toEqual([]);
    // Nobody learns of it in their data download.
    expect(JSON.stringify((await call(a, 'POST', '/user/export')).json())).not.toContain('friend_declines');
    await sql`update friend_declines set declined_at = now() - interval '8 days' where requester_id = ${a.id}`;
    await call(a, 'POST', '/community/friends', { handle: 'c62_decliner' });
    expect(friendsResponseSchema.parse((await call(b, 'GET', '/community/friends')).json()).incoming.map((p) => p.handle)).toEqual(['c62_asker']);
    // Cancelling your own request is not a decline.
    expect((await call(a, 'DELETE', `/community/friends/${b.id}`)).statusCode).toBe(204);
    expect((await sql`select 1 from friend_declines where requester_id = ${a.id} and declined_at > now() - interval '1 day'`).length).toBe(0);
  });

  it('beta 6.2 (A2): deleting a run recounts the week at once', async () => {
    const a = await member('c62_runner');
    await run(a, 5000, 1500);
    expect((await board(a, '/community/boards/friends?metric=distance')).rows[0]!.runM).toBe(5000);
    const [r] = await sql<{ id: string }[]>`select client_run_id as id from runs where user_id = ${a.id}`;
    expect((await call(a, 'DELETE', `/running/runs/${r!.id}`)).statusCode).toBe(204);
    let runM = -1;
    for (let i = 0; i < 40 && runM !== 0; i++) {
      await new Promise((ok) => setTimeout(ok, 50));
      const [s] = await sql<{ run_m: number }[]>`select run_m from community_week_stats where user_id = ${a.id}`;
      runM = s!.run_m;
    }
    expect(runM).toBe(0);
  });
  /* ------------------------------------------------ beta 6.3: Community that talks -- */

  const feedOf = async (u: U): Promise<Feed> => {
    const r = await call(u, 'GET', '/community/feed');
    expect(r.statusCode, r.body).toBe(200);
    return feedSchema.parse(r.json());
  };

  it('beta 6.3 (C1): nothing is shared until chosen; then friends see the kinds shared, from then on; off deletes them', async () => {
    const a = await member('c63_poster');
    const b = await member('c63_friend');
    const c = await member('c63_stranger');
    await friends(a, b, 'c63_friend');
    const me = communityMeSchema.parse((await call(a, 'GET', '/community/me')).json());
    expect(me.profile).toMatchObject({ feed: [], suggest: true, notify: true });

    // Before sharing: nothing is posted.
    await session(a, 6, 20);
    await board(a, '/community/boards/friends');
    expect((await feedOf(b)).items).toEqual([]);

    expect((await call(a, 'PATCH', '/community/me', { feed: ['session', 'run', 'record', 'session'] })).statusCode).toBe(422);
    expect(communityMeSchema.parse((await call(a, 'PATCH', '/community/me', { feed: ['session', 'run', 'record'] })).json()).profile!.feed).toEqual(['session', 'run', 'record']);
    // The earlier session stays unposted; what happens from now is.
    await session(a, 6, 20);
    await sql`update set_logs set is_pr = true where session_exercise_id in (
      select se.id from session_exercises se join workout_sessions ws on ws.id = se.session_id where ws.user_id = ${a.id} and ws.completed_at > now() - interval '1 minute')`;
    await run(a, 5200, 1700);
    const [r] = await sql<{ id: string }[]>`select id from runs where user_id = ${a.id}`;
    await sql`insert into run_best_efforts (run_id, user_id, key, seconds, start_m) values (${r!.id}, ${a.id}, '1k', 300, 0), (${r!.id}, ${a.id}, '5k', 1600, 0)`;
    await board(a, '/community/boards/friends');

    const seen = await feedOf(b);
    expect(seen.items.map((p) => [p.kind, p.title, p.value, p.mine]).sort()).toEqual([
      ['lift-record', 'CM bench', 0, false],
      ['run', null, 5200, false],
      ['run-record', '5k', null, false],
      ['session', 'Push', null, false],
    ]);
    expect(seen.items.every((p) => p.person.handle === 'c63_poster' && p.kudos === 0 && !p.cheered)).toBe(true);
    // Never weights, sets or routes.
    expect(JSON.stringify(seen)).not.toMatch(/weight|kg|track|reps/i);
    expect((await feedOf(a)).items.every((p) => p.mine)).toBe(true);
    expect((await feedOf(c)).items).toEqual([]);

    // Kudos: friends only, once; not your own.
    const post = seen.items.find((p) => p.kind === 'session')!;
    expect(kudosResultSchema.parse((await call(b, 'POST', `/community/feed/${post.id}/kudos`)).json())).toEqual({ kudos: 1, cheered: true });
    expect((await call(b, 'POST', `/community/feed/${post.id}/kudos`)).json()).toEqual({ kudos: 1, cheered: true });
    expect((await call(a, 'POST', `/community/feed/${post.id}/kudos`)).statusCode).toBe(404);
    expect((await call(c, 'POST', `/community/feed/${post.id}/kudos`)).statusCode).toBe(404);
    const mine = (await feedOf(a)).items.find((p) => p.id === post.id)!;
    expect(mine).toMatchObject({ kudos: 1, cheered: false, mine: true });
    expect(mine.cheeredBy.map((p) => p.handle)).toEqual(['c63_friend']);
    expect((await feedOf(b)).items.find((p) => p.id === post.id)).toMatchObject({ kudos: 1, cheered: true, cheeredBy: [] });
    expect((await call(b, 'DELETE', `/community/feed/${post.id}/kudos`)).json()).toEqual({ kudos: 0, cheered: false });

    // Switching a kind off deletes its posts; an unfriended person sees nothing.
    await call(a, 'PATCH', '/community/me', { feed: ['run'] });
    expect((await feedOf(b)).items.map((p) => p.kind)).toEqual(['run']);
    await call(b, 'DELETE', `/community/friends/${a.id}`);
    expect((await feedOf(b)).items).toEqual([]);
    // A deleted run takes its post with it.
    expect((await call(a, 'DELETE', `/running/runs/${(await sql<{ id: string }[]>`select client_run_id as id from runs where user_id = ${a.id}`)[0]!.id}`)).statusCode).toBe(204);
    await board(a, '/community/boards/friends');
    expect((await feedOf(a)).items).toEqual([]);
  });

  it('beta 6.3 (C1): a streak milestone posts once; posts older than 30 days go', async () => {
    const a = await member('c63_streaker');
    await call(a, 'PATCH', '/community/me', { feed: ['streak'] });
    const repo = new CommunityRepository(app.database.db);
    const service = new CommunityService(repo, async () => 7, app.push);
    await service.refreshOne(a.id);
    await service.refreshOne(a.id);
    const items = (await feedOf(a)).items;
    expect(items.map((p) => [p.kind, p.value])).toEqual([['streak', 7]]);
    await sql`update community_posts set at = now() - interval '31 days' where user_id = ${a.id}`;
    // 31 days on, the streak's milestone is long past: the round deletes and does not post again.
    await new CommunityService(repo, async () => 20, app.push).refreshAll();
    expect((await sql`select 1 from community_posts where user_id = ${a.id}`).length).toBe(0);
  });

  it('beta 6.3 (C2): one evening summary a day of the kudos not yet told; none with notifications off', async () => {
    const push = app.push as RecordingPushSender;
    const a = await member('c63_cheered');
    const b = await member('c63_cheer_b');
    const c = await member('c63_cheer_c');
    await friends(a, b, 'c63_cheer_b');
    await friends(a, c, 'c63_cheer_c');
    await sql`insert into push_tokens (user_id, token, platform) values (${a.id}, ${`cm-push-${a.id}`}, 'android')`;
    await call(a, 'PATCH', '/community/me', { feed: ['session'] });
    await session(a, 6, 20);
    await board(a, '/community/boards/friends');
    const post = (await feedOf(b)).items[0]!;
    await call(b, 'POST', `/community/feed/${post.id}/kudos`);
    await call(c, 'POST', `/community/feed/${post.id}/kudos`);

    const day = today();
    const at = (h: number) => new Date(`${day}T${String(h).padStart(2, '0')}:00:00+05:30`);
    const round = (h: number) => new CommunityService(new CommunityRepository(app.database.db), async () => 0, app.push, () => at(h)).kudosRound();
    const mineSends = () => push.sends.filter((s) => s.tokens.includes(`cm-push-${a.id}`));
    const before = mineSends().length;
    await round(18);
    expect(mineSends().length).toBe(before);
    await round(19);
    const told = mineSends().slice(before);
    expect(told.map((s) => [s.message.title, s.message.body])).toEqual([['Kudos', '@c63_cheer_c and @c63_cheer_b cheered you.']]);
    // Once a day: a later cheer waits for tomorrow.
    await call(c, 'DELETE', `/community/feed/${post.id}/kudos`);
    await call(c, 'POST', `/community/feed/${post.id}/kudos`);
    await round(21);
    expect(mineSends().length).toBe(before + 1);
    // Notifications off: nothing, and the kudos count as told.
    await call(a, 'PATCH', '/community/me', { notify: false });
    await sql`update community_profiles set kudos_pushed_on = null where user_id = ${a.id}`;
    await round(20);
    expect(mineSends().length).toBe(before + 1);
    expect((await sql`select 1 from community_kudos k join community_posts p on p.id = k.post_id where p.user_id = ${a.id} and not k.notified`).length).toBe(0);
  });

  it('beta 6.3 (C3): a quiet friend can be nudged once a week, with at most one notification a day; never a stranger', async () => {
    const push = app.push as RecordingPushSender;
    const a = await member('c63_nudger');
    const b = await member('c63_busy');
    const d = await member('c63_quiet');
    const e = await member('c63_nudger_two');
    const s = await member('c63_nobody');
    await friends(a, b, 'c63_busy');
    await friends(a, d, 'c63_quiet');
    await friends(e, d, 'c63_quiet');
    await sql`insert into push_tokens (user_id, token, platform) values (${d.id}, ${`cm-push-${d.id}`}, 'android')`;
    await session(b, 6, 20, 1);

    const busy = await call(a, 'POST', `/community/friends/${b.id}/nudge`);
    expect(busy.statusCode).toBe(409);
    expect(issue(busy)).toBe('active');
    expect(personProfileSchema.parse((await call(a, 'GET', `/community/people/${b.id}`)).json()).nudge).toBe('active');
    expect(personProfileSchema.parse((await call(a, 'GET', `/community/people/${d.id}`)).json()).nudge).toBe('can');
    expect((await call(a, 'POST', `/community/friends/${s.id}/nudge`)).statusCode).toBe(404);

    const sent = push.sends.length;
    expect((await call(a, 'POST', `/community/friends/${d.id}/nudge`)).statusCode).toBe(204);
    expect(push.sends.slice(sent).map((x) => x.message.body)).toEqual(['@c63_nudger nudged you: time to move. A short session counts.']);
    const again = await call(a, 'POST', `/community/friends/${d.id}/nudge`);
    expect(issue(again)).toBe('sent');
    expect(personProfileSchema.parse((await call(a, 'GET', `/community/people/${d.id}`)).json()).nudge).toBe('sent');
    // A second friend's nudge the same day shows in the app, without a notification.
    expect((await call(e, 'POST', `/community/friends/${d.id}/nudge`)).statusCode).toBe(204);
    expect(push.sends.length).toBe(sent + 1);
    expect((await feedOf(d)).nudges.map((n) => n.person.handle)).toEqual(['c63_nudger_two', 'c63_nudger']);
    // A week on, a nudge can go again.
    await sql`update community_nudges set at = now() - interval '8 days' where from_id = ${a.id}`;
    expect(personProfileSchema.parse((await call(a, 'GET', `/community/people/${d.id}`)).json()).nudge).toBe('can');
  });

  it('beta 6.3 (C16): friends of friends and club-mates, a count only; opt-out, asked, blocked and dismissed people are not suggested', async () => {
    const a = await member('c63_me');
    const b = await member('c63_bridge');
    const x = await member('c63_fof');
    const y = await member('c63_mate');
    const z = await member('c63_private');
    const w = await member('c63_asked');
    await friends(a, b, 'c63_bridge');
    await friends(b, x, 'c63_fof');
    await friends(b, z, 'c63_private');
    await friends(b, w, 'c63_asked');
    await call(z, 'PATCH', '/community/me', { suggest: false });
    await call(a, 'POST', '/community/friends', { handle: 'c63_asked' });
    const club = clubSchema.parse((await call(y, 'POST', '/community/clubs', { name: 'C63 Gym' })).json());
    await call(a, 'POST', '/community/clubs/join', { code: club.code });
    await call(x, 'POST', '/community/clubs/join', { code: club.code });

    const got = suggestionListSchema.parse((await call(a, 'GET', '/community/suggestions')).json()).items;
    expect(got.map((s) => [s.person.handle, s.mutualFriends, s.club])).toEqual([
      ['c63_fof', 1, 'C63 Gym'],
      ['c63_mate', 0, 'C63 Gym'],
    ]);
    // Never which friends.
    expect(JSON.stringify(got)).not.toContain('c63_bridge');
    expect((await call(a, 'DELETE', `/community/suggestions/${y.id}`)).statusCode).toBe(204);
    expect((await call(a, 'DELETE', `/community/suggestions/${a.id}`)).statusCode).toBe(404);
    await call(x, 'POST', '/community/blocks', { userId: a.id });
    expect(suggestionListSchema.parse((await call(a, 'GET', '/community/suggestions')).json()).items).toEqual([]);
    // The dismissed person never learns of it.
    expect(JSON.stringify((await call(y, 'POST', '/user/export')).json())).not.toContain('community_suggestion_dismissals');
  });

  it('beta 6.3 (C13): month and all-time boards; all time counts from joining; the podium is for weeks', async () => {
    const a = await member('c63_periods');
    await session(a, 6, 20);
    await session(a, 6, 20, 15);
    await session(a, 6, 20, 25);
    await sql`update community_profiles set created_at = now() - interval '20 days' where user_id = ${a.id}`;
    const all = await board(a, '/community/boards/friends?period=all');
    expect(all).toMatchObject({ period: 'all', periodFrom: localDateOf(new Date(Date.now() - 20 * 86_400_000), 'Asia/Kolkata'), periodTo: today(), lastWeek: null });
    expect(all.rows[0]).toMatchObject({ sessions: 2, activeDays: 2 });
    const month = await board(a, '/community/boards/friends?period=month');
    const first = `${today().slice(0, 7)}-01`;
    const inMonth = [0, 15].filter((d) => localDateOf(new Date(Date.now() - d * 86_400_000), 'Asia/Kolkata') >= first).length;
    expect(month).toMatchObject({ period: 'month', periodFrom: first });
    expect(month.rows[0]!.sessions).toBe(inMonth + (localDateOf(new Date(Date.now() - 25 * 86_400_000), 'Asia/Kolkata') >= first ? 1 : 0));
    expect((await board(a, '/community/boards/friends')).period).toBe('week');
    expect((await call(a, 'GET', '/community/boards/friends?period=year')).statusCode).toBe(422);
    // The world board by period.
    await call(a, 'PATCH', '/community/me', { onWorld: true });
    const world = await board(a, '/community/boards/world?period=all');
    expect(world.period).toBe('all');
  });

  it('beta 6.3: leaving takes posts, kudos given, nudges and period counts with it', async () => {
    const a = await member('c63_leaver');
    const b = await member('c63_stayer');
    await friends(a, b, 'c63_stayer');
    await call(b, 'PATCH', '/community/me', { feed: ['session'] });
    await session(b, 6, 20);
    await board(b, '/community/boards/friends');
    await call(a, 'POST', `/community/feed/${(await feedOf(a)).items[0]!.id}/kudos`);
    await call(a, 'PATCH', '/community/me', { feed: ['session'] });
    await sql`insert into community_nudges (from_id, to_id) values (${a.id}, ${b.id})`;
    expect((await call(a, 'DELETE', '/community/me')).statusCode).toBe(204);
    for (const [table, col] of [['community_posts', 'user_id'], ['community_kudos', 'giver_id'], ['community_nudges', 'from_id'], ['community_period_stats', 'user_id']] as const) {
      expect((await sql`select 1 from ${sql(table)} where ${sql(col)} = ${a.id}`).length, table).toBe(0);
    }
  });
});
