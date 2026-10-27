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

import { clientIdSchema } from './workout.js';

/* ------------------------------------------------------------- vocabulary -- */

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
  })
  .strict()
  .superRefine((r, ctx) => {
    if (r.kind === 'outdoor') {
      if (r.track === undefined) ctx.addIssue({ code: 'custom', path: ['track'], message: 'an outdoor run needs its track' });
      if (r.distanceM !== undefined) ctx.addIssue({ code: 'custom', path: ['distanceM'], message: 'an outdoor run measures its own distance' });
    } else {
      if (r.distanceM === undefined) ctx.addIssue({ code: 'custom', path: ['distanceM'], message: 'a treadmill run needs its distance' });
      if (r.track !== undefined) ctx.addIssue({ code: 'custom', path: ['track'], message: 'a treadmill run has no track' });
    }
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
