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
  ALTERNATIVE_REASONS,
  CONFIDENCE_LEVELS,
  CONSENT_TYPES,
  DIFFICULTIES,
  EQUIPMENT,
  FOOD_SOURCES,
  GOAL_TYPES,
  MOVEMENT_PATTERNS,
  MUSCLE_GROUPS,
  MUSCLE_ROLES,
  NUTRITION_BASES,
  ONBOARDING_STEPS,
  ONBOARDING_COMPLETE,
  PR_TYPES,
  PROGRAM_SOURCES,
  SESSION_STATUSES,
  SET_TYPES,
  SPLIT_TYPES,
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

// Phase 3 — exercise library
export const muscleGroupEnum = pgEnum('muscle_group', MUSCLE_GROUPS);
export const movementPatternEnum = pgEnum('movement_pattern', MOVEMENT_PATTERNS);
export const difficultyEnum = pgEnum('difficulty', DIFFICULTIES);
export const muscleRoleEnum = pgEnum('muscle_role', MUSCLE_ROLES);
export const alternativeReasonEnum = pgEnum('alternative_reason', ALTERNATIVE_REASONS);

// Phase 4 — programmes
export const splitTypeEnum = pgEnum('split_type', SPLIT_TYPES);
export const programSourceEnum = pgEnum('program_source', PROGRAM_SOURCES);

// Phase 5 — workout logging
export const setTypeEnum = pgEnum('set_type', SET_TYPES);
export const sessionStatusEnum = pgEnum('session_status', SESSION_STATUSES);
export const prTypeEnum = pgEnum('pr_type', PR_TYPES);

// Phase 7 — food library
export const foodSourceEnum = pgEnum('food_source', FOOD_SOURCES);
export const nutritionBasisEnum = pgEnum('nutrition_basis', NUTRITION_BASES);
export const nutritionConfidenceEnum = pgEnum('nutrition_confidence', CONFIDENCE_LEVELS);
