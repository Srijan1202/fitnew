ALTER TYPE "public"."run_goal_kind" ADD VALUE 'race';--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "goal_target_seconds" integer;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "goal_split" text;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "cadence_avg" smallint;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "cadence_max" smallint;--> statement-breakpoint
ALTER TABLE "runs" ADD CONSTRAINT "runs_race" CHECK (("runs"."goal_kind"::text = 'race') = ("runs"."goal_target_seconds" is not null and "runs"."goal_split" is not null) and ("runs"."goal_split" is null or "runs"."goal_split" in ('even', 'negative')));--> statement-breakpoint
ALTER TABLE "runs" ADD CONSTRAINT "runs_cadence" CHECK (("runs"."cadence_avg" is null or "runs"."cadence_avg" between 60 and 250) and ("runs"."cadence_max" is null or "runs"."cadence_max" between 60 and 250));