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
import { boolean, check, index, integer, jsonb, numeric, pgEnum, pgTable, smallint, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

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
