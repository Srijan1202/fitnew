CREATE TABLE "user_rewards" (
	"user_id" uuid NOT NULL,
	"reward" text NOT NULL,
	"earned_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_rewards_user_id_reward_pk" PRIMARY KEY("user_id","reward"),
	CONSTRAINT "user_rewards_reward" CHECK ("user_rewards"."reward" in ('spark', 'ember-theme', 'blaze-icon', 'ember-rim', 'century'))
);
--> statement-breakpoint
ALTER TABLE "users" DROP CONSTRAINT "users_avatar_id";--> statement-breakpoint
ALTER TABLE "user_rewards" ADD CONSTRAINT "user_rewards_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_avatar_id" CHECK ("users"."avatar_id" is null or "users"."avatar_id" in ('dumbbell', 'runner', 'yoga', 'cyclist', 'swimmer', 'boxer', 'hiker', 'crown', 'flame', 'trophy', 'spark', 'century'));