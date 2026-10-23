-- Beta 3.2 (ADR-031): undo 0025_custom_targets. Custom rows stay as rows
-- (their numbers are history); only the source column and its check go.
ALTER TABLE "nutrition_targets" DROP CONSTRAINT IF EXISTS "nutrition_targets_source";
ALTER TABLE "nutrition_targets" DROP COLUMN IF EXISTS "source";
