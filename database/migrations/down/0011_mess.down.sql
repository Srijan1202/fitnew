-- Down for 0011_mess (Phase 9, VIT mess). Hand-written: drizzle-kit is forward-only (§25).
--
-- Rows that can only exist under 0011 are removed first, as in 0004's down:
--   * logs made from a mess menu (entry_method 'mess'): their items cascade;
--   * saved meals holding a mess item (kind 'mess'), which 0010 cannot expand.
-- Items of saved-meal logs that came from a mess dish stay: each is a complete
-- 0010 snapshot (food_id NULL, a per-serving row); only its slug is dropped.
-- daily_nutrition is then rebuilt from the live items, exactly as
-- `pnpm db:rebuild-nutrition` does. The mirrored menus and corrections go.
-- Postgres cannot remove an enum value, so food_entry_method is rebuilt with
-- its 0010 value list.
DELETE FROM "saved_meals" WHERE "items" @> '[{"kind": "mess"}]'::jsonb;
DELETE FROM "food_logs" WHERE "entry_method"::text = 'mess';

DELETE FROM "daily_nutrition";
INSERT INTO "daily_nutrition" (user_id, local_date, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high,
  fat_low, fat_high, fibre_known_low, fibre_known_high, fibre_unknown_items, item_count)
SELECT l.user_id, l.local_date,
  sum(i.kcal_low), sum(i.kcal_high), sum(i.protein_low), sum(i.protein_high), sum(i.carb_low), sum(i.carb_high),
  sum(i.fat_low), sum(i.fat_high), coalesce(sum(i.fibre_low), 0), coalesce(sum(i.fibre_high), 0),
  count(*) FILTER (WHERE i.fibre_low IS NULL), count(*)
FROM "food_logs" l JOIN "food_log_items" i ON i.food_log_id = l.id
WHERE l.deleted_at IS NULL
GROUP BY l.user_id, l.local_date;

ALTER TABLE "food_log_items" DROP CONSTRAINT IF EXISTS "food_log_items_mess_or_food";
ALTER TABLE "food_log_items" DROP COLUMN IF EXISTS "mess_dish_slug";
ALTER TABLE "food_logs" DROP CONSTRAINT IF EXISTS "food_logs_mess_method";
ALTER TABLE "food_logs" DROP CONSTRAINT IF EXISTS "food_logs_mess_id_messes_id_fk";
ALTER TABLE "food_logs" DROP COLUMN IF EXISTS "mess_id";

DROP TABLE IF EXISTS "mess_dish_corrections";
DROP TABLE IF EXISTS "mess_dish_nutrition";
DROP TABLE IF EXISTS "mess_menu_snapshots";
DROP TABLE IF EXISTS "messes";
DROP TABLE IF EXISTS "mess_providers";

-- The 0010 CHECK compares entry_method with an enum literal: it cannot survive
-- the type swap, so it is dropped and re-created exactly as 0010 wrote it.
ALTER TABLE "food_logs" DROP CONSTRAINT IF EXISTS "food_logs_saved_meal_method";
ALTER TYPE "public"."food_entry_method" RENAME TO "food_entry_method_0011";
CREATE TYPE "public"."food_entry_method" AS ENUM('search', 'quick-add', 'saved-meal');
ALTER TABLE "food_logs"
  ALTER COLUMN "entry_method" TYPE "public"."food_entry_method" USING "entry_method"::text::"public"."food_entry_method";
DROP TYPE "public"."food_entry_method_0011";
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_saved_meal_method" CHECK ("food_logs"."saved_meal_id" IS NULL OR "food_logs"."entry_method" = 'saved-meal');
