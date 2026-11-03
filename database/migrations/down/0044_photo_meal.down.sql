-- Down for 0044_photo_meal (beta 5.5). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the photo usage rows and rebuilds ai_route without 'photo' (Postgres cannot drop an enum value).
DELETE FROM "ai_usage" WHERE "route"::text = 'photo';
ALTER TYPE "public"."ai_route" RENAME TO "ai_route_b55";
CREATE TYPE "public"."ai_route" AS ENUM('chat', 'parse', 'explain', 'guide');
ALTER TABLE "ai_usage" ALTER COLUMN "route" TYPE "public"."ai_route" USING "route"::text::"public"."ai_route";
DROP TYPE "public"."ai_route_b55";
