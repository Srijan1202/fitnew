/**
 * Workout logging wire shapes (Phase 5; §9.2 workout_sessions /
 * session_exercises / set_logs / exercise_prs, §10.1 /training/sessions*
 * and /training/today, §33 offline).
 *
 * A session records what the user actually did. Every client-created row
 * carries a client id (`clientSessionId`, `clientExerciseId`, `clientSetId`)
 * so an offline queue can replay a request and the server creates each
 * row once. Nothing here recommends anything: target loads and progression
 * reasoning are Phase 6.
 */
import { z } from 'zod';

import { difficultySchema, movementPatternSchema, muscleGroupSchema, slugSchema } from './exercise.js';
import { equipmentSchema } from './profile.js';
import { dayOfWeekSchema, plannedSetSchema } from './training.js';

/* ------------------------------------------------------------- vocabulary -- */

/** Only `working` sets count toward records (and, in Phase 6, volume). */
export const SET_TYPES = ['warmup', 'working', 'drop', 'backoff'] as const;
export const setTypeSchema = z.enum(SET_TYPES);
export type SetType = z.infer<typeof setTypeSchema>;

/** Explicit; a session never auto-completes (owner decision 8.5). */
export const SESSION_STATUSES = ['active', 'completed', 'abandoned'] as const;
export const sessionStatusSchema = z.enum(SESSION_STATUSES);
export type SessionStatus = z.infer<typeof sessionStatusSchema>;

export const PR_TYPES = ['1rm_est', 'weight', 'reps', 'volume'] as const;
export const prTypeSchema = z.enum(PR_TYPES);
export type PrType = z.infer<typeof prTypeSchema>;

/** Client-generated idempotency keys: UUIDs the client mints offline. */
export const clientIdSchema = z.string().uuid();

export const setWeightKgSchema = z.number().min(0).max(500);
export const repsSchema = z.number().int().min(0).max(100);
export const rirSchema = z.number().int().min(0).max(5);

/* ----------------------------------------------------------------- read -- */

export const setLogSchema = z.object({
  id: z.string().uuid(),
  clientSetId: clientIdSchema,
  setIndex: z.number().int().min(1),
  setType: setTypeSchema,
  weightKg: setWeightKgSchema.nullable(),
  reps: repsSchema,
  rir: rirSchema.nullable(),
  isPr: z.boolean(),
  loggedAt: z.string().datetime(),
  /** The planned set this fulfilled, when the exercise came from a programme day. */
  plannedSetId: z.string().uuid().nullable(),
});
export type SetLog = z.infer<typeof setLogSchema>;

/**
 * What the user did last time on this exercise: the working sets of the
 * most recent completed session, in set order. Shown as "last time"; never
 * a recommendation.
 */
export const lastPerformanceSchema = z.object({
  sessionId: z.string().uuid(),
  completedAt: z.string().datetime(),
  sets: z.array(
    z.object({
      setIndex: z.number().int().min(1),
      weightKg: setWeightKgSchema.nullable(),
      reps: repsSchema,
      rir: rirSchema.nullable(),
    }),
  ),
});
export type LastPerformance = z.infer<typeof lastPerformanceSchema>;

/**
 * What a set row opens with (core `prefillSet`): the plan's target reps,
 * the weight from last time when there is one else the plan's, the plan's
 * RIR. A description of the past and the plan — never a recommendation.
 */
export const setPrefillSchema = z.object({
  setIndex: z.number().int().min(1),
  reps: repsSchema,
  weightKg: setWeightKgSchema.nullable(),
  rir: rirSchema,
  weightSource: z.enum(['recommendation', 'last-session', 'plan', 'none']),
});
export type SetPrefill = z.infer<typeof setPrefillSchema>;

/* ------------------------------------------------- Phase 6: progression -- */

