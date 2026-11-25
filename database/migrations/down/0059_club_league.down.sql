-- Down for 0059_club_league (beta 6.6, L1 and L2). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the league and the co-owner role. League matches stay as ordinary matches.
ALTER TABLE "club_matches" DROP COLUMN IF EXISTS "league_season_id";
DROP TABLE IF EXISTS "league_entries";
DROP TABLE IF EXISTS "league_seasons";
DROP TABLE IF EXISTS "league_clubs";
ALTER TABLE "club_members" DROP CONSTRAINT IF EXISTS "club_members_role";
ALTER TABLE "club_members" DROP COLUMN IF EXISTS "role";
