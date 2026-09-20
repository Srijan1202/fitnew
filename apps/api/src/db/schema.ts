/**
 * Drizzle schema barrel. Tables are added per phase, never speculatively, so
 * every migration in git corresponds to a feature that actually shipped.
 *
 * This barrel lives BESIDE schema/, not inside it, on purpose: drizzle-kit's
 * loader is CommonJS and cannot resolve the `.js` re-exports Node ESM needs,
 * so drizzle.config.ts globs the leaf files in schema/ directly and never
 * touches this file. App code imports from here.
 *
 *   Phase 1  users
 *   Phase 2  user_profiles, user_goals, user_preferences, diet_preferences,
 *            user_allergies, user_limitations, consent_records,
 *            nutrition_targets, body_metrics (pulled forward from Phase 12)
 *   Phase 3  exercises, exercise_muscles, exercise_alternatives,
 *            exercise_contraindications
 *   Phase 4  programs, program_days, planned_exercises
 */
export * from './schema/enums.js';
export * from './schema/users.js';
export * from './schema/profile.js';
export * from './schema/diet.js';
export * from './schema/records.js';
export * from './schema/exercise.js';
export * from './schema/training.js';
