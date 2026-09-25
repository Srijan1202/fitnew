-- Down for 0015_progress (Phase 12, Progress). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the measurements table and its site type, and the PR window index. Postgres cannot drop
-- an enum value, so `today_action_kind` is rebuilt without 'calorie-adjust'; any calorie-adjust
-- recommendations (and, by cascade, their events) are removed first. Target rows a calorie-adjust
-- acceptance created stay: they are ordinary history (reason 'calorie-adjust' is plain text).
DROP INDEX IF EXISTS "exercise_prs_user_achieved_idx";
DROP TABLE IF EXISTS "body_measurements";
DROP TYPE IF EXISTS "measurement_site";
DELETE FROM "recommendations" WHERE "kind" = 'calorie-adjust';
ALTER TYPE "today_action_kind" RENAME TO "today_action_kind_p12";
CREATE TYPE "today_action_kind" AS ENUM('deload', 'injured-limitation', 'start-workout', 'eat-protein', 'eat-meal', 'progress-load', 'muscle-neglected', 'rest-day', 'celebrate-pr', 'log-weight');
ALTER TABLE "recommendations" ALTER COLUMN "kind" TYPE "today_action_kind" USING "kind"::text::"today_action_kind";
DROP TYPE "today_action_kind_p12";
