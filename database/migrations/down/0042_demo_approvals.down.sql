-- Down for 0042_demo_approvals (beta 5.2). Hand-written: drizzle-kit is forward-only (§25).
-- Removes the demo approvals; an app on 5.1.1 shows its demos without asking.
DROP TABLE IF EXISTS "exercise_demo_approvals";
