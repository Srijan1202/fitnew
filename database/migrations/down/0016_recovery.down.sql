-- Down for 0016_recovery (Phase 13, Recovery). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the check-in table and its source type. Postgres cannot drop an enum value, so
-- `today_action_kind` is rebuilt without 'low-readiness'; any low-readiness recommendations
-- (and, by cascade, their events) are removed first. Nothing else references either.
DROP TABLE IF EXISTS "recovery_logs";
DROP TYPE IF EXISTS "recovery_source";
DELETE FROM "recommendations" WHERE "kind" = 'low-readiness';
ALTER TYPE "today_action_kind" RENAME TO "today_action_kind_p13";
CREATE TYPE "today_action_kind" AS ENUM('deload', 'injured-limitation', 'start-workout', 'eat-protein', 'eat-meal', 'progress-load', 'muscle-neglected', 'rest-day', 'calorie-adjust', 'celebrate-pr', 'log-weight');
ALTER TABLE "recommendations" ALTER COLUMN "kind" TYPE "today_action_kind" USING "kind"::text::"today_action_kind";
DROP TYPE "today_action_kind_p13";
