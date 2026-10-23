-- Beta 3.4 (ADR-027 amendment): undo 0030_streak_rewards. Earned rewards go;
-- a streak picture in use falls back to none (the old check knows neither).
DROP TABLE IF EXISTS "user_rewards";
UPDATE "users" SET "avatar_id" = NULL WHERE "avatar_id" in ('spark', 'century');
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_avatar_id";
ALTER TABLE "users" ADD CONSTRAINT "users_avatar_id" CHECK ("users"."avatar_id" is null or "users"."avatar_id" in ('dumbbell', 'runner', 'yoga', 'cyclist', 'swimmer', 'boxer', 'hiker', 'crown', 'flame', 'trophy'));
