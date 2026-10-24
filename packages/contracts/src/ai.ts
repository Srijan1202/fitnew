/**
 * Phase 6.6 — FITOS AI (ADR-010). Gate 3 defines the status shape only;
 * the chat and program-request shapes arrive with Gates 4–5. The client
 * uses status to say honestly when AI is not set up on the server rather
 * than showing a chat that cannot answer.
 */
import { z } from 'zod';

import { foodMatchKindSchema, foodNutritionSchema, nutritionBasisSchema } from './food.js';
import { dishSlugSchema, messCodeSchema } from './mess-common.js';
import { mealSlotSchema } from './nutrition-log.js';
import { allergenSchema, isoDateSchema } from './profile.js';
import { programRequestSchema } from './training.js';

export const aiStatusResponseSchema = z.object({
  /**
   * Phase 14 kill switch (`AI_ENABLED`, §19.3): false turns every AI route
   * off (503) and the app hides AI entry points; everything else works.
   */
  enabled: z.boolean(),
  /** False when the server has no model credentials; chat answers 503. */
  configured: z.boolean(),
  /** Provider and model names — never credentials. */
  provider: z.string(),
  model: z.string().nullable(),
  /**
   * What the assistant will not see, stated so the client can explain it
   * to the user. Phase 6.6: Health Connect data stays on the phone.
   */
  excludes: z.array(z.enum(['health-connect', 'food-log'])),
});
export type AiStatusResponse = z.infer<typeof aiStatusResponseSchema>;

/* ------------------------------------------------------------- chat -- */

export const AI_MESSAGE_MAX = 2000;
export const AI_HISTORY_MAX = 20;

export const aiChatMessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1).max(AI_MESSAGE_MAX),
});
export type AiChatMessage = z.infer<typeof aiChatMessageSchema>;

/**
 * Stateless: the client sends the recent exchange and the new message; the
 * server assembles the FITOS context fresh every call and keeps nothing.
 */
export const aiChatRequestSchema = z
  .object({
    message: z.string().trim().min(1).max(AI_MESSAGE_MAX),
    history: z.array(aiChatMessageSchema).max(AI_HISTORY_MAX).default([]),
  })
  .strict();
export type AiChatRequest = z.infer<typeof aiChatRequestSchema>;

/** Navigation the client may offer under an answer; nothing is changed by it. */
export const AI_ACTION_TYPES = [
  'open-workout',
  'open-plan',
  'open-volume',
  'open-progression',
  'open-profile',
  'open-nutrition',
  'open-exercise',
  'open-history',
  /**
   * Phase 6.6 Gate 5: the assistant proposed a programme; the client applies
   * it only when the user explicitly chooses to (a confirmation, then the
   * ordinary generate / apply-template request). The chat never changes the
   * programme by itself.
   */
  'apply-program',
] as const;
export const aiActionSchema = z.object({
  type: z.enum(AI_ACTION_TYPES),
  label: z.string().min(1),
  exerciseId: z.string().uuid().optional(),
  sessionId: z.string().uuid().optional(),
  programRequest: programRequestSchema.optional(),
});
export type AiAction = z.infer<typeof aiActionSchema>;

export const aiChatResponseSchema = z.object({
  text: z.string().min(1),
  actions: z.array(aiActionSchema),
  /** Allowlisted tool names the answer drew on, for transparency. */
  toolsUsed: z.array(z.string()),
  model: z.string(),
});
export type AiChatResponse = z.infer<typeof aiChatResponseSchema>;

/* ------------------------------------------------- Phase 14: drafts -- */

/**
 * §19.2: every AI result is a DRAFT. `source` and `requiresConfirmation`
 * are literals, so a draft can never claim to be anything else, and nothing
 * in it is stored until the user confirms it (ADR-020).
 */
export const AI_CONFIDENCE = ['high', 'medium', 'low'] as const;
export const aiConfidenceSchema = z.enum(AI_CONFIDENCE);

/** POST /nutrition/parse — a meal in the user's words. Nothing else is sent to the model. */
export const PARSE_TEXT_MAX = 500;
export const parseFoodRequestSchema = z.object({ text: z.string().trim().min(2).max(PARSE_TEXT_MAX) }).strict();
export type ParseFoodRequest = z.infer<typeof parseFoodRequestSchema>;

const macroRange = {
  kcalLow: z.number().nonnegative(),
  kcalHigh: z.number().nonnegative(),
  proteinLow: z.number().nonnegative(),
  proteinHigh: z.number().nonnegative(),
  carbLow: z.number().nonnegative(),
  carbHigh: z.number().nonnegative(),
  fatLow: z.number().nonnegative(),
  fatHigh: z.number().nonnegative(),
};

/** A phrase matched to a FITOS food: the numbers are the food database's, never the model's. */
export const draftMatchSchema = z
  .object({
    foodId: z.string().uuid(),
    name: z.string().min(1),
    matchKind: foodMatchKindSchema,
    basis: nutritionBasisSchema,
    servingLabel: z.string().min(1).max(60),
    /** The portion as servings of that row (0.1–20, hundredths) — what the log will send. */
    servings: z.number().min(0.1).max(20),
    /** That row, so the phone can preview a changed portion (display only, §30). */
    row: foodNutritionSchema,
    /** The row at `servings`, rounded as a log item would be. */
    snapshot: z.object(macroRange).strict(),
  })
  .strict();

