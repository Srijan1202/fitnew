/**
 * Community (beta 5.8, ADR-057): friends, clubs and the world board. Every
 * row belongs to a person (CASCADE): exported and deleted with the account;
 * leaving Community deletes the profile, the friendships and the club places.
 */
import { sql } from 'drizzle-orm';
import { boolean, check, index, integer, jsonb, pgTable, primaryKey, smallint, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

const userRef = (name: string) =>
  uuid(name)
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' });

/** A member: the handle others see, a country, and the world-board choice. */
export const communityProfiles = pgTable(
  'community_profiles',
  {
    userId: userRef('user_id').primaryKey(),
    handle: text('handle').notNull(),
    country: text('country'),
    onWorld: boolean('on_world').notNull().default(false),
    /** The admin took this person off every board and out of search. */
    hidden: boolean('hidden').notNull().default(false),
    /** Beta 6.3 (C1, owner Q1): the kinds shared with friends in the feed; none at first. */
    feed: text('feed').array().notNull().default(sql`'{}'::text[]`),
    /** Beta 6.3: when each kind was last switched on; only later events are posted. */
    feedSince: jsonb('feed_since').$type<Record<string, string>>().notNull().default(sql`'{}'::jsonb`),
    /**
     * Beta 6.5 (K0, owner 2026-11-22): the feed is on by default. True once
     * every kind was switched on for this person: at joining, or for those who
     * joined earlier, once, from agreeing to the 2026-11-20 policy (owner Q5,
     * even if they had turned kinds off). They can turn any off again.
     */
    feedDefaulted: boolean('feed_defaulted').notNull().default(false),
    /** Beta 6.3 (C16, owner Q3): suggested to friends of friends and club-mates. */
    suggest: boolean('suggest').notNull().default(true),
    /** Beta 6.3 (C2, C3): the evening kudos summary and nudges as notifications. */
    notify: boolean('notify').notNull().default(true),
    /** Beta 6.3: the local dates of the last kudos summary and the last nudge notification (one a day each). */
    kudosPushedOn: text('kudos_pushed_on'),
    nudgePushedOn: text('nudge_pushed_on'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('community_profiles_handle_key').on(t.handle),
    index('community_profiles_world_idx').on(t.onWorld, t.country),
    check('community_profiles_handle', sql`${t.handle} ~ '^[a-z0-9_]{3,20}$'`),
    check('community_profiles_country', sql`${t.country} is null or ${t.country} ~ '^[A-Z]{2}$'`),
    check('community_profiles_feed', sql`${t.feed} <@ array['session', 'run', 'record', 'streak']::text[]`),
  ],
);

/**
 * A friendship, asked by one and accepted by the other. One row per pair
 * whichever way it was asked (the unique index on the ordered pair).
 */
export const friendships = pgTable(
  'friendships',
  {
    requesterId: userRef('requester_id'),
    addresseeId: userRef('addressee_id'),
    status: text('status').notNull().default('pending'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    acceptedAt: timestamp('accepted_at', { withTimezone: true }),
  },
  (t) => [
    primaryKey({ columns: [t.requesterId, t.addresseeId] }),
    uniqueIndex('friendships_pair_key').on(sql`least(${t.requesterId}, ${t.addresseeId})`, sql`greatest(${t.requesterId}, ${t.addresseeId})`),
    index('friendships_addressee_idx').on(t.addresseeId, t.status),
    check('friendships_status', sql`${t.status} in ('pending', 'accepted')`),
    check('friendships_not_self', sql`${t.requesterId} <> ${t.addresseeId}`),
  ],
);

/** A block: the blocked person cannot find, add or see the blocker. Kept after leaving. */
export const communityBlocks = pgTable(
  'community_blocks',
  {
    blockerId: userRef('blocker_id'),
    blockedId: userRef('blocked_id'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.blockerId, t.blockedId] }),
    index('community_blocks_blocked_idx').on(t.blockedId),
    check('community_blocks_not_self', sql`${t.blockerId} <> ${t.blockedId}`),
  ],
);

/** A club anyone can join with its code; its maker's own (deleted with them). */
export const clubs = pgTable(
  'clubs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    ownerId: userRef('owner_id'),
    name: text('name').notNull(),
    code: text('code').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('clubs_code_key').on(t.code),
    index('clubs_owner_idx').on(t.ownerId),
    check('clubs_name', sql`length(${t.name}) between 3 and 40`),
    check('clubs_code', sql`${t.code} ~ '^[A-HJ-NP-Z2-9]{8}$'`),
  ],
);

