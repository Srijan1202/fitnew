/**
 * Running (beta 4.0, ADR-038): a run as the phone records it and as the
 * server keeps it.
 *
 * A run is recorded on the phone and sent once it is finished, with the
 * client id the phone minted at the start (`clientRunId`), so a replayed
 * upload creates it once. It is addressed by that id everywhere. The server
 * recomputes every figure from the track in packages/core; the phone's own
 * figures are a live view and an offline preview only.
 */
import { z } from 'zod';

import { isoDateSchema } from './profile.js';
import { clientIdSchema } from './workout.js';

/* ------------------------------------------------------------- vocabulary -- */

/** Beta 4.5: where a run was recorded — on the phone, or a Galaxy Watch (through Health Connect). */
export const RUN_SOURCES = ['phone', 'watch'] as const;
export const runSourceSchema = z.enum(RUN_SOURCES);
export type RunSource = z.infer<typeof runSourceSchema>;

/** Heart rate in beats a minute, as a watch reports it. */
export const heartRateSchema = z.number().int().min(25).max(250);

/** Outdoor runs carry a GPS track; treadmill runs a typed distance. */
export const RUN_KINDS = ['outdoor', 'treadmill'] as const;
export const runKindSchema = z.enum(RUN_KINDS);
export type RunKind = z.infer<typeof runKindSchema>;

/** What the runner set out to do. `value`: metres, seconds, or seconds per km. */
export const RUN_GOAL_KINDS = ['free', 'distance', 'time', 'pace'] as const;
export const runGoalKindSchema = z.enum(RUN_GOAL_KINDS);
export type RunGoalKind = z.infer<typeof runGoalKindSchema>;

/** The goal's allowed values: 100 m–1,000 km, 1 min–24 h, 2:00–20:00 per km. */
export const RUN_GOAL_LIMITS = {
  distance: { min: 100, max: 1_000_000 },
  time: { min: 60, max: 86_400 },
  pace: { min: 120, max: 1200 },
} as const;

/** A run lasts at most 48 hours. */
export const RUN_MAX_SECONDS = 172_800;
/** A typed treadmill distance is at most 200 km. */
export const RUN_MAX_TREADMILL_M = 200_000;
/** The encoded track is at most this long (50,000 points, generously). */
export const RUN_MAX_TRACK_CHARS = 1_500_000;
export const RUN_NAME_MAX = 60;
export const RUN_NOTE_MAX = 500;

export const runGoalSchema = z
  .object({ kind: runGoalKindSchema, value: z.number().int().nullable() })
  .strict()
  .superRefine((g, ctx) => {
    if (g.kind === 'free') {
      if (g.value !== null) ctx.addIssue({ code: 'custom', path: ['value'], message: 'a free run has no goal value' });
      return;
    }
    const { min, max } = RUN_GOAL_LIMITS[g.kind];
    if (g.value === null || g.value < min || g.value > max) {
      ctx.addIssue({ code: 'custom', path: ['value'], message: `must be between ${min} and ${max}` });
    }
  });
export type RunGoal = z.infer<typeof runGoalSchema>;

/** The track on the wire (packages/core running/track: encoding v1). */
export const runTrackSchema = z
  .object({
    v: z.literal(1),
    points: z.string().max(RUN_MAX_TRACK_CHARS),
    /** Index of each segment's first point after the first (a pause before it). */
    breaks: z.array(z.number().int().min(1)).max(5000),
    elevation: z.boolean(),
  })
  .strict();
export type RunTrack = z.infer<typeof runTrackSchema>;

export const runEffortSchema = z.number().int().min(1).max(10);
export const runNameSchema = z.string().trim().min(1).max(RUN_NAME_MAX);
export const runNoteSchema = z.string().trim().max(RUN_NOTE_MAX);

/* ------------------------------------------- beta 4.1: workouts and laps -- */

/** A pace range, seconds per km (`fast` the lower). */
export const paceRangeSchema = z
  .object({ fast: z.number().int().min(60).max(1800), slow: z.number().int().min(60).max(1800) })
  .strict()
  .refine((p) => p.fast <= p.slow, { message: 'fast is the lower number' });

export const WORKOUT_STEP_KINDS = ['warmup', 'work', 'recover', 'cooldown'] as const;
export const MAX_WORKOUT_STEPS = 120;

