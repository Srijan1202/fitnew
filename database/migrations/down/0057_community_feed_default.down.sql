-- Down for 0057_community_feed_default (beta 6.5, K0). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the mark that the feed was switched on by default.
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "feed_defaulted";
