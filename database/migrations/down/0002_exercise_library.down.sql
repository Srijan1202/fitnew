-- Down for 0002_exercise_library. Hand-written: drizzle-kit is forward-only (§25).
-- Join tables first (they reference exercises), then the types.
DROP TABLE IF EXISTS "exercise_contraindications";
DROP TABLE IF EXISTS "exercise_alternatives";
DROP TABLE IF EXISTS "exercise_muscles";
DROP TABLE IF EXISTS "exercises";

DROP TYPE IF EXISTS "public"."muscle_role";
DROP TYPE IF EXISTS "public"."muscle_group";
DROP TYPE IF EXISTS "public"."movement_pattern";
DROP TYPE IF EXISTS "public"."difficulty";
DROP TYPE IF EXISTS "public"."alternative_reason";
