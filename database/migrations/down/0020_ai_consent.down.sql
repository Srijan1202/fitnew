-- Down for 0020_ai_consent (Phase 17). Hand-written: drizzle-kit is forward-only (§25).
-- Postgres cannot drop an enum value, so the type is rebuilt without it; the
-- AI consent records go with it (they are meaningless without the purpose).
DELETE FROM "consent_records" WHERE "consent_type" = 'ai-processing';
ALTER TYPE "consent_type" RENAME TO "consent_type_old";
CREATE TYPE "consent_type" AS ENUM ('privacy-policy', 'health-data-processing');
ALTER TABLE "consent_records" ALTER COLUMN "consent_type" TYPE "consent_type" USING "consent_type"::text::"consent_type";
DROP TYPE "consent_type_old";
