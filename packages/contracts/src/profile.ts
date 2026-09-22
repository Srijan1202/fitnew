/**
 * Profile, goal and preference vocabulary (§9.2, §12.1, §32).
 *
 * Every enum here is closed on purpose. The engines in packages/core switch
 * exhaustively over goal, sex and activity; a value the server has not seen
 * must fail at the boundary (422), never reach a formula.
 */
import { z } from 'zod';

import { localeSchema, timeZoneSchema } from './auth.js';

/* ------------------------------------------------------------- vocabulary -- */

/** Six goals, exactly as packages/core's `Goal` (§12.1). */
export const GOAL_TYPES = [
  'muscle-gain',
  'fat-loss',
  'recomposition',
  'strength',
  'general',
  'maintenance',
] as const;
export const goalTypeSchema = z.enum(GOAL_TYPES);
export type GoalType = z.infer<typeof goalTypeSchema>;

/** Mifflin-St Jeor is sex-specific (§13.1); the engine has exactly these two. */
export const sexSchema = z.enum(['male', 'female']);
export type Sex = z.infer<typeof sexSchema>;

export const experienceLevelSchema = z.enum(['beginner', 'intermediate', 'advanced']);
export type ExperienceLevel = z.infer<typeof experienceLevelSchema>;

/** Non-training daily activity; drives the TDEE multiplier (§13.1). */
export const activityLevelSchema = z.enum(['sedentary', 'light', 'moderate', 'high']);
export type ActivityLevel = z.infer<typeof activityLevelSchema>;

export const dietTypeSchema = z.enum(['vegetarian', 'eggetarian', 'non-vegetarian']);
export type DietType = z.infer<typeof dietTypeSchema>;

export const trainingLocationSchema = z.enum(['commercial-gym', 'campus-gym', 'home']);
export type TrainingLocation = z.infer<typeof trainingLocationSchema>;

export const EQUIPMENT = [
  'barbell',
  'dumbbell',
  'machine',
  'cable',
  'kettlebell',
  'resistance-band',
  'pull-up-bar',
  'bodyweight',
] as const;
export const equipmentSchema = z.enum(EQUIPMENT);
export type Equipment = z.infer<typeof equipmentSchema>;

/**
 * Allergens are SAFETY-CRITICAL (§9.2): a hard filter in every food
 * recommendation, never a scoring penalty. The list is the Indian FSSAI
 * mandatory-declaration set plus the two most common regional ones.
 */
export const ALLERGENS = [
  'peanut',
  'tree-nut',
  'milk',
  'egg',
  'soy',
  'wheat',
  'fish',
  'shellfish',
  'sesame',
  'mustard',
] as const;
export const allergenSchema = z.enum(ALLERGENS);
export type Allergen = z.infer<typeof allergenSchema>;

export const allergySeveritySchema = z.enum(['mild', 'moderate', 'severe']);

export const bodyPartSchema = z.enum([
  'neck',
  'shoulder',
  'elbow',
  'wrist',
  'lower-back',
  'hip',
  'knee',
  'ankle',
]);
export type BodyPart = z.infer<typeof bodyPartSchema>;

export const unitsSchema = z.enum(['metric', 'imperial']);
export const budgetTierSchema = z.enum(['low', 'medium', 'high']);

/* ----------------------------------------------------------- measurements -- */

/** ISO date, yyyy-mm-dd. Dates in this API carry no time (§9.1). */
export const isoDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be yyyy-mm-dd');

/** Plausible human ranges. Outside these is a typo, not a person. */
export const heightCmSchema = z.number().min(100).max(250);
export const weightKgSchema = z.number().min(30).max(300);
export const trainingDaysSchema = z.number().int().min(1).max(7);

/** §23 and ADR: 18+ only, enforced at onboarding by birth date. */
export const MIN_AGE_YEARS = 18;

/* ------------------------------------------------------------- read shapes -- */

/** Phase 6.6: what the app calls the user. Trimmed, 1–40 characters. */
export const displayNameSchema = z.string().trim().min(1).max(40);

