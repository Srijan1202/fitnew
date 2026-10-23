/**
 * Beta 3.2 (ADR-032): foods people searched for and did not find.
 *
 * `food_requests` is an anonymous tally per normalised search text: how many
 * people, how many person-days, how many asked for it outright. It has no
 * user column. `food_request_marks` keeps those counts honest (each person
 * counts once a day and once overall) through salted hashes of who and when,
 * so no user id is stored and none can be read back.
 */
import { sql } from 'drizzle-orm';
import { check, index, integer, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const foodRequests = pgTable(
  'food_requests',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    /** The normalised search text (the same normalisation search uses). */
    query: text('query').notNull(),
    /** Distinct person-days that searched it and found nothing. */
    searches: integer('searches').notNull().default(0),
    /** Distinct people. */
    people: integer('people').notNull().default(0),
    /** Distinct people who tapped "Ask us to add it". */
    asked: integer('asked').notNull().default(0),
    /** open | added | already-there | ignored. */
    status: text('status').notNull().default('open'),
    firstSeenAt: timestamp('first_seen_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
    resolvedBy: uuid('resolved_by').references(() => users.id, { onDelete: 'set null' }),
  },
  (t) => [
    uniqueIndex('food_requests_query').on(t.query),
    index('food_requests_status_idx').on(t.status, t.people),
    check('food_requests_status', sql`${t.status} in ('open', 'added', 'already-there', 'ignored')`),
    check('food_requests_query_length', sql`length(${t.query}) between 2 and 60`),
    check('food_requests_counts', sql`${t.searches} >= 0 and ${t.people} >= 0 and ${t.asked} >= 0`),
  ],
);

export const foodRequestMarks = pgTable('food_request_marks', {
  /** sha256(salt, kind, user, text[, day]): counts each person once, stores no one. */
  mark: text('mark').primaryKey(),
  requestId: uuid('request_id')
    .notNull()
    .references(() => foodRequests.id, { onDelete: 'cascade' }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type FoodRequestRow = typeof foodRequests.$inferSelect;
