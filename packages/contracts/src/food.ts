/**
 * Food library contracts (Phase 7). One schema per shape drives validation,
 * types and the OpenAPI document.
 *
 * Every nutrition value is a range (`low <= high`). A measured value (USDA,
 * a packaged label) has equal ends; an estimate does not. Fibre may be
 * unknown: both ends `null`, never 0.
 */
import { z } from 'zod';

import { slugSchema } from './exercise.js';

/** Where a food's numbers came from. Mirrors packages/core `FOOD_SOURCES` (API test keeps them equal). */
export const FOOD_SOURCES = ['estimated', 'usda', 'ifct', 'indb', 'user', 'user-corrected'] as const;
export const foodSourceSchema = z.enum(FOOD_SOURCES);
export type FoodSource = z.infer<typeof foodSourceSchema>;

export const NUTRITION_BASES = ['per_100g', 'per_serving'] as const;
export const nutritionBasisSchema = z.enum(NUTRITION_BASES);
export type NutritionBasis = z.infer<typeof nutritionBasisSchema>;

export const CONFIDENCE_LEVELS = ['high', 'medium', 'low'] as const;
export const confidenceSchema = z.enum(CONFIDENCE_LEVELS);
export type NutritionConfidence = z.infer<typeof confidenceSchema>;

/** How a search result matched, best first. */
export const FOOD_MATCH_KINDS = ['exact', 'alias', 'prefix', 'fuzzy'] as const;
export const foodMatchKindSchema = z.enum(FOOD_MATCH_KINDS);
export type FoodMatchKind = z.infer<typeof foodMatchKindSchema>;

const amount = z.number().finite().nonnegative();

/** One serving (or per-100 g) row of a food, every value a range. */
export const foodNutritionSchema = z
  .object({
    basis: nutritionBasisSchema,
    servingLabel: z.string().min(1).max(60),
    servingGrams: z.number().positive().max(5000).nullable(),
    kcalLow: amount,
    kcalHigh: amount,
    proteinLow: amount,
    proteinHigh: amount,
    carbLow: amount,
    carbHigh: amount,
    fatLow: amount,
    fatHigh: amount,
    /** `null` means the source does not report fibre — unknown, not zero. */
    fibreLow: amount.nullable(),
    fibreHigh: amount.nullable(),
    confidence: confidenceSchema,
  })
  .strict()
  .superRefine((n, ctx) => {
    for (const [low, high, path] of [
      [n.kcalLow, n.kcalHigh, 'kcalHigh'],
      [n.proteinLow, n.proteinHigh, 'proteinHigh'],
      [n.carbLow, n.carbHigh, 'carbHigh'],
      [n.fatLow, n.fatHigh, 'fatHigh'],
    ] as const) {
      if (low > high) ctx.addIssue({ code: z.ZodIssueCode.custom, path: [path], message: 'low must not exceed high' });
    }
    if ((n.fibreLow === null) !== (n.fibreHigh === null)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['fibreHigh'], message: 'fibre is either unknown (both null) or a range' });
    } else if (n.fibreLow !== null && n.fibreHigh !== null && n.fibreLow > n.fibreHigh) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['fibreHigh'], message: 'low must not exceed high' });
    }
  });
export type FoodNutrition = z.infer<typeof foodNutritionSchema>;

/** A food as the API returns it. */
export const foodSchema = z.object({
  id: z.string().uuid(),
  slug: z.string().min(1),
  name: z.string().min(1),
  brand: z.string().nullable(),
  barcode: z.string().nullable(),
  source: foodSourceSchema,
  /** Provenance, e.g. "USDA FoodData Central · SR Legacy (April 2018) · FDC 169757". */
  sourceRef: z.string().nullable(),
  isVerified: z.boolean(),
  /** True for the caller's own custom food. Another user's is never returned. */
  isCustom: z.boolean(),
  aliases: z.array(z.string()),
  nutrition: z.array(foodNutritionSchema).min(1),
});
export type Food = z.infer<typeof foodSchema>;

