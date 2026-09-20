/**
 * Exercise library vocabulary and wire shapes (§9.2, §12, Phase 3).
 *
 * The library is global, not user-scoped: the same 120+ rows for everyone,
 * seeded from `database/seeds/exercises.json` and edited only through the
 * admin (Phase 16). Every closed list here is the source of the matching
 * Postgres enum and of the Dart vocabulary; the conformance tests on both
 * sides read this file's OpenAPI output.
 */
import { z } from 'zod';

import { bodyPartSchema, equipmentSchema } from './profile.js';

/* ------------------------------------------------------------- vocabulary -- */

/**
 * Muscle groups are exactly the rows of the volume-landmark table (§12.3),
 * because weekly hard sets per group is what the generator (Phase 4) and the
 * volume cache (Phase 6) count. A muscle not in this list has no landmark
 * and therefore cannot be programmed.
 */
export const MUSCLE_GROUPS = [
  'chest',
  'back',
  'quads',
  'hamstrings',
  'glutes',
  'shoulders',
  'biceps',
  'triceps',
  'calves',
  'abs',
] as const;
export const muscleGroupSchema = z.enum(MUSCLE_GROUPS);
export type MuscleGroup = z.infer<typeof muscleGroupSchema>;

/**
 * Movement patterns drive selection (§12.2: "select by movement pattern to
 * reach per-muscle MEV") and substitution (§12.6: "matching movement pattern
 * and primary muscle"). Compound patterns first, then the isolation patterns
 * the generator uses to top up a lagging muscle.
 */
export const MOVEMENT_PATTERNS = [
  'squat',
  'hinge',
  'lunge',
  'horizontal-push',
  'vertical-push',
  'horizontal-pull',
  'vertical-pull',
  'elbow-flexion',
  'elbow-extension',
  'shoulder-isolation',
  'chest-isolation',
  'leg-isolation',
  'calf-raise',
  'core',
  'carry',
] as const;
export const movementPatternSchema = z.enum(MOVEMENT_PATTERNS);
export type MovementPattern = z.infer<typeof movementPatternSchema>;

/** Compound patterns are ordered first in a session (§12.2 "compound-first"). */
export const COMPOUND_PATTERNS: readonly MovementPattern[] = [
  'squat',
  'hinge',
  'lunge',
  'horizontal-push',
  'vertical-push',
  'horizontal-pull',
  'vertical-pull',
];

export const DIFFICULTIES = ['beginner', 'intermediate', 'advanced'] as const;
export const difficultySchema = z.enum(DIFFICULTIES);
export type Difficulty = z.infer<typeof difficultySchema>;

export const MUSCLE_ROLES = ['primary', 'secondary'] as const;
export const muscleRoleSchema = z.enum(MUSCLE_ROLES);
export type MuscleRole = z.infer<typeof muscleRoleSchema>;

/** Why an alternative is listed (§9.2). `injury` links are one-way; see seed tests. */
export const ALTERNATIVE_REASONS = ['equipment', 'injury', 'preference'] as const;
export const alternativeReasonSchema = z.enum(ALTERNATIVE_REASONS);
export type AlternativeReason = z.infer<typeof alternativeReasonSchema>;

/** Secondary involvement counts 0.5 sets toward weekly volume (§12.3). */
export const SECONDARY_CONTRIBUTION = 0.5;
export const PRIMARY_CONTRIBUTION = 1;

/* --------------------------------------------------------------- shapes -- */

export const slugSchema = z
  .string()
  .min(2)
  .max(64)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'kebab-case');

export const exerciseMuscleSchema = z.object({
  muscleGroup: muscleGroupSchema,
  role: muscleRoleSchema,
  /** 1 for primary, 0.5 for secondary (§12.3). Stored so the rule can change per row later. */
  contribution: z.number().min(0).max(1),
});
export type ExerciseMuscle = z.infer<typeof exerciseMuscleSchema>;

/** One row of a list result. Enough to render a browser row and to filter client-side. */
export const exerciseSummarySchema = z.object({
  id: z.string().uuid(),
  slug: slugSchema,
  name: z.string().min(1),
  movementPattern: movementPatternSchema,
  equipment: z.array(equipmentSchema).min(1),
  difficulty: difficultySchema,
  isUnilateral: z.boolean(),
  primaryMuscles: z.array(muscleGroupSchema).min(1),
});
export type ExerciseSummary = z.infer<typeof exerciseSummarySchema>;

