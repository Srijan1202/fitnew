CREATE TYPE "public"."food_entry_method" AS ENUM('search', 'quick-add', 'saved-meal');--> statement-breakpoint
CREATE TYPE "public"."meal_slot" AS ENUM('breakfast', 'lunch', 'snacks', 'dinner');--> statement-breakpoint
CREATE TABLE "daily_nutrition" (
	"user_id" uuid NOT NULL,
	"local_date" text NOT NULL,
	"kcal_low" numeric(9, 2) DEFAULT '0' NOT NULL,
	"kcal_high" numeric(9, 2) DEFAULT '0' NOT NULL,
	"protein_low" numeric(9, 2) DEFAULT '0' NOT NULL,
	"protein_high" numeric(9, 2) DEFAULT '0' NOT NULL,
	"carb_low" numeric(9, 2) DEFAULT '0' NOT NULL,
	"carb_high" numeric(9, 2) DEFAULT '0' NOT NULL,
	"fat_low" numeric(9, 2) DEFAULT '0' NOT NULL,
	"fat_high" numeric(9, 2) DEFAULT '0' NOT NULL,
	"fibre_known_low" numeric(9, 2) DEFAULT '0' NOT NULL,
	"fibre_known_high" numeric(9, 2) DEFAULT '0' NOT NULL,
	"fibre_unknown_items" integer DEFAULT 0 NOT NULL,
	"item_count" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "daily_nutrition_user_id_local_date_pk" PRIMARY KEY("user_id","local_date"),
	CONSTRAINT "daily_nutrition_counts" CHECK ("daily_nutrition"."fibre_unknown_items" >= 0 AND "daily_nutrition"."item_count" >= 0 AND "daily_nutrition"."fibre_unknown_items" <= "daily_nutrition"."item_count")
);
--> statement-breakpoint
CREATE TABLE "food_log_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"food_log_id" uuid NOT NULL,
	"position" smallint NOT NULL,
	"food_id" uuid,
	"food_name" text NOT NULL,
	"food_source" "food_source" NOT NULL,
	"basis" "nutrition_basis",
	"serving_label" text,
	"serving_grams" numeric(7, 2),
	"servings" numeric(10, 4) NOT NULL,
	"grams" numeric(7, 1),
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
	CONSTRAINT "food_log_items_name_nonempty" CHECK (length(btrim("food_log_items"."food_name")) > 0),
	CONSTRAINT "food_log_items_servings_positive" CHECK ("food_log_items"."servings" > 0),
	CONSTRAINT "food_log_items_grams_positive" CHECK ("food_log_items"."grams" IS NULL OR "food_log_items"."grams" > 0),
	CONSTRAINT "food_log_items_row_both_or_neither" CHECK (("food_log_items"."basis" IS NULL) = ("food_log_items"."serving_label" IS NULL)),
	CONSTRAINT "food_log_items_nonnegative" CHECK ("food_log_items"."kcal_low" >= 0 AND "food_log_items"."protein_low" >= 0 AND "food_log_items"."carb_low" >= 0 AND "food_log_items"."fat_low" >= 0),
	CONSTRAINT "food_log_items_kcal_range" CHECK ("food_log_items"."kcal_low" <= "food_log_items"."kcal_high"),
	CONSTRAINT "food_log_items_protein_range" CHECK ("food_log_items"."protein_low" <= "food_log_items"."protein_high"),
	CONSTRAINT "food_log_items_carb_range" CHECK ("food_log_items"."carb_low" <= "food_log_items"."carb_high"),
	CONSTRAINT "food_log_items_fat_range" CHECK ("food_log_items"."fat_low" <= "food_log_items"."fat_high"),
	CONSTRAINT "food_log_items_fibre_range" CHECK (("food_log_items"."fibre_low" IS NULL AND "food_log_items"."fibre_high" IS NULL) OR ("food_log_items"."fibre_low" IS NOT NULL AND "food_log_items"."fibre_high" IS NOT NULL AND "food_log_items"."fibre_low" >= 0 AND "food_log_items"."fibre_low" <= "food_log_items"."fibre_high"))
);
--> statement-breakpoint
CREATE TABLE "food_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"client_log_id" uuid NOT NULL,
	"logged_at" timestamp with time zone NOT NULL,
	"local_date" text NOT NULL,
	"meal_slot" "meal_slot" NOT NULL,
	"entry_method" "food_entry_method" NOT NULL,
	"saved_meal_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "food_logs_local_date_format" CHECK ("food_logs"."local_date" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
	CONSTRAINT "food_logs_saved_meal_method" CHECK ("food_logs"."saved_meal_id" IS NULL OR "food_logs"."entry_method" = 'saved-meal')
);
--> statement-breakpoint
CREATE TABLE "saved_meals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"client_meal_id" uuid NOT NULL,
	"name" text NOT NULL,
	"items" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "saved_meals_name_length" CHECK (length(btrim("saved_meals"."name")) between 1 and 60),
	CONSTRAINT "saved_meals_items_nonempty" CHECK (jsonb_typeof("saved_meals"."items") = 'array' AND jsonb_array_length("saved_meals"."items") > 0)
);
--> statement-breakpoint
ALTER TABLE "daily_nutrition" ADD CONSTRAINT "daily_nutrition_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_log_items" ADD CONSTRAINT "food_log_items_food_log_id_food_logs_id_fk" FOREIGN KEY ("food_log_id") REFERENCES "public"."food_logs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_log_items" ADD CONSTRAINT "food_log_items_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_saved_meal_id_saved_meals_id_fk" FOREIGN KEY ("saved_meal_id") REFERENCES "public"."saved_meals"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "saved_meals" ADD CONSTRAINT "saved_meals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "food_log_items_log_position" ON "food_log_items" USING btree ("food_log_id","position");--> statement-breakpoint
CREATE INDEX "food_log_items_food_idx" ON "food_log_items" USING btree ("food_id");--> statement-breakpoint
CREATE UNIQUE INDEX "food_logs_user_client_id" ON "food_logs" USING btree ("user_id","client_log_id");--> statement-breakpoint
CREATE INDEX "food_logs_user_day_idx" ON "food_logs" USING btree ("user_id","local_date") WHERE "food_logs"."deleted_at" IS NULL;--> statement-breakpoint
CREATE INDEX "food_logs_user_logged_at_idx" ON "food_logs" USING btree ("user_id","logged_at" DESC NULLS LAST) WHERE "food_logs"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "saved_meals_user_client_id" ON "saved_meals" USING btree ("user_id","client_meal_id");--> statement-breakpoint
CREATE INDEX "saved_meals_user_created_idx" ON "saved_meals" USING btree ("user_id","created_at");