export const clubMembers = pgTable(
  'club_members',
  {
    clubId: uuid('club_id')
      .notNull()
      .references(() => clubs.id, { onDelete: 'cascade' }),
    userId: userRef('user_id'),
    joinedAt: timestamp('joined_at', { withTimezone: true }).notNull().defaultNow(),
    /** Beta 6.6 (L2, owner Q5): `member` or `co-owner` (up to 2 a club, kept by the service). */
    role: text('role').notNull().default('member'),
  },
  (t) => [
    primaryKey({ columns: [t.clubId, t.userId] }),
    index('club_members_user_idx').on(t.userId),
    check('club_members_role', sql`${t.role} in ('member', 'co-owner')`),
  ],
);

/**
 * Beta 6.2 (C5, owner Q2): someone the club's owner removed. They cannot
 * join again with the code until the owner lets them back.
 */
export const clubBans = pgTable(
  'club_bans',
  {
    clubId: uuid('club_id')
      .notNull()
      .references(() => clubs.id, { onDelete: 'cascade' }),
    userId: userRef('user_id'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.clubId, t.userId] }), index('club_bans_user_idx').on(t.userId)],
);

/**
 * Beta 6.2 (S7): a declined friend request. The requester cannot ask the
 * same person again for FRIEND_DECLINE_COOLDOWN_DAYS.
 */
export const friendDeclines = pgTable(
  'friend_declines',
  {
    requesterId: userRef('requester_id'),
    addresseeId: userRef('addressee_id'),
    declinedAt: timestamp('declined_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.requesterId, t.addresseeId] }), index('friend_declines_addressee_idx').on(t.addresseeId)],
);

/** A report of a person or a club, for the admin; the reporter's own row. */
export const communityReports = pgTable(
  'community_reports',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    reporterId: userRef('reporter_id'),
    targetUserId: uuid('target_user_id').references(() => users.id, { onDelete: 'cascade' }),
    clubId: uuid('club_id').references(() => clubs.id, { onDelete: 'cascade' }),
    reason: text('reason').notNull(),
    note: text('note'),
    status: text('status').notNull().default('open'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    closedAt: timestamp('closed_at', { withTimezone: true }),
    closedBy: uuid('closed_by').references(() => users.id, { onDelete: 'set null' }),
  },
  (t) => [
    index('community_reports_status_idx').on(t.status, t.createdAt),
    check('community_reports_target', sql`(${t.targetUserId} is null) <> (${t.clubId} is null)`),
    check('community_reports_reason', sql`${t.reason} in ('handle', 'club-name', 'cheating', 'harassment', 'other')`),
    check('community_reports_status', sql`${t.status} in ('open', 'closed')`),
    check('community_reports_note', sql`${t.note} is null or length(${t.note}) <= 300`),
  ],
);

/**
 * This week's counts per member, Monday to Sunday in their time zone,
 * refreshed by the server every few minutes (and on reading one's own
 * board), so a board of any size is one indexed read.
 */
export const communityWeekStats = pgTable(
  'community_week_stats',
  {
    userId: userRef('user_id').primaryKey(),
    weekFrom: text('week_from').notNull(),
    sessions: smallint('sessions').notNull().default(0),
    runM: integer('run_m').notNull().default(0),
    streak: integer('streak').notNull().default(0),
    /** Beta 6.2 (C11): days with a counted session or run. */
    activeDays: smallint('active_days').notNull().default(0),
    /** Beta 6.2 (C11): sessions planned up to today; null without a programme. */
    planned: smallint('planned'),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('community_week_stats_sessions_idx').on(t.sessions, t.runM),
    index('community_week_stats_run_idx').on(t.runM),
    check('community_week_stats_counts', sql`${t.sessions} between 0 and 7 and ${t.runM} >= 0 and ${t.streak} >= 0`),
    check('community_week_stats_days', sql`${t.activeDays} between 0 and 7 and (${t.planned} is null or ${t.planned} between 0 and 7)`),
  ],
);

/**
 * Beta 6.2 (C4, C12): a finished week's counts, written when the person's
 * week rolls over (the finished week recounted first). The last 8 are kept.
 */
export const communityWeekHistory = pgTable(
  'community_week_history',
  {
    userId: userRef('user_id'),
    weekFrom: text('week_from').notNull(),
    sessions: smallint('sessions').notNull(),
    runM: integer('run_m').notNull(),
    streak: integer('streak').notNull(),
    activeDays: smallint('active_days').notNull(),
    planned: smallint('planned'),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.weekFrom] }),
    index('community_week_history_week_idx').on(t.weekFrom),
    check(
      'community_week_history_counts',
      sql`${t.sessions} between 0 and 7 and ${t.runM} >= 0 and ${t.streak} >= 0 and ${t.activeDays} between 0 and 7 and (${t.planned} is null or ${t.planned} between 0 and 7)`,
    ),
  ],
);

