CREATE TYPE "public"."plan_goal" AS ENUM('5k', '10k', 'half', 'marathon');--> statement-breakpoint
CREATE TYPE "public"."plan_level" AS ENUM('beginner', 'runner');--> statement-breakpoint
CREATE TYPE "public"."plan_status" AS ENUM('active', 'stopped', 'done');--> statement-breakpoint
CREATE TYPE "public"."planned_run_kind" AS ENUM('easy', 'long', 'tempo', 'intervals', 'run-walk', 'race');--> statement-breakpoint
CREATE TYPE "public"."planned_run_status" AS ENUM('planned', 'done', 'skipped');--> statement-breakpoint
ALTER TYPE "public"."today_action_kind" ADD VALUE 'start-run';--> statement-breakpoint
CREATE TABLE "planned_runs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"plan_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"date" date NOT NULL,
	"week" smallint NOT NULL,
	"kind" "planned_run_kind" NOT NULL,
	"title" text NOT NULL,
	"distance_m" numeric(9, 1),
	"seconds" integer,
	"pace_fast" integer,
	"pace_slow" integer,
	"steps" jsonb,
	"note" text NOT NULL,
	"status" "planned_run_status" DEFAULT 'planned' NOT NULL,
	"run_id" uuid,
	"moved_from" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "planned_runs_pace" CHECK (("planned_runs"."pace_fast" is null) = ("planned_runs"."pace_slow" is null))
);
--> statement-breakpoint
CREATE TABLE "running_plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"goal" "plan_goal" NOT NULL,
	"level" "plan_level" NOT NULL,
	"status" "plan_status" DEFAULT 'active' NOT NULL,
	"vdot" numeric(4, 1),
	"days_per_week" smallint NOT NULL,
	"weekdays" jsonb NOT NULL,
	"long_run_weekday" smallint NOT NULL,
	"start_date" date NOT NULL,
	"weeks" smallint NOT NULL,
	"predicted_seconds" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ended_at" timestamp with time zone,
	CONSTRAINT "running_plans_days" CHECK ("running_plans"."days_per_week" between 3 and 5),
	CONSTRAINT "running_plans_level" CHECK (("running_plans"."level" = 'beginner') = ("running_plans"."vdot" is null))
);
--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "workout" jsonb;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "lap_marks" jsonb;--> statement-breakpoint
ALTER TABLE "planned_runs" ADD CONSTRAINT "planned_runs_plan_id_running_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."running_plans"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "planned_runs" ADD CONSTRAINT "planned_runs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "planned_runs" ADD CONSTRAINT "planned_runs_run_id_runs_id_fk" FOREIGN KEY ("run_id") REFERENCES "public"."runs"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "running_plans" ADD CONSTRAINT "running_plans_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "planned_runs_user_date_idx" ON "planned_runs" USING btree ("user_id","date");--> statement-breakpoint
CREATE INDEX "planned_runs_plan_idx" ON "planned_runs" USING btree ("plan_id","date");--> statement-breakpoint
CREATE UNIQUE INDEX "planned_runs_run" ON "planned_runs" USING btree ("run_id");--> statement-breakpoint
CREATE UNIQUE INDEX "running_plans_one_active" ON "running_plans" USING btree ("user_id") WHERE "running_plans"."status" = 'active';