/** One step of a structured run (packages/core running/workout): it ends after its distance or its time. */
export const workoutStepSchema = z
  .object({
    kind: z.enum(WORKOUT_STEP_KINDS),
    distanceM: z.number().min(1).max(100_000).nullable(),
    seconds: z.number().int().min(1).max(36_000).nullable(),
    pace: paceRangeSchema.nullable(),
    effort: z.string().max(40),
    rep: z.object({ index: z.number().int().min(1), of: z.number().int().min(1) }).strict().nullable(),
  })
  .strict()
  .refine((st) => (st.distanceM === null) !== (st.seconds === null), { message: 'a step ends after a distance or a time, exactly one' });
export type WorkoutStep = z.infer<typeof workoutStepSchema>;

export const runWorkoutSchema = z
  .object({ name: z.string().trim().min(1).max(60), steps: z.array(workoutStepSchema).min(1).max(MAX_WORKOUT_STEPS) })
  .strict();
export type RunWorkout = z.infer<typeof runWorkoutSchema>;

/** Where a step began and ended on the run's clock (the track's own seconds). */
export const lapMarkSchema = z
  .object({ step: z.number().int().min(0), startT: z.number().min(0), endT: z.number().min(0) })
  .strict();
export const lapSchema = z
  .object({ step: z.number().int().min(0), distanceM: z.number(), seconds: z.number(), pace: z.number().nullable() })
  .strict();
export type Lap = z.infer<typeof lapSchema>;

/* ---------------------------------------------------------------- results -- */

export const runSplitSchema = z
  .object({
    index: z.number().int().min(1),
    distanceM: z.number(),
    seconds: z.number(),
    /** Seconds per unit: per km in `splitsKm`, per mile in `splitsMi`. */
    pace: z.number(),
    elevationChangeM: z.number().nullable(),
  })
  .strict();
export type RunSplit = z.infer<typeof runSplitSchema>;

export const runSeriesPointSchema = z
  .object({ distanceM: z.number(), pace: z.number(), ele: z.number().nullable() })
  .strict();
export type RunSeriesPoint = z.infer<typeof runSeriesPointSchema>;

/* ------------------------------------------------ best efforts (beta 4.2) -- */

/**
 * Beta 4.2 (owner 2026-10-29): the fastest stretch of each distance inside a
 * run, on moving time (core running/efforts.ts, the same keys).
 */
export const EFFORT_KEYS = ['400m', '1k', '1mile', '5k', '10k', 'half', 'marathon'] as const;
export const effortKeySchema = z.enum(EFFORT_KEYS);
export type EffortKey = z.infer<typeof effortKeySchema>;

/** One distance in one run, and where it stands among all the user's (1 = the record). */
export const runBestEffortSchema = z
  .object({
    key: effortKeySchema,
    seconds: z.number(),
    /** Metres from the start of the run where the stretch begins. */
    startM: z.number(),
    rank: z.number().int().min(1).max(3).nullable(),
  })
  .strict();
export type RunBestEffort = z.infer<typeof runBestEffortSchema>;

/** A history-list row. */
export const runSummarySchema = z
  .object({
    id: clientIdSchema,
    kind: runKindSchema,
    name: z.string(),
    startedAt: z.string().datetime(),
    endedAt: z.string().datetime(),
    /** The active time the phone's timer showed (pauses excluded). */
    durationSeconds: z.number().int(),
    distanceM: z.number(),
    /** Seconds per km; null under 10 m. */
    avgPaceSecPerKm: z.number().nullable(),
    elevationGainM: z.number().nullable(),
    /** Gross kcal (ACSM); null without a body weight. */
    calories: z.number().int().nullable(),
    effort: runEffortSchema.nullable(),
    /** Up to 64 [lat, lon] points for the list's little map; empty indoors. */
    outline: z.array(z.tuple([z.number(), z.number()])),
    /** Beta 4.2: the distances this run holds the record for (history's trophy). */
    recordKeys: z.array(effortKeySchema),
    /** Beta 4.5: the phone or a Galaxy Watch, and the watch's average and max heart rate. */
    source: runSourceSchema,
    hrAvg: heartRateSchema.nullable(),
    hrMax: heartRateSchema.nullable(),
  })
  .strict();
export type RunSummary = z.infer<typeof runSummarySchema>;

