/**
 * Community (beta 5.8, ADR-057): members, friendships, blocks, clubs,
 * reports and the week's counts. Every read of another person passes the
 * visibility rule: a member, not hidden by the admin, and no block either way.
 */
import { and, asc, desc, eq, gte, inArray, or, sql, type AnyColumn, type SQL } from 'drizzle-orm';
import type { BoardMetricKey } from '@fitos/core/community/board';

import type { DatabaseHandle } from '../../db/client.js';
import {
  auditLogs,
  clubBans,
  clubMembers,
  clubs,
  communityBlocks,
  communityProfiles,
  communityReports,
  communityWeekHistory,
  communityWeekStats,
  friendDeclines,
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
  /** Beta 6.2 (C11). */
  activeDays: number;
  keptPct: number | null;
}

/** Beta 6.2: one person's counts for one week, as stored. */
export interface WeekRow {
  weekFrom: string;
  sessions: number;
  runM: number;
  streak: number;
  activeDays: number;
  planned: number | null;
}

/** Sessions done of planned, in per cent (core keptPlanPct, in SQL). */
const keptPctOf = (sessions: AnyColumn, planned: AnyColumn): SQL<number | null> =>
  sql<number | null>`case when ${planned} is null or ${planned} <= 0 then null
    else round(100.0 * least(greatest(${sessions}, 0), ${planned}) / ${planned})::int end`;

/** Beta 6.2: the world board's order for a metric (core boardKey, in SQL). */
function worldKey(metric: BoardMetricKey): SQL[] {
  const s = sql`${communityWeekStats.sessions}`;
  const m = sql`${communityWeekStats.runM}`;
  const k = sql`${communityWeekStats.streak}`;
  const d = sql`${communityWeekStats.activeDays}`;
  const p = sql`coalesce(${keptPctOf(communityWeekStats.sessions, communityWeekStats.planned)}, -1)`;
  switch (metric) {
    case 'sessions':
      return [s, m, k];
    case 'distance':
      return [m, s, k];
    case 'streak':
      return [k, s, m];
    case 'active-days':
      return [d, s, m];
    case 'plan':
      return [p, s, k];
  }
}

