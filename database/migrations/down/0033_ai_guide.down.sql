-- Beta 3.6 (ADR-020 amendment): undo 0033_ai_guide. Postgres cannot drop an
-- enum value, so the food guide's usage rows go and the type is rebuilt.
DELETE FROM "ai_usage" WHERE "route"::text = 'guide';
ALTER TYPE "public"."ai_route" RENAME TO "ai_route_old";
CREATE TYPE "public"."ai_route" AS ENUM('chat', 'parse', 'explain');
ALTER TABLE "ai_usage" ALTER COLUMN "route" TYPE "public"."ai_route" USING "route"::text::"public"."ai_route";
DROP TYPE "public"."ai_route_old";
