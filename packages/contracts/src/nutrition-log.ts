/**
 * Food logging contracts (Phase 8). One schema per shape drives validation,
 * types and the OpenAPI document.
 *
 * A log item is a SNAPSHOT taken by the server at log time — the food's
 * row scaled to the portion — so history never moves when a food is
 * corrected. Every total is a range; unknown fibre is counted, never 0.
 */
import { z } from 'zod';

import { confidenceSchema, foodNutritionSchema, foodSchema, foodSourceSchema, nutritionBasisSchema } from './food.js';
import { dishSlugSchema, messCodeSchema, messDishNutritionSchema } from './mess-common.js';
import { isoDateSchema, nutritionTargetsSchema } from './profile.js';

/** Mirrors packages/core `MEAL_SLOTS` (the mess vocabulary). */
export const MEAL_SLOTS = ['breakfast', 'lunch', 'snacks', 'dinner'] as const;
export const mealSlotSchema = z.enum(MEAL_SLOTS);
export type MealSlot = z.infer<typeof mealSlotSchema>;

/** Mirrors packages/core `ENTRY_METHODS`. Phase 9 added `mess`. */
export const ENTRY_METHODS = ['search', 'quick-add', 'saved-meal', 'mess'] as const;
export const entryMethodSchema = z.enum(ENTRY_METHODS);
export type EntryMethod = z.infer<typeof entryMethodSchema>;

/** Owner J19. Mirrors packages/core. */
export const SERVINGS_MIN = 0.1;
export const SERVINGS_MAX = 20;
export const GRAMS_MAX = 5000;

const amount = z.number().finite().nonnegative();
const servingLabelSchema = z.string().trim().min(1).max(60);

/* ------------------------------------------------------------ requests -- */

/**
 * One food at a portion. The row is named by its basis and serving label
 * (unique per food). Exactly one of `servings` or `grams`.
 */
export const logFoodItemRequestSchema = z
  .object({
    foodId: z.string().uuid(),
    basis: nutritionBasisSchema,
    servingLabel: servingLabelSchema,
    servings: z.number().finite().min(SERVINGS_MIN).max(SERVINGS_MAX).optional(),
    grams: z.number().finite().positive().max(GRAMS_MAX).optional(),
  })
  .strict()
  .superRefine((r, ctx) => {
    if ((r.servings === undefined) === (r.grams === undefined)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['servings'], message: 'give exactly one of servings or grams' });
    }
  });
export type LogFoodItemRequest = z.infer<typeof logFoodItemRequestSchema>;

/** Owner J6: raw values; kcal and the three macros are required, fibre optional. */
export const quickAddSchema = z
  .object({
    name: z.string().trim().min(1).max(60).nullable().optional(),
    kcal: amount.max(5000),
    proteinG: amount.max(500),
    carbG: amount.max(500),
    fatG: amount.max(500),
    /** Omit or null when not known — never assumed 0. */
    fibreG: amount.max(500).nullable().optional(),
  })
  .strict();
export type QuickAdd = z.infer<typeof quickAddSchema>;

/**
 * Phase 9: one dish from a mess menu at a portion of its serving. Exactly
 * one of `servings` or `grams` (grams only when the serving has a weight).
 * The numbers are the server's own estimate for the dish, taken at log time.
 */
export const logMessDishRequestSchema = z
  .object({
    dishSlug: dishSlugSchema,
    servings: z.number().finite().min(SERVINGS_MIN).max(SERVINGS_MAX).optional(),
    grams: z.number().finite().positive().max(GRAMS_MAX).optional(),
  })
  .strict()
  .superRefine((r, ctx) => {
    if ((r.servings === undefined) === (r.grams === undefined)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['servings'], message: 'give exactly one of servings or grams' });
    }
  });
export type LogMessDishRequest = z.infer<typeof logMessDishRequestSchema>;

const logBase = {
  /** Minted by the phone; the same id always means the same log (owner J12). */
  clientLogId: z.string().uuid(),
  /**
   * When it was eaten (an instant). Defaults to now. The day it belongs to
   * is this instant in `users.timezone`, fixed at write time (owner J3);
   * today and up to 30 days back only (owner J4).
   */
  loggedAt: z.string().datetime({ offset: true }).optional(),
  mealSlot: mealSlotSchema,
};

