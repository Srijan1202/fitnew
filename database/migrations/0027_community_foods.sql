CREATE TABLE "food_reports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"food_id" uuid NOT NULL,
	"mark" text NOT NULL,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "food_reports_note_length" CHECK ("food_reports"."note" IS NULL OR length("food_reports"."note") between 1 and 300)
);
--> statement-breakpoint
ALTER TABLE "foods" ADD COLUMN "visibility" text DEFAULT 'private' NOT NULL;--> statement-breakpoint
ALTER TABLE "food_reports" ADD CONSTRAINT "food_reports_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "food_reports_mark" ON "food_reports" USING btree ("mark");--> statement-breakpoint
CREATE INDEX "food_reports_food_idx" ON "food_reports" USING btree ("food_id");--> statement-breakpoint
CREATE INDEX "foods_community_idx" ON "foods" USING btree ("visibility") WHERE "foods"."visibility" <> 'private';--> statement-breakpoint
ALTER TABLE "foods" ADD CONSTRAINT "foods_visibility" CHECK ("foods"."visibility" in ('private', 'community', 'hidden'));--> statement-breakpoint
ALTER TABLE "foods" ADD CONSTRAINT "foods_visibility_custom_only" CHECK ("foods"."visibility" = 'private' OR "foods"."owner_user_id" IS NOT NULL);