ALTER TYPE "public"."food_entry_method" ADD VALUE 'mess';--> statement-breakpoint
CREATE TABLE "mess_dish_corrections" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"dish_slug" text NOT NULL,
	"user_id" uuid NOT NULL,
	"client_correction_id" uuid NOT NULL,
	"field" text NOT NULL,
	"value_low" numeric(8, 2),
	"value_high" numeric(8, 2),
	"diet_value" text,
	"note" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"reviewed_by" uuid,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mess_dish_corrections_slug_format" CHECK ("dish_slug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
	CONSTRAINT "mess_dish_corrections_status" CHECK ("mess_dish_corrections"."status" in ('pending', 'accepted', 'rejected')),
	CONSTRAINT "mess_dish_corrections_field" CHECK ("mess_dish_corrections"."field" in ('kcal', 'protein', 'carb', 'fat', 'diet', 'other')),
	CONSTRAINT "mess_dish_corrections_value" CHECK (CASE
        WHEN "mess_dish_corrections"."field" in ('kcal', 'protein', 'carb', 'fat') THEN "mess_dish_corrections"."value_low" IS NOT NULL AND "mess_dish_corrections"."value_high" IS NOT NULL AND "mess_dish_corrections"."value_low" >= 0 AND "mess_dish_corrections"."value_low" <= "mess_dish_corrections"."value_high" AND "mess_dish_corrections"."diet_value" IS NULL
        WHEN "mess_dish_corrections"."field" = 'diet' THEN "mess_dish_corrections"."diet_value" in ('veg', 'egg', 'nonveg') AND "mess_dish_corrections"."value_low" IS NULL AND "mess_dish_corrections"."value_high" IS NULL
        ELSE "mess_dish_corrections"."note" IS NOT NULL AND "mess_dish_corrections"."value_low" IS NULL AND "mess_dish_corrections"."value_high" IS NULL AND "mess_dish_corrections"."diet_value" IS NULL
      END),
	CONSTRAINT "mess_dish_corrections_note_length" CHECK ("mess_dish_corrections"."note" IS NULL OR length(btrim("mess_dish_corrections"."note")) between 1 and 280)
);
--> statement-breakpoint
CREATE TABLE "mess_dish_nutrition" (
	"dish_slug" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"serving_label" text NOT NULL,
	"serving_grams" numeric(7, 2),
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
	"source" "food_source" DEFAULT 'estimated' NOT NULL,
	"food_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mess_dish_nutrition_slug_format" CHECK ("dish_slug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
	CONSTRAINT "mess_dish_nutrition_confidence_cap" CHECK ("mess_dish_nutrition"."confidence" <> 'high'),
	CONSTRAINT "mess_dish_nutrition_source" CHECK ("mess_dish_nutrition"."source" = 'estimated'),
	CONSTRAINT "mess_dish_nutrition_serving" CHECK (length(btrim("mess_dish_nutrition"."serving_label")) > 0 AND ("mess_dish_nutrition"."serving_grams" IS NULL OR "mess_dish_nutrition"."serving_grams" > 0)),
	CONSTRAINT "mess_dish_nutrition_nonnegative" CHECK ("mess_dish_nutrition"."kcal_low" >= 0 AND "mess_dish_nutrition"."protein_low" >= 0 AND "mess_dish_nutrition"."carb_low" >= 0 AND "mess_dish_nutrition"."fat_low" >= 0),
	CONSTRAINT "mess_dish_nutrition_ranges" CHECK ("mess_dish_nutrition"."kcal_low" <= "mess_dish_nutrition"."kcal_high" AND "mess_dish_nutrition"."protein_low" <= "mess_dish_nutrition"."protein_high" AND "mess_dish_nutrition"."carb_low" <= "mess_dish_nutrition"."carb_high" AND "mess_dish_nutrition"."fat_low" <= "mess_dish_nutrition"."fat_high"),
	CONSTRAINT "mess_dish_nutrition_fibre_range" CHECK (("mess_dish_nutrition"."fibre_low" IS NULL AND "mess_dish_nutrition"."fibre_high" IS NULL) OR ("mess_dish_nutrition"."fibre_low" IS NOT NULL AND "mess_dish_nutrition"."fibre_high" IS NOT NULL AND "mess_dish_nutrition"."fibre_low" >= 0 AND "mess_dish_nutrition"."fibre_low" <= "mess_dish_nutrition"."fibre_high"))
);
--> statement-breakpoint
CREATE TABLE "mess_menu_snapshots" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"mess_id" uuid NOT NULL,
	"raw_payload" jsonb NOT NULL,
	"payload_hash" text NOT NULL,
	"dates" text[] NOT NULL,
	"first_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mess_menu_snapshots_hash_format" CHECK ("mess_menu_snapshots"."payload_hash" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "mess_menu_snapshots_seen_order" CHECK ("mess_menu_snapshots"."first_seen_at" <= "mess_menu_snapshots"."last_seen_at")
);
--> statement-breakpoint
CREATE TABLE "mess_providers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL,
	"display_name" text NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mess_providers_slug_unique" UNIQUE("slug"),
	CONSTRAINT "mess_providers_status" CHECK ("mess_providers"."status" in ('active', 'disabled'))
);
--> statement-breakpoint
CREATE TABLE "messes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider_id" uuid NOT NULL,
	"code" text NOT NULL,
	"hostel_id" text NOT NULL,
	"hostel_label" text NOT NULL,
	"mess_id" text NOT NULL,
	"mess_label" text NOT NULL,
	"serves_non_veg" boolean NOT NULL,
	"source_url" text NOT NULL,
	"last_attempt_at" timestamp with time zone,
	"last_success_at" timestamp with time zone,
	"last_changed_at" timestamp with time zone,
	"last_error" text,
	"consecutive_failures" integer DEFAULT 0 NOT NULL,
	CONSTRAINT "messes_code_unique" UNIQUE("code"),
	CONSTRAINT "messes_code_format" CHECK ("code" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
	CONSTRAINT "messes_last_error" CHECK ("messes"."last_error" is null or "messes"."last_error" in ('unreachable', 'malformed')),
	CONSTRAINT "messes_failures_nonnegative" CHECK ("messes"."consecutive_failures" >= 0)
);
--> statement-breakpoint
ALTER TABLE "food_log_items" ADD COLUMN "mess_dish_slug" text;--> statement-breakpoint
ALTER TABLE "food_logs" ADD COLUMN "mess_id" uuid;--> statement-breakpoint
ALTER TABLE "mess_dish_corrections" ADD CONSTRAINT "mess_dish_corrections_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mess_dish_corrections" ADD CONSTRAINT "mess_dish_corrections_reviewed_by_users_id_fk" FOREIGN KEY ("reviewed_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mess_dish_nutrition" ADD CONSTRAINT "mess_dish_nutrition_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mess_menu_snapshots" ADD CONSTRAINT "mess_menu_snapshots_mess_id_messes_id_fk" FOREIGN KEY ("mess_id") REFERENCES "public"."messes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "messes" ADD CONSTRAINT "messes_provider_id_mess_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."mess_providers"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "mess_dish_corrections_user_client_id" ON "mess_dish_corrections" USING btree ("user_id","client_correction_id");--> statement-breakpoint
CREATE INDEX "mess_dish_corrections_slug_status_idx" ON "mess_dish_corrections" USING btree ("dish_slug","status");--> statement-breakpoint
CREATE UNIQUE INDEX "mess_menu_snapshots_mess_hash" ON "mess_menu_snapshots" USING btree ("mess_id","payload_hash");--> statement-breakpoint
CREATE INDEX "mess_menu_snapshots_mess_recent_idx" ON "mess_menu_snapshots" USING btree ("mess_id","last_seen_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "mess_menu_snapshots_dates_idx" ON "mess_menu_snapshots" USING gin ("dates");--> statement-breakpoint
CREATE UNIQUE INDEX "messes_provider_hostel_mess" ON "messes" USING btree ("provider_id","hostel_id","mess_id");--> statement-breakpoint
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_mess_id_messes_id_fk" FOREIGN KEY ("mess_id") REFERENCES "public"."messes"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_log_items" ADD CONSTRAINT "food_log_items_mess_or_food" CHECK ("food_log_items"."mess_dish_slug" IS NULL OR "food_log_items"."food_id" IS NULL);--> statement-breakpoint
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_mess_method" CHECK ("food_logs"."mess_id" IS NULL OR "food_logs"."entry_method"::text = 'mess');