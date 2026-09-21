/**
 * Workout logging (§9.2, Phase 5): what the user actually did.
 *
 * Plan targets live in planned_* (Phase 4); nothing here changes them.
 * Every client-created row has a client id with a UNIQUE index so an
 * offline replay (§33) is a no-op at the database, not merely in code.
 * `set_logs` is append-only: a correction is an UPDATE of the row's
 * numbers, a mistake is `deleted_at`; rows are never physically removed
 * except by cascade from their session.
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  numeric,
  pgTable,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { prTypeEnum, sessionStatusEnum, setTypeEnum } from './enums.js';
import { exercises } from './exercise.js';
import { plannedExercises, plannedSets, programDays, programs } from './training.js';
import { users } from './users.js';

export const workoutSessions = pgTable(
  'workout_sessions',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** Kept when the programme or day is later edited away, so history stays whole. */
    programId: uuid('program_id').references(() => programs.id, { onDelete: 'set null' }),
    programDayId: uuid('program_day_id').references(() => programDays.id, { onDelete: 'set null' }),
    /** The day name at start ("Push"), or "Session" for ad-hoc. */
    name: text('name').notNull(),
    /** Explicit; never auto-completed (owner decision 8.5). */
    status: sessionStatusEnum('status').notNull().default('active'),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
    completedAt: timestamp('completed_at', { withTimezone: true }),
    durationSeconds: integer('duration_seconds'),
    notes: text('notes'),
    /** Offline idempotency (§33). */
    clientSessionId: uuid('client_session_id').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('workout_sessions_client_id').on(t.clientSessionId),
    // §9.3, verbatim.
    index('workout_sessions_user_started_idx')
      .on(t.userId, t.startedAt.desc())
      .where(sql`${t.deletedAt} IS NULL`),
    // One active session per user is a database fact, like one_active_program.
    uniqueIndex('one_active_session')
      .on(t.userId)
      .where(sql`${t.status} = 'active' AND ${t.deletedAt} IS NULL`),
    check('workout_sessions_duration_nonnegative', sql`${t.durationSeconds} IS NULL OR ${t.durationSeconds} >= 0`),
  ],
);

export const sessionExercises = pgTable(
  'session_exercises',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    sessionId: uuid('session_id')
      .notNull()
      .references(() => workoutSessions.id, { onDelete: 'cascade' }),
    exerciseId: uuid('exercise_id')
      .notNull()
      .references(() => exercises.id, { onDelete: 'restrict' }),
    /** The programme row this came from (the ADR-005 soft link); null when ad-hoc. */
    plannedExerciseId: uuid('planned_exercise_id').references(() => plannedExercises.id, { onDelete: 'set null' }),
    orderIndex: integer('order_index').notNull(),
    /** Exercises sharing a group alternate sets (owner decision 8.3). */
    supersetGroup: smallint('superset_group'),
    clientExerciseId: uuid('client_exercise_id').notNull(),
    removedAt: timestamp('removed_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('session_exercises_client_id').on(t.clientExerciseId),
    index('session_exercises_session_idx').on(t.sessionId, t.orderIndex),
    check('session_exercises_superset_positive', sql`${t.supersetGroup} IS NULL OR ${t.supersetGroup} >= 1`),
  ],
);

export const setLogs = pgTable(
  'set_logs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    sessionExerciseId: uuid('session_exercise_id')
      .notNull()
      .references(() => sessionExercises.id, { onDelete: 'cascade' }),
    /** The planned set this fulfilled, if any; survives the plan being edited. */
    plannedSetId: uuid('planned_set_id').references(() => plannedSets.id, { onDelete: 'set null' }),
    setIndex: smallint('set_index').notNull(),
    /** Only `working` counts toward records (and Phase 6 volume). */
    setType: setTypeEnum('set_type').notNull().default('working'),
    weightKg: numeric('weight_kg', { precision: 6, scale: 2 }),
    reps: smallint('reps').notNull(),
    rir: smallint('rir'),
    rpe: numeric('rpe', { precision: 3, scale: 1 }),
    isPr: boolean('is_pr').notNull().default(false),
    loggedAt: timestamp('logged_at', { withTimezone: true }).notNull(),
    clientSetId: uuid('client_set_id').notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('set_logs_client_id').on(t.clientSetId),
    // §9.3, verbatim.
    index('set_logs_exercise_index_idx').on(t.sessionExerciseId, t.setIndex),
    // One live row per (exercise, index, type): a replayed batch is a no-op,
    // a soft-deleted row can be re-logged.
    uniqueIndex('set_logs_live_position')
      .on(t.sessionExerciseId, t.setIndex, t.setType)
      .where(sql`${t.deletedAt} IS NULL`),
    check('set_logs_index_positive', sql`${t.setIndex} >= 1`),
    check('set_logs_reps_nonnegative', sql`${t.reps} >= 0`),
    check('set_logs_rir_range', sql`${t.rir} IS NULL OR ${t.rir} BETWEEN 0 AND 5`),
    check('set_logs_weight_nonnegative', sql`${t.weightKg} IS NULL OR ${t.weightKg} >= 0`),
  ],
);

/** Derived cache (§9.4): rebuildable from set_logs; owner decision 8.1 puts it in Phase 5. */
export const exercisePrs = pgTable(
  'exercise_prs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    exerciseId: uuid('exercise_id')
      .notNull()
      .references(() => exercises.id, { onDelete: 'restrict' }),
    prType: prTypeEnum('pr_type').notNull(),
    value: numeric('value', { precision: 8, scale: 2 }).notNull(),
    previous: numeric('previous', { precision: 8, scale: 2 }).notNull(),
    reason: text('reason').notNull(),
    achievedAt: timestamp('achieved_at', { withTimezone: true }).notNull(),
    setLogId: uuid('set_log_id')
      .notNull()
      .references(() => setLogs.id, { onDelete: 'cascade' }),
  },
  (t) => [
    index('exercise_prs_user_exercise_idx').on(t.userId, t.exerciseId, t.achievedAt),
    uniqueIndex('exercise_prs_set_type').on(t.setLogId, t.prType),
  ],
);

export type WorkoutSessionRow = typeof workoutSessions.$inferSelect;
export type SessionExerciseRow = typeof sessionExercises.$inferSelect;
export type SetLogRow = typeof setLogs.$inferSelect;
export type ExercisePrRow = typeof exercisePrs.$inferSelect;
