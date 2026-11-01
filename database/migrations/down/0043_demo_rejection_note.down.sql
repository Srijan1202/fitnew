-- Down for 0043_demo_rejection_note (after beta 5.2). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the rejection notes; a rejected demo stays unapproved.
ALTER TABLE "exercise_demo_approvals" DROP CONSTRAINT IF EXISTS "exercise_demo_approvals_note";
ALTER TABLE "exercise_demo_approvals" DROP COLUMN IF EXISTS "note";