export const exerciseAlternativeSchema = z.object({
  id: z.string().uuid(),
  slug: slugSchema,
  name: z.string().min(1),
  reason: alternativeReasonSchema,
  equipment: z.array(equipmentSchema).min(1),
});
export type ExerciseAlternative = z.infer<typeof exerciseAlternativeSchema>;

export const exerciseDetailSchema = exerciseSummarySchema.extend({
  /** Load step for `increase-load` (§12.4): 2.5 kg upper / 5 kg lower by default. */
  defaultIncrementKg: z.number().positive(),
  /** Ordered coaching steps. Displayed as written; never paraphrased by the client. */
  instructions: z.array(z.string().min(1)).min(1),
  videoUrl: z.string().url().nullable(),
  muscles: z.array(exerciseMuscleSchema).min(1),
  alternatives: z.array(exerciseAlternativeSchema),
  /** Body parts whose `user_limitations` exclude this exercise (§12.2, §12.6). */
  contraindications: z.array(bodyPartSchema),
});
export type ExerciseDetail = z.infer<typeof exerciseDetailSchema>;

/* ---------------------------------------------------------------- query -- */

export const EXERCISE_LIST_DEFAULT_LIMIT = 50;
export const EXERCISE_LIST_MAX_LIMIT = 200;

/** Comma-separated in the URL (`?equipment=barbell,dumbbell`), a set on the way in. */
const csvEnumList = <T extends z.ZodEnum<[string, ...string[]]>>(item: T) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? v.split(',').map((s) => s.trim()).filter(Boolean) : v),
    z.array(item).min(1).max(item.options.length),
  );

/**
 * `GET /exercises?q&equipment&muscle&pattern&limit&offset` (§10.1).
 *
 * `equipment` is the equipment the user HAS; the result is every exercise
 * they can perform with it — an exercise is included only when all of its
 * required equipment is in the set. `bodyweight` is always considered
 * available. This is the acceptance rule "filter by equipment returns only
 * performable exercises".
 */
export const exerciseListQuerySchema = z
  .object({
    q: z.string().trim().min(1).max(64).optional(),
    equipment: csvEnumList(equipmentSchema).optional(),
    muscle: muscleGroupSchema.optional(),
    pattern: movementPatternSchema.optional(),
    limit: z.coerce.number().int().min(1).max(EXERCISE_LIST_MAX_LIMIT).default(EXERCISE_LIST_DEFAULT_LIMIT),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();
export type ExerciseListQuery = z.infer<typeof exerciseListQuerySchema>;

export const exerciseListResponseSchema = z.object({
  items: z.array(exerciseSummarySchema),
  /** Matching rows before limit/offset, so the client can say "12 of 134". */
  total: z.number().int().min(0),
  limit: z.number().int().positive(),
  offset: z.number().int().min(0),
});
export type ExerciseListResponse = z.infer<typeof exerciseListResponseSchema>;

export const exerciseIdParamsSchema = z.object({ id: z.string().uuid() });

/* ----------------------------------------------------------------- seed -- */

/**
 * The shape of one entry in `database/seeds/exercises.json`. Slugs, not ids:
 * ids are assigned by the database on first insert and the seed is
 * idempotent by slug. Alternatives and contraindications reference slugs so
 * the file is readable and diffable.
 */
export const exerciseSeedSchema = z
  .object({
    slug: slugSchema,
    name: z.string().min(1).max(80),
    movementPattern: movementPatternSchema,
    equipment: z.array(equipmentSchema).min(1),
    difficulty: difficultySchema,
    isUnilateral: z.boolean(),
    defaultIncrementKg: z.number().positive(),
    instructions: z.array(z.string().min(1)).min(2),
    videoUrl: z.string().url().nullable(),
    primaryMuscles: z.array(muscleGroupSchema).min(1),
    secondaryMuscles: z.array(muscleGroupSchema),
    alternatives: z.array(
      z.object({ slug: slugSchema, reason: alternativeReasonSchema }).strict(),
    ),
    contraindications: z.array(bodyPartSchema),
  })
  .strict();
export type ExerciseSeed = z.infer<typeof exerciseSeedSchema>;

export const exerciseSeedFileSchema = z.array(exerciseSeedSchema).min(120);
