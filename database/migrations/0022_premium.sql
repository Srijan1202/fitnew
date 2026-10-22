CREATE TABLE "premium_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"message" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"decided_at" timestamp with time zone,
	"decided_by" uuid,
	CONSTRAINT "premium_requests_status" CHECK ("premium_requests"."status" in ('pending', 'approved', 'denied')),
	CONSTRAINT "premium_requests_message" CHECK ("premium_requests"."message" is null or length("premium_requests"."message") <= 500),
	CONSTRAINT "premium_requests_note" CHECK ("premium_requests"."note" is null or length("premium_requests"."note") <= 300)
);
--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "premium_since" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "premium_granted_by" uuid;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "avatar_id" text;--> statement-breakpoint
ALTER TABLE "premium_requests" ADD CONSTRAINT "premium_requests_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "premium_requests" ADD CONSTRAINT "premium_requests_decided_by_users_id_fk" FOREIGN KEY ("decided_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "premium_requests_one_pending" ON "premium_requests" USING btree ("user_id") WHERE "premium_requests"."status" = 'pending';--> statement-breakpoint
CREATE INDEX "premium_requests_status_created_idx" ON "premium_requests" USING btree ("status","created_at");--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_premium_granted_by_users_id_fk" FOREIGN KEY ("premium_granted_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_avatar_id" CHECK ("users"."avatar_id" is null or "users"."avatar_id" in ('dumbbell', 'runner', 'yoga', 'cyclist', 'swimmer', 'boxer', 'hiker', 'crown', 'flame', 'trophy'));