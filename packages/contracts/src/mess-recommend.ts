/**
 * Mess recommendations (Phase 10, ADR-015 and ADR-016): "what should I eat"
 * at one meal of a mess — always a meal (a staple, a protein, a vegetable
 * when the menu allows), never the nutritionally cheapest dish. Computed on request from the server's mirror and the caller's
 * own diet, allergies, goal, targets and logs; never stored.
 *
 * Every number is a range from the stored mess estimates (the same numbers a
 * logged plate snapshots). Reasons are codes with values — the app words
 * them; no prose comes from the server.
 */
import { z } from 'zod';

import { dishSlugSchema, messCodeSchema, messConfidenceSchema } from './mess-common.js';
import { dietClassSchema, menuResolutionSchema, messSchema } from './mess.js';
import { mealSlotSchema } from './nutrition-log.js';
import { allergenSchema, dietTypeSchema, goalTypeSchema, isoDateSchema } from './profile.js';

export const messRecommendQuerySchema = z
  .object({
    /** Today (default) or tomorrow, in your zone. Tomorrow is for planning and cannot be logged. */
    date: isoDateSchema.optional(),
    /** A mess code; default your mess. Browsing another mess still applies YOUR filters. */
    mess: messCodeSchema.optional(),
    /** Default: the next meal you have not logged (today) or breakfast (tomorrow). */
    slot: mealSlotSchema.optional(),
  })
  .strict();
export type MessRecommendQuery = z.infer<typeof messRecommendQuerySchema>;

export const RECOMMENDATION_STATUSES = [
  'ok',
  'no-targets',
  'target-reached',
  'menu-unavailable',
  'meal-not-served',
  'nothing-safe',
  /** ADR-016: dishes pass your filters, but no structurally valid meal can be made from them. */
  'no-meal',
  /** ADR-016: a valid meal exists, but even the smallest goes over everything left today. */
  'nothing-fits',
] as const;

/** ADR-016: what part of a meal a dish is. */
export const MEAL_COMPONENTS = [
  'staple', 'complete', 'protein', 'pulse-gravy', 'dairy', 'veg', 'soup', 'fruit',
  'snack', 'dessert', 'crisp', 'beverage', 'condiment', 'other',
] as const;
export const mealComponentSchema = z.enum(MEAL_COMPONENTS);

/** ADR-016: the meal a plate makes. */
export const STRUCTURE_KINDS = ['complete-meal', 'meal', 'meal-weak-protein', 'limited', 'limited-no-staple', 'snack'] as const;
export const structureKindSchema = z.enum(STRUCTURE_KINDS);
export const MISSING_PARTS = ['staple', 'protein', 'strong-protein', 'vegetable'] as const;
export const missingPartSchema = z.enum(MISSING_PARTS);

export const ALLERGEN_STATUSES = ['contains', 'likely', 'free', 'unknown'] as const;
export const allergenStatusSchema = z.enum(ALLERGEN_STATUSES);

/** Every reason code (ADR-015 §13, ADR-016). Plate reasons, then dish reasons. */
export const REASON_CODES = [
  'protein-covers',
  'protein-may-fall-short',
  'protein-short',
  'kcal-within',
  'kcal-may-exceed',
  'kcal-over',
  'carb-within',
  'carb-over',
  'fat-within',
  'fat-over',
  'goal-weighting',
  'meal-structure',
  'staple-anchor',
  'protein-anchor',
  'vegetable-component',
  'supporting-side',
  'limited-menu',
  'top-protein-dish',
  'post-workout-carbs',
  'repeat',
  'low-confidence-dish',
  'inferred-menu',
  'on-plate',
  'diet',
  'diet-alternative',
  'allergen',
  'allergen-alternative',
  'no-estimate',
  'ambient',
  'not-a-meal-component',
  'disliked',
  'not-top-candidate',
  'not-chosen',
] as const;
export const reasonCodeSchema = z.enum(REASON_CODES);

/** A reason: a code and the values it needs. No text. */
export const recommendationReasonSchema = z
  .object({
    code: reasonCodeSchema,
    target: z.number().optional(),
    low: z.number().optional(),
    high: z.number().optional(),
    goal: goalTypeSchema.optional(),
    dishSlug: dishSlugSchema.optional(),
    days: z.number().int().min(1).max(3).optional(),
    sourceDate: isoDateSchema.optional(),
    ranks: z.array(z.number().int().min(1).max(3)).optional(),
    dietClass: dietClassSchema.optional(),
    alternative: z.string().optional(),
    allergen: allergenSchema.optional(),
    status: allergenStatusSchema.exclude(['free']).optional(),
    kind: structureKindSchema.optional(),
    strength: z.enum(['strong', 'weak']).optional(),
    missing: z.array(missingPartSchema).min(1).optional(),
    component: mealComponentSchema.optional(),
  })
  .strict();
