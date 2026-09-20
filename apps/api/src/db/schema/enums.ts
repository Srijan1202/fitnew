/**
 * Postgres enum types for every closed vocabulary in @fitos/contracts.
 *
 * DB-level integrity that matches the Zod boundary exactly: a value that is
 * not in the contract cannot be stored even by a direct SQL write. Adding a
 * value later is one `ALTER TYPE ... ADD VALUE` migration.
 *
 * The literal arrays are imported from contracts rather than retyped, so the
 * two cannot drift.
 */
import { pgEnum } from 'drizzle-orm/pg-core';

import {
  ALLERGENS,
  CONSENT_TYPES,
  EQUIPMENT,
  GOAL_TYPES,
  ONBOARDING_STEPS,
  ONBOARDING_COMPLETE,
} from '@fitos/contracts';

export const goalTypeEnum = pgEnum('goal_type', GOAL_TYPES);
export const sexEnum = pgEnum('sex', ['male', 'female']);
export const experienceLevelEnum = pgEnum('experience_level', ['beginner', 'intermediate', 'advanced']);
export const activityLevelEnum = pgEnum('activity_level', ['sedentary', 'light', 'moderate', 'high']);
export const dietTypeEnum = pgEnum('diet_type', ['vegetarian', 'eggetarian', 'non-vegetarian']);
export const trainingLocationEnum = pgEnum('training_location', ['commercial-gym', 'campus-gym', 'home']);
export const equipmentEnum = pgEnum('equipment', EQUIPMENT);
export const allergenEnum = pgEnum('allergen', ALLERGENS);
export const allergySeverityEnum = pgEnum('allergy_severity', ['mild', 'moderate', 'severe']);
export const bodyPartEnum = pgEnum('body_part', [
  'neck', 'shoulder', 'elbow', 'wrist', 'lower-back', 'hip', 'knee', 'ankle',
]);
export const unitsEnum = pgEnum('units', ['metric', 'imperial']);
export const budgetTierEnum = pgEnum('budget_tier', ['low', 'medium', 'high']);
export const consentTypeEnum = pgEnum('consent_type', CONSENT_TYPES);
export const onboardingStageEnum = pgEnum('onboarding_stage', [...ONBOARDING_STEPS, ONBOARDING_COMPLETE]);
export const weightSourceEnum = pgEnum('weight_source', ['onboarding', 'manual', 'health-sync']);
