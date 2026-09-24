CREATE TYPE "public"."action_basis" AS ENUM('logged', 'calculated', 'estimated');--> statement-breakpoint
CREATE TYPE "public"."action_target" AS ENUM('train', 'eat', 'progress', 'today');--> statement-breakpoint
CREATE TYPE "public"."recommendation_event" AS ENUM('shown', 'opened', 'accepted', 'dismissed', 'completed');--> statement-breakpoint
CREATE TYPE "public"."today_action_kind" AS ENUM('deload', 'injured-limitation', 'start-workout', 'eat-protein', 'eat-meal', 'progress-load', 'muscle-neglected', 'rest-day', 'celebrate-pr', 'log-weight');--> statement-breakpoint
CREATE TABLE "recommendation_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"recommendation_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"event" "recommendation_event" NOT NULL,
	"client_event_id" uuid NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "recommendations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"generated_for" date NOT NULL,
	"kind" "today_action_kind" NOT NULL,
	"subject_key" text DEFAULT '' NOT NULL,
	"rank" smallint NOT NULL,
	"priority" smallint NOT NULL,
	"basis" "action_basis" NOT NULL,
	"target" "action_target" NOT NULL,
	"payload" jsonb NOT NULL,
	"engine_version" text NOT NULL,
	"input_digest" text NOT NULL,
	"headline" text NOT NULL,
	"detail" text NOT NULL,
	"content_hash" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "recommendations_rank" CHECK ("recommendations"."rank" between 1 and 4),
	CONSTRAINT "recommendations_priority" CHECK ("recommendations"."priority" between 0 and 100),
	CONSTRAINT "recommendations_content_hash" CHECK ("recommendations"."content_hash" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "recommendations_input_digest" CHECK ("recommendations"."input_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "recommendations_text" CHECK (length("recommendations"."headline") > 0 AND length("recommendations"."detail") > 0)
);
--> statement-breakpoint
ALTER TABLE "recommendation_events" ADD CONSTRAINT "recommendation_events_recommendation_id_recommendations_id_fk" FOREIGN KEY ("recommendation_id") REFERENCES "public"."recommendations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "recommendation_events" ADD CONSTRAINT "recommendation_events_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "recommendations" ADD CONSTRAINT "recommendations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "recommendation_events_client_id" ON "recommendation_events" USING btree ("user_id","client_event_id");--> statement-breakpoint
CREATE UNIQUE INDEX "recommendation_events_once" ON "recommendation_events" USING btree ("recommendation_id","event");--> statement-breakpoint
CREATE INDEX "recommendation_events_user_received_idx" ON "recommendation_events" USING btree ("user_id","received_at");--> statement-breakpoint
CREATE UNIQUE INDEX "recommendations_identity" ON "recommendations" USING btree ("user_id","generated_for","kind","subject_key","content_hash");--> statement-breakpoint
CREATE INDEX "recommendations_user_day_idx" ON "recommendations" USING btree ("user_id","generated_for");