export type RecommendationReason = z.infer<typeof recommendationReasonSchema>;

const amount = z.number().finite().nonnegative();
const macroTotals = {
  kcalLow: amount,
  kcalHigh: amount,
  proteinLow: amount,
  proteinHigh: amount,
  carbLow: amount,
  carbHigh: amount,
  fatLow: amount,
  fatHigh: amount,
};

export const plateItemSchema = z.object({
  dishSlug: dishSlugSchema,
  name: z.string().min(1),
  /** Whole servings of `servingLabel`. */
  servings: z.number().int().min(1).max(3),
  servingLabel: z.string().min(1),
  servingGrams: z.number().positive().nullable(),
  ...macroTotals,
  confidence: messConfidenceSchema,
  /** What part of the meal this dish is. */
  component: mealComponentSchema,
});
export type PlateItem = z.infer<typeof plateItemSchema>;

export const plateSchema = z.object({
  rank: z.number().int().min(1).max(3),
  items: z.array(plateItemSchema).min(1),
  /** The sum of the items (what logging the plate adds to the day). */
  totals: z.object(macroTotals),
  /** The worst item's confidence. */
  confidence: messConfidenceSchema,
  /** The meal this plate makes, and what it lacks for a complete meal. */
  structure: z.object({ kind: structureKindSchema, missing: z.array(missingPartSchema) }),
  reasons: z.array(recommendationReasonSchema),
});
export type Plate = z.infer<typeof plateSchema>;

/** ADR-015 §10: the top plate's own range below a meal target — never inflated. */
export const recommendationGapSchema = z.object({
  target: amount,
  gapLow: amount,
  gapHigh: amount,
  /** The highest optimistic value any plate from this menu reaches. */
  menuMax: amount,
  menuCanMeet: z.boolean(),
});
export type RecommendationGap = z.infer<typeof recommendationGapSchema>;

export const dishOutcomeSchema = z.object({
  dishSlug: dishSlugSchema,
  name: z.string().min(1),
  diet: dietClassSchema,
  onPlate: z.boolean(),
  reasons: z.array(recommendationReasonSchema).min(1),
  /** Each "/" alternative, classified on its own. */
  alternatives: z.array(
    z.object({
      name: z.string().min(1),
      diet: dietClassSchema,
      allergens: z.array(z.object({ allergen: allergenSchema, status: allergenStatusSchema })),
    }),
  ),
});
export type DishOutcome = z.infer<typeof dishOutcomeSchema>;

export const messRecommendationSchema = z.object({
  status: z.enum(RECOMMENDATION_STATUSES),
  mess: messSchema,
  date: isoDateSchema,
  today: isoDateSchema,
  slot: mealSlotSchema,
  /** You have already logged this meal today (it was opened explicitly, or every later meal is logged). */
  slotAlreadyLogged: z.boolean(),
  /** Only today's plates can be logged. */
  loggable: z.boolean(),
  resolution: menuResolutionSchema,
  basis: z.enum(['published', 'inferred']).nullable(),
  /** The filters applied — the hard rules. Severity never relaxes an allergy. */
  filters: z.object({ diet: dietTypeSchema, allergies: z.array(allergenSchema) }),
  goal: goalTypeSchema,
  /** The meal's share of what the day still needs (null before targets exist). */
  target: z
    .object({
      share: z.number().min(0).max(1),
      kcal: amount,
      protein: amount,
      carb: amount,
      fat: amount,
      /** Everything left today, conservatively (for `nothing-fits`). */
      dayRemainingKcal: amount,
    })
    .nullable(),
  postWorkout: z.boolean(),
  plates: z.array(plateSchema).max(3),
  /** For the top plate; null when nothing falls short. */
  shortfall: z.object({ protein: recommendationGapSchema.nullable(), kcal: recommendationGapSchema.nullable() }).nullable(),
  /** Every dish at the meal, and why it is or is not on a plate. */
  dishes: z.array(dishOutcomeSchema),
  /** `nothing-fits` only: the low-end kcal of the smallest valid meal on the menu. */
  smallestMealKcal: amount.nullable(),
});
export type MessRecommendation = z.infer<typeof messRecommendationSchema>;
