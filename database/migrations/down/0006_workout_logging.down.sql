-- Reverses 0006_workout_logging. Logged sessions are user data (§9.1);
-- rolling this back destroys them, which is why it is only ever run by
-- the migration test against the test database.
DROP TABLE IF EXISTS "exercise_prs";
DROP TABLE IF EXISTS "set_logs";
DROP TABLE IF EXISTS "session_exercises";
DROP TABLE IF EXISTS "workout_sessions";
DROP TYPE IF EXISTS "public"."pr_type";
DROP TYPE IF EXISTS "public"."session_status";
DROP TYPE IF EXISTS "public"."set_type";