export const foodSearchQuerySchema = z.object({
  q: z.string().trim().min(1).max(80),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
export type FoodSearchQuery = z.infer<typeof foodSearchQuerySchema>;

export const foodSearchResultSchema = foodSchema.extend({ match: foodMatchKindSchema });
export type FoodSearchResult = z.infer<typeof foodSearchResultSchema>;

export const foodSearchResponseSchema = z.object({
  items: z.array(foodSearchResultSchema),
});
export type FoodSearchResponse = z.infer<typeof foodSearchResponseSchema>;

/**
 * A custom food from a packaged label: one row of exact values (stored as
 * ranges with equal ends). Retry-safe: the same `clientFoodId` returns the
 * food already created instead of a second one.
 */
export const createFoodRequestSchema = z
  .object({
    clientFoodId: z.string().uuid(),
    name: z.string().trim().min(1).max(80),
    brand: z.string().trim().min(1).max(60).nullable().optional(),
    basis: nutritionBasisSchema,
    /** For `per_serving`, e.g. "1 bar", "1 pack (30 g)". Ignored for `per_100g`. */
    servingLabel: z.string().trim().min(1).max(60).optional(),
    servingGrams: z.number().positive().max(5000).nullable().optional(),
    kcal: z.number().finite().nonnegative().max(5000),
    proteinG: z.number().finite().nonnegative().max(500),
    carbG: z.number().finite().nonnegative().max(500),
    fatG: z.number().finite().nonnegative().max(500),
    /** Omit or null when the label does not state fibre. */
    fibreG: z.number().finite().nonnegative().max(500).nullable().optional(),
  })
  .strict()
  .superRefine((r, ctx) => {
    if (r.basis === 'per_serving' && r.servingLabel === undefined) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['servingLabel'], message: 'a per-serving food needs a serving label' });
    }
    // Fibre is left out of the weight sums: most labels count it inside
    // carbohydrate, so adding it again would reject real high-fibre foods (bran).
    const grams = r.proteinG + r.carbG + r.fatG;
    if (r.basis === 'per_100g') {
      if (r.kcal > 900) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['kcal'], message: 'more than 900 kcal per 100 g' });
      if ((r.fibreG ?? 0) > 100) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['fibreG'], message: 'more than 100 g per 100 g' });
      if (grams > 100) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['proteinG'], message: 'macros add up to more than 100 g per 100 g' });
    }
    if (r.servingGrams !== undefined && r.servingGrams !== null) {
      if (grams > r.servingGrams) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['servingGrams'], message: 'macros weigh more than the serving' });
      }
    }
  });
export type CreateFoodRequest = z.infer<typeof createFoodRequestSchema>;

// ------------------------------------------------------------------- seed --

/** One food in database/seeds/foods.json (built by the deterministic builder). */
export const foodSeedSchema = z
  .object({
    slug: slugSchema,
    name: z.string().min(1).max(160),
    brand: z.null(),
    barcode: z.null(),
    source: z.enum(['usda', 'estimated']),
    sourceRef: z.string().min(1),
    isVerified: z.boolean(),
    aliases: z.array(z.string().min(1)),
    nutrition: z.array(foodNutritionSchema).min(1),
  })
  .strict()
  .superRefine((f, ctx) => {
    if (f.source === 'estimated') {
      if (f.isVerified) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['isVerified'], message: 'an estimate is never verified' });
      if (f.nutrition.some((n) => n.confidence === 'high')) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['nutrition'], message: 'an estimate never has high confidence' });
      }
    }
    if (f.source === 'usda') {
      if (!f.isVerified) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['isVerified'], message: 'a direct USDA record is verified' });
      if (f.nutrition.some((n) => n.confidence !== 'high' || n.kcalLow !== n.kcalHigh)) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['nutrition'], message: 'a direct USDA record is exact with high confidence' });
      }
    }
  });
export type FoodSeed = z.infer<typeof foodSeedSchema>;

/** No minimum count: the seed is honest about its size (Phase 7, D2). */
export const foodSeedFileSchema = z.array(foodSeedSchema).min(1);
