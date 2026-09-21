/**
 * Programmes (§9.2, Phase 4): the generator's output or the user's own,
 * persisted as a week of days with planned exercises.
 *
 * `programs` is user-authored content, so it soft-deletes (§9.1). One
 * active programme per user is a partial unique index — a database fact.
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  jsonb,
  numeric,
  pgTable,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { muscleGroupEnum, programSourceEnum, splitTypeEnum } from './enums.js';
import { exercises } from './exercise.js';
import { users } from './users.js';

export const programs = pgTable(
  'programs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    splitType: splitTypeEnum('split_type').notNull(),
    daysPerWeek: smallint('days_per_week').notNull(),
    source: programSourceEnum('source').notNull(),
    /** The professional template this came from (Phase 4 rework), else null. */
    templateSlug: text('template_slug'),
    mesocycleWeek: smallint('mesocycle_week').notNull().default(1),
    active: boolean('active').notNull().default(true),
    /** The generator's explanation and shortfalls, stored with the plan they explain. */
    rationale: jsonb('rationale').$type<string[]>().notNull().default([]),
    shortfalls: jsonb('shortfalls')
      .$type<{ muscle: string; targetSets: number; plannedSets: number; reason: string; detail: string }[]>()
      .notNull()
      .default([]),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    // §9.3, verbatim.
    uniqueIndex('one_active_program')
      .on(t.userId)
      .where(sql`${t.active} AND ${t.deletedAt} IS NULL`),
    index('programs_user_idx').on(t.userId, t.createdAt),
    check('programs_days_range', sql`${t.daysPerWeek} BETWEEN 2 AND 6`),
    check('programs_week_positive', sql`${t.mesocycleWeek} >= 1`),
  ],
);

export const programDays = pgTable(
  'program_days',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    programId: uuid('program_id')
      .notNull()
      .references(() => programs.id, { onDelete: 'cascade' }),
    /** 1 = Monday … 7 = Sunday. */
    dayOfWeek: smallint('day_of_week').notNull(),
    sessionName: text('session_name').notNull(),
    focus: muscleGroupEnum('focus').array().notNull().default([]),
    isRest: boolean('is_rest').notNull().default(false),
  },
  (t) => [
    uniqueIndex('program_days_program_day').on(t.programId, t.dayOfWeek),
    check('program_days_dow_range', sql`${t.dayOfWeek} BETWEEN 1 AND 7`),
  ],
);

export const plannedExercises = pgTable(
  'planned_exercises',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    programDayId: uuid('program_day_id')
      .notNull()
      .references(() => programDays.id, { onDelete: 'cascade' }),
    exerciseId: uuid('exercise_id')
      .notNull()
      .references(() => exercises.id, { onDelete: 'restrict' }),
    orderIndex: integer('order_index').notNull(),
    setCount: smallint('set_count').notNull(),
    repMin: smallint('rep_min').notNull(),
    repMax: smallint('rep_max').notNull(),
    targetRir: smallint('target_rir').notNull(),
    incrementKg: numeric('increment_kg', { precision: 5, scale: 2 }).notNull(),
    /** Why this exercise (§12.4 "a recommendation without a reason is a bug"); null when the user chose it. */
    reason: text('reason'),
  },
  (t) => [
    uniqueIndex('planned_exercises_day_order').on(t.programDayId, t.orderIndex),
    index('planned_exercises_exercise_idx').on(t.exerciseId),
    check('planned_exercises_sets_range', sql`${t.setCount} BETWEEN 1 AND 10`),
    check('planned_exercises_reps_ordered', sql`${t.repMin} >= 1 AND ${t.repMin} <= ${t.repMax} AND ${t.repMax} <= 50`),
    check('planned_exercises_rir_range', sql`${t.targetRir} BETWEEN 0 AND 5`),
    check('planned_exercises_increment_positive', sql`${t.incrementKg} > 0`),
  ],
);

/**
 * Per-set TARGETS (Phase 4 rework, owner decision 2026-09-21). One row per
 * set, always: `planned_exercises.set_count` rows, ordered by set_index.
 * A rep range as §12.4 models it (collapsed when the user pins a number),
 * a starting weight the user typed or NULL (the generator never invents a
 * load — §12.4 rule 1), and the RIR target. What the lifter actually did
 * is Phase 5's `set_logs`, which will reference these rows.
 */
export const plannedSets = pgTable(
  'planned_sets',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    plannedExerciseId: uuid('planned_exercise_id')
      .notNull()
      .references(() => plannedExercises.id, { onDelete: 'cascade' }),
    setIndex: smallint('set_index').notNull(),
    repsMin: smallint('reps_min').notNull(),
    repsMax: smallint('reps_max').notNull(),
    weightKg: numeric('weight_kg', { precision: 6, scale: 2 }),
    rir: smallint('rir').notNull(),
  },
  (t) => [
    uniqueIndex('planned_sets_exercise_index').on(t.plannedExerciseId, t.setIndex),
    check('planned_sets_index_positive', sql`${t.setIndex} >= 1`),
    check('planned_sets_reps_ordered', sql`${t.repsMin} >= 1 AND ${t.repsMin} <= ${t.repsMax} AND ${t.repsMax} <= 50`),
    check('planned_sets_rir_range', sql`${t.rir} BETWEEN 0 AND 5`),
    check('planned_sets_weight_nonnegative', sql`${t.weightKg} IS NULL OR ${t.weightKg} >= 0`),
  ],
);

export type ProgramRow = typeof programs.$inferSelect;
export type PlannedSetRow = typeof plannedSets.$inferSelect;
export type ProgramDayRow = typeof programDays.$inferSelect;
export type PlannedExerciseRow = typeof plannedExercises.$inferSelect;
