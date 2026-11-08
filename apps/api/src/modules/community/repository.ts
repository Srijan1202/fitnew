/**
 * Community (beta 5.8, ADR-057): members, friendships, blocks, clubs,
 * reports and the week's counts. Every read of another person passes the
 * visibility rule: a member, not hidden by the admin, and no block either way.
 */
import { and, asc, desc, eq, inArray, or, sql, type AnyColumn } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  auditLogs,
  clubMembers,
  clubs,
  communityBlocks,
  communityProfiles,
  communityReports,
  communityWeekStats,
  consentRecords,
  friendships,
  pushTokens,
  users,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export type ProfileRow = typeof communityProfiles.$inferSelect;

/** A person as others see them, with their avatar. */
export interface PersonRow {
  userId: string;
  handle: string;
  avatarId: string | null;
  country: string | null;
}

/** One row of a board, before ranking. */
export interface StatRow extends PersonRow {
  sessions: number;
  runM: number;
  streak: number;
}

/** True when neither has blocked the other. */
const notBlocked = (viewer: string, other: AnyColumn) => sql`not exists (
  select 1 from ${communityBlocks}
  where (${communityBlocks.blockerId} = ${viewer} and ${communityBlocks.blockedId} = ${other})
     or (${communityBlocks.blockerId} = ${other} and ${communityBlocks.blockedId} = ${viewer}))`;

const person = {
  userId: communityProfiles.userId,
  handle: communityProfiles.handle,
  avatarId: users.avatarId,
  country: communityProfiles.country,
};

export class CommunityRepository {
  constructor(private readonly db: Db) {}

  async inTransaction<T>(fn: (repo: CommunityRepository) => Promise<T>): Promise<T> {
    return this.db.transaction(async (tx) => fn(new CommunityRepository(tx as unknown as Db)));
  }

  /* -------------------------------------------------------------- profile -- */

  async profile(userId: string): Promise<(ProfileRow & { avatarId: string | null }) | null> {
    const [r] = await this.db
      .select({ p: communityProfiles, avatarId: users.avatarId })
      .from(communityProfiles)
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(eq(communityProfiles.userId, userId))
      .limit(1);
    return r === undefined ? null : { ...r.p, avatarId: r.avatarId };
  }

  async handleOwner(handle: string): Promise<string | null> {
    const [r] = await this.db.select({ userId: communityProfiles.userId }).from(communityProfiles).where(eq(communityProfiles.handle, handle)).limit(1);
    return r?.userId ?? null;
  }

  /** Null when the handle was taken meanwhile (the unique index). */
  async insertProfile(userId: string, handle: string, country: string | null, onWorld: boolean): Promise<ProfileRow | null> {
    const [r] = await this.db.insert(communityProfiles).values({ userId, handle, country, onWorld }).onConflictDoNothing().returning();
    return r ?? null;
  }

  async updateProfile(
    userId: string,
    patch: { handle?: string | undefined; country?: string | null | undefined; onWorld?: boolean | undefined; hidden?: boolean | undefined },
  ): Promise<void> {
    const set = Object.fromEntries(Object.entries(patch).filter(([, v]) => v !== undefined));
    await this.db.update(communityProfiles).set({ ...set, updatedAt: new Date() }).where(eq(communityProfiles.userId, userId));
  }

  async timezoneOf(userId: string): Promise<string> {
    const [u] = await this.db.select({ tz: users.timezone }).from(users).where(eq(users.id, userId)).limit(1);
    return u?.tz ?? 'Asia/Kolkata';
  }

  async recordConsent(userId: string, granted: boolean, policyVersion: string, ipHash: string | null): Promise<void> {
    await this.db.insert(consentRecords).values({ userId, consentType: 'community', granted, policyVersion, ipHash });
  }

