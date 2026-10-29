CREATE TABLE "running_workouts" (
	"user_id" uuid NOT NULL,
	"client_id" uuid NOT NULL,
	"name" text NOT NULL,
	"steps" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "running_workouts_user_id_client_id_pk" PRIMARY KEY("user_id","client_id"),
	CONSTRAINT "running_workouts_name" CHECK (length("running_workouts"."name") between 1 and 60)
);
--> statement-breakpoint
ALTER TABLE "running_plans" DROP CONSTRAINT "running_plans_days";--> statement-breakpoint
ALTER TABLE "running_workouts" ADD CONSTRAINT "running_workouts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "running_plans" ADD CONSTRAINT "running_plans_days" CHECK ("running_plans"."days_per_week" between 1 and 5);