export const createLogRequestSchema = z.discriminatedUnion('entryMethod', [
  z
    .object({ ...logBase, entryMethod: z.literal('search'), items: z.array(logFoodItemRequestSchema).min(1).max(20) })
    .strict(),
  z.object({ ...logBase, entryMethod: z.literal('quick-add'), quickAdd: quickAddSchema }).strict(),
  z.object({ ...logBase, entryMethod: z.literal('saved-meal'), savedMealId: z.string().uuid() }).strict(),
  z
    .object({
      ...logBase,
      entryMethod: z.literal('mess'),
      /** The mess whose menu the dishes are on. */
      mess: messCodeSchema,
      /** The menu's date; each dish must be on that day's menu (published or inferred). */
      menuDate: isoDateSchema,
      items: z.array(logMessDishRequestSchema).min(1).max(20),
    })
    .strict(),
]);
export type CreateLogRequest = z.infer<typeof createLogRequestSchema>;

export const clientLogIdParamsSchema = z.object({ clientLogId: z.string().uuid() }).strict();

export const nutritionDayParamsSchema = z.object({ date: isoDateSchema }).strict();

/* ----------------------------------------------------------- responses -- */

/** A logged item: everything needed to reproduce its nutrition, frozen at log time. */
export const foodLogItemSchema = z.object({
  id: z.string().uuid(),
  position: z.number().int().nonnegative(),
  /** The food it came from; null for quick add, a mess dish (and if a food were ever removed). */
  foodId: z.string().uuid().nullable(),
  /** Phase 9: the mess dish it came from (provenance only; the numbers are the snapshot). */
  messDishSlug: dishSlugSchema.nullable(),
  foodName: z.string().min(1),
  foodSource: foodSourceSchema,
  /** The row the portion was measured against; null for quick add. */
  basis: nutritionBasisSchema.nullable(),
  servingLabel: z.string().nullable(),
  servingGrams: z.number().positive().nullable(),
  servings: z.number().positive(),
  /** The portion's weight when known. */
  grams: z.number().positive().nullable(),
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
  confidence: confidenceSchema,
});
export type FoodLogItem = z.infer<typeof foodLogItemSchema>;

/** A sum of snapshots. Fibre: what is known, and how many items did not say. */
export const nutritionTotalsSchema = z.object({
  kcalLow: amount,
  kcalHigh: amount,
  proteinLow: amount,
  proteinHigh: amount,
  carbLow: amount,
  carbHigh: amount,
  fatLow: amount,
  fatHigh: amount,
  fibreKnownLow: amount,
  fibreKnownHigh: amount,
  /** Items whose fibre is unknown; their fibre is not in `fibreKnown*` (and is not 0). */
  fibreUnknownItems: z.number().int().nonnegative(),
  itemCount: z.number().int().nonnegative(),
});
export type NutritionTotals = z.infer<typeof nutritionTotalsSchema>;

export const foodLogSchema = z.object({
  id: z.string().uuid(),
  clientLogId: z.string().uuid(),
  loggedAt: z.string().datetime(),
  localDate: isoDateSchema,
  mealSlot: mealSlotSchema,
  entryMethod: entryMethodSchema,
  savedMealId: z.string().uuid().nullable(),
  /** Phase 9: the mess a `mess` log came from. */
  messCode: messCodeSchema.nullable(),
  items: z.array(foodLogItemSchema).min(1),
  totals: nutritionTotalsSchema,
});
export type FoodLog = z.infer<typeof foodLogSchema>;

export const REMAINING_STATES = ['under', 'around', 'over'] as const;
export const remainingStateSchema = z.enum(REMAINING_STATES);

/** target − consumed, as a range; negative is over. Never clamped at zero. */
export const remainingRangeSchema = z.object({
  target: z.number(),
  low: z.number(),
  high: z.number(),
  state: remainingStateSchema,
});
export type RemainingRange = z.infer<typeof remainingRangeSchema>;

export const nutritionRemainingSchema = z.object({
  kcal: remainingRangeSchema,
  protein: remainingRangeSchema,
  carb: remainingRangeSchema,
  fat: remainingRangeSchema,
});
export type NutritionRemaining = z.infer<typeof nutritionRemainingSchema>;

