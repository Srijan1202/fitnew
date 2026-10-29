-- Down for 0037_best_efforts (beta 4.2). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the best efforts and the runs' rules version, removes the running distance firsts from
-- user_rewards, and restores the streak-only check.
DROP TABLE IF EXISTS "run_best_efforts";
DROP TYPE IF EXISTS "effort_key";
ALTER TABLE "runs" DROP COLUMN IF EXISTS "efforts_version";
DELETE FROM "user_rewards" WHERE "reward" in ('first-run', 'first-5k', 'first-10k', 'first-half', 'first-marathon');
ALTER TABLE "user_rewards" DROP CONSTRAINT IF EXISTS "user_rewards_reward";
ALTER TABLE "user_rewards" ADD CONSTRAINT "user_rewards_reward" CHECK ("user_rewards"."reward" in ('spark', 'ember-theme', 'blaze-icon', 'ember-rim', 'century'));
