CREATE TABLE "food_request_marks" (
	"mark" text PRIMARY KEY NOT NULL,
	"request_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "food_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"query" text NOT NULL,
	"searches" integer DEFAULT 0 NOT NULL,
	"people" integer DEFAULT 0 NOT NULL,
	"asked" integer DEFAULT 0 NOT NULL,
	"status" text DEFAULT 'open' NOT NULL,
	"first_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"resolved_at" timestamp with time zone,
	"resolved_by" uuid,
	CONSTRAINT "food_requests_status" CHECK ("food_requests"."status" in ('open', 'added', 'already-there', 'ignored')),
	CONSTRAINT "food_requests_query_length" CHECK (length("food_requests"."query") between 2 and 60),
	CONSTRAINT "food_requests_counts" CHECK ("food_requests"."searches" >= 0 and "food_requests"."people" >= 0 and "food_requests"."asked" >= 0)
);
--> statement-breakpoint
ALTER TABLE "food_request_marks" ADD CONSTRAINT "food_request_marks_request_id_food_requests_id_fk" FOREIGN KEY ("request_id") REFERENCES "public"."food_requests"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_requests" ADD CONSTRAINT "food_requests_resolved_by_users_id_fk" FOREIGN KEY ("resolved_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "food_requests_query" ON "food_requests" USING btree ("query");--> statement-breakpoint
CREATE INDEX "food_requests_status_idx" ON "food_requests" USING btree ("status","people");