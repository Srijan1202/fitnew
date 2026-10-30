-- Down for 0040_rewards_unlocked (after beta 4.6). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the admin's test switch that unlocks every reward theme, icon, picture and rim.
ALTER TABLE "users" DROP COLUMN IF EXISTS "rewards_unlocked";