/** §12.4 branches, exactly as `recommendProgression` names them. */
export const PROGRESSION_ACTIONS = ['increase-load', 'add-reps', 'hold', 'reduce-load', 'deload', 'establish-baseline'] as const;
export const progressionActionSchema = z.enum(PROGRESSION_ACTIONS);
export type ProgressionAction = z.infer<typeof progressionActionSchema>;

/**
 * What to do next on a lift (Phase 6, §12.4): the engine's branch, its
 * load (null when it prescribes none), rep target, RIR and — always — the
 * reason. `basis` is 'calculated' from logged history; a recommendation
 * without a reason is a bug.
 */
export const progressionRecommendationSchema = z.object({
  action: progressionActionSchema,
  weightKg: setWeightKgSchema.nullable(),
  repTarget: z.string().min(1),
  targetRir: rirSchema,
  reason: z.string().min(1),
  basis: z.enum(['calculated', 'logged']),
  /** How many completed sessions the decision looked at (≤ 3). */
  sessionsConsidered: z.number().int().min(0).max(3),
});
export type ProgressionRecommendation = z.infer<typeof progressionRecommendationSchema>;

/** The user's best so far on a lift, so a set can be recognised as a record the moment it is logged. */
export const priorBestSchema = z.object({
  weightKg: setWeightKgSchema.nullable(),
  repsAtBestWeight: repsSchema.nullable(),
  estimated1rm: z.number().min(0).nullable(),
});
export type PriorBest = z.infer<typeof priorBestSchema>;

export const SUBSTITUTION_TRIGGERS = ['equipment', 'limitation', 'rejected'] as const;
export const substitutionTriggerSchema = z.enum(SUBSTITUTION_TRIGGERS);

/** §12.6: why a planned lift should be swapped and for what — or, honestly, that the library has nothing. */
export const substitutionSchema = z.object({
  trigger: substitutionTriggerSchema,
  alternative: z
    .object({
      exerciseId: z.string().uuid(),
      slug: slugSchema,
      name: z.string().min(1),
      equipment: z.array(equipmentSchema).min(1),
    })
    .nullable(),
  reason: z.string().min(1),
});
export type Substitution = z.infer<typeof substitutionSchema>;

export const DELOAD_STATES = ['none', 'offered', 'active'] as const;
export const deloadStateSchema = z.object({
  state: z.enum(DELOAD_STATES),
  trigger: z.enum(['fatigue', 'mrv']).nullable(),
  reason: z.string().min(1),
  /** Active: the local date the lighter week ends (exclusive). */
  endsOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
});
export type DeloadState = z.infer<typeof deloadStateSchema>;

export const sessionExerciseSchema = z.object({
  id: z.string().uuid(),
  clientExerciseId: clientIdSchema,
  exerciseId: z.string().uuid(),
  slug: slugSchema,
  name: z.string().min(1),
  movementPattern: movementPatternSchema,
  equipment: z.array(equipmentSchema).min(1),
  difficulty: difficultySchema,
  primaryMuscles: z.array(muscleGroupSchema),
  secondaryMuscles: z.array(muscleGroupSchema),
  incrementKg: z.number().positive(),
  orderIndex: z.number().int().min(0),
  /** Exercises sharing a group alternate sets (owner decision 8.3). */
  supersetGroup: z.number().int().min(1).nullable(),
  /** The programme row this came from; null for an ad-hoc addition. */
  plannedExerciseId: z.string().uuid().nullable(),
  /** The plan's per-set targets at the time the session started; [] for ad-hoc. */
  targets: z.array(plannedSetSchema),
  /** One per target, in order; [] when there are no targets. */
  prefill: z.array(setPrefillSchema),
  lastPerformance: lastPerformanceSchema.nullable(),
  /** Phase 6: null for an ad-hoc exercise with no plan row. */
  recommendation: progressionRecommendationSchema.nullable(),
  priorBest: priorBestSchema,
  /** Targets during an accepted deload week are the lighter ones; the plan's originals sit here. */
  originalTargets: z.array(plannedSetSchema).nullable(),
  sets: z.array(setLogSchema),
});
export type SessionExercise = z.infer<typeof sessionExerciseSchema>;

