CREATE TYPE "public"."run_source" AS ENUM('phone', 'watch');--> statement-breakpoint
ALTER TABLE "user_rewards" DROP CONSTRAINT "user_rewards_reward";--> statement-breakpoint
ALTER TABLE "runs" DROP CONSTRAINT "runs_track_kind";--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "source" "run_source" DEFAULT 'phone' NOT NULL;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "external_id" text;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "hr_avg" smallint;--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "hr_max" smallint;--> statement-breakpoint
CREATE UNIQUE INDEX "runs_user_external_id" ON "runs" USING btree ("user_id","external_id");--> statement-breakpoint
ALTER TABLE "user_rewards" ADD CONSTRAINT "user_rewards_reward" CHECK ("user_rewards"."reward" in ('spark', 'ember-theme', 'blaze-icon', 'ember-rim', 'century', 'first-run', 'first-5k', 'first-10k', 'first-half', 'first-marathon', 'speed-5k-30', 'speed-5k-25', 'speed-5k-20', 'speed-10k-60', 'speed-10k-50', 'speed-half-2h', 'speed-marathon-4h', 'total-50k', 'total-100k', 'total-250k', 'total-500k', 'total-1000k', 'weeks-4', 'three-in-a-week', 'plan-finished'));--> statement-breakpoint
ALTER TABLE "runs" ADD CONSTRAINT "runs_external" CHECK (("runs"."source" = 'watch') = ("runs"."external_id" is not null));--> statement-breakpoint
ALTER TABLE "runs" ADD CONSTRAINT "runs_hr" CHECK (("runs"."hr_avg" is null or "runs"."hr_avg" between 25 and 250) and ("runs"."hr_max" is null or "runs"."hr_max" between 25 and 250));--> statement-breakpoint
ALTER TABLE "runs" ADD CONSTRAINT "runs_track_kind" CHECK (("runs"."kind" = 'outdoor') = ("runs"."track_points" is not null and "runs"."track_breaks" is not null and "runs"."track_elevation" is not null) or ("runs"."kind" = 'outdoor' and "runs"."source" = 'watch' and "runs"."track_points" is null and "runs"."track_breaks" is null and "runs"."track_elevation" is null));