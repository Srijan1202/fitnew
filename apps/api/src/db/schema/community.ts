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
  },
  (t) => [primaryKey({ columns: [t.clubId, t.userId] }), index('club_members_user_idx').on(t.userId)],
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
