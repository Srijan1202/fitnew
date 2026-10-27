-- Down for 0036_running_plans (beta 4.1, ADR-039). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the plans and their planned runs, the workout and lap columns on runs, and their types.
-- Postgres cannot drop an enum value, so `today_action_kind` is rebuilt without 'start-run';
-- any start-run recommendations (and, by cascade, their events) are removed first.
DROP TABLE IF EXISTS "planned_runs";
DROP TABLE IF EXISTS "running_plans";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "workout";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "lap_marks";
DROP TYPE IF EXISTS "planned_run_status";
DROP TYPE IF EXISTS "planned_run_kind";
DROP TYPE IF EXISTS "plan_status";
DROP TYPE IF EXISTS "plan_level";
DROP TYPE IF EXISTS "plan_goal";
DELETE FROM "recommendations" WHERE "kind" = 'start-run';
ALTER TYPE "today_action_kind" RENAME TO "today_action_kind_b41";
CREATE TYPE "today_action_kind" AS ENUM('deload', 'injured-limitation', 'start-workout', 'low-readiness', 'eat-protein', 'eat-meal', 'progress-load', 'muscle-neglected', 'rest-day', 'calorie-adjust', 'celebrate-pr', 'log-weight');
ALTER TABLE "recommendations" ALTER COLUMN "kind" TYPE "today_action_kind" USING "kind"::text::"today_action_kind";
DROP TYPE "today_action_kind_b41";
