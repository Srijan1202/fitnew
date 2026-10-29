/**
 * Running (beta 4.0, ADR-038).
 *
 * `runs`: one finished run, created once from the phone's upload (UNIQUE
 * `client_run_id`, the phone's idempotency key). An outdoor run keeps its
 * GPS track as the encoded wire form (packages/core running/track, v1) in
 * one column, not a row per point; a treadmill run has no track.
 *
 * The figures beside it (distance, pace, elevation gain, calories, the
 * list's outline) are core's, computed from the track when the run is
 * written and kept so the history list never decodes a track (§9.4: they
 * are rebuildable from `track` and `duration_seconds`; calories also need
 * the weight at the time, which is why they are kept). Splits and the chart
 * are computed on read.
 *
 * Location is personal: a deleted run is deleted (no soft delete), and runs
 * go with the account (CASCADE) and appear in the data export.
 */
import { sql } from 'drizzle-orm';
import { boolean, check, date, index, integer, jsonb, numeric, pgEnum, pgTable, primaryKey, smallint, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const runKindEnum = pgEnum('run_kind', ['outdoor', 'treadmill']);
export const runGoalKindEnum = pgEnum('run_goal_kind', ['free', 'distance', 'time', 'pace']);

export const runs = pgTable(
  'runs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    clientRunId: uuid('client_run_id').notNull(),
    kind: runKindEnum('kind').notNull(),
    name: text('name').notNull(),
    note: text('note'),
    /** 1 easy – 10 all out. */
    effort: smallint('effort'),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
    endedAt: timestamp('ended_at', { withTimezone: true }).notNull(),
    /** The active time the phone's timer counted (pauses excluded). */
    durationSeconds: integer('duration_seconds').notNull(),
    goalKind: runGoalKindEnum('goal_kind').notNull(),
    goalValue: integer('goal_value'),
    /** The encoded points (v1); null indoors. */
    trackPoints: text('track_points'),
    trackBreaks: jsonb('track_breaks').$type<number[]>(),
    trackElevation: boolean('track_elevation'),
    distanceM: numeric('distance_m', { precision: 9, scale: 1 }).notNull(),
    avgPaceSecPerKm: numeric('avg_pace_sec_per_km', { precision: 8, scale: 1 }),
    elevationGainM: numeric('elevation_gain_m', { precision: 7, scale: 1 }),
    calories: integer('calories'),
    outline: jsonb('outline').$type<[number, number][]>().notNull().default(sql`'[]'::jsonb`),
    /** Beta 4.1: the structured session run (core WorkoutStep[] with its name), and where each step began and ended. */
    workout: jsonb('workout').$type<{ name: string; steps: unknown[] }>(),
    lapMarks: jsonb('lap_marks').$type<{ step: number; startT: number; endT: number }[]>(),
    /** Beta 4.2: the version of core's best-effort rules its `run_best_efforts` rows come from (0: none yet). */
    effortsVersion: smallint('efforts_version').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('runs_client_id').on(t.clientRunId),
    index('runs_user_started_idx').on(t.userId, t.startedAt.desc()),
    check('runs_effort', sql`${t.effort} is null or ${t.effort} between 1 and 10`),
    check('runs_duration', sql`${t.durationSeconds} >= 0`),
    check('runs_times', sql`${t.endedAt} >= ${t.startedAt}`),
    check('runs_distance', sql`${t.distanceM} >= 0`),
    check(
      'runs_track_kind',
      sql`(${t.kind} = 'outdoor') = (${t.trackPoints} is not null and ${t.trackBreaks} is not null and ${t.trackElevation} is not null)`,
    ),
    check('runs_goal', sql`(${t.goalKind} = 'free') = (${t.goalValue} is null)`),
  ],
);

export type RunRow = typeof runs.$inferSelect;

/**
 * Beta 4.2 (owner 2026-10-29): the fastest stretch of each distance inside
 * a run (packages/core running/efforts.ts), one row per run and distance,
 * kept so records are a query, not a decode of every track. Rebuildable from
 * the track (§9.4; `runs.efforts_version`); deleted with the run.
 */
export const effortKeyEnum = pgEnum('effort_key', ['400m', '1k', '1mile', '5k', '10k', 'half', 'marathon']);

