CREATE TYPE "public"."effort_key" AS ENUM('400m', '1k', '1mile', '5k', '10k', 'half', 'marathon');--> statement-breakpoint
CREATE TABLE "run_best_efforts" (
	"run_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"key" "effort_key" NOT NULL,
	"seconds" numeric(8, 1) NOT NULL,
	"start_m" numeric(9, 1) NOT NULL,
	CONSTRAINT "run_best_efforts_run_id_key_pk" PRIMARY KEY("run_id","key"),
	CONSTRAINT "run_best_efforts_seconds" CHECK ("run_best_efforts"."seconds" > 0)
);
--> statement-breakpoint
ALTER TABLE "user_rewards" DROP CONSTRAINT "user_rewards_reward";--> statement-breakpoint
ALTER TABLE "runs" ADD COLUMN "efforts_version" smallint DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "run_best_efforts" ADD CONSTRAINT "run_best_efforts_run_id_runs_id_fk" FOREIGN KEY ("run_id") REFERENCES "public"."runs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "run_best_efforts" ADD CONSTRAINT "run_best_efforts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "run_best_efforts_user_key_idx" ON "run_best_efforts" USING btree ("user_id","key","seconds");--> statement-breakpoint
ALTER TABLE "user_rewards" ADD CONSTRAINT "user_rewards_reward" CHECK ("user_rewards"."reward" in ('spark', 'ember-theme', 'blaze-icon', 'ember-rim', 'century', 'first-run', 'first-5k', 'first-10k', 'first-half', 'first-marathon'));