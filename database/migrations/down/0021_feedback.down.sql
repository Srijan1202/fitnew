-- Phase 19 (ADR-026): undo 0021_feedback. The table and its rows go; nothing
-- else references it.
DROP TABLE IF EXISTS "feedback";
