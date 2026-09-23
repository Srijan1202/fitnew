CREATE TYPE "public"."food_source" AS ENUM('estimated', 'usda', 'ifct', 'indb', 'user', 'user-corrected');--> statement-breakpoint
CREATE TYPE "public"."nutrition_basis" AS ENUM('per_100g', 'per_serving');--> statement-breakpoint
CREATE TYPE "public"."nutrition_confidence" AS ENUM('high', 'medium', 'low');--> statement-breakpoint
CREATE TABLE "food_aliases" (
	"food_id" uuid NOT NULL,
	"alias" text NOT NULL,
	CONSTRAINT "food_aliases_food_id_alias_pk" PRIMARY KEY("food_id","alias"),
	CONSTRAINT "food_aliases_normalised" CHECK ("food_aliases"."alias" ~ '^[a-z0-9]+( [a-z0-9]+)*$')
);
--> statement-breakpoint
CREATE TABLE "food_nutrition" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"food_id" uuid NOT NULL,
	"position" smallint NOT NULL,
	"basis" "nutrition_basis" NOT NULL,
	"serving_label" text NOT NULL,
	"serving_grams" numeric(8, 2),
	"kcal_low" numeric(8, 2) NOT NULL,
	"kcal_high" numeric(8, 2) NOT NULL,
	"protein_low" numeric(8, 2) NOT NULL,
	"protein_high" numeric(8, 2) NOT NULL,
	"carb_low" numeric(8, 2) NOT NULL,
	"carb_high" numeric(8, 2) NOT NULL,
	"fat_low" numeric(8, 2) NOT NULL,
	"fat_high" numeric(8, 2) NOT NULL,
	"fibre_low" numeric(8, 2),
	"fibre_high" numeric(8, 2),
	"confidence" "nutrition_confidence" NOT NULL,
	CONSTRAINT "food_nutrition_serving_grams_positive" CHECK ("food_nutrition"."serving_grams" IS NULL OR "food_nutrition"."serving_grams" > 0),
	CONSTRAINT "food_nutrition_label_nonempty" CHECK (length(btrim("food_nutrition"."serving_label")) > 0),
	CONSTRAINT "food_nutrition_nonnegative" CHECK ("food_nutrition"."kcal_low" >= 0 AND "food_nutrition"."protein_low" >= 0 AND "food_nutrition"."carb_low" >= 0 AND "food_nutrition"."fat_low" >= 0),
	CONSTRAINT "food_nutrition_kcal_range" CHECK ("food_nutrition"."kcal_low" <= "food_nutrition"."kcal_high"),
	CONSTRAINT "food_nutrition_protein_range" CHECK ("food_nutrition"."protein_low" <= "food_nutrition"."protein_high"),
	CONSTRAINT "food_nutrition_carb_range" CHECK ("food_nutrition"."carb_low" <= "food_nutrition"."carb_high"),
	CONSTRAINT "food_nutrition_fat_range" CHECK ("food_nutrition"."fat_low" <= "food_nutrition"."fat_high"),
	CONSTRAINT "food_nutrition_fibre_range" CHECK (("food_nutrition"."fibre_low" IS NULL AND "food_nutrition"."fibre_high" IS NULL) OR ("food_nutrition"."fibre_low" IS NOT NULL AND "food_nutrition"."fibre_high" IS NOT NULL AND "food_nutrition"."fibre_low" >= 0 AND "food_nutrition"."fibre_low" <= "food_nutrition"."fibre_high"))
);
--> statement-breakpoint
CREATE TABLE "foods" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL,
	"name" text NOT NULL,
	"search_name" text GENERATED ALWAYS AS (btrim(regexp_replace(lower(name), '[^a-z0-9]+', ' ', 'g'))) STORED NOT NULL,
	"brand" text,
	"barcode" text,
	"source" "food_source" NOT NULL,
	"source_ref" text,
	"is_verified" boolean DEFAULT false NOT NULL,
	"owner_user_id" uuid,
	"client_food_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "foods_slug_unique" UNIQUE("slug"),
	CONSTRAINT "foods_name_nonempty" CHECK (length(btrim("foods"."name")) > 0),
	CONSTRAINT "foods_owner_matches_source" CHECK (("foods"."owner_user_id" IS NOT NULL) = ("foods"."source" IN ('user', 'user-corrected'))),
	CONSTRAINT "foods_unverified_sources" CHECK (NOT ("foods"."is_verified" AND "foods"."source" IN ('estimated', 'user', 'user-corrected'))),
	CONSTRAINT "foods_client_id_custom_only" CHECK (("foods"."source" = 'user') = ("foods"."client_food_id" IS NOT NULL))
);
--> statement-breakpoint
ALTER TABLE "food_aliases" ADD CONSTRAINT "food_aliases_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_nutrition" ADD CONSTRAINT "food_nutrition_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "foods" ADD CONSTRAINT "foods_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "food_aliases_alias_trgm_idx" ON "food_aliases" USING gin ("alias" gin_trgm_ops);--> statement-breakpoint
CREATE UNIQUE INDEX "food_nutrition_food_position_idx" ON "food_nutrition" USING btree ("food_id","position");--> statement-breakpoint
CREATE UNIQUE INDEX "food_nutrition_food_serving_idx" ON "food_nutrition" USING btree ("food_id","basis","serving_label");--> statement-breakpoint
CREATE INDEX "foods_search_name_trgm_idx" ON "foods" USING gin ("search_name" gin_trgm_ops);--> statement-breakpoint
CREATE INDEX "foods_owner_idx" ON "foods" USING btree ("owner_user_id") WHERE "foods"."owner_user_id" IS NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "foods_owner_client_idx" ON "foods" USING btree ("owner_user_id","client_food_id") WHERE "foods"."client_food_id" IS NOT NULL;