CREATE TYPE "public"."activity_level" AS ENUM('sedentary', 'light', 'moderate', 'high');--> statement-breakpoint
CREATE TYPE "public"."allergen" AS ENUM('peanut', 'tree-nut', 'milk', 'egg', 'soy', 'wheat', 'fish', 'shellfish', 'sesame', 'mustard');--> statement-breakpoint
CREATE TYPE "public"."allergy_severity" AS ENUM('mild', 'moderate', 'severe');--> statement-breakpoint
CREATE TYPE "public"."body_part" AS ENUM('neck', 'shoulder', 'elbow', 'wrist', 'lower-back', 'hip', 'knee', 'ankle');--> statement-breakpoint
CREATE TYPE "public"."budget_tier" AS ENUM('low', 'medium', 'high');--> statement-breakpoint
CREATE TYPE "public"."consent_type" AS ENUM('privacy-policy', 'health-data-processing');--> statement-breakpoint
CREATE TYPE "public"."diet_type" AS ENUM('vegetarian', 'eggetarian', 'non-vegetarian');--> statement-breakpoint
CREATE TYPE "public"."equipment" AS ENUM('barbell', 'dumbbell', 'machine', 'cable', 'kettlebell', 'resistance-band', 'pull-up-bar', 'bodyweight');--> statement-breakpoint
CREATE TYPE "public"."experience_level" AS ENUM('beginner', 'intermediate', 'advanced');--> statement-breakpoint
CREATE TYPE "public"."goal_type" AS ENUM('muscle-gain', 'fat-loss', 'recomposition', 'strength', 'general', 'maintenance');--> statement-breakpoint
CREATE TYPE "public"."onboarding_stage" AS ENUM('goal', 'about', 'experience', 'training', 'food', 'vit', 'complete');--> statement-breakpoint
CREATE TYPE "public"."sex" AS ENUM('male', 'female');--> statement-breakpoint
CREATE TYPE "public"."training_location" AS ENUM('commercial-gym', 'campus-gym', 'home');--> statement-breakpoint
CREATE TYPE "public"."units" AS ENUM('metric', 'imperial');--> statement-breakpoint
CREATE TYPE "public"."weight_source" AS ENUM('onboarding', 'manual', 'health-sync');--> statement-breakpoint
CREATE TABLE "diet_preferences" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"diet_type" "diet_type" NOT NULL,
	"excluded_dish_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"budget_tier" "budget_tier",
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_allergies" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"allergen" "allergen" NOT NULL,
	"severity" "allergy_severity" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_limitations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"body_part" "body_part" NOT NULL,
	"note" text,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_goals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"goal_type" "goal_type" NOT NULL,
	"target_weight_kg" numeric(5, 2),
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ended_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "user_preferences" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"units" "units" DEFAULT 'metric' NOT NULL,
	"notification_settings" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"feature_flags" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_profiles" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"sex" "sex",
	"birth_date" text,
	"height_cm" numeric(4, 1),
	"experience_level" "experience_level",
	"training_days_per_week" smallint,
	"activity_level" "activity_level",
	"preferred_session_minutes" smallint,
	"training_location" "training_location",
	"equipment" "equipment"[] DEFAULT '{}'::equipment[] NOT NULL,
	"is_vit_student" boolean,
	"mess_provider_id" text,
	"mess_hostel_id" text,
	"mess_mess_id" text,
	"onboarding_stage" "onboarding_stage" DEFAULT 'goal' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "body_metrics" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"measured_on" text NOT NULL,
	"weight_kg" numeric(5, 2) NOT NULL,
	"source" "weight_source" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "consent_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"consent_type" "consent_type" NOT NULL,
	"granted" boolean NOT NULL,
	"policy_version" text NOT NULL,
	"granted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ip_hash" text
);
--> statement-breakpoint
CREATE TABLE "nutrition_targets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"effective_from" text NOT NULL,
	"kcal" integer NOT NULL,
	"protein_g" integer NOT NULL,
	"carb_g" integer NOT NULL,
	"fat_g" integer NOT NULL,
	"fiber_g" integer NOT NULL,
	"bmr" integer NOT NULL,
	"tdee_estimate" integer NOT NULL,
	"rationale" jsonb NOT NULL,
	"reason" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "diet_preferences" ADD CONSTRAINT "diet_preferences_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_allergies" ADD CONSTRAINT "user_allergies_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_limitations" ADD CONSTRAINT "user_limitations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_goals" ADD CONSTRAINT "user_goals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_preferences" ADD CONSTRAINT "user_preferences_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "body_metrics" ADD CONSTRAINT "body_metrics_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "consent_records" ADD CONSTRAINT "consent_records_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "nutrition_targets" ADD CONSTRAINT "nutrition_targets_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "user_allergies_user_allergen" ON "user_allergies" USING btree ("user_id","allergen");--> statement-breakpoint
CREATE INDEX "user_limitations_user_active_idx" ON "user_limitations" USING btree ("user_id","active");--> statement-breakpoint
CREATE UNIQUE INDEX "one_active_goal" ON "user_goals" USING btree ("user_id") WHERE "user_goals"."ended_at" IS NULL;--> statement-breakpoint
CREATE INDEX "user_goals_user_started_idx" ON "user_goals" USING btree ("user_id","started_at");--> statement-breakpoint
CREATE UNIQUE INDEX "body_metrics_user_day" ON "body_metrics" USING btree ("user_id","measured_on");--> statement-breakpoint
CREATE INDEX "consent_records_user_type_idx" ON "consent_records" USING btree ("user_id","consent_type","granted_at");--> statement-breakpoint
CREATE INDEX "nutrition_targets_user_effective_idx" ON "nutrition_targets" USING btree ("user_id","effective_from","created_at");