/**
 * One day in the user's calendar. `targets` is the `nutrition_targets` row
 * in effect on that date (owner J2) — never a copy; null before any exist,
 * and then `remaining` is null too.
 */
export const nutritionDaySchema = z.object({
  date: isoDateSchema,
  /** Today in the user's zone, so the client can tell today from history. */
  today: isoDateSchema,
  timezone: z.string(),
  targets: nutritionTargetsSchema.nullable(),
  totals: nutritionTotalsSchema,
  remaining: nutritionRemainingSchema.nullable(),
  logs: z.array(foodLogSchema),
});
export type NutritionDay = z.infer<typeof nutritionDaySchema>;

export const createLogResponseSchema = z.object({
  log: foodLogSchema,
  /** The log's day after the write — the new totals in the same response. */
  day: nutritionDaySchema,
});
export type CreateLogResponse = z.infer<typeof createLogResponseSchema>;

export const deleteLogResponseSchema = z.object({ day: nutritionDaySchema });
export type DeleteLogResponse = z.infer<typeof deleteLogResponseSchema>;

/* -------------------------------------------------------- recent foods -- */

export const recentFoodsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

/** A food you logged recently, with the portion you used last (owner J13). */
export const recentFoodSchema = z.object({
  food: foodSchema,
  lastLoggedAt: z.string().datetime(),
  lastBasis: nutritionBasisSchema,
  lastServingLabel: z.string(),
  lastServings: z.number().positive(),
});
export type RecentFood = z.infer<typeof recentFoodSchema>;

export const recentFoodsResponseSchema = z.object({ items: z.array(recentFoodSchema) });
export type RecentFoodsResponse = z.infer<typeof recentFoodsResponseSchema>;

/* --------------------------------------------------------- saved meals -- */

/**
 * A saved meal's item. Food items keep the food and portion — logging the
 * meal re-snapshots the food's current values; quick-add items keep their
 * values. `row` is the food's row as it is NOW, for a display-only preview.
 */
export const savedMealItemSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('food'),
    foodId: z.string().uuid(),
    foodName: z.string().min(1),
    basis: nutritionBasisSchema,
    servingLabel: z.string().min(1),
    servings: z.number().positive(),
    grams: z.number().positive().nullable(),
    /** Null when the food is no longer available to you. */
    row: foodNutritionSchema.nullable(),
  }),
  z.object({
    kind: z.literal('quick-add'),
    name: z.string().min(1),
    kcal: amount,
    proteinG: amount,
    carbG: amount,
    fatG: amount,
    fibreG: amount.nullable(),
  }),
  /**
   * Phase 9 (owner D11): a mess dish keeps its identity and portion — logging
   * the meal re-snapshots the dish's CURRENT estimate, as a range. Never turned
   * into an exact quick add. `row` is that estimate now (preview only).
   */
  z.object({
    kind: z.literal('mess'),
    dishSlug: dishSlugSchema,
    name: z.string().min(1),
    servings: z.number().positive(),
    /** Null when the dish no longer has an estimate. */
    row: messDishNutritionSchema.nullable(),
  }),
]);
export type SavedMealItem = z.infer<typeof savedMealItemSchema>;

export const savedMealSchema = z.object({
  id: z.string().uuid(),
  clientMealId: z.string().uuid(),
  name: z.string().min(1),
  items: z.array(savedMealItemSchema).min(1),
  createdAt: z.string().datetime(),
});
export type SavedMeal = z.infer<typeof savedMealSchema>;

export const savedMealsResponseSchema = z.object({ items: z.array(savedMealSchema) });
export type SavedMealsResponse = z.infer<typeof savedMealsResponseSchema>;

/**
 * Owner J7: a saved meal is made from logged meals — the items of the named
 * logs, in order. There is no from-scratch builder. Retry-safe by `clientMealId`.
 */
export const createSavedMealRequestSchema = z
  .object({
    clientMealId: z.string().uuid(),
    name: z.string().trim().min(1).max(60),
    fromClientLogIds: z.array(z.string().uuid()).min(1).max(10),
  })
  .strict();
export type CreateSavedMealRequest = z.infer<typeof createSavedMealRequestSchema>;

export const savedMealIdParamsSchema = z.object({ id: z.string().uuid() }).strict();
