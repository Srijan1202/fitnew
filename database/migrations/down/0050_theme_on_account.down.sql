-- Down for 0050_theme_on_account (beta 6.1, E23). Hand-written: drizzle-kit is forward-only (§25).
-- Phones keep their own choice, as before 6.1.
ALTER TABLE "user_preferences" DROP CONSTRAINT IF EXISTS "user_preferences_theme_id";
ALTER TABLE "user_preferences" DROP COLUMN IF EXISTS "theme_id";