/** The viewer's own values in [worldKey]'s order. */
function worldKeyOf(metric: BoardMetricKey, r: StatRow): number[] {
  switch (metric) {
    case 'sessions':
      return [r.sessions, r.runM, r.streak];
    case 'distance':
      return [r.runM, r.sessions, r.streak];
    case 'streak':
      return [r.streak, r.sessions, r.runM];
    case 'active-days':
      return [r.activeDays, r.sessions, r.runM];
    case 'plan':
      return [r.keptPct ?? -1, r.sessions, r.streak];
  }
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
    await this.db.delete(communityWeekHistory).where(eq(communityWeekHistory.userId, userId));
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

  /** Beta 6.2 (S7): the addressee declined the requester's request. */
  async recordDecline(requester: string, addressee: string): Promise<void> {
    await this.db
      .insert(friendDeclines)
      .values({ requesterId: requester, addresseeId: addressee })
      .onConflictDoUpdate({ target: [friendDeclines.requesterId, friendDeclines.addresseeId], set: { declinedAt: new Date() } });
  }

  async declinedSince(requester: string, addressee: string, since: Date): Promise<boolean> {
    const [r] = await this.db
      .select({ one: sql<number>`1` })
      .from(friendDeclines)
      .where(and(eq(friendDeclines.requesterId, requester), eq(friendDeclines.addresseeId, addressee), gte(friendDeclines.declinedAt, since)))
      .limit(1);
    return r !== undefined;
  }

  async clearDeclines(a: string, b: string): Promise<void> {
    await this.db
      .delete(friendDeclines)
      .where(
        or(
          and(eq(friendDeclines.requesterId, a), eq(friendDeclines.addresseeId, b)),
          and(eq(friendDeclines.requesterId, b), eq(friendDeclines.addresseeId, a)),
        ),
      );
  }

  /** Beta 6.2 (C4): clubs both are in. */
  async clubsInCommon(a: string, b: string): Promise<{ id: string; name: string }[]> {
    return this.db
      .select({ id: clubs.id, name: clubs.name })
      .from(clubs)
      .where(
        and(
          sql`exists (select 1 from ${clubMembers} m where m.club_id = ${clubs.id} and m.user_id = ${a})`,
          sql`exists (select 1 from ${clubMembers} m where m.club_id = ${clubs.id} and m.user_id = ${b})`,
        ),
      )
      .orderBy(asc(clubs.name));
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

  /* ------------------------------------------------- beta 6.2: the owner -- */

  async renameClub(clubId: string, name: string): Promise<void> {
    await this.db.update(clubs).set({ name }).where(eq(clubs.id, clubId));
  }

  /** False when the code was taken meanwhile. */
  async setClubCode(clubId: string, code: string): Promise<boolean> {
    const taken = await this.db.select({ id: clubs.id }).from(clubs).where(eq(clubs.code, code)).limit(1);
    if (taken.length > 0) return false;
    try {
      await this.db.update(clubs).set({ code }).where(eq(clubs.id, clubId));
      return true;
    } catch (e) {
      if (String((e as { code?: string }).code) === '23505') return false;
      throw e;
    }
  }

  async setClubOwner(clubId: string, userId: string): Promise<void> {
    await this.db.update(clubs).set({ ownerId: userId }).where(eq(clubs.id, clubId));
  }

  /** Out of the club, and kept out until let back (owner Q2). */
  async removeFromClub(clubId: string, userId: string): Promise<void> {
    await this.db.delete(clubMembers).where(and(eq(clubMembers.clubId, clubId), eq(clubMembers.userId, userId)));
    await this.db.insert(clubBans).values({ clubId, userId }).onConflictDoNothing();
  }

  async letBack(clubId: string, userId: string): Promise<boolean> {
    return (await this.db.delete(clubBans).where(and(eq(clubBans.clubId, clubId), eq(clubBans.userId, userId))).returning()).length > 0;
  }

  async isBanned(clubId: string, userId: string): Promise<boolean> {
    const [r] = await this.db
      .select({ one: sql<number>`1` })
      .from(clubBans)
      .where(and(eq(clubBans.clubId, clubId), eq(clubBans.userId, userId)))
      .limit(1);
    return r !== undefined;
  }

  /** The people removed from a club who are still in Community, by handle. */
  async removedFrom(clubId: string): Promise<PersonRow[]> {
    return this.db
      .select(person)
      .from(clubBans)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, clubBans.userId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(eq(clubBans.clubId, clubId))
      .orderBy(asc(communityProfiles.handle));
  }

  /* --------------------------------------------------------------- boards -- */

  private statSelect = {
    ...person,
    sessions: sql<number>`coalesce(${communityWeekStats.sessions}, 0)::int`,
    runM: sql<number>`coalesce(${communityWeekStats.runM}, 0)::int`,
    streak: sql<number>`coalesce(${communityWeekStats.streak}, 0)::int`,
    activeDays: sql<number>`coalesce(${communityWeekStats.activeDays}, 0)::int`,
    keptPct: keptPctOf(communityWeekStats.sessions, communityWeekStats.planned),
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
  async worldBoard(viewer: string, metric: BoardMetricKey, country: string | null, limit: number): Promise<{ rows: StatRow[]; total: number; me: (StatRow & { rank: number }) | null }> {
    const key = worldKey(metric);
    // On it: something counted this week (the plan board: a plan and a session).
    const where = and(
      eq(communityProfiles.onWorld, true),
      eq(communityProfiles.hidden, false),
      country === null ? undefined : eq(communityProfiles.country, country),
      metric === 'plan' ? sql`${communityWeekStats.planned} > 0 and ${communityWeekStats.sessions} > 0` : sql`${key[0]} > 0`,
    );
    const order = [...key.map((k) => sql`${k} desc`), asc(communityProfiles.handle)];
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
        const mineKey = worldKeyOf(metric, mine);
        const ahead = sql`(${sql.join(key, sql`, `)}) > (${sql.join(mineKey.map((v) => sql`${v}`), sql`, `)})`;
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
    return Math.min(7, (await this.sessionDays(userId, tz, weekFrom, '9999-12-31', minSets, minSeconds)).length);
  }

  /** Beta 6.2: the local days with a counted session, from `from` to `to`. */
  private async sessionDays(userId: string, tz: string, from: string, to: string, minSets: number, minSeconds: number): Promise<string[]> {
    const rows = await this.db.execute<{ d: string }>(sql`
      select distinct ((ws.completed_at at time zone ${tz})::date)::text as d
      from workout_sessions ws
      where ws.user_id = ${userId}
        and ws.status = 'completed'
        and ws.deleted_at is null
        and ws.completed_at is not null
        and (ws.completed_at at time zone ${tz})::date between ${from}::date and ${to}::date
        and coalesce(ws.duration_seconds, extract(epoch from ws.completed_at - ws.started_at)) >= ${minSeconds}
        and (select count(*) from set_logs sl join session_exercises se on se.id = sl.session_exercise_id
             where se.session_id = ws.id and se.removed_at is null and sl.deleted_at is null and sl.reps > 0) >= ${minSets}`);
    return [...rows].map((r) => r.d);
  }

  /** Beta 6.2: the local days with counted runs and their metres, from `from` to `to`. */
  private async runDays(userId: string, tz: string, from: string, to: string, minM: number, fastest: number, slowest: number): Promise<{ d: string; m: number }[]> {
    const rows = await this.db.execute<{ d: string; m: number }>(sql`
      select ((r.started_at at time zone ${tz})::date)::text as d, sum(r.distance_m)::int as m
      from runs r
      where r.user_id = ${userId}
        and (r.started_at at time zone ${tz})::date between ${from}::date and ${to}::date
        and r.distance_m >= ${minM}
        and (r.source = 'watch' or (r.kind = 'outdoor' and r.track_points is not null))
        and r.duration_seconds > 0
        and coalesce(r.avg_pace_sec_per_km, r.duration_seconds / (r.distance_m / 1000)) between ${fastest} and ${slowest}
      group by 1`);
    return [...rows];
  }

  /**
   * Beta 6.2: a week's counted sessions, run metres and active days (a day
   * with either), from `from` to `to`.
   */
  async weekCounts(
    userId: string,
    tz: string,
    from: string,
    to: string,
    session: { minSets: number; minSeconds: number },
    run: { minM: number; fastestSecPerKm: number; slowestSecPerKm: number },
  ): Promise<{ sessions: number; runM: number; activeDays: number }> {
    const [s, r] = await Promise.all([
      this.sessionDays(userId, tz, from, to, session.minSets, session.minSeconds),
      this.runDays(userId, tz, from, to, run.minM, run.fastestSecPerKm, run.slowestSecPerKm),
    ]);
    const days = new Set([...s, ...r.map((x) => x.d)]);
    return { sessions: Math.min(7, s.length), runM: r.reduce((n, x) => n + x.m, 0), activeDays: Math.min(7, days.size) };
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

  async saveStats(userId: string, weekFrom: string, sessions: number, runM: number, streak: number, activeDays = 0, planned: number | null = null): Promise<void> {
    await this.db
      .insert(communityWeekStats)
      .values({ userId, weekFrom, sessions, runM, streak, activeDays, planned })
      .onConflictDoUpdate({ target: communityWeekStats.userId, set: { weekFrom, sessions, runM, streak, activeDays, planned, updatedAt: new Date() } });
  }

  /** Beta 6.2: the stored counts for this person's current week, or null. */
  async stats(userId: string): Promise<WeekRow | null> {
    const [r] = await this.db
      .select({
        weekFrom: communityWeekStats.weekFrom,
        sessions: communityWeekStats.sessions,
        runM: communityWeekStats.runM,
        streak: communityWeekStats.streak,
        activeDays: communityWeekStats.activeDays,
        planned: communityWeekStats.planned,
      })
      .from(communityWeekStats)
      .where(eq(communityWeekStats.userId, userId))
      .limit(1);
    return r ?? null;
  }

  /** Beta 6.2: a finished week, kept; only the newest `keep` weeks stay. */
  async saveHistory(userId: string, w: WeekRow, keep: number): Promise<void> {
    await this.db
      .insert(communityWeekHistory)
      .values({ userId, ...w })
      .onConflictDoUpdate({
        target: [communityWeekHistory.userId, communityWeekHistory.weekFrom],
        set: { sessions: w.sessions, runM: w.runM, streak: w.streak, activeDays: w.activeDays, planned: w.planned },
      });
    await this.db.execute(sql`
      delete from ${communityWeekHistory}
      where ${communityWeekHistory.userId} = ${userId}
        and ${communityWeekHistory.weekFrom} not in (
          select h.week_from from community_week_history h where h.user_id = ${userId} order by h.week_from desc limit ${keep})`);
  }

  /** Beta 6.2: stored past weeks for these people and weeks. */
  async history(userIds: readonly string[], weeks: readonly string[]): Promise<(WeekRow & { userId: string })[]> {
    if (userIds.length === 0 || weeks.length === 0) return [];
    return this.db
      .select({
        userId: communityWeekHistory.userId,
        weekFrom: communityWeekHistory.weekFrom,
        sessions: communityWeekHistory.sessions,
        runM: communityWeekHistory.runM,
        streak: communityWeekHistory.streak,
        activeDays: communityWeekHistory.activeDays,
        planned: communityWeekHistory.planned,
      })
      .from(communityWeekHistory)
      .where(and(inArray(communityWeekHistory.userId, [...userIds]), inArray(communityWeekHistory.weekFrom, [...weeks])));
  }

  /** Beta 6.2 (C12): the world board's people (who chose it, not hidden) in past weeks. */
  async worldHistory(country: string | null, weeks: readonly string[]): Promise<(PersonRow & WeekRow)[]> {
    if (weeks.length === 0) return [];
    return this.db
      .select({
        ...person,
        weekFrom: communityWeekHistory.weekFrom,
        sessions: communityWeekHistory.sessions,
        runM: communityWeekHistory.runM,
        streak: communityWeekHistory.streak,
        activeDays: communityWeekHistory.activeDays,
        planned: communityWeekHistory.planned,
      })
      .from(communityWeekHistory)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityWeekHistory.userId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(
        and(
          inArray(communityWeekHistory.weekFrom, [...weeks]),
          eq(communityProfiles.onWorld, true),
          eq(communityProfiles.hidden, false),
          country === null ? undefined : eq(communityProfiles.country, country),
        ),
      );
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
