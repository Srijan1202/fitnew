CREATE TABLE "club_match_members" (
	"match_id" uuid NOT NULL,
	"club_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	CONSTRAINT "club_match_members_match_id_club_id_user_id_pk" PRIMARY KEY("match_id","club_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "club_matches" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"home_club_id" uuid NOT NULL,
	"away_club_id" uuid NOT NULL,
	"metric" text NOT NULL,
	"week_from" text NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"accepted_at" timestamp with time zone,
	"started_at" timestamp with time zone,
	"home_score" integer,
	"away_score" integer,
	"home_members" integer,
	"away_members" integer,
	"finished_at" timestamp with time zone,
	CONSTRAINT "club_matches_not_self" CHECK ("club_matches"."home_club_id" <> "club_matches"."away_club_id"),
	CONSTRAINT "club_matches_metric" CHECK ("club_matches"."metric" in ('sessions', 'distance', 'active-days')),
	CONSTRAINT "club_matches_status" CHECK ("club_matches"."status" in ('pending', 'accepted', 'finished')),
	CONSTRAINT "club_matches_week" CHECK ("club_matches"."week_from" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
);
--> statement-breakpoint
ALTER TABLE "club_match_members" ADD CONSTRAINT "club_match_members_match_id_club_matches_id_fk" FOREIGN KEY ("match_id") REFERENCES "public"."club_matches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_match_members" ADD CONSTRAINT "club_match_members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_matches" ADD CONSTRAINT "club_matches_home_club_id_clubs_id_fk" FOREIGN KEY ("home_club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_matches" ADD CONSTRAINT "club_matches_away_club_id_clubs_id_fk" FOREIGN KEY ("away_club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "club_match_members_user_idx" ON "club_match_members" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "club_matches_home_idx" ON "club_matches" USING btree ("home_club_id","week_from");--> statement-breakpoint
CREATE INDEX "club_matches_away_idx" ON "club_matches" USING btree ("away_club_id","week_from");