/** One run in full. */
export const runDetailSchema = runSummarySchema
  .extend({
    note: z.string().nullable(),
    goal: runGoalSchema,
    track: runTrackSchema.nullable(),
    splitsKm: z.array(runSplitSchema),
    splitsMi: z.array(runSplitSchema),
    series: z.array(runSeriesPointSchema),
    /** Beta 4.1: the structured session, its laps (core, from the track) and the planned run it did. */
    workout: runWorkoutSchema.nullable(),
    laps: z.array(lapSchema),
    plannedRunId: z.string().uuid().nullable(),
    /** Beta 4.2: every distance the run covers, at its fastest (outdoor only). */
    efforts: z.array(runBestEffortSchema),
  })
  .strict();
export type RunDetail = z.infer<typeof runDetailSchema>;

export const runTotalsSchema = z
  .object({ runs: z.number().int().min(0), distanceM: z.number(), durationSeconds: z.number().int().min(0) })
  .strict();
export type RunTotals = z.infer<typeof runTotalsSchema>;

/* -------------------------------------------------------------- requests -- */

/** POST /running/runs: a finished run. 201 the first time, 200 on a replay. */
export const createRunRequestSchema = z
  .object({
    clientRunId: clientIdSchema,
    kind: runKindSchema,
    name: runNameSchema,
    startedAt: z.string().datetime(),
    endedAt: z.string().datetime(),
    durationSeconds: z.number().int().min(0).max(RUN_MAX_SECONDS),
    goal: runGoalSchema,
    note: runNoteSchema.nullable().optional(),
    effort: runEffortSchema.nullable().optional(),
    /** Outdoor only, and required there. */
    track: runTrackSchema.optional(),
    /** Treadmill only, and required there. */
    distanceM: z.number().min(0).max(RUN_MAX_TREADMILL_M).optional(),
    /** Beta 4.1: the structured session run, and where each step began and ended (outdoor). */
    workout: runWorkoutSchema.optional(),
    laps: z.array(lapMarkSchema).max(MAX_WORKOUT_STEPS).optional(),
    /** Beta 4.1: the plan's run this one did. */
    plannedRunId: z.string().uuid().optional(),
    /**
     * Beta 4.5: a run from a Galaxy Watch (Health Connect): its record id
     * there (imported once), and the watch's heart rate. A watch run outdoors
     * may come without a route, with the watch's distance instead.
     */
    source: runSourceSchema.optional(),
    externalId: z.string().min(1).max(200).optional(),
    hrAvg: heartRateSchema.optional(),
    hrMax: heartRateSchema.optional(),
  })
  .strict()
  .superRefine((r, ctx) => {
    const watch = r.source === 'watch';
    if (watch !== (r.externalId !== undefined)) {
      ctx.addIssue({ code: 'custom', path: ['externalId'], message: 'a watch run, and only a watch run, has its record id' });
    }
    if (!watch && (r.hrAvg !== undefined || r.hrMax !== undefined)) {
      ctx.addIssue({ code: 'custom', path: ['hrAvg'], message: 'heart rate comes from a watch' });
    }
    if (r.kind === 'outdoor') {
      const routeless = watch && r.track === undefined;
      if (r.track === undefined && !watch) ctx.addIssue({ code: 'custom', path: ['track'], message: 'an outdoor run needs its track' });
      if (routeless && r.distanceM === undefined) ctx.addIssue({ code: 'custom', path: ['distanceM'], message: 'a watch run without its route needs its distance' });
      if (!routeless && r.distanceM !== undefined) ctx.addIssue({ code: 'custom', path: ['distanceM'], message: 'an outdoor run measures its own distance' });
    } else {
      if (r.distanceM === undefined) ctx.addIssue({ code: 'custom', path: ['distanceM'], message: 'a treadmill run needs its distance' });
      if (r.track !== undefined) ctx.addIssue({ code: 'custom', path: ['track'], message: 'a treadmill run has no track' });
    }
    if (r.laps !== undefined && r.workout === undefined) ctx.addIssue({ code: 'custom', path: ['laps'], message: 'laps need their workout' });
    const start = Date.parse(r.startedAt);
    const end = Date.parse(r.endedAt);
    if (end < start) ctx.addIssue({ code: 'custom', path: ['endedAt'], message: 'a run ends after it starts' });
    else if (r.durationSeconds > Math.ceil((end - start) / 1000) + 1) {
      ctx.addIssue({ code: 'custom', path: ['durationSeconds'], message: 'longer than the run itself' });
    } else if (end - start > RUN_MAX_SECONDS * 1000) {
      ctx.addIssue({ code: 'custom', path: ['endedAt'], message: 'a run lasts at most 48 hours' });
    }
  });
