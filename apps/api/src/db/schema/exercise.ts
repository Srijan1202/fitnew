/**
 * Exercise library (§9.2, Phase 3). Global, not user-scoped: no user_id
 * anywhere here. Seeded from database/seeds/exercises.json by slug; edited
 * only through the admin (Phase 16).
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  numeric,
  pgTable,
  primaryKey,
  smallint,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

import {
  alternativeReasonEnum,
  bodyPartEnum,
  difficultyEnum,
  equipmentEnum,
  movementPatternEnum,
  muscleGroupEnum,
  muscleRoleEnum,
} from './enums.js';

export const exercises = pgTable(
  'exercises',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    slug: text('slug').notNull().unique(),
    name: text('name').notNull(),
    movementPattern: movementPatternEnum('movement_pattern').notNull(),
    /** Everything REQUIRED to perform it; a user must have all of it (§12.2 filter). */
    equipment: equipmentEnum('equipment').array().notNull(),
    difficulty: difficultyEnum('difficulty').notNull(),
    isUnilateral: boolean('is_unilateral').notNull().default(false),
    /** Load step for `increase-load` (§12.4). numeric, never float (§9.1). */
    defaultIncrementKg: numeric('default_increment_kg', { precision: 5, scale: 2 }).notNull(),
    /** Ordered coaching steps. */
    instructions: text('instructions').array().notNull(),
    videoUrl: text('video_url'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // `?q=` searches name by trigram (pg_trgm is created at DB init / CI).
    index('exercises_name_trgm_idx').using('gin', sql`${t.name} gin_trgm_ops`),
    index('exercises_pattern_idx').on(t.movementPattern),
    // `equipment <@ $available` is answered from a GIN index on the array.
    index('exercises_equipment_idx').using('gin', t.equipment),
    check('exercises_equipment_nonempty', sql`cardinality(${t.equipment}) > 0`),
    check('exercises_instructions_nonempty', sql`cardinality(${t.instructions}) > 0`),
    check('exercises_increment_positive', sql`${t.defaultIncrementKg} > 0`),
  ],
);

const exerciseRef = (name: string) =>
  uuid(name)
    .notNull()
    .references(() => exercises.id, { onDelete: 'cascade' });

/**
 * Which muscles an exercise trains and how much a set counts toward that
 * muscle's weekly volume (§12.3: secondary = 0.5). One row per muscle per
 * exercise, so a muscle cannot be both primary and secondary.
 */
export const exerciseMuscles = pgTable(
  'exercise_muscles',
  {
    exerciseId: exerciseRef('exercise_id'),
    muscleGroup: muscleGroupEnum('muscle_group').notNull(),
    role: muscleRoleEnum('role').notNull(),
    contribution: numeric('contribution', { precision: 3, scale: 2 }).notNull(),
    /**
     * Order within the role as the seed lists it. The generator reads the
     * FIRST primary as the muscle a movement is for (close-grip bench:
     * triceps, then chest); reading the join back in enum order lost that
     * and made close-grip bench the push day's chest press (0005).
     */
    position: smallint('position').notNull().default(0),
  },
  (t) => [
    primaryKey({ columns: [t.exerciseId, t.muscleGroup] }),
    index('exercise_muscles_muscle_idx').on(t.muscleGroup, t.role),
    check('exercise_muscles_contribution_range', sql`${t.contribution} > 0 AND ${t.contribution} <= 1`),
  ],
);

/**
 * Substitutes (§12.6): same movement pattern and a shared primary muscle,
 * enforced by the seed tests rather than the database (it would need a
 * trigger). `equipment` and `preference` links are symmetric; `injury`
 * links point from the exercise to avoid toward the gentler one.
 */
export const exerciseAlternatives = pgTable(
  'exercise_alternatives',
  {
    exerciseId: exerciseRef('exercise_id'),
    alternativeId: exerciseRef('alternative_id'),
    reason: alternativeReasonEnum('reason').notNull(),
  },
  (t) => [
    primaryKey({ columns: [t.exerciseId, t.alternativeId, t.reason] }),
    index('exercise_alternatives_alt_idx').on(t.alternativeId),
    check('exercise_alternatives_not_self', sql`${t.exerciseId} <> ${t.alternativeId}`),
  ],
);

/** Joins `user_limitations.body_part` to exclude exercises (§12.2). */
export const exerciseContraindications = pgTable(
  'exercise_contraindications',
  {
    exerciseId: exerciseRef('exercise_id'),
    bodyPart: bodyPartEnum('body_part').notNull(),
  },
  (t) => [
    primaryKey({ columns: [t.exerciseId, t.bodyPart] }),
    index('exercise_contraindications_part_idx').on(t.bodyPart),
  ],
);

export type ExerciseRow = typeof exercises.$inferSelect;
export type ExerciseMuscleRow = typeof exerciseMuscles.$inferSelect;
export type ExerciseAlternativeRow = typeof exerciseAlternatives.$inferSelect;
export type ExerciseContraindicationRow = typeof exerciseContraindications.$inferSelect;
