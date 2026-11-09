-- Down for 0051_flag_audience (beta 6.1, early access). Hand-written: drizzle-kit is forward-only (§25).
-- A switch on for premium only becomes on for everyone, as before 6.1.
ALTER TABLE "feature_flags" DROP CONSTRAINT IF EXISTS "feature_flags_audience";
ALTER TABLE "feature_flags" DROP COLUMN IF EXISTS "audience";
