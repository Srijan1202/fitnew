-- Reverts 0009_food_library (Phase 7 food library). Children first; the enum
-- types go last, once nothing uses them. Custom foods are user data: running
-- this deletes them along with the seeded library.
DROP TABLE IF EXISTS "food_aliases";
DROP TABLE IF EXISTS "food_nutrition";
DROP TABLE IF EXISTS "foods";
DROP TYPE IF EXISTS "public"."nutrition_confidence";
DROP TYPE IF EXISTS "public"."nutrition_basis";
DROP TYPE IF EXISTS "public"."food_source";