  /**
   * Leaving: the profile, friendships, club places and counts go. A club this
   * person made passes to its longest member, or goes when it has none.
   * Blocks stay: they protect the blocker.
   */
  async leave(userId: string): Promise<void> {
    const owned = await this.db.select({ id: clubs.id }).from(clubs).where(eq(clubs.ownerId, userId));
    for (const c of owned) {
      const [heir] = await this.db
        .select({ userId: clubMembers.userId })
        .from(clubMembers)
        .where(and(eq(clubMembers.clubId, c.id), sql`${clubMembers.userId} <> ${userId}`))
        .orderBy(asc(clubMembers.joinedAt))
        .limit(1);
      if (heir === undefined) await this.db.delete(clubs).where(eq(clubs.id, c.id));
      else await this.db.update(clubs).set({ ownerId: heir.userId }).where(eq(clubs.id, c.id));
    }
    await this.db.delete(clubMembers).where(eq(clubMembers.userId, userId));
    await this.db.delete(friendships).where(or(eq(friendships.requesterId, userId), eq(friendships.addresseeId, userId)));
    await this.db.delete(communityWeekStats).where(eq(communityWeekStats.userId, userId));
    await this.db.delete(communityProfiles).where(eq(communityProfiles.userId, userId));
  }

  /* --------------------------------------------------------------- people -- */

  /** Another member the viewer may see, or null. */
  async visible(viewer: string, userId: string): Promise<PersonRow | null> {
    const [r] = await this.db
      .select(person)
      .from(communityProfiles)
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(and(eq(communityProfiles.userId, userId), eq(communityProfiles.hidden, false), notBlocked(viewer, communityProfiles.userId)))
      .limit(1);
    return r ?? null;
  }

  async visibleByHandle(viewer: string, handle: string): Promise<PersonRow | null> {
    const id = await this.handleOwner(handle);
    return id === null || id === viewer ? null : this.visible(viewer, id);
  }

