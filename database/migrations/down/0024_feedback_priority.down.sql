-- Phase 19 (ADR-026 amendment): undo 0024_feedback_priority. The triage
-- tags go; the feedback itself stays.
ALTER TABLE "feedback" DROP CONSTRAINT IF EXISTS "feedback_priority";
ALTER TABLE "feedback" DROP COLUMN IF EXISTS "priority";
