-- Beta 3.7 (ADR-036): undo 0034_food_source_cofid. Postgres cannot drop an
-- enum value, so CoFID foods and log items fall back to "estimated" (and lose
-- "verified", which an estimate may not have) and the type is rebuilt. The
-- four CHECKs that compare the column with literals of the type are dropped
-- first and recreated after (a literal of the old type cannot be re-typed).
UPDATE "foods" SET "source" = 'estimated', "is_verified" = false WHERE "source"::text = 'cofid';
UPDATE "food_log_items" SET "food_source" = 'estimated' WHERE "food_source"::text = 'cofid';
ALTER TABLE "foods" DROP CONSTRAINT "foods_owner_matches_source";
ALTER TABLE "foods" DROP CONSTRAINT "foods_unverified_sources";
ALTER TABLE "foods" DROP CONSTRAINT "foods_client_id_custom_only";
ALTER TABLE "mess_dish_nutrition" DROP CONSTRAINT "mess_dish_nutrition_source";
ALTER TYPE "public"."food_source" RENAME TO "food_source_old";
CREATE TYPE "public"."food_source" AS ENUM('estimated', 'usda', 'ifct', 'indb', 'user', 'user-corrected');
ALTER TABLE "foods" ALTER COLUMN "source" TYPE "public"."food_source" USING "source"::text::"public"."food_source";
ALTER TABLE "food_log_items" ALTER COLUMN "food_source" TYPE "public"."food_source" USING "food_source"::text::"public"."food_source";
ALTER TABLE "mess_dish_nutrition" ALTER COLUMN "source" DROP DEFAULT;
ALTER TABLE "mess_dish_nutrition" ALTER COLUMN "source" TYPE "public"."food_source" USING "source"::text::"public"."food_source";
ALTER TABLE "mess_dish_nutrition" ALTER COLUMN "source" SET DEFAULT 'estimated';
DROP TYPE "public"."food_source_old";
ALTER TABLE "foods" ADD CONSTRAINT "foods_owner_matches_source" CHECK (("owner_user_id" IS NOT NULL) = ("source" IN ('user', 'user-corrected')));
ALTER TABLE "foods" ADD CONSTRAINT "foods_unverified_sources" CHECK (NOT ("is_verified" AND "source" IN ('estimated', 'user', 'user-corrected')));
ALTER TABLE "foods" ADD CONSTRAINT "foods_client_id_custom_only" CHECK (("source" = 'user') = ("client_food_id" IS NOT NULL));
ALTER TABLE "mess_dish_nutrition" ADD CONSTRAINT "mess_dish_nutrition_source" CHECK ("source" = 'estimated');
