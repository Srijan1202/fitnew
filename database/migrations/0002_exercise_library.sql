CREATE TYPE "public"."alternative_reason" AS ENUM('equipment', 'injury', 'preference');--> statement-breakpoint
CREATE TYPE "public"."difficulty" AS ENUM('beginner', 'intermediate', 'advanced');--> statement-breakpoint
CREATE TYPE "public"."movement_pattern" AS ENUM('squat', 'hinge', 'lunge', 'horizontal-push', 'vertical-push', 'horizontal-pull', 'vertical-pull', 'elbow-flexion', 'elbow-extension', 'shoulder-isolation', 'chest-isolation', 'leg-isolation', 'calf-raise', 'core', 'carry');--> statement-breakpoint
CREATE TYPE "public"."muscle_group" AS ENUM('chest', 'back', 'quads', 'hamstrings', 'glutes', 'shoulders', 'biceps', 'triceps', 'calves', 'abs');--> statement-breakpoint
CREATE TYPE "public"."muscle_role" AS ENUM('primary', 'secondary');--> statement-breakpoint
CREATE TABLE "exercise_alternatives" (
	"exercise_id" uuid NOT NULL,
	"alternative_id" uuid NOT NULL,
	"reason" "alternative_reason" NOT NULL,
	CONSTRAINT "exercise_alternatives_exercise_id_alternative_id_reason_pk" PRIMARY KEY("exercise_id","alternative_id","reason"),
	CONSTRAINT "exercise_alternatives_not_self" CHECK ("exercise_alternatives"."exercise_id" <> "exercise_alternatives"."alternative_id")
);
--> statement-breakpoint
CREATE TABLE "exercise_contraindications" (
	"exercise_id" uuid NOT NULL,
	"body_part" "body_part" NOT NULL,
	CONSTRAINT "exercise_contraindications_exercise_id_body_part_pk" PRIMARY KEY("exercise_id","body_part")
);
--> statement-breakpoint
CREATE TABLE "exercise_muscles" (
	"exercise_id" uuid NOT NULL,
	"muscle_group" "muscle_group" NOT NULL,
	"role" "muscle_role" NOT NULL,
	"contribution" numeric(3, 2) NOT NULL,
	CONSTRAINT "exercise_muscles_exercise_id_muscle_group_pk" PRIMARY KEY("exercise_id","muscle_group"),
	CONSTRAINT "exercise_muscles_contribution_range" CHECK ("exercise_muscles"."contribution" > 0 AND "exercise_muscles"."contribution" <= 1)
);
--> statement-breakpoint
CREATE TABLE "exercises" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL,
	"name" text NOT NULL,
	"movement_pattern" "movement_pattern" NOT NULL,
	"equipment" "equipment"[] NOT NULL,
	"difficulty" "difficulty" NOT NULL,
	"is_unilateral" boolean DEFAULT false NOT NULL,
	"default_increment_kg" numeric(5, 2) NOT NULL,
	"instructions" text[] NOT NULL,
	"video_url" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exercises_slug_unique" UNIQUE("slug"),
	CONSTRAINT "exercises_equipment_nonempty" CHECK (cardinality("exercises"."equipment") > 0),
	CONSTRAINT "exercises_instructions_nonempty" CHECK (cardinality("exercises"."instructions") > 0),
	CONSTRAINT "exercises_increment_positive" CHECK ("exercises"."default_increment_kg" > 0)
);
--> statement-breakpoint
ALTER TABLE "exercise_alternatives" ADD CONSTRAINT "exercise_alternatives_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_alternatives" ADD CONSTRAINT "exercise_alternatives_alternative_id_exercises_id_fk" FOREIGN KEY ("alternative_id") REFERENCES "public"."exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_contraindications" ADD CONSTRAINT "exercise_contraindications_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_muscles" ADD CONSTRAINT "exercise_muscles_exercise_id_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "exercise_alternatives_alt_idx" ON "exercise_alternatives" USING btree ("alternative_id");--> statement-breakpoint
CREATE INDEX "exercise_contraindications_part_idx" ON "exercise_contraindications" USING btree ("body_part");--> statement-breakpoint
CREATE INDEX "exercise_muscles_muscle_idx" ON "exercise_muscles" USING btree ("muscle_group","role");--> statement-breakpoint
CREATE INDEX "exercises_name_trgm_idx" ON "exercises" USING gin ("name" gin_trgm_ops);--> statement-breakpoint
CREATE INDEX "exercises_pattern_idx" ON "exercises" USING btree ("movement_pattern");--> statement-breakpoint
CREATE INDEX "exercises_equipment_idx" ON "exercises" USING gin ("equipment");