-- Beta 3.2 (ADR-032): undo 0027_community_foods. Shared foods become their
-- owners' private foods again; the wrong-numbers reports go.
DROP TABLE IF EXISTS "food_reports";
DROP INDEX IF EXISTS "foods_community_idx";
ALTER TABLE "foods" DROP CONSTRAINT IF EXISTS "foods_visibility_custom_only";
ALTER TABLE "foods" DROP CONSTRAINT IF EXISTS "foods_visibility";
ALTER TABLE "foods" DROP COLUMN IF EXISTS "visibility";
