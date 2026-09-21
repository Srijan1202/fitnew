ALTER TYPE "public"."program_source" ADD VALUE 'template' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'bro-split' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'upper-lower-6' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'full-body-2' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'push-pull' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'two-muscle' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'bodybuilding-5' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'full-body-3' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'upper-lower-4' BEFORE 'custom';--> statement-breakpoint
ALTER TYPE "public"."split_type" ADD VALUE 'push-pull-legs-6' BEFORE 'custom';--> statement-breakpoint
CREATE TABLE "planned_sets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"planned_exercise_id" uuid NOT NULL,
	"set_index" smallint NOT NULL,
	"reps_min" smallint NOT NULL,
	"reps_max" smallint NOT NULL,
	"weight_kg" numeric(6, 2),
	"rir" smallint NOT NULL,
	CONSTRAINT "planned_sets_index_positive" CHECK ("planned_sets"."set_index" >= 1),
	CONSTRAINT "planned_sets_reps_ordered" CHECK ("planned_sets"."reps_min" >= 1 AND "planned_sets"."reps_min" <= "planned_sets"."reps_max" AND "planned_sets"."reps_max" <= 50),
	CONSTRAINT "planned_sets_rir_range" CHECK ("planned_sets"."rir" BETWEEN 0 AND 5),
	CONSTRAINT "planned_sets_weight_nonnegative" CHECK ("planned_sets"."weight_kg" IS NULL OR "planned_sets"."weight_kg" >= 0)
);
--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "template_slug" text;--> statement-breakpoint
ALTER TABLE "planned_sets" ADD CONSTRAINT "planned_sets_planned_exercise_id_planned_exercises_id_fk" FOREIGN KEY ("planned_exercise_id") REFERENCES "public"."planned_exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "planned_sets_exercise_index" ON "planned_sets" USING btree ("planned_exercise_id","set_index");