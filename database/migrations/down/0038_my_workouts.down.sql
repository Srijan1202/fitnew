-- Down for 0038_my_workouts (beta 4.4). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the runners' own sessions, and restores 3–5 runs a week: plans with 1 or 2
-- (allowed from 4.4) are removed first, with their planned runs (cascade).
DROP TABLE IF EXISTS "running_workouts";
DELETE FROM "running_plans" WHERE "days_per_week" < 3;
ALTER TABLE "running_plans" DROP CONSTRAINT IF EXISTS "running_plans_days";
ALTER TABLE "running_plans" ADD CONSTRAINT "running_plans_days" CHECK ("running_plans"."days_per_week" between 3 and 5);
