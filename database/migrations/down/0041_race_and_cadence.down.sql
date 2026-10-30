-- Down for 0041_race_and_cadence (beta 4.9). Hand-written: drizzle-kit is forward-only (§25).
-- Removes race runs (their goal kind goes away), the race target and split, the watch's
-- cadence, and rebuilds run_goal_kind without 'race' (Postgres cannot drop an enum value).
DELETE FROM "runs" WHERE "goal_kind"::text = 'race';
ALTER TABLE "runs" DROP CONSTRAINT IF EXISTS "runs_race";
ALTER TABLE "runs" DROP CONSTRAINT IF EXISTS "runs_cadence";
ALTER TABLE "runs" DROP CONSTRAINT IF EXISTS "runs_goal";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "goal_target_seconds";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "goal_split";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "cadence_avg";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "cadence_max";
ALTER TYPE "public"."run_goal_kind" RENAME TO "run_goal_kind_b49";
CREATE TYPE "public"."run_goal_kind" AS ENUM('free', 'distance', 'time', 'pace');
ALTER TABLE "runs" ALTER COLUMN "goal_kind" TYPE "public"."run_goal_kind" USING "goal_kind"::text::"public"."run_goal_kind";
DROP TYPE "public"."run_goal_kind_b49";
ALTER TABLE "runs" ADD CONSTRAINT "runs_goal" CHECK (("runs"."goal_kind" = 'free') = ("runs"."goal_value" is null));