export const personalRecordSchema = z.object({
  prType: prTypeSchema,
  exerciseId: z.string().uuid(),
  exerciseName: z.string().min(1),
  value: z.number(),
  previous: z.number(),
  setLogId: z.string().uuid(),
  reason: z.string().min(1),
});
export type PersonalRecord = z.infer<typeof personalRecordSchema>;

export const sessionSummarySchema = z.object({
  durationSeconds: z.number().int().min(0),
  totalSets: z.number().int().min(0),
  workingSets: z.number().int().min(0),
  tonnageKg: z.number().min(0),
  hardSetsByMuscle: z.record(muscleGroupSchema, z.number().min(0)),
  exercisesCompleted: z.number().int().min(0),
  exercisesSkipped: z.number().int().min(0),
  prs: z.array(personalRecordSchema),
});
export type SessionSummary = z.infer<typeof sessionSummarySchema>;

export const workoutSessionSchema = z.object({
  id: z.string().uuid(),
  clientSessionId: clientIdSchema,
  status: sessionStatusSchema,
  programId: z.string().uuid().nullable(),
  programDayId: z.string().uuid().nullable(),
  /** The day's name at start ("Push"), or "Session" for ad-hoc. */
  name: z.string().min(1),
  startedAt: z.string().datetime(),
  completedAt: z.string().datetime().nullable(),
  durationSeconds: z.number().int().min(0).nullable(),
  notes: z.string().max(1000).nullable(),
  exercises: z.array(sessionExerciseSchema),
  /** Present once completed. */
  summary: sessionSummarySchema.nullable(),
});
export type WorkoutSession = z.infer<typeof workoutSessionSchema>;

/** A history row: enough for a list, no sets. */
export const sessionListItemSchema = z.object({
  id: z.string().uuid(),
  status: sessionStatusSchema,
  name: z.string().min(1),
  startedAt: z.string().datetime(),
  completedAt: z.string().datetime().nullable(),
  durationSeconds: z.number().int().min(0).nullable(),
  exerciseCount: z.number().int().min(0),
  workingSets: z.number().int().min(0),
  tonnageKg: z.number().min(0),
  prCount: z.number().int().min(0),
});
export type SessionListItem = z.infer<typeof sessionListItemSchema>;

export const sessionListResponseSchema = z.object({
  items: z.array(sessionListItemSchema),
  /** Pass back as `?before=` for the next page; null when this is the last. */
  nextBefore: z.string().datetime().nullable(),
});
export type SessionListResponse = z.infer<typeof sessionListResponseSchema>;

/**
 * GET /training/today: the day to train (or rest), with per-set targets and
 * last performance so the set rows can open pre-filled, and the active
 * session if one is open. Cached offline by the client (§33).
 */
export const todayExerciseSchema = z.object({
  plannedExerciseId: z.string().uuid(),
  exerciseId: z.string().uuid(),
  slug: slugSchema,
  name: z.string().min(1),
  movementPattern: movementPatternSchema,
  equipment: z.array(equipmentSchema).min(1),
  difficulty: difficultySchema,
  primaryMuscles: z.array(muscleGroupSchema),
  secondaryMuscles: z.array(muscleGroupSchema),
  orderIndex: z.number().int().min(0),
  incrementKg: z.number().positive(),
  targets: z.array(plannedSetSchema),
  prefill: z.array(setPrefillSchema),
  lastPerformance: lastPerformanceSchema.nullable(),
  recommendation: progressionRecommendationSchema.nullable(),
  priorBest: priorBestSchema,
  originalTargets: z.array(plannedSetSchema).nullable(),
  substitution: substitutionSchema.nullable(),
});