export type CreateRunRequest = z.infer<typeof createRunRequestSchema>;

/** PATCH /running/runs/{id}: the runner's own words. At least one field. */
export const patchRunRequestSchema = z
  .object({
    name: runNameSchema.optional(),
    note: runNoteSchema.nullable().optional(),
    effort: runEffortSchema.nullable().optional(),
  })
  .strict()
  .refine((p) => p.name !== undefined || p.note !== undefined || p.effort !== undefined, { message: 'change at least one field' });
export type PatchRunRequest = z.infer<typeof patchRunRequestSchema>;

export const runParamsSchema = z.object({ id: clientIdSchema }).strict();

/** GET /running/runs: newest first, 20 a page; `before` is the last row's `startedAt`. */
export const runListQuerySchema = z
  .object({ before: z.string().datetime().optional(), limit: z.coerce.number().int().min(1).max(50).optional() })
  .strict();

export const runListSchema = z
  .object({
    runs: z.array(runSummarySchema),
    nextBefore: z.string().datetime().nullable(),
    /** This week (Monday on) and this calendar month, in the user's timezone. */
    totals: z.object({ week: runTotalsSchema, month: runTotalsSchema }).strict(),
  })
  .strict();
export type RunList = z.infer<typeof runListSchema>;

/** One of the best three efforts at a distance. */
export const recordEntrySchema = z
  .object({ runId: clientIdSchema, name: z.string(), startedAt: z.string().datetime(), seconds: z.number() })
  .strict();

/**
 * GET /running/records (beta 4.2): the best three at each distance, in
 * [EFFORT_KEYS] order (empty where none yet). `pending`: older runs not
 * worked out yet (they are, a batch a request).
 */
export const runningRecordsSchema = z
  .object({
    records: z.array(z.object({ key: effortKeySchema, best: z.array(recordEntrySchema).max(3) }).strict()),
    pending: z.number().int().min(0),
    /** Beta 4.3: the longest single run, metres (0 with none): how far each distance badge is. */
    longestM: z.number().min(0),
    /** Beta 4.5: every run's distance added up, metres: how far each lifetime badge is. */
    totalM: z.number().min(0),
  })
  .strict();
export type RunningRecords = z.infer<typeof runningRecordsSchema>;

/* ------------------------------------- your own sessions (beta 4.4, E28) -- */

/** The most sessions one user keeps. */
export const MAX_MY_WORKOUTS = 50;

/** A session the runner built, kept with the account (the phone's id). */
export const myWorkoutSchema = z
  .object({
    id: clientIdSchema,
    name: z.string(),
    steps: z.array(workoutStepSchema),
    updatedAt: z.string().datetime(),
  })
  .strict();
export type MyWorkout = z.infer<typeof myWorkoutSchema>;

/** GET /running/my-workouts: newest first. */
export const myWorkoutListSchema = z.object({ workouts: z.array(myWorkoutSchema).max(MAX_MY_WORKOUTS) }).strict();
export type MyWorkoutList = z.infer<typeof myWorkoutListSchema>;

/** PUT /running/my-workouts/{id}: created or replaced (idempotent). */
export const putMyWorkoutRequestSchema = runWorkoutSchema;

/* --------------------------------------------------- beta 4.1: plans -- */

export const PLAN_GOALS = ['5k', '10k', 'half', 'marathon'] as const;
export const planGoalSchema = z.enum(PLAN_GOALS);
export type PlanGoal = z.infer<typeof planGoalSchema>;
export const PLAN_LEVELS = ['beginner', 'runner'] as const;
export const PLANNED_RUN_KINDS = ['easy', 'long', 'tempo', 'intervals', 'run-walk', 'race'] as const;
export const PLANNED_RUN_STATUSES = ['planned', 'done', 'skipped'] as const;
export const RUNNING_PLAN_STATUSES = ['active', 'stopped', 'done'] as const;

const weekdaySchema = z.number().int().min(1).max(7);

