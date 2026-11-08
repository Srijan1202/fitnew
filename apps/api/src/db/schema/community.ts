/**
 * Community (beta 5.8, ADR-057): friends, clubs and the world board. Every
 * row belongs to a person (CASCADE): exported and deleted with the account;
 * leaving Community deletes the profile, the friendships and the club places.
 */
import { sql } from 'drizzle-orm';
import { boolean, check, index, integer, pgTable, primaryKey, smallint, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

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
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('community_profiles_handle_key').on(t.handle),
    index('community_profiles_world_idx').on(t.onWorld, t.country),
    check('community_profiles_handle', sql`${t.handle} ~ '^[a-z0-9_]{3,20}$'`),
    check('community_profiles_country', sql`${t.country} is null or ${t.country} ~ '^[A-Z]{2}$'`),
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
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('community_week_stats_sessions_idx').on(t.sessions, t.runM),
    index('community_week_stats_run_idx').on(t.runM),
    check('community_week_stats_counts', sql`${t.sessions} between 0 and 7 and ${t.runM} >= 0 and ${t.streak} >= 0`),
  ],
);
