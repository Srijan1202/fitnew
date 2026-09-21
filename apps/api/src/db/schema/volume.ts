/**
 * Phase 6 caches and signals (§9.2, §9.4, §12.6).
 *
 * `muscle_volume_weekly` is a derived cache — rebuildable from set_logs by
 * `pnpm db:rebuild-volume` — written on every session completion.
 * `exercise_rejections` records "skip this" so the substitution rule can
 * fire on the second one.
 */
import { sql } from 'drizzle-orm';
import { index, numeric, pgTable, primaryKey, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { muscleGroupEnum } from './enums.js';
import { exercises } from './exercise.js';
import { users } from './users.js';

export const muscleVolumeWeekly = pgTable(
  'muscle_volume_weekly',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** ISO week in the user's calendar, "2026-W39". */
    isoWeek: text('iso_week').notNull(),
    muscleGroup: muscleGroupEnum('muscle_group').notNull(),
    hardSets: numeric('hard_sets', { precision: 5, scale: 1 }).notNull(),
    tonnageKg: numeric('tonnage_kg', { precision: 9, scale: 1 }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.isoWeek, t.muscleGroup] }),
    index('muscle_volume_weekly_user_week_idx').on(t.userId, t.isoWeek),
  ],
);

export const exerciseRejections = pgTable(
  'exercise_rejections',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    exerciseId: uuid('exercise_id')
      .notNull()
      .references(() => exercises.id, { onDelete: 'cascade' }),
    rejectedAt: timestamp('rejected_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('exercise_rejections_user_exercise_idx').on(t.userId, t.exerciseId)],
);

export type MuscleVolumeWeeklyRow = typeof muscleVolumeWeekly.$inferSelect;