/**
 * Beta 6.3 (C13, owner Q4): each member's counts for this week, this
 * calendar month and since joining Community, written with the week's counts,
 * so every board period is one indexed read.
 */
export const communityPeriodStats = pgTable(
  'community_period_stats',
  {
    userId: userRef('user_id'),
    period: text('period').notNull(),
    periodFrom: text('period_from').notNull(),
    sessions: integer('sessions').notNull().default(0),
    runM: integer('run_m').notNull().default(0),
    streak: integer('streak').notNull().default(0),
    activeDays: integer('active_days').notNull().default(0),
    planned: integer('planned'),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.period] }),
    index('community_period_stats_sessions_idx').on(t.period, t.sessions, t.runM),
    index('community_period_stats_run_idx').on(t.period, t.runM),
    check('community_period_stats_period', sql`${t.period} in ('week', 'month', 'all')`),
    check(
      'community_period_stats_counts',
      sql`${t.sessions} >= 0 and ${t.runM} >= 0 and ${t.streak} >= 0 and ${t.activeDays} >= 0 and (${t.planned} is null or ${t.planned} >= 0)`,
    ),
  ],
);

/**
 * Beta 6.3 (C1): a post in friends' feeds — a counted session, a counted run,
 * a record or a streak milestone. Never weights, sets, routes or food. One per
 * event (`ref`: the session or run id, or the streak's milestone and first day);
 * deleted after 30 days, when its kind is switched off, or with its session or run.
 */
export const communityPosts = pgTable(
  'community_posts',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef('user_id'),
    kind: text('kind').notNull(),
    ref: text('ref').notNull(),
    title: text('title'),
    value: integer('value'),
    at: timestamp('at', { withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('community_posts_event_key').on(t.userId, t.kind, t.ref),
    index('community_posts_user_at_idx').on(t.userId, t.at),
    index('community_posts_at_idx').on(t.at),
    check('community_posts_kind', sql`${t.kind} in ('session', 'run', 'lift-record', 'run-record', 'streak')`),
    check('community_posts_title', sql`${t.title} is null or length(${t.title}) <= 80`),
    check('community_posts_value', sql`${t.value} is null or ${t.value} >= 0`),
  ],
);

/** Beta 6.3 (C2): a friend cheered a post; `notified` once it was in an evening summary. */
export const communityKudos = pgTable(
  'community_kudos',
  {
    postId: uuid('post_id')
      .notNull()
      .references(() => communityPosts.id, { onDelete: 'cascade' }),
    giverId: userRef('giver_id'),
    notified: boolean('notified').notNull().default(false),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.postId, t.giverId] }), index('community_kudos_giver_idx').on(t.giverId)],
);

