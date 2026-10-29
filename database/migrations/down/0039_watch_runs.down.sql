-- Down for 0039_watch_runs (beta 4.5). Hand-written: drizzle-kit is forward-only (§25).
-- Removes the watch runs (they need columns going away), the source, record id and heart rate,
-- the beta 4.5 badges from user_rewards, and restores the 4.2 checks.
DELETE FROM "runs" WHERE "source" = 'watch';
ALTER TABLE "runs" DROP CONSTRAINT IF EXISTS "runs_track_kind";
ALTER TABLE "runs" DROP CONSTRAINT IF EXISTS "runs_external";
ALTER TABLE "runs" DROP CONSTRAINT IF EXISTS "runs_hr";
DROP INDEX IF EXISTS "runs_user_external_id";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "source";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "external_id";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "hr_avg";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "hr_max";
DROP TYPE IF EXISTS "run_source";
ALTER TABLE "runs" ADD CONSTRAINT "runs_track_kind" CHECK (("runs"."kind" = 'outdoor') = ("runs"."track_points" is not null and "runs"."track_breaks" is not null and "runs"."track_elevation" is not null));
DELETE FROM "user_rewards" WHERE "reward" in ('speed-5k-30', 'speed-5k-25', 'speed-5k-20', 'speed-10k-60', 'speed-10k-50', 'speed-half-2h', 'speed-marathon-4h', 'total-50k', 'total-100k', 'total-250k', 'total-500k', 'total-1000k', 'weeks-4', 'three-in-a-week', 'plan-finished');
ALTER TABLE "user_rewards" DROP CONSTRAINT IF EXISTS "user_rewards_reward";
ALTER TABLE "user_rewards" ADD CONSTRAINT "user_rewards_reward" CHECK ("user_rewards"."reward" in ('spark', 'ember-theme', 'blaze-icon', 'ember-rim', 'century', 'first-run', 'first-5k', 'first-10k', 'first-half', 'first-marathon'));