  /** Handles starting with `prefix`, shortest first. */
  async search(viewer: string, prefix: string, limit: number): Promise<PersonRow[]> {
    const like = `${prefix.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    return this.db
      .select(person)
      .from(communityProfiles)
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(
        and(
          sql`${communityProfiles.handle} like ${like}`,
          sql`${communityProfiles.userId} <> ${viewer}`,
          eq(communityProfiles.hidden, false),
          notBlocked(viewer, communityProfiles.userId),
        ),
      )
      .orderBy(sql`length(${communityProfiles.handle})`, asc(communityProfiles.handle))
      .limit(limit);
  }

  /* ---------------------------------------------------------- friendships -- */

  async friendship(a: string, b: string): Promise<typeof friendships.$inferSelect | null> {
    const [r] = await this.db
      .select()
      .from(friendships)
      .where(
        or(
          and(eq(friendships.requesterId, a), eq(friendships.addresseeId, b)),
          and(eq(friendships.requesterId, b), eq(friendships.addresseeId, a)),
        ),
      )
      .limit(1);
    return r ?? null;
  }

  async request(from: string, to: string): Promise<boolean> {
    const r = await this.db.insert(friendships).values({ requesterId: from, addresseeId: to }).onConflictDoNothing().returning();
    return r.length > 0;
  }

  async accept(requester: string, addressee: string): Promise<boolean> {
    const r = await this.db
      .update(friendships)
      .set({ status: 'accepted', acceptedAt: new Date() })
      .where(and(eq(friendships.requesterId, requester), eq(friendships.addresseeId, addressee), eq(friendships.status, 'pending')))
      .returning();
    return r.length > 0;
  }

  async unfriend(a: string, b: string): Promise<boolean> {
    const r = await this.db
      .delete(friendships)
      .where(
        or(
          and(eq(friendships.requesterId, a), eq(friendships.addresseeId, b)),
          and(eq(friendships.requesterId, b), eq(friendships.addresseeId, a)),
        ),
      )
      .returning();
    return r.length > 0;
  }

  async friendCount(userId: string): Promise<number> {
    const [r] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(friendships)
      .where(and(or(eq(friendships.requesterId, userId), eq(friendships.addresseeId, userId)), eq(friendships.status, 'accepted')));
    return r?.n ?? 0;
  }

  async incomingCount(userId: string): Promise<number> {
    const [r] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(friendships)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, friendships.requesterId))
      .where(and(eq(friendships.addresseeId, userId), eq(friendships.status, 'pending'), eq(communityProfiles.hidden, false)));
    return r?.n ?? 0;
  }

  /** Friends, requests to answer and requests waiting: visible people only, by handle. */
  async friendLists(viewer: string): Promise<{ friends: PersonRow[]; incoming: PersonRow[]; outgoing: PersonRow[] }> {
    const rows = await this.db
      .select({ ...person, requesterId: friendships.requesterId, status: friendships.status })
      .from(friendships)
      .innerJoin(
        communityProfiles,
        sql`${communityProfiles.userId} = case when ${friendships.requesterId} = ${viewer} then ${friendships.addresseeId} else ${friendships.requesterId} end`,
      )
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(
        and(
          or(eq(friendships.requesterId, viewer), eq(friendships.addresseeId, viewer)),
          eq(communityProfiles.hidden, false),
          notBlocked(viewer, communityProfiles.userId),
        ),
      )
      .orderBy(asc(communityProfiles.handle));
    const strip = ({ requesterId: _r, status: _s, ...p }: (typeof rows)[number]): PersonRow => p;
    return {
      friends: rows.filter((r) => r.status === 'accepted').map(strip),
      incoming: rows.filter((r) => r.status === 'pending' && r.requesterId !== viewer).map(strip),
      outgoing: rows.filter((r) => r.status === 'pending' && r.requesterId === viewer).map(strip),
    };
  }

  /* --------------------------------------------------------------- blocks -- */

  async block(blocker: string, blocked: string): Promise<void> {
    await this.db.insert(communityBlocks).values({ blockerId: blocker, blockedId: blocked }).onConflictDoNothing();
  }

  async unblock(blocker: string, blocked: string): Promise<void> {
    await this.db.delete(communityBlocks).where(and(eq(communityBlocks.blockerId, blocker), eq(communityBlocks.blockedId, blocked)));
  }

  /** Whom this person blocked, with their handle when they are still members. */
  async blocked(blocker: string): Promise<PersonRow[]> {
    return this.db
      .select(person)
      .from(communityBlocks)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityBlocks.blockedId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(eq(communityBlocks.blockerId, blocker))
      .orderBy(asc(communityProfiles.handle));
  }

  async blockedEitherWay(a: string, b: string): Promise<boolean> {
    const [r] = await this.db
      .select({ one: sql<number>`1` })
      .from(communityBlocks)
      .where(
        or(
          and(eq(communityBlocks.blockerId, a), eq(communityBlocks.blockedId, b)),
          and(eq(communityBlocks.blockerId, b), eq(communityBlocks.blockedId, a)),
        ),
      )
      .limit(1);
    return r !== undefined;
  }

  /* ---------------------------------------------------------------- clubs -- */

  async clubsOf(userId: string) {
    return this.db
      .select({
        id: clubs.id,
        name: clubs.name,
        code: clubs.code,
        ownerId: clubs.ownerId,
        createdAt: clubs.createdAt,
        members: sql<number>`(select count(*)::int from ${clubMembers} m where m.club_id = ${clubs.id})`,
      })
      .from(clubMembers)
      .innerJoin(clubs, eq(clubs.id, clubMembers.clubId))
      .where(eq(clubMembers.userId, userId))
      .orderBy(asc(clubs.name));
  }

  async club(id: string) {
    const [r] = await this.db
      .select({
        id: clubs.id,
        name: clubs.name,
        code: clubs.code,
        ownerId: clubs.ownerId,
        createdAt: clubs.createdAt,
        members: sql<number>`(select count(*)::int from ${clubMembers} m where m.club_id = ${clubs.id})`,
      })
      .from(clubs)
      .where(eq(clubs.id, id))
      .limit(1);
    return r ?? null;
  }

  async clubByCode(code: string) {
    const [r] = await this.db.select({ id: clubs.id }).from(clubs).where(eq(clubs.code, code)).limit(1);
    return r === undefined ? null : this.club(r.id);
  }

  async ownedCount(userId: string): Promise<number> {
    const [r] = await this.db.select({ n: sql<number>`count(*)::int` }).from(clubs).where(eq(clubs.ownerId, userId));
    return r?.n ?? 0;
  }

  async joinedCount(userId: string): Promise<number> {
    const [r] = await this.db.select({ n: sql<number>`count(*)::int` }).from(clubMembers).where(eq(clubMembers.userId, userId));
    return r?.n ?? 0;
  }

  async isMember(clubId: string, userId: string): Promise<boolean> {
    const [r] = await this.db
      .select({ one: sql<number>`1` })
      .from(clubMembers)
      .where(and(eq(clubMembers.clubId, clubId), eq(clubMembers.userId, userId)))
      .limit(1);
    return r !== undefined;
  }

  /** Null when the code was taken meanwhile. */
  async createClub(ownerId: string, name: string, code: string): Promise<string | null> {
    const [r] = await this.db.insert(clubs).values({ ownerId, name, code }).onConflictDoNothing().returning({ id: clubs.id });
    if (r === undefined) return null;
    await this.db.insert(clubMembers).values({ clubId: r.id, userId: ownerId });
    return r.id;
  }

  async joinClub(clubId: string, userId: string): Promise<void> {
    await this.db.insert(clubMembers).values({ clubId, userId }).onConflictDoNothing();
  }

  async leaveClub(clubId: string, userId: string): Promise<void> {
    const c = await this.club(clubId);
    if (c === null) return;
    await this.db.delete(clubMembers).where(and(eq(clubMembers.clubId, clubId), eq(clubMembers.userId, userId)));
    if (c.ownerId !== userId) return;
    const [heir] = await this.db.select({ userId: clubMembers.userId }).from(clubMembers).where(eq(clubMembers.clubId, clubId)).orderBy(asc(clubMembers.joinedAt)).limit(1);
    if (heir === undefined) await this.db.delete(clubs).where(eq(clubs.id, clubId));
    else await this.db.update(clubs).set({ ownerId: heir.userId }).where(eq(clubs.id, clubId));
  }

  async deleteClub(clubId: string): Promise<boolean> {
    return (await this.db.delete(clubs).where(eq(clubs.id, clubId)).returning()).length > 0;
  }

  /* --------------------------------------------------------------- boards -- */

  private statSelect = {
    ...person,
    sessions: sql<number>`coalesce(${communityWeekStats.sessions}, 0)::int`,
    runM: sql<number>`coalesce(${communityWeekStats.runM}, 0)::int`,
    streak: sql<number>`coalesce(${communityWeekStats.streak}, 0)::int`,
  };

  /** The viewer and their friends. */
  async friendsBoard(viewer: string): Promise<StatRow[]> {
    return this.db
      .select(this.statSelect)
      .from(communityProfiles)
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .leftJoin(communityWeekStats, eq(communityWeekStats.userId, communityProfiles.userId))
      .where(
        or(
          eq(communityProfiles.userId, viewer),
          and(
            eq(communityProfiles.hidden, false),
            sql`exists (select 1 from ${friendships} f where f.status = 'accepted'
              and ((f.requester_id = ${viewer} and f.addressee_id = ${communityProfiles.userId})
                or (f.addressee_id = ${viewer} and f.requester_id = ${communityProfiles.userId})))`,
          ),
        ),
      );
  }

  /** A club's members the viewer may see (and the viewer). */
  async clubBoard(viewer: string, clubId: string): Promise<StatRow[]> {
    return this.db
      .select(this.statSelect)
      .from(clubMembers)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, clubMembers.userId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .leftJoin(communityWeekStats, eq(communityWeekStats.userId, communityProfiles.userId))
      .where(
        and(
          eq(clubMembers.clubId, clubId),
          or(eq(communityProfiles.userId, viewer), and(eq(communityProfiles.hidden, false), notBlocked(viewer, communityProfiles.userId))),
        ),
      );
  }

  /**
   * The world board (or a country's): members who chose to be on it, with a
   * count this week, best first. One indexed read of the counts table.
   */
  async worldBoard(viewer: string, metric: 'sessions' | 'distance', country: string | null, limit: number): Promise<{ rows: StatRow[]; total: number; me: (StatRow & { rank: number }) | null }> {
    const where = and(
      eq(communityProfiles.onWorld, true),
      eq(communityProfiles.hidden, false),
      country === null ? undefined : eq(communityProfiles.country, country),
      metric === 'sessions' ? sql`${communityWeekStats.sessions} > 0` : sql`${communityWeekStats.runM} > 0`,
    );
    const order =
      metric === 'sessions'
        ? [desc(communityWeekStats.sessions), desc(communityWeekStats.runM), desc(communityWeekStats.streak), asc(communityProfiles.handle)]
        : [desc(communityWeekStats.runM), desc(communityWeekStats.sessions), desc(communityWeekStats.streak), asc(communityProfiles.handle)];
    const rows = await this.db
      .select(this.statSelect)
      .from(communityWeekStats)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityWeekStats.userId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(and(where, notBlocked(viewer, communityProfiles.userId)))
      .orderBy(...order)
      .limit(limit);
    const [count] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(communityWeekStats)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityWeekStats.userId))
      .where(where);
    let me: (StatRow & { rank: number }) | null = null;
    if (!rows.some((r) => r.userId === viewer)) {
      const [mine] = await this.db
        .select(this.statSelect)
        .from(communityWeekStats)
        .innerJoin(communityProfiles, eq(communityProfiles.userId, communityWeekStats.userId))
        .innerJoin(users, eq(users.id, communityProfiles.userId))
        .where(and(where, eq(communityProfiles.userId, viewer)))
        .limit(1);
      if (mine !== undefined) {
        const ahead =
          metric === 'sessions'
            ? sql`(${communityWeekStats.sessions}, ${communityWeekStats.runM}, ${communityWeekStats.streak}) > (${mine.sessions}, ${mine.runM}, ${mine.streak})`
            : sql`(${communityWeekStats.runM}, ${communityWeekStats.sessions}, ${communityWeekStats.streak}) > (${mine.runM}, ${mine.sessions}, ${mine.streak})`;
        const [above] = await this.db
          .select({ n: sql<number>`count(*)::int` })
          .from(communityWeekStats)
          .innerJoin(communityProfiles, eq(communityProfiles.userId, communityWeekStats.userId))
          .where(and(where, ahead));
        me = { ...mine, rank: (above?.n ?? 0) + 1 };
      }
    }
    return { rows, total: count?.n ?? 0, me };
  }

  /* --------------------------------------------------------- week counts -- */

  /** Every member, for the refresher. */
  async memberIds(): Promise<string[]> {
    return (await this.db.select({ id: communityProfiles.userId }).from(communityProfiles)).map((r) => r.id);
  }

  /**
   * Gym sessions that count (ADR-057): completed, at least `minSets` sets and
   * `minSeconds` long, at most one a local day, from `weekFrom` in `tz`.
   */
  async countedSessions(userId: string, tz: string, weekFrom: string, minSets: number, minSeconds: number): Promise<number> {
    const [r] = await this.db.execute<{ n: number }>(sql`
      select count(distinct (ws.completed_at at time zone ${tz})::date)::int as n
      from workout_sessions ws
      where ws.user_id = ${userId}
        and ws.status = 'completed'
        and ws.deleted_at is null
        and ws.completed_at is not null
        and (ws.completed_at at time zone ${tz})::date >= ${weekFrom}::date
        and coalesce(ws.duration_seconds, extract(epoch from ws.completed_at - ws.started_at)) >= ${minSeconds}
        and (select count(*) from set_logs sl join session_exercises se on se.id = sl.session_exercise_id
             where se.session_id = ws.id and se.removed_at is null and sl.deleted_at is null and sl.reps > 0) >= ${minSets}`);
    return Math.min(7, r?.n ?? 0);
  }

  /**
   * Run metres that count (ADR-057): GPS or watch, at least `minM`, at a
   * human pace; a phone treadmill run (typed in) never counts.
   */
  async countedRunM(userId: string, tz: string, weekFrom: string, minM: number, fastest: number, slowest: number): Promise<number> {
    const [r] = await this.db.execute<{ m: number }>(sql`
      select coalesce(sum(r.distance_m), 0)::int as m
      from runs r
      where r.user_id = ${userId}
        and (r.started_at at time zone ${tz})::date >= ${weekFrom}::date
        and r.distance_m >= ${minM}
        and (r.source = 'watch' or (r.kind = 'outdoor' and r.track_points is not null))
        and r.duration_seconds > 0
        and coalesce(r.avg_pace_sec_per_km, r.duration_seconds / (r.distance_m / 1000)) between ${fastest} and ${slowest}`);
    return r?.m ?? 0;
  }

  async saveStats(userId: string, weekFrom: string, sessions: number, runM: number, streak: number): Promise<void> {
    await this.db
      .insert(communityWeekStats)
      .values({ userId, weekFrom, sessions, runM, streak })
      .onConflictDoUpdate({ target: communityWeekStats.userId, set: { weekFrom, sessions, runM, streak, updatedAt: new Date() } });
  }

  /* -------------------------------------------------------------- reports -- */

  async report(reporterId: string, target: { userId?: string; clubId?: string }, reason: string, note: string | null): Promise<void> {
    await this.db.insert(communityReports).values({ reporterId, targetUserId: target.userId ?? null, clubId: target.clubId ?? null, reason, note });
  }

  async reports(status: 'open' | 'closed') {
    const reporter = sql<string | null>`(select p.handle from ${communityProfiles} p where p.user_id = ${communityReports.reporterId})`;
    return this.db
      .select({
        id: communityReports.id,
        reason: communityReports.reason,
        note: communityReports.note,
        status: communityReports.status,
        createdAt: communityReports.createdAt,
        reporterHandle: reporter,
        targetUserId: communityReports.targetUserId,
        targetHandle: communityProfiles.handle,
        targetHidden: communityProfiles.hidden,
        clubId: communityReports.clubId,
        clubName: clubs.name,
      })
      .from(communityReports)
      .leftJoin(communityProfiles, eq(communityProfiles.userId, communityReports.targetUserId))
      .leftJoin(clubs, eq(clubs.id, communityReports.clubId))
      .where(eq(communityReports.status, status))
      .orderBy(desc(communityReports.createdAt))
      .limit(200);
  }

  async closeReport(id: string, actor: string | null): Promise<boolean> {
    const r = await this.db
      .update(communityReports)
      .set({ status: 'closed', closedAt: new Date(), closedBy: actor })
      .where(and(eq(communityReports.id, id), eq(communityReports.status, 'open')))
      .returning();
    return r.length > 0;
  }

  /* ---------------------------------------------------------------- admin -- */

  async members(q: string | undefined) {
    const where = q === undefined || q === '' ? undefined : sql`${communityProfiles.handle} like ${`%${q.toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`)}%`}`;
    const items = await this.db.select().from(communityProfiles).where(where).orderBy(desc(communityProfiles.createdAt)).limit(200);
    const [count] = await this.db.select({ n: sql<number>`count(*)::int` }).from(communityProfiles);
    return { items, total: count?.n ?? 0 };
  }

  async allClubs() {
    return this.db
      .select({
        id: clubs.id,
        name: clubs.name,
        createdAt: clubs.createdAt,
        ownerHandle: communityProfiles.handle,
        members: sql<number>`(select count(*)::int from ${clubMembers} m where m.club_id = ${clubs.id})`,
      })
      .from(clubs)
      .leftJoin(communityProfiles, eq(communityProfiles.userId, clubs.ownerId))
      .orderBy(desc(clubs.createdAt))
      .limit(200);
  }

  async audit(row: typeof auditLogs.$inferInsert): Promise<void> {
    await this.db.insert(auditLogs).values(row);
  }

  async pushTokens(userId: string): Promise<string[]> {
    return (await this.db.select({ token: pushTokens.token }).from(pushTokens).where(eq(pushTokens.userId, userId))).map((r) => r.token);
  }

  async removeTokens(tokens: readonly string[]): Promise<void> {
    if (tokens.length > 0) await this.db.delete(pushTokens).where(inArray(pushTokens.token, [...tokens]));
  }
}
