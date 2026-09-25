CREATE TYPE "public"."measurement_site" AS ENUM('waist', 'chest', 'arm', 'thigh', 'hip');--> statement-breakpoint
ALTER TYPE "public"."today_action_kind" ADD VALUE 'calorie-adjust' BEFORE 'celebrate-pr';--> statement-breakpoint
CREATE TABLE "body_measurements" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"measured_on" text NOT NULL,
	"site" "measurement_site" NOT NULL,
	"value_cm" numeric(5, 1) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "body_measurements_date" CHECK ("body_measurements"."measured_on" ~ '^\d{4}-\d{2}-\d{2}$'),
	CONSTRAINT "body_measurements_value" CHECK ("body_measurements"."value_cm" between 10 and 250)
);
--> statement-breakpoint
ALTER TABLE "body_measurements" ADD CONSTRAINT "body_measurements_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "body_measurements_user_day_site" ON "body_measurements" USING btree ("user_id","measured_on","site");--> statement-breakpoint
CREATE INDEX "exercise_prs_user_achieved_idx" ON "exercise_prs" USING btree ("user_id","achieved_at");