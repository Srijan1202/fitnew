CREATE TABLE "feedback" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"category" text NOT NULL,
	"message" text NOT NULL,
	"app_version" text NOT NULL,
	"status" text DEFAULT 'new' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "feedback_category" CHECK ("feedback"."category" in ('bug', 'idea', 'food', 'training', 'other')),
	CONSTRAINT "feedback_status" CHECK ("feedback"."status" in ('new', 'read', 'done')),
	CONSTRAINT "feedback_message" CHECK (length(btrim("feedback"."message")) between 1 and 2000),
	CONSTRAINT "feedback_app_version" CHECK (length(btrim("feedback"."app_version")) between 1 and 40)
);
--> statement-breakpoint
ALTER TABLE "feedback" ADD CONSTRAINT "feedback_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "feedback_status_created_idx" ON "feedback" USING btree ("status","created_at");--> statement-breakpoint
CREATE INDEX "feedback_user_idx" ON "feedback" USING btree ("user_id");