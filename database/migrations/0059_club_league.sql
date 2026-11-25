CREATE TABLE "league_clubs" (
	"club_id" uuid PRIMARY KEY NOT NULL,
	"entered_at" timestamp with time zone DEFAULT now() NOT NULL,
	"leaving" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "league_entries" (
	"season_id" uuid NOT NULL,
	"club_id" uuid NOT NULL,
	"played" integer DEFAULT 0 NOT NULL,
	"won" integer DEFAULT 0 NOT NULL,
	"drawn" integer DEFAULT 0 NOT NULL,
	"lost" integer DEFAULT 0 NOT NULL,
	"byes" integer DEFAULT 0 NOT NULL,
	"points" integer DEFAULT 0 NOT NULL,
	"score_tenths" integer DEFAULT 0 NOT NULL,
	"place" integer,
	CONSTRAINT "league_entries_season_id_club_id_pk" PRIMARY KEY("season_id","club_id"),
	CONSTRAINT "league_entries_counts" CHECK ("league_entries"."played" >= 0 and "league_entries"."won" >= 0 and "league_entries"."drawn" >= 0 and "league_entries"."lost" >= 0 and "league_entries"."byes" >= 0 and "league_entries"."points" >= 0 and "league_entries"."score_tenths" >= 0)
);
--> statement-breakpoint
CREATE TABLE "league_seasons" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"starts_on" text NOT NULL,
	"ends_on" text NOT NULL,
	"finished_at" timestamp with time zone,
	CONSTRAINT "league_seasons_dates" CHECK ("league_seasons"."starts_on" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' and "league_seasons"."ends_on" > "league_seasons"."starts_on")
);
--> statement-breakpoint
ALTER TABLE "club_matches" ADD COLUMN "league_season_id" uuid;--> statement-breakpoint
ALTER TABLE "club_members" ADD COLUMN "role" text DEFAULT 'member' NOT NULL;--> statement-breakpoint
ALTER TABLE "league_clubs" ADD CONSTRAINT "league_clubs_club_id_clubs_id_fk" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "league_entries" ADD CONSTRAINT "league_entries_season_id_league_seasons_id_fk" FOREIGN KEY ("season_id") REFERENCES "public"."league_seasons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "league_entries" ADD CONSTRAINT "league_entries_club_id_clubs_id_fk" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "league_entries_club_idx" ON "league_entries" USING btree ("club_id");--> statement-breakpoint
CREATE UNIQUE INDEX "league_seasons_starts_key" ON "league_seasons" USING btree ("starts_on");--> statement-breakpoint
ALTER TABLE "club_matches" ADD CONSTRAINT "club_matches_league_season_id_league_seasons_id_fk" FOREIGN KEY ("league_season_id") REFERENCES "public"."league_seasons"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_members" ADD CONSTRAINT "club_members_role" CHECK ("club_members"."role" in ('member', 'co-owner'));