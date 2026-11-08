/**
 * Beta 6.0 (F7, ADR-059): water. One total per local day, set by the phone
 * (PUT replaces it, so a repeated or delayed send is harmless); the target
 * comes from the latest weigh-in (core's `waterTargetMl`).
 */
import { z } from 'zod';

import { isoDateSchema } from './profile.js';

/** The most a day can hold, and how far back a day can be changed. */
export const WATER_MAX_ML = 10_000;
export const WATER_DAYS_BACK = 7;

export const waterMlSchema = z.number().int().min(0).max(WATER_MAX_ML);

export const waterDaySchema = z
  .object({
    /** The user's local date (stored timezone). */
    date: isoDateSchema,
    /** Drunk that day, in ml (0 when nothing is logged). */
    ml: waterMlSchema,
    /** The day's target, in ml. */
    targetMl: z.number().int().positive(),
    /** True when the target comes from a weigh-in; false when it is the 2.5 L default. */
    fromWeight: z.boolean(),
  })
  .strict();

export const setWaterRequestSchema = z.object({ ml: waterMlSchema }).strict();
export const waterDateParamsSchema = z.object({ date: isoDateSchema }).strict();

export type WaterDay = z.infer<typeof waterDaySchema>;
export type SetWaterRequest = z.infer<typeof setWaterRequestSchema>;