export const runBestEfforts = pgTable(
  'run_best_efforts',
  {
    runId: uuid('run_id')
      .notNull()
      .references(() => runs.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    key: effortKeyEnum('key').notNull(),
    /** Moving seconds, to 0.1 s. */
    seconds: numeric('seconds', { precision: 8, scale: 1 }).notNull(),
    /** Metres from the start of the run where the stretch begins. */
    startM: numeric('start_m', { precision: 9, scale: 1 }).notNull(),
  },
  (t) => [
    primaryKey({ columns: [t.runId, t.key] }),
    index('run_best_efforts_user_key_idx').on(t.userId, t.key, t.seconds),
    check('run_best_efforts_seconds', sql`${t.seconds} > 0`),
  ],
);

/*
 * Beta 4.1 (ADR-039): running plans. `running_plans` holds what the runner
 * chose (one active at a time); `planned_runs` its dated runs, generated
 * once by packages/core when the plan is made. A planned run is done when a
 * run links to it (`run_id`), skipped by the runner, or still planned; a
 * move keeps the date it came from. Zones are recomputed from `vdot`.
 */
export const planGoalEnum = pgEnum('plan_goal', ['5k', '10k', 'half', 'marathon']);
export const planLevelEnum = pgEnum('plan_level', ['beginner', 'runner']);
export const planStatusEnum = pgEnum('plan_status', ['active', 'stopped', 'done']);
export const plannedRunKindEnum = pgEnum('planned_run_kind', ['easy', 'long', 'tempo', 'intervals', 'run-walk', 'race']);
export const plannedRunStatusEnum = pgEnum('planned_run_status', ['planned', 'done', 'skipped']);

export const runningPlans = pgTable(
  'running_plans',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    goal: planGoalEnum('goal').notNull(),
    level: planLevelEnum('level').notNull(),
    status: planStatusEnum('status').notNull().default('active'),
    vdot: numeric('vdot', { precision: 4, scale: 1 }),
    daysPerWeek: smallint('days_per_week').notNull(),
    weekdays: jsonb('weekdays').$type<number[]>().notNull(),
    longRunWeekday: smallint('long_run_weekday').notNull(),
    startDate: date('start_date', { mode: 'string' }).notNull(),
    weeks: smallint('weeks').notNull(),
    predictedSeconds: integer('predicted_seconds'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    endedAt: timestamp('ended_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('running_plans_one_active').on(t.userId).where(sql`${t.status} = 'active'`),
    // Beta 4.4 (owner): 1–5 runs a week (3–5 before).
    check('running_plans_days', sql`${t.daysPerWeek} between 1 and 5`),
    check('running_plans_level', sql`(${t.level} = 'beginner') = (${t.vdot} is null)`),
  ],
);

export type RunningPlanRow = typeof runningPlans.$inferSelect;

export const plannedRuns = pgTable(
  'planned_runs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    planId: uuid('plan_id')
      .notNull()
      .references(() => runningPlans.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    date: date('date', { mode: 'string' }).notNull(),
    week: smallint('week').notNull(),
    kind: plannedRunKindEnum('kind').notNull(),
    title: text('title').notNull(),
    distanceM: numeric('distance_m', { precision: 9, scale: 1 }),
    seconds: integer('seconds'),
    paceFast: integer('pace_fast'),
    paceSlow: integer('pace_slow'),
    steps: jsonb('steps').$type<unknown[]>(),
    note: text('note').notNull(),
    status: plannedRunStatusEnum('status').notNull().default('planned'),
    runId: uuid('run_id').references(() => runs.id, { onDelete: 'set null' }),
    movedFrom: date('moved_from', { mode: 'string' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('planned_runs_user_date_idx').on(t.userId, t.date),
    index('planned_runs_plan_idx').on(t.planId, t.date),
    uniqueIndex('planned_runs_run').on(t.runId),
    // No "done ⇔ run_id" CHECK: deleting a run sets run_id null before the
    // service resets the status, and an account deletion cascades both at
    // once. The service keeps the two in step.
    check('planned_runs_pace', sql`(${t.paceFast} is null) = (${t.paceSlow} is null)`),
  ],
);

export type PlannedRunRow = typeof plannedRuns.$inferSelect;

/**
 * Beta 4.4 (E28): the sessions a runner built (ADR-039 C2), kept with the
 * account so a new phone or a reinstall has them. Addressed by the phone's
 * id (an idempotent PUT); at most MAX_MY_WORKOUTS a user (checked by the
 * service). Gone with the account; in the data export.
 */
export const runningWorkouts = pgTable(
  'running_workouts',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    clientId: uuid('client_id').notNull(),
    name: text('name').notNull(),
    steps: jsonb('steps').$type<unknown[]>().notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.clientId] }),
    check('running_workouts_name', sql`length(${t.name}) between 1 and 60`),
  ],
);
