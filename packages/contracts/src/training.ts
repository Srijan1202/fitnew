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

/** The generator's §12.2 splits, then each professional template's slug, then custom. */
export const SPLIT_TYPES = [
  'full-body',
  'upper-lower',
  'push-pull-legs',
  'upper-lower-full',
  'ppl-upper-lower',
  'bro-split',
  'upper-lower-6',
  'full-body-2',
  'push-pull',
  'two-muscle',
  'bodybuilding-5',
  'full-body-3',
  'upper-lower-4',
  'push-pull-legs-6',
  'custom',
] as const;
export const splitTypeSchema = z.enum(SPLIT_TYPES);
export type SplitType = z.infer<typeof splitTypeSchema>;

export const PROGRAM_SOURCES = ['generated', 'template', 'custom'] as const;
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

/**
 * One planned set: the TARGET for that set (Phase 4 rework, owner decision
 * 2026-09-21). A rep range as the spec models it (§12.4), collapsed to a
 * single number when the user pins one; a starting weight the user typed,
 * or null — the generator never invents a load (§12.4 rule 1). What the
 * lifter actually did is Phase 5's `set_logs`, which overlay these.
 */
export const plannedSetSchema = z.object({
  /** The planned_sets row, so a logged set can name the target it fulfilled (Phase 5). */
  id: z.string().uuid().optional(),
  setIndex: z.number().int().min(1),
  repsMin: z.number().int().min(1).max(50),
  repsMax: z.number().int().min(1).max(50),
  weightKg: z.number().min(0).max(500).nullable(),
  rir: z.number().int().min(0).max(5),
});
export type PlannedSet = z.infer<typeof plannedSetSchema>;

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
  /** Exactly `setCount` entries, ordered by setIndex. */
  sets: z.array(plannedSetSchema).min(1),
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
  /** Set when the programme came from the professional library. */
  templateSlug: z.string().nullable(),
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

/** A per-set target sent by the client. */
export const customSetSchema = z
  .object({
    repsMin: z.number().int().min(1).max(50),
    repsMax: z.number().int().min(1).max(50),
    weightKg: z.number().min(0).max(500).nullable(),
    rir: z.number().int().min(0).max(5),
  })
  .strict()
  .refine((s) => s.repsMin <= s.repsMax, { message: 'repsMin must be <= repsMax', path: ['repsMin'] });
export type CustomSet = z.infer<typeof customSetSchema>;

/**
 * One exercise in a custom day: exercise + prescription. `sets`, when sent,
 * must have exactly `setCount` entries and carries the per-set targets;
 * when omitted every set is the prescription with `startingWeightKg` (or
 * no weight).
 */
export const customExerciseSchema = z
  .object({
    /**
     * The planned exercise this row continues, when editing a day. The
     * server keeps that row (and so its id) instead of deleting and
     * re-inserting; clients key UI state — an expanded card — by it.
     * Unknown or missing ⇒ a new row.
     */
    id: z.string().uuid().optional(),
    exerciseId: z.string().uuid(),
    setCount: z.number().int().min(1).max(10),
    repMin: z.number().int().min(1).max(50),
    repMax: z.number().int().min(1).max(50),
    targetRir: z.number().int().min(0).max(5),
    /** Defaults to the exercise's own increment when omitted. */
    incrementKg: z.number().positive().optional(),
    startingWeightKg: z.number().min(0).max(500).optional(),
    sets: z.array(customSetSchema).min(1).max(10).optional(),
  })
  .strict()
  .superRefine((e, ctx) => {
    if (e.repMin > e.repMax) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'repMin must be <= repMax', path: ['repMin'] });
    }
    if (e.sets !== undefined && e.sets.length !== e.setCount) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'sets must have exactly setCount entries', path: ['sets'] });
    }
  });
export type CustomExercise = z.infer<typeof customExerciseSchema>;

export const customDaySchema = z
  .object({
    dayOfWeek: dayOfWeekSchema,
    sessionName: z.string().trim().min(1).max(40),
    /** Muscle groups the user chose for the day; derived from the exercises when omitted. */
    focus: z.array(muscleGroupSchema).max(10).optional(),
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
    focus: z.array(muscleGroupSchema).max(10).optional(),
    exercises: z.array(customExerciseSchema).min(1).max(15).optional(),
  })
  .strict()
  .refine((b) => b.sessionName !== undefined || b.exercises !== undefined || b.focus !== undefined, {
    message: 'nothing to change',
  });
export type PatchProgramDayRequest = z.infer<typeof patchProgramDayRequestSchema>;

export const patchProgramRequestSchema = z.object({ name: z.string().trim().min(1).max(60) }).strict();
export type PatchProgramRequest = z.infer<typeof patchProgramRequestSchema>;

export const programDayIdParamsSchema = z.object({ id: z.string().uuid() });

/* ------------------------------------------------------------ templates -- */

export const TEMPLATE_LEVELS = ['beginner', 'intermediate', 'advanced', 'any'] as const;
export const templateLevelSchema = z.enum(TEMPLATE_LEVELS);

/** A professional template as listed: structure only, no exercises yet. */
export const programTemplateSchema = z.object({
  slug: z.string().min(1),
  name: z.string().min(1),
  daysPerWeek: daysPerWeekSchema,
  level: templateLevelSchema,
  approxMinutes: z.number().int().positive(),
  summary: z.string().min(1),
  days: z.array(
    z.object({
      dayOfWeek: dayOfWeekSchema,
      sessionName: z.string().min(1),
      muscles: z.array(muscleGroupSchema),
    }),
  ),
});
export type ProgramTemplate = z.infer<typeof programTemplateSchema>;

export const templateListResponseSchema = z.object({ items: z.array(programTemplateSchema) });

/** A day of a preview: like a programme day but not yet persisted (no ids). */
export const previewExerciseSchema = plannedExerciseSchema.omit({ id: true });
export const previewDaySchema = programDaySchema.omit({ id: true, exercises: true }).extend({
  exercises: z.array(previewExerciseSchema),
});

/** `GET /training/templates/{slug}` — materialised for THIS user; nothing stored. */
export const templatePreviewSchema = z.object({
  template: programTemplateSchema,
  days: z.array(previewDaySchema).length(7),
  weeklyVolume: z.record(muscleGroupSchema, z.number()),
  rationale: z.array(z.string()),
  shortfalls: z.array(volumeShortfallSchema),
});
export type TemplatePreview = z.infer<typeof templatePreviewSchema>;

export const templateSlugParamsSchema = z.object({ slug: z.string().min(1).max(64) });

/** Same overrides as generate, as a query string (preview is a GET). */
export const templatePreviewQuerySchema = z
  .object({
    daysPerWeek: z.coerce.number().int().min(MIN_DAYS_PER_WEEK).max(MAX_DAYS_PER_WEEK).optional(),
    preferredSessionMinutes: z.coerce.number().int().min(15).max(180).optional(),
  })
  .strict();
