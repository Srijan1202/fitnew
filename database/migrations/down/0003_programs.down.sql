-- Down for 0003_programs. Hand-written: drizzle-kit is forward-only (§25).
DROP TABLE IF EXISTS "planned_exercises";
DROP TABLE IF EXISTS "program_days";
DROP TABLE IF EXISTS "programs";

DROP TYPE IF EXISTS "public"."split_type";
DROP TYPE IF EXISTS "public"."program_source";
