-- Reverts 0010_nutrition_logging (Phase 8 food logging). Children first; the
-- enum types go last, once nothing uses them. Food logs and saved meals are
-- user data: running this deletes every logged day. The food library (0009)
-- is untouched.
DROP TABLE IF EXISTS "food_log_items";
DROP TABLE IF EXISTS "food_logs";
DROP TABLE IF EXISTS "saved_meals";
DROP TABLE IF EXISTS "daily_nutrition";
DROP TYPE IF EXISTS "public"."meal_slot";
DROP TYPE IF EXISTS "public"."food_entry_method";
