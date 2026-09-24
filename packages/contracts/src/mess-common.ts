/**
 * Mess shapes shared by the mess routes (mess.ts) and food logging
 * (nutrition-log.ts) — kept apart so neither module imports the other.
 */
import { z } from 'zod';

/** A mess's public code, e.g. `mens-veg` (packages/core `messCode`). */
export const messCodeSchema = z
  .string()
  .max(40)
  .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'must be a mess code such as mens-veg');
export type MessCode = z.infer<typeof messCodeSchema>;

/** A dish's stable id: packages/core `slugifyDish` of its name. */
export const dishSlugSchema = z
  .string()
  .max(120)
  .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'must be a dish slug such as dal-tadka');

const amount = z.number().finite().nonnegative();

/** Owner (Phase 9): mess nutrition is never `high` confidence. */
export const MESS_CONFIDENCE_LEVELS = ['medium', 'low'] as const;
export const messConfidenceSchema = z.enum(MESS_CONFIDENCE_LEVELS);

/**
 * A mess dish's current estimate (`mess_dish_nutrition`), per one serving of
 * `servingLabel`. Always an estimate (`source: estimated`), always a range.
 * Fibre is not estimated for mess dishes: null = unknown, never 0.
 * `servingGrams` is null when the serving has no known weight (then a
 * portion can be given in servings only).
 */
export const messDishNutritionSchema = z.object({
  servingLabel: z.string().min(1),
  servingGrams: z.number().positive().nullable(),
  kcalLow: amount,
  kcalHigh: amount,
  proteinLow: amount,
  proteinHigh: amount,
  carbLow: amount,
  carbHigh: amount,
  fatLow: amount,
  fatHigh: amount,
  fibreLow: amount.nullable(),
  fibreHigh: amount.nullable(),
  confidence: messConfidenceSchema,
  source: z.literal('estimated'),
});
export type MessDishNutrition = z.infer<typeof messDishNutritionSchema>;
