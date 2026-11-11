CREATE TABLE "club_bans" (
	"club_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "club_bans_club_id_user_id_pk" PRIMARY KEY("club_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "community_week_history" (
	"user_id" uuid NOT NULL,
	"week_from" text NOT NULL,
	"sessions" smallint NOT NULL,
	"run_m" integer NOT NULL,
	"streak" integer NOT NULL,
	"active_days" smallint NOT NULL,
	"planned" smallint,
	CONSTRAINT "community_week_history_user_id_week_from_pk" PRIMARY KEY("user_id","week_from"),
	CONSTRAINT "community_week_history_counts" CHECK ("community_week_history"."sessions" between 0 and 7 and "community_week_history"."run_m" >= 0 and "community_week_history"."streak" >= 0 and "community_week_history"."active_days" between 0 and 7 and ("community_week_history"."planned" is null or "community_week_history"."planned" between 0 and 7))
);
--> statement-breakpoint
CREATE TABLE "friend_declines" (
	"requester_id" uuid NOT NULL,
	"addressee_id" uuid NOT NULL,
	"declined_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "friend_declines_requester_id_addressee_id_pk" PRIMARY KEY("requester_id","addressee_id")
);
--> statement-breakpoint
ALTER TABLE "community_week_stats" ADD COLUMN "active_days" smallint DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "community_week_stats" ADD COLUMN "planned" smallint;--> statement-breakpoint
ALTER TABLE "club_bans" ADD CONSTRAINT "club_bans_club_id_clubs_id_fk" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_bans" ADD CONSTRAINT "club_bans_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_week_history" ADD CONSTRAINT "community_week_history_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friend_declines" ADD CONSTRAINT "friend_declines_requester_id_users_id_fk" FOREIGN KEY ("requester_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friend_declines" ADD CONSTRAINT "friend_declines_addressee_id_users_id_fk" FOREIGN KEY ("addressee_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "club_bans_user_idx" ON "club_bans" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "community_week_history_week_idx" ON "community_week_history" USING btree ("week_from");--> statement-breakpoint
CREATE INDEX "friend_declines_addressee_idx" ON "friend_declines" USING btree ("addressee_id");--> statement-breakpoint
ALTER TABLE "community_week_stats" ADD CONSTRAINT "community_week_stats_days" CHECK ("community_week_stats"."active_days" between 0 and 7 and ("community_week_stats"."planned" is null or "community_week_stats"."planned" between 0 and 7));