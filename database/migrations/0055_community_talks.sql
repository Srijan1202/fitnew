CREATE TABLE "community_kudos" (
	"post_id" uuid NOT NULL,
	"giver_id" uuid NOT NULL,
	"notified" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_kudos_post_id_giver_id_pk" PRIMARY KEY("post_id","giver_id")
);
--> statement-breakpoint
CREATE TABLE "community_nudges" (
	"from_id" uuid NOT NULL,
	"to_id" uuid NOT NULL,
	"at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_nudges_from_id_to_id_pk" PRIMARY KEY("from_id","to_id"),
	CONSTRAINT "community_nudges_not_self" CHECK ("community_nudges"."from_id" <> "community_nudges"."to_id")
);
--> statement-breakpoint
CREATE TABLE "community_period_stats" (
	"user_id" uuid NOT NULL,
	"period" text NOT NULL,
	"period_from" text NOT NULL,
	"sessions" integer DEFAULT 0 NOT NULL,
	"run_m" integer DEFAULT 0 NOT NULL,
	"streak" integer DEFAULT 0 NOT NULL,
	"active_days" integer DEFAULT 0 NOT NULL,
	"planned" integer,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_period_stats_user_id_period_pk" PRIMARY KEY("user_id","period"),
	CONSTRAINT "community_period_stats_period" CHECK ("community_period_stats"."period" in ('week', 'month', 'all')),
	CONSTRAINT "community_period_stats_counts" CHECK ("community_period_stats"."sessions" >= 0 and "community_period_stats"."run_m" >= 0 and "community_period_stats"."streak" >= 0 and "community_period_stats"."active_days" >= 0 and ("community_period_stats"."planned" is null or "community_period_stats"."planned" >= 0))
);
--> statement-breakpoint
CREATE TABLE "community_posts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"ref" text NOT NULL,
	"title" text,
	"value" integer,
	"at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_posts_kind" CHECK ("community_posts"."kind" in ('session', 'run', 'lift-record', 'run-record', 'streak')),
	CONSTRAINT "community_posts_title" CHECK ("community_posts"."title" is null or length("community_posts"."title") <= 80),
	CONSTRAINT "community_posts_value" CHECK ("community_posts"."value" is null or "community_posts"."value" >= 0)
);
--> statement-breakpoint
CREATE TABLE "community_suggestion_dismissals" (
	"viewer_id" uuid NOT NULL,
	"dismissed_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_suggestion_dismissals_viewer_id_dismissed_id_pk" PRIMARY KEY("viewer_id","dismissed_id")
);
--> statement-breakpoint
ALTER TABLE "community_profiles" ADD COLUMN "feed" text[] DEFAULT '{}'::text[] NOT NULL;--> statement-breakpoint
ALTER TABLE "community_profiles" ADD COLUMN "feed_since" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "community_profiles" ADD COLUMN "suggest" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "community_profiles" ADD COLUMN "notify" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "community_profiles" ADD COLUMN "kudos_pushed_on" text;--> statement-breakpoint
ALTER TABLE "community_profiles" ADD COLUMN "nudge_pushed_on" text;--> statement-breakpoint
ALTER TABLE "community_kudos" ADD CONSTRAINT "community_kudos_post_id_community_posts_id_fk" FOREIGN KEY ("post_id") REFERENCES "public"."community_posts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_kudos" ADD CONSTRAINT "community_kudos_giver_id_users_id_fk" FOREIGN KEY ("giver_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_nudges" ADD CONSTRAINT "community_nudges_from_id_users_id_fk" FOREIGN KEY ("from_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_nudges" ADD CONSTRAINT "community_nudges_to_id_users_id_fk" FOREIGN KEY ("to_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_period_stats" ADD CONSTRAINT "community_period_stats_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_posts" ADD CONSTRAINT "community_posts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_suggestion_dismissals" ADD CONSTRAINT "community_suggestion_dismissals_viewer_id_users_id_fk" FOREIGN KEY ("viewer_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_suggestion_dismissals" ADD CONSTRAINT "community_suggestion_dismissals_dismissed_id_users_id_fk" FOREIGN KEY ("dismissed_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "community_kudos_giver_idx" ON "community_kudos" USING btree ("giver_id");--> statement-breakpoint
CREATE INDEX "community_nudges_to_idx" ON "community_nudges" USING btree ("to_id","at");--> statement-breakpoint
CREATE INDEX "community_period_stats_sessions_idx" ON "community_period_stats" USING btree ("period","sessions","run_m");--> statement-breakpoint
CREATE INDEX "community_period_stats_run_idx" ON "community_period_stats" USING btree ("period","run_m");--> statement-breakpoint
CREATE UNIQUE INDEX "community_posts_event_key" ON "community_posts" USING btree ("user_id","kind","ref");--> statement-breakpoint
CREATE INDEX "community_posts_user_at_idx" ON "community_posts" USING btree ("user_id","at");--> statement-breakpoint
CREATE INDEX "community_posts_at_idx" ON "community_posts" USING btree ("at");--> statement-breakpoint
CREATE INDEX "community_suggestion_dismissals_dismissed_idx" ON "community_suggestion_dismissals" USING btree ("dismissed_id");--> statement-breakpoint
ALTER TABLE "community_profiles" ADD CONSTRAINT "community_profiles_feed" CHECK ("community_profiles"."feed" <@ array['session', 'run', 'record', 'streak']::text[]);--> statement-breakpoint
-- Beta 6.3 (C13): the boards read the period table; this week's counts are there at once (month and all time follow on the first round).
INSERT INTO "community_period_stats" ("user_id", "period", "period_from", "sessions", "run_m", "streak", "active_days", "planned") SELECT "user_id", 'week', "week_from", "sessions", "run_m", "streak", "active_days", "planned" FROM "community_week_stats" ON CONFLICT DO NOTHING;
