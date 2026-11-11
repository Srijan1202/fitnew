-- Down for 0054_community_moves (beta 6.2). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the club bans, friend declines and past weeks, and the two new week counts.
DROP TABLE IF EXISTS "club_bans";
DROP TABLE IF EXISTS "friend_declines";
DROP TABLE IF EXISTS "community_week_history";
ALTER TABLE "community_week_stats" DROP CONSTRAINT IF EXISTS "community_week_stats_days";
ALTER TABLE "community_week_stats" DROP COLUMN IF EXISTS "planned";
ALTER TABLE "community_week_stats" DROP COLUMN IF EXISTS "active_days";