export const todayResponseSchema = z.object({
  /** Local calendar date the server used (user's timezone). */
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  dayOfWeek: dayOfWeekSchema,
  programId: z.string().uuid().nullable(),
  programDayId: z.string().uuid().nullable(),
  sessionName: z.string().nullable(),
  isRest: z.boolean(),
  focus: z.array(muscleGroupSchema),
  exercises: z.array(todayExerciseSchema),
  /** An `active` session, whatever day it belongs to, or null. */
  activeSession: workoutSessionSchema.nullable(),
  /** A session completed today for this day, if any (so TODAY can say "Done"). */
  completedSessionId: z.string().uuid().nullable(),
  /** Phase 6. */
  mesocycleWeek: z.number().int().min(1).nullable(),
  deload: deloadStateSchema,
  /** Owned muscles with no working set in the last 6 days (owner 12.7). */
  neglected: z.array(z.object({ muscle: muscleGroupSchema, daysSince: z.number().int().min(0).nullable() })),
});
export type TodayResponse = z.infer<typeof todayResponseSchema>;

/* ---------------------------------------------------- Phase 6: volume -- */

export const LANDMARK_STATUSES = ['none', 'below-mv', 'below-mev', 'mev-to-mav', 'above-mav', 'at-mrv'] as const;
export const landmarkStatusSchema = z.enum(LANDMARK_STATUSES);

export const muscleWeekSchema = z.object({
  muscle: muscleGroupSchema,
  hardSets: z.number().min(0),
  tonnageKg: z.number().min(0),
  status: landmarkStatusSchema,
  landmarks: z.object({ mv: z.number(), mev: z.number(), mavLow: z.number(), mavHigh: z.number(), mrv: z.number() }),
  owned: z.boolean(),
});

export const volumeResponseSchema = z.object({
  /** Oldest first; the last entry is the current ISO week. */
  weeks: z.array(z.object({ isoWeek: z.string().regex(/^\d{4}-W\d{2}$/), muscles: z.array(muscleWeekSchema) })),
  owned: z.array(muscleGroupSchema),
  neglected: z.array(z.object({ muscle: muscleGroupSchema, daysSince: z.number().int().min(0).nullable() })),
  mesocycleWeek: z.number().int().min(1).nullable(),
  deload: deloadStateSchema,
});
export type VolumeResponse = z.infer<typeof volumeResponseSchema>;

/** One lift's last three sessions and what the engine makes of them. */
export const progressionDetailSchema = z.object({
  exerciseId: z.string().uuid(),
  name: z.string().min(1),
  target: z.object({ repMin: z.number().int(), repMax: z.number().int(), targetRir: rirSchema, sets: z.number().int(), incrementKg: z.number().positive() }).nullable(),
  recommendation: progressionRecommendationSchema,
  history: z.array(
    z.object({
      sessionId: z.string().uuid(),
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      sets: z.array(z.object({ setIndex: z.number().int().min(1), weightKg: setWeightKgSchema.nullable(), reps: repsSchema, rir: rirSchema.nullable() })),
    }),
  ),
});
export type ProgressionDetail = z.infer<typeof progressionDetailSchema>;

export const progressionParamsSchema = z.object({ exerciseId: z.string().uuid() });

/* ---------------------------------------------------------------- write -- */

/**
 * An exercise the client seeded locally before the server heard of the
 * session (offline start). Sending them lets the server adopt the
 * client's ids, so sets logged against them replay cleanly.
 */
export const seededExerciseSchema = z
  .object({
    clientExerciseId: clientIdSchema,
    exerciseId: z.string().uuid(),
    plannedExerciseId: z.string().uuid().optional(),
    orderIndex: z.number().int().min(0),
  })
  .strict();

export const startSessionRequestSchema = z
  .object({
    clientSessionId: clientIdSchema,
    /** Omit for an ad-hoc session (owner decision 8.6). */
    programDayId: z.string().uuid().optional(),
    startedAt: z.string().datetime(),
    /** When present, seeds these instead of the day's planned exercises. */
    exercises: z.array(seededExerciseSchema).max(30).optional(),
  })
  .strict();