/** A food the database does not have: the model's estimate, checked against §19.2's bounds. */
export const draftEstimateSchema = z
  .object({
    name: z.string().min(1).max(60),
    grams: z.number().positive().nullable(),
    kcal: z.number().nonnegative(),
    proteinG: z.number().nonnegative(),
    carbG: z.number().nonnegative(),
    fatG: z.number().nonnegative(),
  })
  .strict();

export const draftItemSchema = z
  .object({
    /** What the model read from the text, e.g. "2 rotis". */
    phrase: z.string().min(1).max(120),
    quantity: z.number().positive(),
    unit: z.string().min(1).max(30),
    confidence: aiConfidenceSchema,
    /** Exactly one of `match`, `estimate`, or a `problem` saying why there is neither. */
    match: draftMatchSchema.nullable(),
    estimate: draftEstimateSchema.nullable(),
    problem: z.string().min(1).nullable(),
  })
  .strict();
export type DraftItem = z.infer<typeof draftItemSchema>;

export const foodDraftSchema = z
  .object({
    data: z.object({ items: z.array(draftItemSchema).max(12) }).strict(),
    confidence: aiConfidenceSchema,
    source: z.literal('ai-draft'),
    requiresConfirmation: z.literal(true),
  })
  .strict();

export const parseFoodResponseSchema = z.object({ draft: foodDraftSchema, model: z.string() }).strict();
export type ParseFoodResponse = z.infer<typeof parseFoodResponseSchema>;

/** POST /ai/explain — a TODAY action's reason in plainer words, or the engine's own. */
export const explainRequestSchema = z.object({ actionId: z.string().uuid() }).strict();
export type ExplainRequest = z.infer<typeof explainRequestSchema>;

export const explainResponseSchema = z
  .object({
    text: z.string().min(1),
    /** `engine`: the rephrasing was discarded (§19.2) and FITOS's own words are shown. */
    source: z.enum(['ai', 'engine']),
    discarded: z.enum(['new-number', 'empty', 'too-long']).nullable(),
  })
  .strict();
export type ExplainResponse = z.infer<typeof explainResponseSchema>;

/* ------------------------------------------------- beta 3.6: food guide -- */

/**
 * POST /nutrition/guide (beta 3.6, owner F15): "What should I eat?" for one
 * meal, from what the person has with them and/or today's mess menu. The
 * model picks from those only; every number is the food database's or the
 * mess table's. Nothing is stored; the app logs an option the person picks.
 */
export const GUIDE_HAVE_MAX = 20;
export const GUIDE_HAVE_ITEM_MAX = 40;
export const GUIDE_FEEL_MAX = 120;
export const foodGuideRequestSchema = z
  .object({
    slot: mealSlotSchema,
    /** Use today's menu of the person's mess. */
    fromMess: z.boolean(),
    /** What they have with them, in their words ("bread", "2 eggs"). */
    have: z.array(z.string().trim().min(1).max(GUIDE_HAVE_ITEM_MAX)).max(GUIDE_HAVE_MAX),
    /** What they feel like, in their words; null when nothing. */
    feel: z.string().trim().min(1).max(GUIDE_FEEL_MAX).nullable(),
  })
  .strict()
  .refine((b) => b.fromMess || b.have.length > 0, { message: 'choose the mess menu or something you have', path: ['have'] });
export type FoodGuideRequest = z.infer<typeof foodGuideRequestSchema>;

export const guideItemSchema = z
  .object({
    source: z.enum(['mess', 'have']),
    name: z.string().min(1),
    /** Of the item's serving, in quarters. */
    servings: z.number().min(0.25).max(4),
    servingLabel: z.string().min(1),
    /** This item at these servings: the database's or the mess table's numbers. */
    macros: z.object(macroRange).strict(),
    /** A food the person has: what the log sends (as a meal draft's match). */
    food: draftMatchSchema.nullable(),
    /** A mess dish: what the log sends. */
    dishSlug: dishSlugSchema.nullable(),
  })
  .strict();

export const guideOptionSchema = z
  .object({
    title: z.string().min(1).max(60),
    why: z.string().max(200),
    items: z.array(guideItemSchema).min(1).max(5),
    totals: z.object(macroRange).strict(),
    /** Allergens the names cannot rule out: "check the label". */
    caution: z.array(allergenSchema),
  })
  .strict();

export const foodGuideResponseSchema = z
  .object({
    slot: mealSlotSchema,
    date: isoDateSchema,
    /** The mess menu used, when it was. */
    mess: z.object({ code: messCodeSchema, menuDate: isoDateSchema }).strict().nullable(),
    /** What is left of today's targets; null when none are set. */
    remaining: z.object({ kcal: z.number().int().min(0), proteinG: z.number().int().min(0) }).strict().nullable(),
    options: z.array(guideOptionSchema).max(3),
    /** Things typed that FITOS does not know (not suggested). */
    unknown: z.array(z.string()),
    /** Things typed that break the person's diet or hold their allergen (not suggested). */
    refused: z.array(z.string()),
    /** Why the mess menu was not used when asked for: no mess chosen, no menu, nothing allowed. */
    messNote: z.string().nullable(),
    model: z.string(),
  })
  .strict();
export type FoodGuideResponse = z.infer<typeof foodGuideResponseSchema>;
export type GuideOption = z.infer<typeof guideOptionSchema>;
export type GuideItem = z.infer<typeof guideItemSchema>;
