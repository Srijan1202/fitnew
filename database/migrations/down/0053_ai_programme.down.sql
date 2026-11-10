-- Down for 0053_ai_programme (beta 6.1). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the programme-builder usage rows and rebuilds ai_route without 'programme' (Postgres cannot drop an enum value).
DELETE FROM "ai_usage" WHERE "route"::text = 'programme';
ALTER TYPE "public"."ai_route" RENAME TO "ai_route_b61";
CREATE TYPE "public"."ai_route" AS ENUM('chat', 'parse', 'explain', 'guide', 'photo');
ALTER TABLE "ai_usage" ALTER COLUMN "route" TYPE "public"."ai_route" USING "route"::text::"public"."ai_route";
DROP TYPE "public"."ai_route_b61";
