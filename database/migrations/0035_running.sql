CREATE TYPE "public"."run_goal_kind" AS ENUM('free', 'distance', 'time', 'pace');--> statement-breakpoint
CREATE TYPE "public"."run_kind" AS ENUM('outdoor', 'treadmill');--> statement-breakpoint
CREATE TABLE "runs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"client_run_id" uuid NOT NULL,
	"kind" "run_kind" NOT NULL,
	"name" text NOT NULL,
	"note" text,
	"effort" smallint,
	"started_at" timestamp with time zone NOT NULL,
	"ended_at" timestamp with time zone NOT NULL,
	"duration_seconds" integer NOT NULL,
	"goal_kind" "run_goal_kind" NOT NULL,
	"goal_value" integer,
	"track_points" text,
	"track_breaks" jsonb,
	"track_elevation" boolean,
	"distance_m" numeric(9, 1) NOT NULL,
	"avg_pace_sec_per_km" numeric(8, 1),
	"elevation_gain_m" numeric(7, 1),
	"calories" integer,
	"outline" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "runs_effort" CHECK ("runs"."effort" is null or "runs"."effort" between 1 and 10),
	CONSTRAINT "runs_duration" CHECK ("runs"."duration_seconds" >= 0),
	CONSTRAINT "runs_times" CHECK ("runs"."ended_at" >= "runs"."started_at"),
	CONSTRAINT "runs_distance" CHECK ("runs"."distance_m" >= 0),
	CONSTRAINT "runs_track_kind" CHECK (("runs"."kind" = 'outdoor') = ("runs"."track_points" is not null and "runs"."track_breaks" is not null and "runs"."track_elevation" is not null)),
	CONSTRAINT "runs_goal" CHECK (("runs"."goal_kind" = 'free') = ("runs"."goal_value" is null))
);
--> statement-breakpoint
ALTER TABLE "runs" ADD CONSTRAINT "runs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "runs_client_id" ON "runs" USING btree ("client_run_id");--> statement-breakpoint
CREATE INDEX "runs_user_started_idx" ON "runs" USING btree ("user_id","started_at" DESC NULLS LAST);