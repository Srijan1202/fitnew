CREATE TYPE "public"."pr_type" AS ENUM('1rm_est', 'weight', 'reps', 'volume');--> statement-breakpoint
CREATE TYPE "public"."session_status" AS ENUM('active', 'completed', 'abandoned');--> statement-breakpoint
CREATE TYPE "public"."set_type" AS ENUM('warmup', 'working', 'drop', 'backoff');--> statement-breakpoint
CREATE TABLE "exercise_prs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"pr_type" "pr_type" NOT NULL,
	"value" numeric(8, 2) NOT NULL,
	"previous" numeric(8, 2) NOT NULL,
	"reason" text NOT NULL,
	"achieved_at" timestamp with time zone NOT NULL,
	"set_log_id" uuid NOT NULL
);
--> statement-breakpoint
CREATE TABLE "session_exercises" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"planned_exercise_id" uuid,
	"order_index" integer NOT NULL,
	"superset_group" smallint,
	"client_exercise_id" uuid NOT NULL,
	"removed_at" timestamp with time zone,
	CONSTRAINT "session_exercises_superset_positive" CHECK ("session_exercises"."superset_group" IS NULL OR "session_exercises"."superset_group" >= 1)
);
--> statement-breakpoint
CREATE TABLE "set_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_exercise_id" uuid NOT NULL,
	"planned_set_id" uuid,
	"set_index" smallint NOT NULL,
	"set_type" "set_type" DEFAULT 'working' NOT NULL,
	"weight_kg" numeric(6, 2),
	"reps" smallint NOT NULL,
	"rir" smallint,
	"rpe" numeric(3, 1),
	"is_pr" boolean DEFAULT false NOT NULL,
	"logged_at" timestamp with time zone NOT NULL,
	"client_set_id" uuid NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "set_logs_index_positive" CHECK ("set_logs"."set_index" >= 1),
	CONSTRAINT "set_logs_reps_nonnegative" CHECK ("set_logs"."reps" >= 0),
	CONSTRAINT "set_logs_rir_range" CHECK ("set_logs"."rir" IS NULL OR "set_logs"."rir" BETWEEN 0 AND 5),
	CONSTRAINT "set_logs_weight_nonnegative" CHECK ("set_logs"."weight_kg" IS NULL OR "set_logs"."weight_kg" >= 0)
);
--> statement-breakpoint
CREATE TABLE "workout_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"program_id" uuid,
	"program_day_id" uuid,
	"name" text NOT NULL,
	"status" "session_status" DEFAULT 'active' NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"completed_at" timestamp with time zone,
	"duration_seconds" integer,
	"notes" text,
	"client_session_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "workout_sessions_duration_nonnegative" CHECK ("workout_sessions"."duration_seconds" IS NULL OR "workout_sessions"."duration_seconds" >= 0)
);
--> statement-breakpoint
ALTER TABLE "exercise_prs" ADD CONSTRAINT "exercise_prs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_prs" ADD CONSTRAINT "exercise_prs_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_prs" ADD CONSTRAINT "exercise_prs_set_log_id_set_logs_id_fk" FOREIGN KEY ("set_log_id") REFERENCES "public"."set_logs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_exercises" ADD CONSTRAINT "session_exercises_session_id_workout_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."workout_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_exercises" ADD CONSTRAINT "session_exercises_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_exercises" ADD CONSTRAINT "session_exercises_planned_exercise_id_planned_exercises_id_fk" FOREIGN KEY ("planned_exercise_id") REFERENCES "public"."planned_exercises"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "set_logs" ADD CONSTRAINT "set_logs_session_exercise_id_session_exercises_id_fk" FOREIGN KEY ("session_exercise_id") REFERENCES "public"."session_exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "set_logs" ADD CONSTRAINT "set_logs_planned_set_id_planned_sets_id_fk" FOREIGN KEY ("planned_set_id") REFERENCES "public"."planned_sets"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_program_id_programs_id_fk" FOREIGN KEY ("program_id") REFERENCES "public"."programs"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_program_day_id_program_days_id_fk" FOREIGN KEY ("program_day_id") REFERENCES "public"."program_days"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "exercise_prs_user_exercise_idx" ON "exercise_prs" USING btree ("user_id","exercise_id","achieved_at");--> statement-breakpoint
CREATE UNIQUE INDEX "exercise_prs_set_type" ON "exercise_prs" USING btree ("set_log_id","pr_type");--> statement-breakpoint
CREATE UNIQUE INDEX "session_exercises_client_id" ON "session_exercises" USING btree ("client_exercise_id");--> statement-breakpoint
CREATE INDEX "session_exercises_session_idx" ON "session_exercises" USING btree ("session_id","order_index");--> statement-breakpoint
CREATE UNIQUE INDEX "set_logs_client_id" ON "set_logs" USING btree ("client_set_id");--> statement-breakpoint
CREATE INDEX "set_logs_exercise_index_idx" ON "set_logs" USING btree ("session_exercise_id","set_index");--> statement-breakpoint
CREATE UNIQUE INDEX "set_logs_live_position" ON "set_logs" USING btree ("session_exercise_id","set_index","set_type") WHERE "set_logs"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "workout_sessions_client_id" ON "workout_sessions" USING btree ("client_session_id");--> statement-breakpoint
CREATE INDEX "workout_sessions_user_started_idx" ON "workout_sessions" USING btree ("user_id","started_at" DESC NULLS LAST) WHERE "workout_sessions"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "one_active_session" ON "workout_sessions" USING btree ("user_id") WHERE "workout_sessions"."status" = 'active' AND "workout_sessions"."deleted_at" IS NULL;