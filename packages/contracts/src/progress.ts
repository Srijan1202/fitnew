/**
 * Progress (Phase 12, MASTER-SPEC §17, §10.1; ADR-018): the summary read,
 * and the two writes the spec names. Every number is computed on the server
 * from the user's own rows, on read; nothing derived is stored (§9.4).
 * There is no day-over-day figure: every change covers at least 7 days.
 */
import { z } from 'zod';

import { isoDateSchema, weightKgSchema } from './profile.js';
import { prTypeSchema } from './workout.js';

export const PROGRESS_WINDOWS = ['30d', '90d'] as const;
export const progressWindowSchema = z.enum(PROGRESS_WINDOWS);
export type ProgressWindow = z.infer<typeof progressWindowSchema>;

export const MEASUREMENT_SITES = ['waist', 'chest', 'arm', 'thigh', 'hip'] as const;
export const measurementSiteSchema = z.enum(MEASUREMENT_SITES);
export type MeasurementSite = z.infer<typeof measurementSiteSchema>;

/** Plausible tape readings, in centimetres (one decimal). */
export const measurementCmSchema = z.number().min(10).max(250);

export const progressSummaryQuerySchema = z
  .object({ window: progressWindowSchema.default('30d') })
  .strict();

const kg = z.number().finite();
const count = z.number().int().min(0);
const percent = z.number().int().min(0).nullable();

export const weightPointSchema = z
  .object({ date: isoDateSchema, rawKg: kg, trendKg: kg })
  .strict();

export const progressSummarySchema = z
  .object({
    window: progressWindowSchema,
    /** The user's local date the window ends on (stored timezone). */
    today: isoDateSchema,
    /** The window's first local date. */
    from: isoDateSchema,
    weight: z
      .object({
        /** Raw readings with the trend at each, oldest first. The trend is the headline (§13.2). */
        points: z.array(weightPointSchema),
        currentTrendKg: kg.nullable(),
        /** kg/week from the trend; null before the 10-day reliability gate. */
        weeklyChangeKg: kg.nullable(),
        daysOfData: count,
        isReliable: z.boolean(),
        /** The trend's change across the window, only when its readings are ≥ 7 days apart. */
        windowChangeKg: kg.nullable(),
        windowChangeDays: z.number().int().min(7).nullable(),
      })
      .strict(),
    /** The latest reading per site that has one, with its change over ≥ 7 days in the window. */
    measurements: z.array(
      z
        .object({
          site: measurementSiteSchema,
          latest: z.object({ date: isoDateSchema, valueCm: z.number() }).strict(),
          changeCm: z.number().nullable(),
          changeDays: z.number().int().min(7).nullable(),
        })
        .strict(),
    ),
    /** Records set in the window, newest first. */
    prs: z.array(
      z
        .object({
          id: z.string().uuid(),
          exerciseId: z.string().uuid(),
          exerciseName: z.string().min(1),
          prType: prTypeSchema,
          value: z.number(),
          previous: z.number(),
          reason: z.string().min(1),
          /** The local date it was set (stored timezone). */
          achievedOn: isoDateSchema,
        })
        .strict(),
    ),
    /** The best estimated 1RM (Epley — display only) per lift trained in the window. */
    bestLifts: z.array(
      z
        .object({
          exerciseId: z.string().uuid(),
          exerciseName: z.string().min(1),
          estimated1RmKg: z.number().min(0),
          weightKg: z.number().min(0),
          reps: z.number().int().min(1),
          date: isoDateSchema,
        })
        .strict(),
    ),
    /** Owner D6: over logged days only, against the target in effect each day. */
    adherence: z
      .object({
        protein: z.object({ met: count, of: count, percent }).strict(),
        calories: z.object({ met: count, of: count, percent }).strict(),
        loggedDays: count,
        daysWithoutTarget: count,
      })
      .strict(),
    /** Owner D7: completed sessions per ISO week against the programme's planned days. */
    consistency: z
      .object({
        weeks: z.array(
          z.object({ isoWeek: z.string().regex(/^\d{4}-W\d{2}$/), completed: count, planned: count }).strict(),
        ),
        completed: count,
        planned: count.nullable(),
        percent,
      })
      .strict(),
  })
  .strict();
export type ProgressSummary = z.infer<typeof progressSummarySchema>;

/** POST /progress/weight — one reading per local day (upsert); up to 30 days back, never ahead. */
export const logWeightRequestSchema = z
  .object({
    weightKg: weightKgSchema,
    /** The user's local date; default today (stored timezone). */
    date: isoDateSchema.optional(),
  })
  .strict();
export type LogWeightRequest = z.infer<typeof logWeightRequestSchema>;

export const weightReadingSchema = z
  .object({ date: isoDateSchema, weightKg: z.number(), source: z.enum(['onboarding', 'manual', 'health-sync']) })
  .strict();

export const logWeightResponseSchema = z.object({ weight: weightReadingSchema }).strict();
export type LogWeightResponse = z.infer<typeof logWeightResponseSchema>;

/** POST /progress/measurement — one reading per local day and site (upsert); same date window as weight. */
export const logMeasurementRequestSchema = z
  .object({
    site: measurementSiteSchema,
    valueCm: measurementCmSchema,
    date: isoDateSchema.optional(),
  })
  .strict();
export type LogMeasurementRequest = z.infer<typeof logMeasurementRequestSchema>;

export const measurementReadingSchema = z
  .object({ date: isoDateSchema, site: measurementSiteSchema, valueCm: z.number() })
  .strict();

export const logMeasurementResponseSchema = z.object({ measurement: measurementReadingSchema }).strict();
export type LogMeasurementResponse = z.infer<typeof logMeasurementResponseSchema>;

/** Owner D5: readings can be dated up to this many days back, never ahead. */
export const PROGRESS_DAYS_BACK = 30;