/** Beta 6.3 (C3): the last time one friend nudged another (once a week per pair). */
export const communityNudges = pgTable(
  'community_nudges',
  {
    fromId: userRef('from_id'),
    toId: userRef('to_id'),
    at: timestamp('at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.fromId, t.toId] }),
    index('community_nudges_to_idx').on(t.toId, t.at),
    check('community_nudges_not_self', sql`${t.fromId} <> ${t.toId}`),
  ],
);

/**
 * Beta 6.3 (C16): a suggestion the viewer hid; never suggested to them again.
 * Other people's to the dismissed person (never in their data download).
 */
export const communitySuggestionDismissals = pgTable(
  'community_suggestion_dismissals',
  {
    viewerId: userRef('viewer_id'),
    dismissedId: userRef('dismissed_id'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.viewerId, t.dismissedId] }), index('community_suggestion_dismissals_dismissed_idx').on(t.dismissedId)],
);

/**
 * Beta 6.5 (K2, C6): a club's goal for a calendar month (owner Q2), set by its
 * owner. No free text: the title is made from the metric, target and month.
 * One open challenge a club; closed ones are kept a year for the club's history.
 */
export const clubChallenges = pgTable(
  'club_challenges',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    clubId: uuid('club_id')
      .notNull()
      .references(() => clubs.id, { onDelete: 'cascade' }),
    metric: text('metric').notNull(),
    /** Sessions, kilometres or active days. */
    target: integer('target').notNull(),
    /** The calendar month, "2026-12". */
    month: text('month').notNull(),
    createdBy: uuid('created_by').references(() => users.id, { onDelete: 'set null' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    /** The club's count, in the metric's raw unit (metres for distance), kept by the round. */
    total: integer('total').notNull().default(0),
    reachedAt: timestamp('reached_at', { withTimezone: true }),
    closedAt: timestamp('closed_at', { withTimezone: true }),
    /** The owner ended it before the month was over. */
    endedEarly: boolean('ended_early').notNull().default(false),
  },
  (t) => [
    uniqueIndex('club_challenges_open_key').on(t.clubId).where(sql`${t.closedAt} is null`),
    index('club_challenges_club_idx').on(t.clubId, t.month),
    check('club_challenges_metric', sql`${t.metric} in ('sessions', 'distance', 'active-days')`),
    check('club_challenges_target', sql`${t.target} between 10 and 100000`),
    check('club_challenges_month', sql`${t.month} ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'`),
    check('club_challenges_total', sql`${t.total} >= 0`),
  ],
);

/**
 * Beta 6.5 (K2): what one member added to an open challenge, counted in their
 * own month and time zone. Leaving the club takes their part with them; the
 * parts go when the challenge closes (its total stays).
 */
export const clubChallengeParts = pgTable(
  'club_challenge_parts',
  {
    challengeId: uuid('challenge_id')
      .notNull()
      .references(() => clubChallenges.id, { onDelete: 'cascade' }),
    userId: userRef('user_id'),
    value: integer('value').notNull().default(0),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.challengeId, t.userId] }),
    index('club_challenge_parts_user_idx').on(t.userId),
    check('club_challenge_parts_value', sql`${t.value} >= 0`),
  ],
);

/**
 * Beta 6.5 (K3, owner Q3): club vs club for one week, Monday to Sunday. The
 * home club challenged; the away club's owner accepts before the week starts
 * (declined or unanswered, the row goes). When it ends, each club's total
 * (in the metric's raw unit, metres for distance) and its members are kept;
 * the score is the total per member. No person's id is kept here: the other
 * club sees only a name and an average.
 */
