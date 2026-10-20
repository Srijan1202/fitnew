CREATE TYPE "public"."recovery_source" AS ENUM('manual');--> statement-breakpoint
ALTER TYPE "public"."today_action_kind" ADD VALUE 'low-readiness' BEFORE 'eat-protein';--> statement-breakpoint
CREATE TABLE "recovery_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"logged_on" date NOT NULL,
	"sleep_hours" numeric(3, 1),
	"sleep_quality" smallint,
	"soreness" smallint,
	"energy" smallint,
	"stress" smallint,
	"source" "recovery_source" DEFAULT 'manual' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "recovery_logs_sleep_hours" CHECK ("recovery_logs"."sleep_hours" is null or "recovery_logs"."sleep_hours" between 0 and 24),
	CONSTRAINT "recovery_logs_sleep_quality" CHECK ("recovery_logs"."sleep_quality" is null or "recovery_logs"."sleep_quality" between 1 and 5),
	CONSTRAINT "recovery_logs_soreness" CHECK ("recovery_logs"."soreness" is null or "recovery_logs"."soreness" between 1 and 5),
	CONSTRAINT "recovery_logs_energy" CHECK ("recovery_logs"."energy" is null or "recovery_logs"."energy" between 1 and 5),
	CONSTRAINT "recovery_logs_stress" CHECK ("recovery_logs"."stress" is null or "recovery_logs"."stress" between 1 and 5),
	CONSTRAINT "recovery_logs_something" CHECK (num_nonnulls("recovery_logs"."sleep_hours", "recovery_logs"."sleep_quality", "recovery_logs"."soreness", "recovery_logs"."energy", "recovery_logs"."stress") > 0)
);
--> statement-breakpoint
ALTER TABLE "recovery_logs" ADD CONSTRAINT "recovery_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "recovery_logs_user_day" ON "recovery_logs" USING btree ("user_id","logged_on");