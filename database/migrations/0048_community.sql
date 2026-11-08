ALTER TYPE "public"."consent_type" ADD VALUE 'community';--> statement-breakpoint
CREATE TABLE "club_members" (
	"club_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"joined_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "club_members_club_id_user_id_pk" PRIMARY KEY("club_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "clubs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "clubs_name" CHECK (length("clubs"."name") between 3 and 40),
	CONSTRAINT "clubs_code" CHECK ("clubs"."code" ~ '^[A-HJ-NP-Z2-9]{8}$')
);
--> statement-breakpoint
CREATE TABLE "community_blocks" (
	"blocker_id" uuid NOT NULL,
	"blocked_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_blocks_blocker_id_blocked_id_pk" PRIMARY KEY("blocker_id","blocked_id"),
	CONSTRAINT "community_blocks_not_self" CHECK ("community_blocks"."blocker_id" <> "community_blocks"."blocked_id")
);
--> statement-breakpoint
CREATE TABLE "community_profiles" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"handle" text NOT NULL,
	"country" text,
	"on_world" boolean DEFAULT false NOT NULL,
	"hidden" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_profiles_handle" CHECK ("community_profiles"."handle" ~ '^[a-z0-9_]{3,20}$'),
	CONSTRAINT "community_profiles_country" CHECK ("community_profiles"."country" is null or "community_profiles"."country" ~ '^[A-Z]{2}$')
);
--> statement-breakpoint
CREATE TABLE "community_reports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"reporter_id" uuid NOT NULL,
	"target_user_id" uuid,
	"club_id" uuid,
	"reason" text NOT NULL,
	"note" text,
	"status" text DEFAULT 'open' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"closed_at" timestamp with time zone,
	"closed_by" uuid,
	CONSTRAINT "community_reports_target" CHECK (("community_reports"."target_user_id" is null) <> ("community_reports"."club_id" is null)),
	CONSTRAINT "community_reports_reason" CHECK ("community_reports"."reason" in ('handle', 'club-name', 'cheating', 'harassment', 'other')),
	CONSTRAINT "community_reports_status" CHECK ("community_reports"."status" in ('open', 'closed')),
	CONSTRAINT "community_reports_note" CHECK ("community_reports"."note" is null or length("community_reports"."note") <= 300)
);
--> statement-breakpoint
CREATE TABLE "community_week_stats" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"week_from" text NOT NULL,
	"sessions" smallint DEFAULT 0 NOT NULL,
	"run_m" integer DEFAULT 0 NOT NULL,
	"streak" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "community_week_stats_counts" CHECK ("community_week_stats"."sessions" between 0 and 7 and "community_week_stats"."run_m" >= 0 and "community_week_stats"."streak" >= 0)
);
--> statement-breakpoint
CREATE TABLE "friendships" (
	"requester_id" uuid NOT NULL,
	"addressee_id" uuid NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"accepted_at" timestamp with time zone,
	CONSTRAINT "friendships_requester_id_addressee_id_pk" PRIMARY KEY("requester_id","addressee_id"),
	CONSTRAINT "friendships_status" CHECK ("friendships"."status" in ('pending', 'accepted')),
	CONSTRAINT "friendships_not_self" CHECK ("friendships"."requester_id" <> "friendships"."addressee_id")
);
--> statement-breakpoint
ALTER TABLE "club_members" ADD CONSTRAINT "club_members_club_id_clubs_id_fk" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "club_members" ADD CONSTRAINT "club_members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "clubs" ADD CONSTRAINT "clubs_owner_id_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_blocks" ADD CONSTRAINT "community_blocks_blocker_id_users_id_fk" FOREIGN KEY ("blocker_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_blocks" ADD CONSTRAINT "community_blocks_blocked_id_users_id_fk" FOREIGN KEY ("blocked_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_profiles" ADD CONSTRAINT "community_profiles_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_reports" ADD CONSTRAINT "community_reports_reporter_id_users_id_fk" FOREIGN KEY ("reporter_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_reports" ADD CONSTRAINT "community_reports_target_user_id_users_id_fk" FOREIGN KEY ("target_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_reports" ADD CONSTRAINT "community_reports_club_id_clubs_id_fk" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_reports" ADD CONSTRAINT "community_reports_closed_by_users_id_fk" FOREIGN KEY ("closed_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "community_week_stats" ADD CONSTRAINT "community_week_stats_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_requester_id_users_id_fk" FOREIGN KEY ("requester_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_addressee_id_users_id_fk" FOREIGN KEY ("addressee_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "club_members_user_idx" ON "club_members" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "clubs_code_key" ON "clubs" USING btree ("code");--> statement-breakpoint
CREATE INDEX "clubs_owner_idx" ON "clubs" USING btree ("owner_id");--> statement-breakpoint
CREATE INDEX "community_blocks_blocked_idx" ON "community_blocks" USING btree ("blocked_id");--> statement-breakpoint
CREATE UNIQUE INDEX "community_profiles_handle_key" ON "community_profiles" USING btree ("handle");--> statement-breakpoint
CREATE INDEX "community_profiles_world_idx" ON "community_profiles" USING btree ("on_world","country");--> statement-breakpoint
CREATE INDEX "community_reports_status_idx" ON "community_reports" USING btree ("status","created_at");--> statement-breakpoint
CREATE INDEX "community_week_stats_sessions_idx" ON "community_week_stats" USING btree ("sessions","run_m");--> statement-breakpoint
CREATE INDEX "community_week_stats_run_idx" ON "community_week_stats" USING btree ("run_m");--> statement-breakpoint
CREATE UNIQUE INDEX "friendships_pair_key" ON "friendships" USING btree (least("requester_id", "addressee_id"),greatest("requester_id", "addressee_id"));--> statement-breakpoint
CREATE INDEX "friendships_addressee_idx" ON "friendships" USING btree ("addressee_id","status");