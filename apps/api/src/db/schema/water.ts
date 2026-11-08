/**
 * Beta 6.0 (F7, ADR-059): `water_logs`, the water drunk on a local day — one
 * row per user and date (UNIQUE, upsert: the phone sends the day's total).
 * Hard-deleted, and it goes with the user (CASCADE), so it is in Download my
 * data and deleted with the account.
 */
import { sql } from 'drizzle-orm';
import { check, date, integer, pgTable, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const waterLogs = pgTable(
  'water_logs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** The user's local date (stored timezone). */
    loggedOn: date('logged_on', { mode: 'string' }).notNull(),
    ml: integer('ml').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex('water_logs_user_day').on(t.userId, t.loggedOn), check('water_logs_ml', sql`${t.ml} between 0 and 10000`)],
);

export type WaterLogRow = typeof waterLogs.$inferSelect;