/** POST /running/plans: replaces the active plan, if any. */
export const createPlanRequestSchema = z
  .object({
    goal: planGoalSchema,
    level: z.enum(PLAN_LEVELS),
    /** A recent race or time trial (runner), at any of the four distances. */
    race: z.object({ distance: planGoalSchema, seconds: z.number().int().min(60).max(86_400) }).strict().nullable(),
    /** Or a goal time at the plan's own distance. */
    goalSeconds: z.number().int().min(600).max(86_400).nullable(),
    /** Beta 4.4 (owner): 1–5 for every plan (3–5 before). */
    daysPerWeek: z.union([z.literal(1), z.literal(2), z.literal(3), z.literal(4), z.literal(5)]),
    weekdays: z.array(weekdaySchema).min(1).max(5),
    longRunWeekday: weekdaySchema,
    /** Defaults to today (the user's zone). */
    startDate: isoDateSchema.optional(),
  })
  .strict()
  .superRefine((p, ctx) => {
    if (p.level === 'runner' && p.race === null && p.goalSeconds === null) {
      ctx.addIssue({ code: 'custom', path: ['race'], message: 'a recent race or a goal time is needed' });
    }
  });
export type CreatePlanRequest = z.infer<typeof createPlanRequestSchema>;

export const plannedRunSchema = z
  .object({
    id: z.string().uuid(),
    date: isoDateSchema,
    week: z.number().int().min(1),
    kind: z.enum(PLANNED_RUN_KINDS),
    title: z.string(),
    distanceM: z.number().nullable(),
    seconds: z.number().int().nullable(),
    pace: paceRangeSchema.nullable(),
    steps: z.array(workoutStepSchema).nullable(),
    note: z.string(),
    status: z.enum(PLANNED_RUN_STATUSES),
    /** The run that did it. */
    runId: z.string().uuid().nullable(),
    /** The date it was planned for before a move. */
    movedFrom: isoDateSchema.nullable(),
  })
  .strict();
export type PlannedRun = z.infer<typeof plannedRunSchema>;

export const paceZonesSchema = z
  .object({
    vdot: z.number(),
    easy: paceRangeSchema,
    marathon: z.number().int(),
    threshold: z.number().int(),
    interval: z.number().int(),
    repetition: z.number().int(),
  })
  .strict();
export type PaceZones = z.infer<typeof paceZonesSchema>;

export const runningPlanSchema = z
  .object({
    id: z.string().uuid(),
    goal: planGoalSchema,
    level: z.enum(PLAN_LEVELS),
    status: z.enum(RUNNING_PLAN_STATUSES),
    daysPerWeek: z.number().int(),
    weekdays: z.array(weekdaySchema),
    longRunWeekday: weekdaySchema,
    startDate: isoDateSchema,
    weeks: z.number().int(),
    zones: paceZonesSchema.nullable(),
    /** The predicted race time at the plan's fitness; null for a beginner. */
    predictedSeconds: z.number().int().nullable(),
    /** Running weekdays that are also gym days: a warning (owner: allowed). */
    gymOverlap: z.array(weekdaySchema),
    runs: z.array(plannedRunSchema),
  })
  .strict();
export type RunningPlan = z.infer<typeof runningPlanSchema>;

/** GET /running/plans/current. */
export const currentPlanSchema = z.object({ plan: runningPlanSchema.nullable() }).strict();
export type CurrentPlan = z.infer<typeof currentPlanSchema>;

/** PATCH /running/planned/{id}: skip, un-skip, or move within its week. */
export const patchPlannedRunRequestSchema = z
  .object({ action: z.enum(['skip', 'unskip', 'move']), date: isoDateSchema.optional() })
  .strict()
  .refine((p) => (p.action === 'move') === (p.date !== undefined), { message: 'a move needs its date, and only a move' });
export type PatchPlannedRunRequest = z.infer<typeof patchPlannedRunRequestSchema>;
export const plannedRunParamsSchema = z.object({ id: z.string().uuid() }).strict();

/** GET /running/workouts: FITOS's ready-made sessions, paced from the active plan's zones when there is one. */
export const workoutPresetsSchema = z
  .object({
    zones: paceZonesSchema.nullable(),
    presets: z.array(z.object({ id: z.string(), name: z.string(), about: z.string(), steps: z.array(workoutStepSchema) }).strict()),
  })
  .strict();
export type WorkoutPresets = z.infer<typeof workoutPresetsSchema>;
