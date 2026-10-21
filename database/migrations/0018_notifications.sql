CREATE TYPE "public"."notify_kind" AS ENUM('workout-reminder', 'missed-session', 'protein-gap', 'streak-at-risk', 'weigh-in', 'recovery-checkin', 'weekly-recap', 'comeback');--> statement-breakpoint
CREATE TYPE "public"."notify_status" AS ENUM('planned', 'delivered', 'opened', 'cancelled');--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" "notify_kind" NOT NULL,
	"local_date" text NOT NULL,
	"scheduled_for" timestamp with time zone NOT NULL,
	"variant" text NOT NULL,
	"title" text NOT NULL,
	"body" text NOT NULL,
	"status" "notify_status" DEFAULT 'planned' NOT NULL,
	"sent_at" timestamp with time zone,
	"opened_at" timestamp with time zone,
	"cancelled_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "notifications_local_date_format" CHECK ("notifications"."local_date" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
);
--> statement-breakpoint
CREATE TABLE "push_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"token" text NOT NULL,
	"platform" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "push_tokens_platform" CHECK ("push_tokens"."platform" in ('android'))
);
--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "push_tokens" ADD CONSTRAINT "push_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "notifications_user_kind_day" ON "notifications" USING btree ("user_id","kind","local_date");--> statement-breakpoint
CREATE INDEX "notifications_user_day_idx" ON "notifications" USING btree ("user_id","local_date");--> statement-breakpoint
CREATE UNIQUE INDEX "push_tokens_token" ON "push_tokens" USING btree ("token");--> statement-breakpoint
CREATE INDEX "push_tokens_user_idx" ON "push_tokens" USING btree ("user_id");