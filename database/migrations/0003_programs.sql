CREATE TYPE "public"."program_source" AS ENUM('generated', 'custom');--> statement-breakpoint
CREATE TYPE "public"."split_type" AS ENUM('full-body', 'upper-lower', 'push-pull-legs', 'upper-lower-full', 'ppl-upper-lower', 'custom');--> statement-breakpoint
CREATE TABLE "planned_exercises" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"program_day_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"order_index" integer NOT NULL,
	"set_count" smallint NOT NULL,
	"rep_min" smallint NOT NULL,
	"rep_max" smallint NOT NULL,
	"target_rir" smallint NOT NULL,
	"increment_kg" numeric(5, 2) NOT NULL,
	"reason" text,
	CONSTRAINT "planned_exercises_sets_range" CHECK ("planned_exercises"."set_count" BETWEEN 1 AND 10),
	CONSTRAINT "planned_exercises_reps_ordered" CHECK ("planned_exercises"."rep_min" >= 1 AND "planned_exercises"."rep_min" <= "planned_exercises"."rep_max" AND "planned_exercises"."rep_max" <= 50),
	CONSTRAINT "planned_exercises_rir_range" CHECK ("planned_exercises"."target_rir" BETWEEN 0 AND 5),
	CONSTRAINT "planned_exercises_increment_positive" CHECK ("planned_exercises"."increment_kg" > 0)
);
--> statement-breakpoint
CREATE TABLE "program_days" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"program_id" uuid NOT NULL,
	"day_of_week" smallint NOT NULL,
	"session_name" text NOT NULL,
	"focus" "muscle_group"[] DEFAULT '{}' NOT NULL,
	"is_rest" boolean DEFAULT false NOT NULL,
	CONSTRAINT "program_days_dow_range" CHECK ("program_days"."day_of_week" BETWEEN 1 AND 7)
);
--> statement-breakpoint
CREATE TABLE "programs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text NOT NULL,
	"split_type" "split_type" NOT NULL,
	"days_per_week" smallint NOT NULL,
	"source" "program_source" NOT NULL,
	"mesocycle_week" smallint DEFAULT 1 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"rationale" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"shortfalls" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "programs_days_range" CHECK ("programs"."days_per_week" BETWEEN 2 AND 6),
	CONSTRAINT "programs_week_positive" CHECK ("programs"."mesocycle_week" >= 1)
);
--> statement-breakpoint
ALTER TABLE "planned_exercises" ADD CONSTRAINT "planned_exercises_program_day_id_program_days_id_fk" FOREIGN KEY ("program_day_id") REFERENCES "public"."program_days"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "planned_exercises" ADD CONSTRAINT "planned_exercises_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "program_days" ADD CONSTRAINT "program_days_program_id_programs_id_fk" FOREIGN KEY ("program_id") REFERENCES "public"."programs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "programs" ADD CONSTRAINT "programs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "planned_exercises_day_order" ON "planned_exercises" USING btree ("program_day_id","order_index");--> statement-breakpoint
CREATE INDEX "planned_exercises_exercise_idx" ON "planned_exercises" USING btree ("exercise_id");--> statement-breakpoint
CREATE UNIQUE INDEX "program_days_program_day" ON "program_days" USING btree ("program_id","day_of_week");--> statement-breakpoint
CREATE UNIQUE INDEX "one_active_program" ON "programs" USING btree ("user_id") WHERE "programs"."active" AND "programs"."deleted_at" IS NULL;--> statement-breakpoint
CREATE INDEX "programs_user_idx" ON "programs" USING btree ("user_id","created_at");