export const userProfileDetailSchema = z.object({
  /** Canonical display name (`users.display_name`); null until answered. */
  displayName: z.string().nullable(),
  sex: sexSchema.nullable(),
  birthDate: isoDateSchema.nullable(),
  heightCm: z.number().nullable(),
  experienceLevel: experienceLevelSchema.nullable(),
  trainingDaysPerWeek: z.number().int().nullable(),
  activityLevel: activityLevelSchema.nullable(),
  preferredSessionMinutes: z.number().int().nullable(),
  trainingLocation: trainingLocationSchema.nullable(),
  equipment: z.array(equipmentSchema),
  /** Latest logged weight, if any. Trend is Phase 12; this is the raw reading. */
  latestWeightKg: z.number().nullable(),
  timezone: timeZoneSchema,
  locale: localeSchema,
  /** The next onboarding step, or 'complete'. */
  onboardingStage: z.string(),
  /** Mess selection (§32 screen 6). Null when not a VIT student. */
  mess: z
    .object({
      providerId: z.string(),
      hostelId: z.string(),
      messId: z.string(),
    })
    .nullable(),
});
export type UserProfileDetail = z.infer<typeof userProfileDetailSchema>;

export const goalSchema = z.object({
  id: z.string().uuid(),
  goalType: goalTypeSchema,
  targetWeightKg: z.number().nullable(),
  startedAt: z.string().datetime(),
});
export type Goal = z.infer<typeof goalSchema>;

export const allergySchema = z.object({
  allergen: allergenSchema,
  severity: allergySeveritySchema,
});

export const dietPreferencesSchema = z.object({
  dietType: dietTypeSchema,
  allergies: z.array(allergySchema),
  excludedDishIds: z.array(z.string()),
  budgetTier: budgetTierSchema.nullable(),
});
export type DietPreferences = z.infer<typeof dietPreferencesSchema>;

export const userPreferencesSchema = z.object({
  units: unitsSchema,
  notificationSettings: z.record(z.string(), z.unknown()),
  featureFlags: z.record(z.string(), z.unknown()),
});
export type UserPreferences = z.infer<typeof userPreferencesSchema>;

/**
 * Nutrition targets as computed by packages/core (§13.1). Every number here is
 * `calculated` (§6.5) and the rationale is the engine's own explanation —
 * shown in-app so the numbers are never a black box.
 */
export const nutritionTargetsSchema = z.object({
  effectiveFrom: isoDateSchema,
  kcal: z.number().int(),
  proteinG: z.number().int(),
  carbG: z.number().int(),
  fatG: z.number().int(),
  fiberG: z.number().int(),
  bmr: z.number().int(),
  tdeeEstimate: z.number().int(),
  rationale: z.array(z.string()),
  /** Why this row exists: 'onboarding', 'goal-change', 'profile-change'. */
  reason: z.string(),
});
export type NutritionTargets = z.infer<typeof nutritionTargetsSchema>;

/* ------------------------------------------------------------ write shapes -- */

export const patchProfileRequestSchema = z
  .object({
    displayName: displayNameSchema.optional(),
    heightCm: heightCmSchema.optional(),
    experienceLevel: experienceLevelSchema.optional(),
    trainingDaysPerWeek: trainingDaysSchema.optional(),
    activityLevel: activityLevelSchema.optional(),
    preferredSessionMinutes: z.number().int().min(15).max(180).optional(),
    trainingLocation: trainingLocationSchema.optional(),
    equipment: z.array(equipmentSchema).optional(),
    timezone: timeZoneSchema.optional(),
    locale: localeSchema.optional(),
  })
  .strict();
export type PatchProfileRequest = z.infer<typeof patchProfileRequestSchema>;

export const putGoalRequestSchema = z
  .object({
    goalType: goalTypeSchema,
    targetWeightKg: weightKgSchema.nullable().optional(),
  })
  .strict();
export type PutGoalRequest = z.infer<typeof putGoalRequestSchema>;

export const putDietPreferencesRequestSchema = z
  .object({
    dietType: dietTypeSchema,
    allergies: z.array(allergySchema).max(ALLERGENS.length),
    excludedDishIds: z.array(z.string().min(1).max(80)).max(200).optional(),
    budgetTier: budgetTierSchema.nullable().optional(),
  })
  .strict();
export type PutDietPreferencesRequest = z.infer<typeof putDietPreferencesRequestSchema>;

export const patchPreferencesRequestSchema = z
  .object({
    units: unitsSchema.optional(),
    notificationSettings: z.record(z.string(), z.unknown()).optional(),
  })
  .strict();
export type PatchPreferencesRequest = z.infer<typeof patchPreferencesRequestSchema>;

/** GET /user/goal and PUT /user/goal both return the goal with fresh targets. */
export const goalResponseSchema = z.object({
  goal: goalSchema,
  targets: nutritionTargetsSchema.nullable(),
});
export type GoalResponse = z.infer<typeof goalResponseSchema>;