export const clubMatches = pgTable(
  'club_matches',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    homeClubId: uuid('home_club_id')
      .notNull()
      .references(() => clubs.id, { onDelete: 'cascade' }),
    awayClubId: uuid('away_club_id')
      .notNull()
      .references(() => clubs.id, { onDelete: 'cascade' }),
    metric: text('metric').notNull(),
    /** The week's Monday, "2026-11-30". */
    weekFrom: text('week_from').notNull(),
    status: text('status').notNull().default('pending'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    acceptedAt: timestamp('accepted_at', { withTimezone: true }),
    /** When the members were fixed (the week started). */
    startedAt: timestamp('started_at', { withTimezone: true }),
    homeScore: integer('home_score'),
    awayScore: integer('away_score'),
    homeMembers: integer('home_members'),
    awayMembers: integer('away_members'),
    finishedAt: timestamp('finished_at', { withTimezone: true }),
    /** Beta 6.6 (L1): a league match; null for one set up by hand. */
    leagueSeasonId: uuid('league_season_id').references(() => leagueSeasons.id, { onDelete: 'set null' }),
  },
  (t) => [
    index('club_matches_home_idx').on(t.homeClubId, t.weekFrom),
    index('club_matches_away_idx').on(t.awayClubId, t.weekFrom),
    check('club_matches_not_self', sql`${t.homeClubId} <> ${t.awayClubId}`),
    check('club_matches_metric', sql`${t.metric} in ('sessions', 'distance', 'active-days')`),
    check('club_matches_status', sql`${t.status} in ('pending', 'accepted', 'finished')`),
    check('club_matches_week', sql`${t.weekFrom} ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`),
  ],
);

/**
 * Beta 6.5 (K3): who counts for each club in a match, fixed when the week
 * starts; someone who joins mid-week does not count. Never exported (the
 * privacy download's OTHER_PEOPLES): the other club never learns who.
 */
export const clubMatchMembers = pgTable(
  'club_match_members',
  {
    matchId: uuid('match_id')
      .notNull()
      .references(() => clubMatches.id, { onDelete: 'cascade' }),
    clubId: uuid('club_id').notNull(),
    userId: userRef('user_id'),
  },
  (t) => [primaryKey({ columns: [t.matchId, t.clubId, t.userId] }), index('club_match_members_user_idx').on(t.userId)],
);

/**
 * Beta 6.6 (L1, owner 2026-11-25): the clubs in the league. Its owner or a
 * co-owner enters a club of 3 or more; leaving takes effect after the week.
 */
export const leagueClubs = pgTable('league_clubs', {
  clubId: uuid('club_id')
    .primaryKey()
    .references(() => clubs.id, { onDelete: 'cascade' }),
  enteredAt: timestamp('entered_at', { withTimezone: true }).notNull().defaultNow(),
  /** Out after the current week: not paired again. */
  leaving: boolean('leaving').notNull().default(false),
});

/** Beta 6.6 (L1, Q3): a season of 4 weeks, Monday to Sunday; kept a year. */
export const leagueSeasons = pgTable(
  'league_seasons',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    startsOn: text('starts_on').notNull(),
    endsOn: text('ends_on').notNull(),
    /** The last week paired, so the Saturday round pairs a week once. */
    pairedWeek: text('paired_week'),
    finishedAt: timestamp('finished_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('league_seasons_starts_key').on(t.startsOn),
    check('league_seasons_dates', sql`${t.startsOn} ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' and ${t.endsOn} > ${t.startsOn}`),
  ],
);

/**
 * Beta 6.6 (L1): a club's season in the league. `score_tenths` sums its
 * per-member scores, in tenths (the tie-break); `place` is kept when the
 * season ends.
 */
export const leagueEntries = pgTable(
  'league_entries',
  {
    seasonId: uuid('season_id')
      .notNull()
      .references(() => leagueSeasons.id, { onDelete: 'cascade' }),
    clubId: uuid('club_id')
      .notNull()
      .references(() => clubs.id, { onDelete: 'cascade' }),
    played: integer('played').notNull().default(0),
    won: integer('won').notNull().default(0),
    drawn: integer('drawn').notNull().default(0),
    lost: integer('lost').notNull().default(0),
    byes: integer('byes').notNull().default(0),
    points: integer('points').notNull().default(0),
    scoreTenths: integer('score_tenths').notNull().default(0),
    place: integer('place'),
  },
  (t) => [
    primaryKey({ columns: [t.seasonId, t.clubId] }),
    index('league_entries_club_idx').on(t.clubId),
    check('league_entries_counts', sql`${t.played} >= 0 and ${t.won} >= 0 and ${t.drawn} >= 0 and ${t.lost} >= 0 and ${t.byes} >= 0 and ${t.points} >= 0 and ${t.scoreTenths} >= 0`),
  ],
);
