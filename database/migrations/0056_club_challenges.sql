CREATE TABLE "club_challenge_parts" (
	"challenge_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"value" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "club_challenge_parts_challenge_id_user_id_pk" PRIMARY KEY("challenge_id","user_id"),
	CONSTRAINT "club_challenge_parts_value" CHECK ("club_challenge_parts"."value" >= 0)
);
--> statement-breakpoint
CREATE TABLE "club_challenges" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"club_id" uuid NOT NULL,
	"metric" text NOT NULL,
	"target" integer NOT NULL,
	"month" text NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"total" integer DEFAULT 0 NOT NULL,
	"reached_at" timestamp with time zone,
	"closed_at" timestamp with time zone,
	"ended_early" boolean DEFAULT false NOT NULL,
	CONSTRAINT "club_challenges_metric" CHECK ("club_challenges"."metric" in ('sessions', 'distance', 'active-days')),
	CONSTRAINT "club_challenges_target" CHECK ("club_challenges"."target" between 10 and 100000),
	CONSTRAINT "club_challenges_month" CHECK ("club_challenges"."month" ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
	CONSTRAINT "club_challenges_total" CHECK ("club_challenges"."total" >= 0)
);
--> statement-breakpoint
ALTER TABLE "club_challenge_parts" ADD CONSTRAINT "club_challenge_parts_challenge_id_club_challenges_id_fk" FOREIGN KEY ("challenge_id") REFERENCES "public"."club_challenges"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_challenge_parts" ADD CONSTRAINT "club_challenge_parts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_challenges" ADD CONSTRAINT "club_challenges_club_id_clubs_id_fk" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_challenges" ADD CONSTRAINT "club_challenges_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "club_challenge_parts_user_idx" ON "club_challenge_parts" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "club_challenges_open_key" ON "club_challenges" USING btree ("club_id") WHERE "club_challenges"."closed_at" is null;--> statement-breakpoint
CREATE INDEX "club_challenges_club_idx" ON "club_challenges" USING btree ("club_id","month");