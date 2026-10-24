CREATE TABLE "feedback_pictures" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"feedback_id" uuid NOT NULL,
	"position" integer DEFAULT 0 NOT NULL,
	"content_type" text NOT NULL,
	"bytes" integer NOT NULL,
	"data" "bytea" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "feedback_pictures_type" CHECK ("feedback_pictures"."content_type" in ('image/jpeg', 'image/png', 'image/webp')),
	CONSTRAINT "feedback_pictures_bytes" CHECK ("feedback_pictures"."bytes" between 1 and 1000000),
	CONSTRAINT "feedback_pictures_position" CHECK ("feedback_pictures"."position" between 0 and 2)
);
--> statement-breakpoint
CREATE TABLE "feedback_replies" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"feedback_id" uuid NOT NULL,
	"admin_user_id" uuid,
	"message" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"read_at" timestamp with time zone,
	CONSTRAINT "feedback_replies_message" CHECK (length(btrim("feedback_replies"."message")) between 1 and 2000)
);
--> statement-breakpoint
ALTER TABLE "feedback" ADD COLUMN "device_model" text;--> statement-breakpoint
ALTER TABLE "feedback" ADD COLUMN "device_os" text;--> statement-breakpoint
ALTER TABLE "feedback" ADD COLUMN "screen" text;--> statement-breakpoint
ALTER TABLE "feedback_pictures" ADD CONSTRAINT "feedback_pictures_feedback_id_feedback_id_fk" FOREIGN KEY ("feedback_id") REFERENCES "public"."feedback"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "feedback_replies" ADD CONSTRAINT "feedback_replies_feedback_id_feedback_id_fk" FOREIGN KEY ("feedback_id") REFERENCES "public"."feedback"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "feedback_replies" ADD CONSTRAINT "feedback_replies_admin_user_id_users_id_fk" FOREIGN KEY ("admin_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "feedback_pictures_feedback_idx" ON "feedback_pictures" USING btree ("feedback_id");--> statement-breakpoint
CREATE INDEX "feedback_pictures_created_idx" ON "feedback_pictures" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "feedback_replies_feedback_idx" ON "feedback_replies" USING btree ("feedback_id");