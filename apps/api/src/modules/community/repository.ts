/**
 * Community (beta 5.8, ADR-057): members, friendships, blocks, clubs,
 * reports and the week's counts. Every read of another person passes the
 * visibility rule: a member, not hidden by the admin, and no block either way.
 */
import { and, asc, desc, eq, gte, inArray, lt, or, sql, type AnyColumn, type SQL } from 'drizzle-orm';
import type { BoardMetricKey } from '@fitos/core/community/board';
import { CLUB_FEED_FROM_POLICY, type BoardPeriod } from '@fitos/core/community/feed';

import type { DatabaseHandle } from '../../db/client.js';
import { uniqueViolationOf } from '../../db/errors.js';
import {
  auditLogs,
  clubBans,
  clubChallengeParts,
  clubChallenges,
  clubMatches,
  clubMembers,
  clubs,
  communityBlocks,
  communityKudos,
  communityNudges,
  communityPeriodStats,
  communityPosts,
  communityProfiles,
  communityReports,
  communitySuggestionDismissals,
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
export type ChallengeRow = typeof clubChallenges.$inferSelect;
export type MatchRow = typeof clubMatches.$inferSelect & { homeName: string; awayName: string; homeOwnerId: string; awayOwnerId: string };

/** Beta 6.5 (K3): a week-count column, by metric (a fixed list, never user text). */
const WEEK_COLUMN: Record<string, string> = { sessions: 'sessions', distance: 'run_m', 'active-days': 'active_days' };

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
  const s = sql`${communityPeriodStats.sessions}`;
  const m = sql`${communityPeriodStats.runM}`;
  const k = sql`${communityPeriodStats.streak}`;
  const d = sql`${communityPeriodStats.activeDays}`;
  const p = sql`coalesce(${keptPctOf(communityPeriodStats.sessions, communityPeriodStats.planned)}, -1)`;
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
const notBlocked = (viewer: string, other: AnyColumn | SQL) => sql`not exists (
  select 1 from ${communityBlocks}
  where (${communityBlocks.blockerId} = ${viewer} and ${communityBlocks.blockedId} = ${other})
     or (${communityBlocks.blockerId} = ${other} and ${communityBlocks.blockedId} = ${viewer}))`;

const person = {
  userId: communityProfiles.userId,
  handle: communityProfiles.handle,
  avatarId: users.avatarId,
  country: communityProfiles.country,
};

/** Beta 6.3: when a run finished (a post is about a run done, not begun). */
const RUN_END = sql`coalesce(r.ended_at, r.started_at + make_interval(secs => r.duration_seconds))`;

/** Beta 6.3: the share kind a post belongs to (both records are `record`). */
const shareKindOf = (kind: AnyColumn | SQL) => sql`(case when ${kind} in ('lift-record', 'run-record') then 'record' else ${kind} end)`;

/**
 * Beta 6.5 (K1, owner Q1): a post `p` its author's club `m` may see: from
 * after they joined it and after they agreed to the policy that says clubs
 * see the feed (CLUB_FEED_FROM_POLICY or later).
 */
const inClubFeed = sql`p.at >= m.joined_at
  and exists (select 1 from consent_records c where c.user_id = p.user_id and c.granted
        and c.policy_version >= ${CLUB_FEED_FROM_POLICY} and c.granted_at <= p.at)`;

type PostDbRow = {
  id: string; user_id: string; handle: string; avatar_id: string | null; country: string | null;
  kind: string; title: string | null; value: number | null; at: Date; kudos: number; cheered: boolean;
};

const postRowOf = (r: PostDbRow): PostRow => ({
  id: r.id,
  userId: r.user_id,
  handle: r.handle,
  avatarId: r.avatar_id,
  country: r.country,
  kind: r.kind,
  title: r.title,
  value: r.value,
  at: new Date(r.at),
  kudos: r.kudos,
  cheered: r.cheered,
});

/** A post's columns as the feeds return them, with its cheers. */
const postColumns = (viewer: string) => sql`p.id, p.user_id, cp.handle, u.avatar_id, cp.country, p.kind, p.title, p.value, p.at,
  (select count(*)::int from community_kudos k where k.post_id = p.id) as kudos,
  exists (select 1 from community_kudos k where k.post_id = p.id and k.giver_id = ${viewer}) as cheered`;

/** Beta 6.3 (C1): a post as stored, with its author. */
export interface PostRow extends PersonRow {
  id: string;
  kind: string;
  title: string | null;
  value: number | null;
  at: Date;
  kudos: number;
  cheered: boolean;
}

/** Beta 6.3 (C16): a suggestion before it is shown. */
export interface SuggestionRow extends PersonRow {
  mutual: number;
  club: string | null;
}

/** Beta 6.3: what a counted event is, for a post. */
export interface EventRow {
  ref: string;
  title: string | null;
  value: number | null;
  at: Date;
}

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
    patch: {
      handle?: string | undefined;
      country?: string | null | undefined;
      onWorld?: boolean | undefined;
      hidden?: boolean | undefined;
      feed?: string[] | undefined;
      feedSince?: Record<string, string> | undefined;
      feedDefaulted?: boolean | undefined;
      suggest?: boolean | undefined;
      notify?: boolean | undefined;
      kudosPushedOn?: string | undefined;
      nudgePushedOn?: string | undefined;
    },
  ): Promise<void> {
    const set = Object.fromEntries(Object.entries(patch).filter(([, v]) => v !== undefined));
    await this.db.update(communityProfiles).set({ ...set, updatedAt: new Date() }).where(eq(communityProfiles.userId, userId));
  }

  /**
   * Beta 6.5 (K0): when this person first agreed to `version` of the policy
   * or a later one (any purpose granted at it); null when they have not.
   */
  async agreedSince(userId: string, version: string): Promise<Date | null> {
    const [r] = await this.db
      .select({ at: sql<Date | null>`min(${consentRecords.grantedAt})` })
      .from(consentRecords)
      .where(and(eq(consentRecords.userId, userId), eq(consentRecords.granted, true), gte(consentRecords.policyVersion, version)));
    return r?.at === null || r?.at === undefined ? null : new Date(r.at);
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
    // Beta 6.3: posts (with their kudos), kudos given, nudges, dismissals and the period counts.
    await this.db.delete(communityPosts).where(eq(communityPosts.userId, userId));
    await this.db.delete(communityKudos).where(eq(communityKudos.giverId, userId));
    await this.db.delete(communityNudges).where(or(eq(communityNudges.fromId, userId), eq(communityNudges.toId, userId)));
    await this.db
      .delete(communitySuggestionDismissals)
      .where(or(eq(communitySuggestionDismissals.viewerId, userId), eq(communitySuggestionDismissals.dismissedId, userId)));
    await this.db.delete(communityPeriodStats).where(eq(communityPeriodStats.userId, userId));
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

  /** Beta 6.6 (L2): a club's co-owners, longest in the club first. */
  private coOwnersOf = sql<string[]>`coalesce((select array_agg(m2.user_id::text order by m2.joined_at) from club_members m2
      where m2.club_id = ${clubs.id} and m2.role = 'co-owner'), '{}'::text[])`;

  async clubsOf(userId: string) {
    return this.db
      .select({
        id: clubs.id,
        name: clubs.name,
        code: clubs.code,
        ownerId: clubs.ownerId,
        createdAt: clubs.createdAt,
        members: sql<number>`(select count(*)::int from ${clubMembers} m where m.club_id = ${clubs.id})`,
        coOwners: this.coOwnersOf,
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
        coOwners: this.coOwnersOf,
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
    // Beta 6.6 (L2): a co-owner first (the longest in the club), then the longest member.
    const [heir] = await this.db
      .select({ userId: clubMembers.userId })
      .from(clubMembers)
      .where(eq(clubMembers.clubId, clubId))
      .orderBy(sql`${clubMembers.role} = 'co-owner' desc`, asc(clubMembers.joinedAt))
      .limit(1);
    if (heir === undefined) await this.db.delete(clubs).where(eq(clubs.id, clubId));
    else await this.setClubOwner(clubId, heir.userId);
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
      if (uniqueViolationOf(e) !== null) return false;
      throw e;
    }
  }

  /** The new owner is no longer a co-owner; the old one stays a member. */
  async setClubOwner(clubId: string, userId: string): Promise<void> {
    await this.db.update(clubs).set({ ownerId: userId }).where(eq(clubs.id, clubId));
    await this.setRole(clubId, userId, 'member');
  }

  /** Beta 6.6 (L2): a member's role in a club. */
  async setRole(clubId: string, userId: string, role: 'member' | 'co-owner'): Promise<void> {
    await this.db.update(clubMembers).set({ role }).where(and(eq(clubMembers.clubId, clubId), eq(clubMembers.userId, userId)));
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

  /** Beta 6.3 (C13): boards read the period table (the week, the month, since joining). */
  private statSelect = {
    ...person,
    sessions: sql<number>`coalesce(${communityPeriodStats.sessions}, 0)::int`,
    runM: sql<number>`coalesce(${communityPeriodStats.runM}, 0)::int`,
    streak: sql<number>`coalesce(${communityPeriodStats.streak}, 0)::int`,
    activeDays: sql<number>`coalesce(${communityPeriodStats.activeDays}, 0)::int`,
    keptPct: keptPctOf(communityPeriodStats.sessions, communityPeriodStats.planned),
  };

  private periodJoin = (period: BoardPeriod) =>
    and(eq(communityPeriodStats.userId, communityProfiles.userId), eq(communityPeriodStats.period, period));

  /** The viewer and their friends. */
  async friendsBoard(viewer: string, period: BoardPeriod = 'week'): Promise<StatRow[]> {
    return this.db
      .select(this.statSelect)
      .from(communityProfiles)
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .leftJoin(communityPeriodStats, this.periodJoin(period))
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
  async clubBoard(viewer: string, clubId: string, period: BoardPeriod = 'week'): Promise<StatRow[]> {
    return this.db
      .select(this.statSelect)
      .from(clubMembers)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, clubMembers.userId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .leftJoin(communityPeriodStats, this.periodJoin(period))
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
  async worldBoard(
    viewer: string,
    metric: BoardMetricKey,
    country: string | null,
    limit: number,
    period: BoardPeriod = 'week',
  ): Promise<{ rows: StatRow[]; total: number; me: (StatRow & { rank: number }) | null }> {
    const key = worldKey(metric);
    // On it: something counted in the period (the plan board: a plan and a session).
    const where = and(
      eq(communityPeriodStats.period, period),
      eq(communityProfiles.onWorld, true),
      eq(communityProfiles.hidden, false),
      country === null ? undefined : eq(communityProfiles.country, country),
      metric === 'plan' ? sql`${communityPeriodStats.planned} > 0 and ${communityPeriodStats.sessions} > 0` : sql`${key[0]} > 0`,
    );
    const order = [...key.map((k) => sql`${k} desc`), asc(communityProfiles.handle)];
    const rows = await this.db
      .select(this.statSelect)
      .from(communityPeriodStats)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityPeriodStats.userId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(and(where, notBlocked(viewer, communityProfiles.userId)))
      .orderBy(...order)
      .limit(limit);
    const [count] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(communityPeriodStats)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityPeriodStats.userId))
      .where(where);
    let me: (StatRow & { rank: number }) | null = null;
    if (!rows.some((r) => r.userId === viewer)) {
      const [mine] = await this.db
        .select(this.statSelect)
        .from(communityPeriodStats)
        .innerJoin(communityProfiles, eq(communityProfiles.userId, communityPeriodStats.userId))
        .innerJoin(users, eq(users.id, communityProfiles.userId))
        .where(and(where, eq(communityProfiles.userId, viewer)))
        .limit(1);
      if (mine !== undefined) {
        const mineKey = worldKeyOf(metric, mine);
        const ahead = sql`(${sql.join(key, sql`, `)}) > (${sql.join(mineKey.map((v) => sql`${v}`), sql`, `)})`;
        const [above] = await this.db
          .select({ n: sql<number>`count(*)::int` })
          .from(communityPeriodStats)
          .innerJoin(communityProfiles, eq(communityProfiles.userId, communityPeriodStats.userId))
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
    const c = await this.periodCounts(userId, tz, from, to, session, run);
    return { sessions: Math.min(7, c.sessions), runM: c.runM, activeDays: Math.min(7, c.activeDays) };
  }

  /** Beta 6.3 (C13): the same counts for any stretch (a month, since joining), not capped at a week. */
  async periodCounts(
    userId: string,
    tz: string,
    from: string,
    to: string,
    session: { minSets: number; minSeconds: number },
    run: { minM: number; fastestSecPerKm: number; slowestSecPerKm: number },
  ): Promise<{ sessions: number; runM: number; activeDays: number; lastActive: string | null }> {
    const [s, r] = await Promise.all([
      this.sessionDays(userId, tz, from, to, session.minSets, session.minSeconds),
      this.runDays(userId, tz, from, to, run.minM, run.fastestSecPerKm, run.slowestSecPerKm),
    ]);
    const days = [...new Set([...s, ...r.map((x) => x.d)])].sort();
    return { sessions: s.length, runM: r.reduce((n, x) => n + x.m, 0), activeDays: days.length, lastActive: days.at(-1) ?? null };
  }

  /** Beta 6.3 (C13): one period's counts. */
  async savePeriod(
    userId: string,
    period: BoardPeriod,
    c: { periodFrom: string; sessions: number; runM: number; streak: number; activeDays: number; planned: number | null },
  ): Promise<void> {
    await this.db
      .insert(communityPeriodStats)
      .values({ userId, period, ...c })
      .onConflictDoUpdate({ target: [communityPeriodStats.userId, communityPeriodStats.period], set: { ...c, updatedAt: new Date() } });
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

  /* ------------------------------------------------- beta 6.3: the feed -- */

  /**
   * Counted sessions completed at or after `since` (the ADR-057 rules): the
   * day's name. The same rules as the boards, so a post never shows a session
   * the board would not count.
   */
  async sessionEvents(userId: string, since: Date, minSets: number, minSeconds: number): Promise<EventRow[]> {
    const rows = await this.db.execute<{ ref: string; title: string; at: Date }>(sql`
      select ws.id::text as ref, ws.name as title, ws.completed_at as at
      from workout_sessions ws
      where ws.user_id = ${userId}
        and ws.status = 'completed'
        and ws.deleted_at is null
        and ws.completed_at >= ${since.toISOString()}::timestamptz
        and coalesce(ws.duration_seconds, extract(epoch from ws.completed_at - ws.started_at)) >= ${minSeconds}
        and (select count(*) from set_logs sl join session_exercises se on se.id = sl.session_exercise_id
             where se.session_id = ws.id and se.removed_at is null and sl.deleted_at is null and sl.reps > 0) >= ${minSets}`);
    return [...rows].map((r) => ({ ref: r.ref, title: r.title.slice(0, 80), value: null, at: new Date(r.at) }));
  }

  /** Sessions completed at or after `since` with a record: the first lift's name, and how many more lifts. */
  async liftRecordEvents(userId: string, since: Date): Promise<EventRow[]> {
    const rows = await this.db.execute<{ ref: string; title: string; more: number; at: Date }>(sql`
      select ws.id::text as ref, ws.completed_at as at,
             (array_agg(e.name order by se.order_index))[1] as title,
             (count(distinct e.id) - 1)::int as more
      from workout_sessions ws
      join session_exercises se on se.session_id = ws.id and se.removed_at is null
      join exercises e on e.id = se.exercise_id
      where ws.user_id = ${userId}
        and ws.status = 'completed'
        and ws.deleted_at is null
        and ws.completed_at >= ${since.toISOString()}::timestamptz
        and exists (select 1 from set_logs sl where sl.session_exercise_id = se.id and sl.is_pr and sl.deleted_at is null and sl.reps > 0)
      group by ws.id, ws.completed_at`);
    return [...rows].map((r) => ({ ref: r.ref, title: r.title.slice(0, 80), value: r.more, at: new Date(r.at) }));
  }

  /** Counted runs finished at or after `since` (the ADR-057 rules): the metres. */
  async runEvents(userId: string, since: Date, minM: number, fastest: number, slowest: number): Promise<EventRow[]> {
    const rows = await this.db.execute<{ ref: string; m: number; at: Date }>(sql`
      select r.id::text as ref, r.distance_m::int as m, ${RUN_END} as at
      from runs r
      where r.user_id = ${userId}
        and ${RUN_END} >= ${since.toISOString()}::timestamptz
        and r.distance_m >= ${minM}
        and (r.source = 'watch' or (r.kind = 'outdoor' and r.track_points is not null))
        and r.duration_seconds > 0
        and coalesce(r.avg_pace_sec_per_km, r.duration_seconds / (r.distance_m / 1000)) between ${fastest} and ${slowest}`);
    return [...rows].map((r) => ({ ref: r.ref, title: null, value: r.m, at: new Date(r.at) }));
  }

  /**
   * Counted runs finished at or after `since` that set the person's best for a
   * distance (the earliest run wins a tie): the longest such distance.
   */
  async runRecordEvents(userId: string, since: Date, minM: number, fastest: number, slowest: number): Promise<EventRow[]> {
    const rows = await this.db.execute<{ ref: string; title: string; at: Date }>(sql`
      select r.id::text as ref, ${RUN_END} as at,
             (array_agg(be.key::text order by array_position(array['400m','1k','1mile','5k','10k','half','marathon'], be.key::text) desc))[1] as title
      from runs r
      join run_best_efforts be on be.run_id = r.id
      where r.user_id = ${userId}
        and ${RUN_END} >= ${since.toISOString()}::timestamptz
        and r.distance_m >= ${minM}
        and (r.source = 'watch' or (r.kind = 'outdoor' and r.track_points is not null))
        and r.duration_seconds > 0
        and coalesce(r.avg_pace_sec_per_km, r.duration_seconds / (r.distance_m / 1000)) between ${fastest} and ${slowest}
        and not exists (
          select 1 from run_best_efforts o join runs orun on orun.id = o.run_id
          where o.user_id = r.user_id and o.key = be.key and o.run_id <> r.id
            and (o.seconds < be.seconds or (o.seconds = be.seconds and orun.started_at < r.started_at)))
      group by r.id, r.started_at`);
    return [...rows].map((r) => ({ ref: r.ref, title: r.title, value: null, at: new Date(r.at) }));
  }

  /** New posts only (one per event). */
  async savePosts(userId: string, kind: string, events: readonly EventRow[]): Promise<void> {
    if (events.length === 0) return;
    await this.db
      .insert(communityPosts)
      .values(events.map((e) => ({ userId, kind, ref: e.ref, title: e.title, value: e.value, at: e.at })))
      .onConflictDoNothing();
  }

  /**
   * A person's posts that should no longer be: kinds no longer shared, and
   * posts whose session or run is gone (or no longer counts as one).
   */
  async prunePosts(userId: string, shared: readonly string[]): Promise<void> {
    const kinds = shared.length === 0 ? sql`array[]::text[]` : sql`array[${sql.join(shared.map((k) => sql`${k}`), sql`, `)}]::text[]`;
    await this.db.execute(sql`
      delete from community_posts p
      where p.user_id = ${userId}
        and (not (${shareKindOf(sql`p.kind`)} = any(${kinds}))
          or (p.kind in ('session', 'lift-record') and not exists (
                select 1 from workout_sessions ws where ws.id::text = p.ref and ws.deleted_at is null and ws.status = 'completed'))
          or (p.kind in ('run', 'run-record') and not exists (select 1 from runs r where r.id::text = p.ref)))`);
  }

  /** Posts older than `before`, for everyone (the hourly round). */
  async deleteOldPosts(before: Date): Promise<void> {
    await this.db.delete(communityPosts).where(lt(communityPosts.at, before));
  }

  /**
   * The viewer's feed: their own posts and friends' (visible, still sharing
   * the kind), from `since`, older than `before`, newest first.
   */
  async feed(viewer: string, since: Date, before: Date | null, limit: number): Promise<PostRow[]> {
    const rows = await this.db.execute<PostDbRow>(sql`
      select ${postColumns(viewer)}
      from community_posts p
      join community_profiles cp on cp.user_id = p.user_id
      join users u on u.id = p.user_id
      where p.at >= ${since.toISOString()}::timestamptz
        ${before === null ? sql`` : sql`and p.at < ${before.toISOString()}::timestamptz`}
        and ${shareKindOf(sql`p.kind`)} = any(cp.feed)
        and (p.user_id = ${viewer} or (
          cp.hidden = false
          and exists (select 1 from friendships f where f.status = 'accepted'
                and ((f.requester_id = ${viewer} and f.addressee_id = p.user_id) or (f.addressee_id = ${viewer} and f.requester_id = p.user_id)))
          and ${notBlocked(viewer, sql`p.user_id`)}))
      order by p.at desc, p.id
      limit ${limit}`);
    return [...rows].map(postRowOf);
  }

  /**
   * Beta 6.5 (K1): a club's feed: its members' posts (the kinds each shares)
   * the club may see, the viewer's own included; hidden and blocked people
   * left out. The caller checks the viewer is in the club.
   */
  async clubFeed(viewer: string, clubId: string, since: Date, before: Date | null, limit: number): Promise<PostRow[]> {
    const rows = await this.db.execute<PostDbRow>(sql`
      select ${postColumns(viewer)}
      from community_posts p
      join club_members m on m.club_id = ${clubId} and m.user_id = p.user_id
      join community_profiles cp on cp.user_id = p.user_id
      join users u on u.id = p.user_id
      where p.at >= ${since.toISOString()}::timestamptz
        ${before === null ? sql`` : sql`and p.at < ${before.toISOString()}::timestamptz`}
        and ${shareKindOf(sql`p.kind`)} = any(cp.feed)
        and ${inClubFeed}
        and (p.user_id = ${viewer} or (cp.hidden = false and ${notBlocked(viewer, sql`p.user_id`)}))
      order by p.at desc, p.id
      limit ${limit}`);
    return [...rows].map(postRowOf);
  }

  /** Who cheered these posts (visible members), newest first. */
  async cheerers(viewer: string, postIds: readonly string[]): Promise<(PersonRow & { postId: string })[]> {
    if (postIds.length === 0) return [];
    return this.db
      .select({ ...person, postId: communityKudos.postId })
      .from(communityKudos)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityKudos.giverId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(and(inArray(communityKudos.postId, [...postIds]), eq(communityProfiles.hidden, false), notBlocked(viewer, communityProfiles.userId)))
      .orderBy(desc(communityKudos.createdAt));
  }

  /** A friend's or a club-mate's post the viewer may see and cheer (not their own), or null. */
  async cheerablePost(viewer: string, postId: string): Promise<{ id: string; userId: string } | null> {
    const [r] = await this.db.execute<{ id: string; user_id: string }>(sql`
      select p.id, p.user_id
      from community_posts p
      join community_profiles cp on cp.user_id = p.user_id
      where p.id = ${postId}
        and p.user_id <> ${viewer}
        and cp.hidden = false
        and ${shareKindOf(sql`p.kind`)} = any(cp.feed)
        and (exists (select 1 from friendships f where f.status = 'accepted'
              and ((f.requester_id = ${viewer} and f.addressee_id = p.user_id) or (f.addressee_id = ${viewer} and f.requester_id = p.user_id)))
          or exists (select 1 from club_members m join club_members mv on mv.club_id = m.club_id and mv.user_id = ${viewer}
              where m.user_id = p.user_id and ${inClubFeed}))
        and ${notBlocked(viewer, sql`p.user_id`)}
      limit 1`);
    return r === undefined ? null : { id: r.id, userId: r.user_id };
  }

  async cheer(postId: string, giverId: string): Promise<void> {
    await this.db.insert(communityKudos).values({ postId, giverId }).onConflictDoNothing();
  }

  async uncheer(postId: string, giverId: string): Promise<void> {
    await this.db.delete(communityKudos).where(and(eq(communityKudos.postId, postId), eq(communityKudos.giverId, giverId)));
  }

  async kudosOf(postId: string, viewer: string): Promise<{ kudos: number; cheered: boolean }> {
    const [r] = await this.db.execute<{ kudos: number; cheered: boolean }>(sql`
      select count(*)::int as kudos, coalesce(bool_or(k.giver_id = ${viewer}), false) as cheered
      from community_kudos k where k.post_id = ${postId}`);
    return { kudos: r?.kudos ?? 0, cheered: r?.cheered ?? false };
  }

  /** Members with kudos not yet in a summary, with what the summary needs. */
  async kudosWaiting(): Promise<{ userId: string; tz: string; notify: boolean; pushedOn: string | null }[]> {
    const rows = await this.db.execute<{ user_id: string; tz: string | null; notify: boolean; pushed_on: string | null }>(sql`
      select distinct p.user_id, u.timezone as tz, cp.notify, cp.kudos_pushed_on as pushed_on
      from community_kudos k
      join community_posts p on p.id = k.post_id
      join community_profiles cp on cp.user_id = p.user_id
      join users u on u.id = p.user_id
      where k.notified = false`);
    return [...rows].map((r) => ({ userId: r.user_id, tz: r.tz ?? 'Asia/Kolkata', notify: r.notify, pushedOn: r.pushed_on }));
  }

  /** The handles of those whose kudos wait for this person's summary (visible ones), newest first. */
  async waitingCheerers(userId: string): Promise<string[]> {
    const rows = await this.db.execute<{ handle: string }>(sql`
      select cp.handle, max(k.created_at) as last
      from community_kudos k
      join community_posts p on p.id = k.post_id
      join community_profiles cp on cp.user_id = k.giver_id
      where p.user_id = ${userId} and k.notified = false and cp.hidden = false
        and ${notBlocked(userId, sql`k.giver_id`)}
      group by cp.handle
      order by last desc`);
    return [...rows].map((r) => r.handle);
  }

  async markKudosNotified(userId: string): Promise<void> {
    await this.db.execute(sql`
      update community_kudos k set notified = true
      from community_posts p
      where p.id = k.post_id and p.user_id = ${userId} and k.notified = false`);
  }

  /* ------------------------------------------------ beta 6.3: nudges -- */

  async lastNudge(from: string, to: string): Promise<Date | null> {
    const [r] = await this.db
      .select({ at: communityNudges.at })
      .from(communityNudges)
      .where(and(eq(communityNudges.fromId, from), eq(communityNudges.toId, to)))
      .limit(1);
    return r?.at ?? null;
  }

  async nudge(from: string, to: string, at: Date): Promise<void> {
    await this.db
      .insert(communityNudges)
      .values({ fromId: from, toId: to, at })
      .onConflictDoUpdate({ target: [communityNudges.fromId, communityNudges.toId], set: { at } });
  }

  /** Nudges this person received since `since`, from people they can still see, newest first. */
  async nudgesTo(userId: string, since: Date): Promise<(PersonRow & { at: Date })[]> {
    return this.db
      .select({ ...person, at: communityNudges.at })
      .from(communityNudges)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, communityNudges.fromId))
      .innerJoin(users, eq(users.id, communityProfiles.userId))
      .where(and(eq(communityNudges.toId, userId), gte(communityNudges.at, since), eq(communityProfiles.hidden, false), notBlocked(userId, communityProfiles.userId)))
      .orderBy(desc(communityNudges.at));
  }

  /* ------------------------------------------- beta 6.3: suggestions -- */

  /**
   * Friends of friends and club-mates (owner Q3): not the viewer, not already
   * friends or asked either way, no block or decline either way, not hidden,
   * not dismissed, and only people who allow suggestions. Best first by
   * friends in common, then a shared club.
   */
  async suggestions(viewer: string, limit: number): Promise<SuggestionRow[]> {
    const rows = await this.db.execute<{
      user_id: string; handle: string; avatar_id: string | null; country: string | null; mutual: number; club: string | null;
    }>(sql`
      with mine as (
        select case when f.requester_id = ${viewer} then f.addressee_id else f.requester_id end as id
        from friendships f
        where f.status = 'accepted' and (f.requester_id = ${viewer} or f.addressee_id = ${viewer})),
      fof as (
        select case when f.requester_id = m.id then f.addressee_id else f.requester_id end as id, count(*)::int as n
        from friendships f join mine m on f.requester_id = m.id or f.addressee_id = m.id
        where f.status = 'accepted'
        group by 1),
      mates as (
        select m2.user_id as id, min(c.name) as club
        from club_members m1
        join club_members m2 on m2.club_id = m1.club_id and m2.user_id <> ${viewer}
        join clubs c on c.id = m1.club_id
        where m1.user_id = ${viewer}
        group by 1),
      cand as (select id from fof union select id from mates)
      select cp.user_id, cp.handle, u.avatar_id, cp.country, coalesce(fof.n, 0)::int as mutual, mates.club
      from cand
      join community_profiles cp on cp.user_id = cand.id
      join users u on u.id = cp.user_id
      left join fof on fof.id = cand.id
      left join mates on mates.id = cand.id
      where cand.id <> ${viewer}
        and cp.hidden = false
        and cp.suggest = true
        and not exists (select 1 from friendships f
              where (f.requester_id = ${viewer} and f.addressee_id = cand.id) or (f.requester_id = cand.id and f.addressee_id = ${viewer}))
        and not exists (select 1 from friend_declines d
              where (d.requester_id = ${viewer} and d.addressee_id = cand.id) or (d.requester_id = cand.id and d.addressee_id = ${viewer}))
        and not exists (select 1 from community_suggestion_dismissals x where x.viewer_id = ${viewer} and x.dismissed_id = cand.id)
        and ${notBlocked(viewer, sql`cand.id`)}
      order by mutual desc, (mates.club is not null) desc, cp.handle
      limit ${limit}`);
    return [...rows].map((r) => ({ userId: r.user_id, handle: r.handle, avatarId: r.avatar_id, country: r.country, mutual: r.mutual, club: r.club }));
  }

  async dismissSuggestion(viewer: string, other: string): Promise<void> {
    await this.db.insert(communitySuggestionDismissals).values({ viewerId: viewer, dismissedId: other }).onConflictDoNothing();
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
        // Beta 6.5: the open challenge, and the latest match with the other club's name.
        challenge: sql<{ metric: string; target: number; month: string; total: number; reached: boolean } | null>`(
          select json_build_object('metric', c.metric, 'target', c.target, 'month', c.month, 'total', c.total, 'reached', c.reached_at is not null)
          from club_challenges c where c.club_id = ${clubs.id} and c.closed_at is null limit 1)`,
        match: sql<{ other: string; weekFrom: string; status: string } | null>`(
          select json_build_object('other', o.name, 'weekFrom', m.week_from, 'status', m.status)
          from club_matches m
          join clubs o on o.id = case when m.home_club_id = ${clubs.id} then m.away_club_id else m.home_club_id end
          where m.home_club_id = ${clubs.id} or m.away_club_id = ${clubs.id}
          order by m.week_from desc limit 1)`,
      })
      .from(clubs)
      .leftJoin(communityProfiles, eq(communityProfiles.userId, clubs.ownerId))
      .orderBy(desc(clubs.createdAt))
      .limit(200);
  }

  /* ------------------------------------------ beta 6.5 (K2): challenges -- */

  async openChallenge(clubId: string): Promise<ChallengeRow | null> {
    const [r] = await this.db
      .select()
      .from(clubChallenges)
      .where(and(eq(clubChallenges.clubId, clubId), sql`${clubChallenges.closedAt} is null`))
      .limit(1);
    return r ?? null;
  }

  /** The last finished, newest month first. */
  async finishedChallenges(clubId: string, limit: number): Promise<ChallengeRow[]> {
    return this.db
      .select()
      .from(clubChallenges)
      .where(and(eq(clubChallenges.clubId, clubId), sql`${clubChallenges.closedAt} is not null`))
      .orderBy(desc(clubChallenges.month), desc(clubChallenges.closedAt))
      .limit(limit);
  }

  /** Null when the club has an open one already (one at a time). */
  async createChallenge(clubId: string, createdBy: string, metric: string, target: number, month: string): Promise<ChallengeRow | null> {
    try {
      const [r] = await this.db.insert(clubChallenges).values({ clubId, createdBy, metric, target, month }).returning();
      return r ?? null;
    } catch (e) {
      if (uniqueViolationOf(e) !== null) return null;
      throw e;
    }
  }

  async setChallengeTarget(id: string, target: number): Promise<void> {
    await this.db.update(clubChallenges).set({ target }).where(eq(clubChallenges.id, id));
  }

  /** Closed: the total stays, the members' parts go. */
  async closeChallenge(id: string, at: Date, endedEarly: boolean): Promise<void> {
    await this.db.update(clubChallenges).set({ closedAt: at, endedEarly }).where(and(eq(clubChallenges.id, id), sql`${clubChallenges.closedAt} is null`));
    await this.db.delete(clubChallengeParts).where(eq(clubChallengeParts.challengeId, id));
  }

  async challengePart(challengeId: string, userId: string): Promise<number> {
    const [r] = await this.db
      .select({ value: clubChallengeParts.value })
      .from(clubChallengeParts)
      .where(and(eq(clubChallengeParts.challengeId, challengeId), eq(clubChallengeParts.userId, userId)))
      .limit(1);
    return r?.value ?? 0;
  }

  /** The open challenges of the clubs this person is in. */
  async openChallengesOf(userId: string): Promise<{ id: string; metric: string; month: string }[]> {
    return this.db
      .select({ id: clubChallenges.id, metric: clubChallenges.metric, month: clubChallenges.month })
      .from(clubChallenges)
      .innerJoin(clubMembers, and(eq(clubMembers.clubId, clubChallenges.clubId), eq(clubMembers.userId, userId)))
      .where(sql`${clubChallenges.closedAt} is null`);
  }

  async savePart(challengeId: string, userId: string, value: number): Promise<void> {
    await this.db
      .insert(clubChallengeParts)
      .values({ challengeId, userId, value })
      .onConflictDoUpdate({ target: [clubChallengeParts.challengeId, clubChallengeParts.userId], set: { value, updatedAt: new Date() } });
  }

  /**
   * The club's count: the parts of its current members. Someone who left
   * takes their part with them.
   */
  async recountChallenge(id: string): Promise<number> {
    await this.db.execute(sql`
      delete from club_challenge_parts p using club_challenges c
      where c.id = ${id} and p.challenge_id = c.id
        and not exists (select 1 from club_members m where m.club_id = c.club_id and m.user_id = p.user_id)`);
    const [r] = await this.db.execute<{ total: number }>(sql`
      update club_challenges c set total = coalesce((select sum(p.value) from club_challenge_parts p where p.challenge_id = c.id), 0)::int
      where c.id = ${id} returning c.total`);
    return r?.total ?? 0;
  }

  /** Every open challenge, with its club's name, for the round. */
  async openChallenges(): Promise<(ChallengeRow & { clubName: string })[]> {
    const rows = await this.db
      .select({ c: clubChallenges, clubName: clubs.name })
      .from(clubChallenges)
      .innerJoin(clubs, eq(clubs.id, clubChallenges.clubId))
      .where(sql`${clubChallenges.closedAt} is null`);
    return rows.map((r) => ({ ...r.c, clubName: r.clubName }));
  }

  /** True only the first time (the push goes once). */
  async markReached(id: string, at: Date): Promise<boolean> {
    return (
      await this.db
        .update(clubChallenges)
        .set({ reachedAt: at })
        .where(and(eq(clubChallenges.id, id), sql`${clubChallenges.reachedAt} is null`))
        .returning({ id: clubChallenges.id })
    ).length > 0;
  }

  /** A club's members, and whether each allows Community notifications. */
  async clubMembersToTell(clubId: string): Promise<{ userId: string; notify: boolean }[]> {
    return this.db
      .select({ userId: clubMembers.userId, notify: communityProfiles.notify })
      .from(clubMembers)
      .innerJoin(communityProfiles, eq(communityProfiles.userId, clubMembers.userId))
      .where(eq(clubMembers.clubId, clubId));
  }

  async clubMemberIds(clubId: string): Promise<string[]> {
    return (await this.db.select({ userId: clubMembers.userId }).from(clubMembers).where(eq(clubMembers.clubId, clubId))).map((r) => r.userId);
  }

  /** Finished challenges are kept a year. */
  async deleteChallengesClosedBefore(before: Date): Promise<void> {
    await this.db.delete(clubChallenges).where(lt(clubChallenges.closedAt, before));
  }

  /** The club's current members' counts over these past weeks, summed. */
  async clubWeeksTotal(clubId: string, weeks: readonly string[]): Promise<{ sessions: number; runM: number; activeDays: number }> {
    const [r] = await this.db
      .select({
        sessions: sql<number>`coalesce(sum(${communityWeekHistory.sessions}), 0)::int`,
        runM: sql<number>`coalesce(sum(${communityWeekHistory.runM}), 0)::int`,
        activeDays: sql<number>`coalesce(sum(${communityWeekHistory.activeDays}), 0)::int`,
      })
      .from(communityWeekHistory)
      .innerJoin(clubMembers, and(eq(clubMembers.userId, communityWeekHistory.userId), eq(clubMembers.clubId, clubId)))
      .where(inArray(communityWeekHistory.weekFrom, [...weeks]));
    return r ?? { sessions: 0, runM: 0, activeDays: 0 };
  }

  /* ------------------------------------------- beta 6.5 (K3): matches -- */

  private matchSelect() {
    const home = sql`(select name from clubs c where c.id = ${clubMatches.homeClubId})`;
    const away = sql`(select name from clubs c where c.id = ${clubMatches.awayClubId})`;
    return this.db
      .select({
        m: clubMatches,
        homeName: sql<string>`${home}`,
        awayName: sql<string>`${away}`,
        homeOwnerId: sql<string>`(select owner_id from clubs c where c.id = ${clubMatches.homeClubId})`,
        awayOwnerId: sql<string>`(select owner_id from clubs c where c.id = ${clubMatches.awayClubId})`,
      })
      .from(clubMatches);
  }

  private static matchRowOf(r: { m: typeof clubMatches.$inferSelect; homeName: string; awayName: string; homeOwnerId: string; awayOwnerId: string }): MatchRow {
    return { ...r.m, homeName: r.homeName, awayName: r.awayName, homeOwnerId: r.homeOwnerId, awayOwnerId: r.awayOwnerId };
  }

  async match(id: string): Promise<MatchRow | null> {
    const [r] = await this.matchSelect().where(eq(clubMatches.id, id)).limit(1);
    return r === undefined ? null : CommunityRepository.matchRowOf(r);
  }

  /** A club's matches: waiting, on, and finished since `finishedSince`; the latest week first. */
  async matchesOf(clubId: string, finishedSince: Date): Promise<MatchRow[]> {
    const rows = await this.matchSelect()
      .where(
        and(
          or(eq(clubMatches.homeClubId, clubId), eq(clubMatches.awayClubId, clubId)),
          or(sql`${clubMatches.status} <> 'finished'`, gte(clubMatches.finishedAt, finishedSince)),
        ),
      )
      .orderBy(desc(clubMatches.weekFrom), desc(clubMatches.createdAt));
    return rows.map((r) => CommunityRepository.matchRowOf(r));
  }

  /** The club has a match that week already, waiting or on (one a week). */
  async clubBusy(clubId: string, weekFrom: string): Promise<boolean> {
    const [r] = await this.db
      .select({ one: sql<number>`1` })
      .from(clubMatches)
      .where(and(eq(clubMatches.weekFrom, weekFrom), or(eq(clubMatches.homeClubId, clubId), eq(clubMatches.awayClubId, clubId))))
      .limit(1);
    return r !== undefined;
  }

  async createMatch(homeClubId: string, awayClubId: string, metric: string, weekFrom: string): Promise<void> {
    await this.db.insert(clubMatches).values({ homeClubId, awayClubId, metric, weekFrom });
  }

  async acceptMatch(id: string, at: Date): Promise<boolean> {
    return (
      await this.db
        .update(clubMatches)
        .set({ status: 'accepted', acceptedAt: at })
        .where(and(eq(clubMatches.id, id), eq(clubMatches.status, 'pending')))
        .returning({ id: clubMatches.id })
    ).length > 0;
  }

  async deleteMatch(id: string): Promise<void> {
    await this.db.delete(clubMatches).where(eq(clubMatches.id, id));
  }

  /** Unanswered once its week has started: it lapses. */
  async lapseMatches(utcToday: string): Promise<void> {
    await this.db.delete(clubMatches).where(and(eq(clubMatches.status, 'pending'), sql`${clubMatches.weekFrom} <= ${utcToday}`));
  }

  /** Accepted matches whose members are not fixed yet. */
  async matchesToStart(utcToday: string): Promise<MatchRow[]> {
    const rows = await this.matchSelect().where(
      and(eq(clubMatches.status, 'accepted'), sql`${clubMatches.startedAt} is null`, sql`${clubMatches.weekFrom} <= ${utcToday}`),
    );
    return rows.map((r) => CommunityRepository.matchRowOf(r));
  }

  /** The week starts: each club's members now are the ones who count. */
  async startMatch(id: string, at: Date): Promise<void> {
    await this.db.execute(sql`
      insert into club_match_members (match_id, club_id, user_id)
      select m.id, cm.club_id, cm.user_id from club_matches m
      join club_members cm on cm.club_id in (m.home_club_id, m.away_club_id)
      where m.id = ${id}
      on conflict do nothing`);
    await this.db.execute(sql`
      update club_matches m set started_at = ${at.toISOString()}::timestamptz,
        home_members = (select count(*) from club_match_members x where x.match_id = m.id and x.club_id = m.home_club_id)::int,
        away_members = (select count(*) from club_match_members x where x.match_id = m.id and x.club_id = m.away_club_id)::int
      where m.id = ${id}`);
  }

  /** Matches on now (members fixed, not finished). */
  async liveMatches(): Promise<MatchRow[]> {
    const rows = await this.matchSelect().where(and(eq(clubMatches.status, 'accepted'), sql`${clubMatches.startedAt} is not null`));
    return rows.map((r) => CommunityRepository.matchRowOf(r));
  }

  /**
   * Each club's total for the match's week, in the metric's raw unit, from
   * the members who count: their week now, or that week's kept row.
   */
  async matchTotals(id: string, metric: string, weekFrom: string): Promise<Map<string, number>> {
    const col = sql.raw(WEEK_COLUMN[metric] ?? 'sessions');
    const rows = await this.db.execute<{ club_id: string; total: number }>(sql`
      select x.club_id, coalesce(sum(coalesce(ws.${col}, wh.${col}, 0)), 0)::int as total
      from club_match_members x
      left join community_week_stats ws on ws.user_id = x.user_id and ws.week_from = ${weekFrom}
      left join community_week_history wh on wh.user_id = x.user_id and wh.week_from = ${weekFrom}
      where x.match_id = ${id}
      group by x.club_id`);
    return new Map([...rows].map((r) => [r.club_id, r.total]));
  }

  /** The result is kept; who counted goes. */
  async finishMatch(id: string, homeScore: number, awayScore: number, at: Date): Promise<void> {
    await this.db.update(clubMatches).set({ status: 'finished', homeScore, awayScore, finishedAt: at }).where(eq(clubMatches.id, id));
    await this.db.execute(sql`delete from club_match_members where match_id = ${id}`);
  }

  /** A result stays a week. */
  async deleteFinishedMatches(before: Date): Promise<void> {
    await this.db.delete(clubMatches).where(and(eq(clubMatches.status, 'finished'), lt(clubMatches.finishedAt, before)));
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
