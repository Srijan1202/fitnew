-- Beta 4.0 (ADR-038): undo 0035_running. The runs go with the table.
DROP TABLE IF EXISTS "runs";
DROP TYPE IF EXISTS "public"."run_kind";
DROP TYPE IF EXISTS "public"."run_goal_kind";
