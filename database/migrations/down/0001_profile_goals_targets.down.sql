-- Down for 0001_profile_goals_targets. Hand-written: drizzle-kit is forward-only (§25).
-- Tables first (they depend on the enum types), then the types.
DROP TABLE IF EXISTS "body_metrics";
DROP TABLE IF EXISTS "nutrition_targets";
DROP TABLE IF EXISTS "consent_records";
DROP TABLE IF EXISTS "user_limitations";
DROP TABLE IF EXISTS "user_allergies";
DROP TABLE IF EXISTS "diet_preferences";
DROP TABLE IF EXISTS "user_preferences";
DROP TABLE IF EXISTS "user_goals";
DROP TABLE IF EXISTS "user_profiles";

DROP TYPE IF EXISTS "public"."weight_source";
DROP TYPE IF EXISTS "public"."onboarding_stage";
DROP TYPE IF EXISTS "public"."consent_type";
DROP TYPE IF EXISTS "public"."budget_tier";
DROP TYPE IF EXISTS "public"."units";
DROP TYPE IF EXISTS "public"."body_part";
DROP TYPE IF EXISTS "public"."allergy_severity";
DROP TYPE IF EXISTS "public"."allergen";
DROP TYPE IF EXISTS "public"."equipment";
DROP TYPE IF EXISTS "public"."training_location";
DROP TYPE IF EXISTS "public"."diet_type";
DROP TYPE IF EXISTS "public"."activity_level";
DROP TYPE IF EXISTS "public"."experience_level";
DROP TYPE IF EXISTS "public"."sex";
DROP TYPE IF EXISTS "public"."goal_type";
