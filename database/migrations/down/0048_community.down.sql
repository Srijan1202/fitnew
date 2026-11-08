-- Down for 0048_community (beta 5.8, ADR-057). Hand-written: drizzle-kit is forward-only (§25).
-- The tables go with their rows. Postgres cannot drop an enum value, so the
-- consent type is rebuilt without `community`; those consent records go too.
DROP TABLE "community_week_stats";
DROP TABLE "community_reports";
DROP TABLE "club_members";
DROP TABLE "clubs";
DROP TABLE "community_blocks";
DROP TABLE "friendships";
DROP TABLE "community_profiles";
DELETE FROM "consent_records" WHERE "consent_type" = 'community';
ALTER TYPE "consent_type" RENAME TO "consent_type_old";
CREATE TYPE "consent_type" AS ENUM ('privacy-policy', 'health-data-processing', 'ai-processing');
ALTER TABLE "consent_records" ALTER COLUMN "consent_type" TYPE "consent_type" USING "consent_type"::text::"consent_type";
DROP TYPE "consent_type_old";
