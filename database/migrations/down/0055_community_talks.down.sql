-- Down for 0055_community_talks (beta 6.3). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the feed, kudos, nudges, dismissed suggestions and period counts, and the profile's new settings.
DROP TABLE IF EXISTS "community_kudos";
DROP TABLE IF EXISTS "community_posts";
DROP TABLE IF EXISTS "community_nudges";
DROP TABLE IF EXISTS "community_suggestion_dismissals";
DROP TABLE IF EXISTS "community_period_stats";
ALTER TABLE "community_profiles" DROP CONSTRAINT IF EXISTS "community_profiles_feed";
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "nudge_pushed_on";
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "kudos_pushed_on";
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "notify";
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "suggest";
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "feed_since";
ALTER TABLE "community_profiles" DROP COLUMN IF EXISTS "feed";
