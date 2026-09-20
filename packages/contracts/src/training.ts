/**
 * Training programme wire shapes (§9.2 programs/program_days/planned_exercises,
 * §10.1 /training/program*, Phase 4).
 *
 * A programme is the generator's output persisted (source `generated`), or
 * the user's own (source `custom`). Either way `mesocycle_week` advances and
 * the progression engine (Phase 5) reads planned_exercises the same way —
 * that is what "remains adaptive" means (§31 Phase 4 acceptance).
 */
import { z } from 'zod';

import { difficultySchema, movementPatternSchema, muscleGroupSchema, slugSchema } from './exercise.js';
import { equipmentSchema } from './profile.js';

/* ------------------------------------------------------------- vocabulary -- */

export const SPLIT_TYPES = [
  'full-body',
  'upper-lower',
  'push-pull-legs',
  'upper-lower-full',
  'ppl-upper-lower',
  'custom',
] as const;
export const splitTypeSchema = z.enum(SPLIT_TYPES);
export type SplitType = z.infer<typeof splitTypeSchema>;

export const PROGRAM_SOURCES = ['generated', 'custom'] as const;
export const programSourceSchema = z.enum(PROGRAM_SOURCES);
export type ProgramSource = z.infer<typeof programSourceSchema>;

export const SHORTFALL_REASONS = ['no-performable-exercise', 'session-time', 'limitation'] as const;
export const shortfallReasonSchema = z.enum(SHORTFALL_REASONS);

export const MIN_DAYS_PER_WEEK = 2;
export const MAX_DAYS_PER_WEEK = 6;
export const daysPerWeekSchema = z.number().int().min(MIN_DAYS_PER_WEEK).max(MAX_DAYS_PER_WEEK);

/** 1 = Monday … 7 = Sunday (ISO). */
export const dayOfWeekSchema = z.number().int().min(1).max(7);

/* ----------------------------------------------------------------- read -- */

export const plannedExerciseSchema = z.object({
  id: z.string().uuid(),
  exerciseId: z.string().uuid(),
  slug: slugSchema,
  name: z.string().min(1),
  movementPattern: movementPatternSchema,
  equipment: z.array(equipmentSchema).min(1),
  difficulty: difficultySchema,
  isUnilateral: z.boolean(),
  primaryMuscles: z.array(muscleGroupSchema),
  orderIndex: z.number().int().min(0),
  setCount: z.number().int().min(1).max(10),
  repMin: z.number().int().min(1).max(50),
  repMax: z.number().int().min(1).max(50),
  targetRir: z.number().int().min(0).max(5),
  incrementKg: z.number().positive(),
  /** The generator's justification; null on a custom entry. Rendered verbatim. */
  reason: z.string().nullable(),
});
export type PlannedExercise = z.infer<typeof plannedExerciseSchema>;

export const programDaySchema = z.object({
  id: z.string().uuid(),
  dayOfWeek: dayOfWeekSchema,
  sessionName: z.string().min(1),
  focus: z.array(muscleGroupSchema),
  isRest: z.boolean(),
  /** ~3.5 min per working set (§12.2). Derived, not stored. */
  estimatedMinutes: z.number().int().min(0),
  exercises: z.array(plannedExerciseSchema),
});
export type ProgramDay = z.infer<typeof programDaySchema>;

export const volumeShortfallSchema = z.object({
  muscle: muscleGroupSchema,
  targetSets: z.number(),
  plannedSets: z.number(),
  reason: shortfallReasonSchema,
  detail: z.string(),
});

export const programSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  splitType: splitTypeSchema,
  daysPerWeek: daysPerWeekSchema,
  source: programSourceSchema,
  mesocycleWeek: z.number().int().min(1),
  active: z.boolean(),
  createdAt: z.string().datetime(),
  /** Always seven, Monday first; rest days included so a week is a week. */
  days: z.array(programDaySchema).length(7),
  /** Weekly hard sets per muscle as planned, secondaries at 0.5. Derived on read. */
  weeklyVolume: z.record(muscleGroupSchema, z.number()),
  /** The generator's explanation; empty on a custom programme. */
  rationale: z.array(z.string()),
  shortfalls: z.array(volumeShortfallSchema),
});
export type Program = z.infer<typeof programSchema>;

/* ---------------------------------------------------------------- write -- */

/**
 * `POST /training/program/generate`. Everything comes from the profile
 * (goal, experience, days, equipment, limitations, session length); a body
 * overrides only what a user might reasonably change per programme.
 */
export const generateProgramRequestSchema = z
  .object({
    daysPerWeek: daysPerWeekSchema.optional(),
    preferredSessionMinutes: z.number().int().min(15).max(180).optional(),
  })
  .strict();
export type GenerateProgramRequest = z.infer<typeof generateProgramRequestSchema>;

/** One exercise in a custom day: exercise + prescription. */
export const customExerciseSchema = z
  .object({
    exerciseId: z.string().uuid(),
    setCount: z.number().int().min(1).max(10),
    repMin: z.number().int().min(1).max(50),
    repMax: z.number().int().min(1).max(50),
    targetRir: z.number().int().min(0).max(5),
    /** Defaults to the exercise's own increment when omitted. */
    incrementKg: z.number().positive().optional(),
  })
  .strict()
  .refine((e) => e.repMin <= e.repMax, { message: 'repMin must be ≤ repMax', path: ['repMin'] });
export type CustomExercise = z.infer<typeof customExerciseSchema>;

export const customDaySchema = z
  .object({
    dayOfWeek: dayOfWeekSchema,
    sessionName: z.string().trim().min(1).max(40),
    exercises: z.array(customExerciseSchema).max(15),
  })
  .strict();
export type CustomDay = z.infer<typeof customDaySchema>;

/**
 * `PUT /training/program` — replace the active programme with a custom one.
 * Only training days are sent; the rest of the week is rest. A day with no
 * exercises is rejected — a session must have something in it.
 */
export const putProgramRequestSchema = z
  .object({
    name: z.string().trim().min(1).max(60),
    days: z.array(customDaySchema).min(MIN_DAYS_PER_WEEK).max(MAX_DAYS_PER_WEEK),
  })
  .strict()
  .superRefine((body, ctx) => {
    const seen = new Set<number>();
    body.days.forEach((d, i) => {
      if (seen.has(d.dayOfWeek)) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'duplicate dayOfWeek', path: ['days', i, 'dayOfWeek'] });
      }
      seen.add(d.dayOfWeek);
      if (d.exercises.length === 0) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'a training day needs at least one exercise', path: ['days', i, 'exercises'] });
      }
    });
  });
export type PutProgramRequest = z.infer<typeof putProgramRequestSchema>;

/**
 * `PATCH /training/program/days/{id}` — edit one day of the active programme.
 * Replacing the exercise list on a generated programme keeps the programme
 * `generated`; the day's `reason`s are dropped for the exercises that changed.
 */
export const patchProgramDayRequestSchema = z
  .object({
    sessionName: z.string().trim().min(1).max(40).optional(),
    exercises: z.array(customExerciseSchema).min(1).max(15).optional(),
  })
  .strict()
  .refine((b) => b.sessionName !== undefined || b.exercises !== undefined, { message: 'nothing to change' });
export type PatchProgramDayRequest = z.infer<typeof patchProgramDayRequestSchema>;

export const programDayIdParamsSchema = z.object({ id: z.string().uuid() });
