/**
 * Recovery (Phase 13, MASTER-SPEC §9.2 "Recommendations, recovery, ops",
 * §18; ADR-019).
 *
 * `recovery_logs`: the §18 check-in, one row per user and local date
 * (UNIQUE, upsert). Source rows only — readiness is computed on read and
 * never stored (§9.4). Every value is optional, but a row holds at least
 * one. Not in §9.1's soft-delete list, so rows hard-delete (and go with the
 * user). `source` is 'manual' only: Health Connect data never leaves the
 * phone (ADR-008); the V2 health sync would add its own value.
 */
import { sql } from 'drizzle-orm';
import { check, date, numeric, pgEnum, pgTable, smallint, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const recoverySourceEnum = pgEnum('recovery_source', ['manual']);

export const recoveryLogs = pgTable(
  'recovery_logs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** The user's local date (stored timezone), fixed at write. */
    loggedOn: date('logged_on', { mode: 'string' }).notNull(),
    sleepHours: numeric('sleep_hours', { precision: 3, scale: 1 }),
    /** 1 poor – 5 great. */
    sleepQuality: smallint('sleep_quality'),
    /** 1 none – 5 very sore. */
    soreness: smallint('soreness'),
    /** 1 drained – 5 great. */
    energy: smallint('energy'),
    /** 1 calm – 5 very stressed. */
    stress: smallint('stress'),
    source: recoverySourceEnum('source').notNull().default('manual'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('recovery_logs_user_day').on(t.userId, t.loggedOn),
    check('recovery_logs_sleep_hours', sql`${t.sleepHours} is null or ${t.sleepHours} between 0 and 24`),
    check('recovery_logs_sleep_quality', sql`${t.sleepQuality} is null or ${t.sleepQuality} between 1 and 5`),
    check('recovery_logs_soreness', sql`${t.soreness} is null or ${t.soreness} between 1 and 5`),
    check('recovery_logs_energy', sql`${t.energy} is null or ${t.energy} between 1 and 5`),
    check('recovery_logs_stress', sql`${t.stress} is null or ${t.stress} between 1 and 5`),
    check(
      'recovery_logs_something',
      sql`num_nonnulls(${t.sleepHours}, ${t.sleepQuality}, ${t.soreness}, ${t.energy}, ${t.stress}) > 0`,
    ),
  ],
);

export type RecoveryLogRow = typeof recoveryLogs.$inferSelect;