export type StartSessionRequest = z.infer<typeof startSessionRequestSchema>;

/** One set in a batch. Exactly one of `sessionExerciseId` / `clientExerciseId` names the exercise. */
export const logSetSchema = z
  .object({
    clientSetId: clientIdSchema,
    sessionExerciseId: z.string().uuid().optional(),
    clientExerciseId: clientIdSchema.optional(),
    setIndex: z.number().int().min(1).max(50),
    setType: setTypeSchema.default('working'),
    weightKg: setWeightKgSchema.nullable().default(null),
    reps: repsSchema,
    rir: rirSchema.nullable().default(null),
    loggedAt: z.string().datetime(),
    plannedSetId: z.string().uuid().optional(),
  })
  .strict()
  .refine((s) => (s.sessionExerciseId === undefined) !== (s.clientExerciseId === undefined), {
    message: 'exactly one of sessionExerciseId or clientExerciseId',
    path: ['sessionExerciseId'],
  });

export const logSetsRequestSchema = z
  .object({
    sets: z.array(logSetSchema).min(1).max(50),
    /** §33: the session was completed elsewhere; add these sets to it anyway. */
    merge: z.boolean().default(false),
  })
  .strict();
export type LogSetsRequest = z.infer<typeof logSetsRequestSchema>;

export const patchSetRequestSchema = z
  .object({
    setType: setTypeSchema.optional(),
    weightKg: setWeightKgSchema.nullable().optional(),
    reps: repsSchema.optional(),
    rir: rirSchema.nullable().optional(),
  })
  .strict()
  .refine((p) => Object.keys(p).length > 0, { message: 'nothing to change' });
export type PatchSetRequest = z.infer<typeof patchSetRequestSchema>;

export const addSessionExerciseRequestSchema = z
  .object({
    clientExerciseId: clientIdSchema,
    exerciseId: z.string().uuid(),
    /** When replacing or adding a planned movement mid-session. */
    plannedExerciseId: z.string().uuid().optional(),
    /** Insert position; appended when omitted. */
    orderIndex: z.number().int().min(0).optional(),
    supersetGroup: z.number().int().min(1).optional(),
  })
  .strict();
export type AddSessionExerciseRequest = z.infer<typeof addSessionExerciseRequestSchema>;

export const patchSessionExerciseRequestSchema = z
  .object({
    orderIndex: z.number().int().min(0).optional(),
    supersetGroup: z.number().int().min(1).nullable().optional(),
    /** Replace the movement; logged sets stay with the row (no load carries over — the user retypes). */
    exerciseId: z.string().uuid().optional(),
    /** Drop the exercise from the session (its sets go with it). */
    removed: z.literal(true).optional(),
  })
  .strict()
  .refine((p) => Object.keys(p).length > 0, { message: 'nothing to change' });
export type PatchSessionExerciseRequest = z.infer<typeof patchSessionExerciseRequestSchema>;

export const completeSessionRequestSchema = z
  .object({
    completedAt: z.string().datetime(),
    notes: z.string().trim().max(1000).optional(),
  })
  .strict();
export type CompleteSessionRequest = z.infer<typeof completeSessionRequestSchema>;

export const sessionListQuerySchema = z.object({
  /** ISO timestamp: sessions started strictly before it. */
  before: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  status: sessionStatusSchema.optional(),
});
export type SessionListQuery = z.infer<typeof sessionListQuerySchema>;

export const todayQuerySchema = z.object({
  /** Another day of the week, for the day screen; defaults to today. */
  dayOfWeek: z.coerce.number().int().min(1).max(7).optional(),
});

export const sessionParamsSchema = z.object({ id: z.string().uuid() });
export const sessionSetParamsSchema = z.object({ id: z.string().uuid(), setId: z.string().uuid() });
export const sessionExerciseParamsSchema = z.object({ id: z.string().uuid(), exerciseId: z.string().uuid() });
