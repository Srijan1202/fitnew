/**
 * Recovery (Phase 13, MASTER-SPEC §18, §10.1; ADR-019): the daily check-in
 * and today's readiness. Readiness is computed on the server, on read, from
 * the user's own records (never stored, never on the phone — §30) and is
 * advice only: nothing here changes the plan.
 */
import { z } from 'zod';

import { isoDateSchema } from './profile.js';

/** §18's 1–5 scales. */
export const recoveryScaleSchema = z.number().int().min(1).max(5);
/** Hours slept, one decimal kept. */
export const sleepHoursSchema = z.number().min(0).max(24);

export const RECOVERY_SOURCES = ['manual'] as const;

export const READINESS_BANDS = ['ready', 'advisory', 'reduce', 'rest'] as const;
export const readinessBandSchema = z.enum(READINESS_BANDS);

export const READINESS_COMPONENTS = ['sleep', 'soreness', 'energy', 'performance', 'adherence'] as const;

/** Owner D2: a check-in can be dated up to this many days back, never ahead. */
export const RECOVERY_DAYS_BACK = 7;

export const recoveryLogSchema = z
  .object({
    /** The user's local date (stored timezone). */
    date: isoDateSchema,
    sleepHours: z.number().nullable(),
    /** 1 poor – 5 great. */
    sleepQuality: recoveryScaleSchema.nullable(),
    /** 1 none – 5 very sore. */
    soreness: recoveryScaleSchema.nullable(),
    /** 1 drained – 5 great. */
    energy: recoveryScaleSchema.nullable(),
    /** 1 calm – 5 very stressed. */
    stress: recoveryScaleSchema.nullable(),
    source: z.enum(RECOVERY_SOURCES),
  })
  .strict();
export type RecoveryLog = z.infer<typeof recoveryLogSchema>;

export const readinessSchema = z
  .object({
    score: z.number().int().min(0).max(100),
    band: readinessBandSchema,
    /** §18's effect for the band, in plain words (deterministic; never a diagnosis). */
    advice: z.string().min(1),
    /** Every §18 component: its penalty, its cap, and whether its input was available. */
    components: z
      .array(
        z
          .object({
            key: z.enum(READINESS_COMPONENTS),
            penalty: z.number().int().min(0),
            max: z.number().int().min(1),
            available: z.boolean(),
          })
          .strict(),
      )
      .length(READINESS_COMPONENTS.length),
    /** Local days running with readiness under 35 (three escalate to a deload check). */
    lowDays: z.number().int().min(0),
  })
  .strict();
export type Readiness = z.infer<typeof readinessSchema>;

/** GET /recovery/today. */
export const recoveryTodaySchema = z
  .object({
    date: isoDateSchema,
    log: recoveryLogSchema.nullable(),
    /** Null until today's check-in exists: readiness is computed only from available inputs. */
    readiness: readinessSchema.nullable(),
  })
  .strict();
export type RecoveryToday = z.infer<typeof recoveryTodaySchema>;

/**
 * POST /recovery/log — the §18 card. Every value is optional (null or left
 * out), but at least one is required. Upsert on the local date: the day's
 * check-in is replaced by what is sent.
 */
export const logRecoveryRequestSchema = z
  .object({
    date: isoDateSchema.optional(),
    sleepHours: sleepHoursSchema.nullable().optional(),
    sleepQuality: recoveryScaleSchema.nullable().optional(),
    soreness: recoveryScaleSchema.nullable().optional(),
    energy: recoveryScaleSchema.nullable().optional(),
    stress: recoveryScaleSchema.nullable().optional(),
  })
  .strict();
export type LogRecoveryRequest = z.infer<typeof logRecoveryRequestSchema>;

export const logRecoveryResponseSchema = z.object({ log: recoveryLogSchema }).strict();
export type LogRecoveryResponse = z.infer<typeof logRecoveryResponseSchema>;
