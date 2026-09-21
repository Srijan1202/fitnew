CREATE TABLE "exercise_rejections" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"rejected_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "muscle_volume_weekly" (
	"user_id" uuid NOT NULL,
	"iso_week" text NOT NULL,
	"muscle_group" "muscle_group" NOT NULL,
	"hard_sets" numeric(5, 1) NOT NULL,
	"tonnage_kg" numeric(9, 1) NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "muscle_volume_weekly_user_id_iso_week_muscle_group_pk" PRIMARY KEY("user_id","iso_week","muscle_group")
);
--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "deload_started_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "deload_snoozed_until" text;--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "mesocycle_reset_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "exercise_rejections" ADD CONSTRAINT "exercise_rejections_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_rejections" ADD CONSTRAINT "exercise_rejections_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "muscle_volume_weekly" ADD CONSTRAINT "muscle_volume_weekly_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "exercise_rejections_user_exercise_idx" ON "exercise_rejections" USING btree ("user_id","exercise_id");--> statement-breakpoint
CREATE INDEX "muscle_volume_weekly_user_week_idx" ON "muscle_volume_weekly" USING btree ("user_id","iso_week");