CREATE TABLE "exercise_demo_approvals" (
	"demo_slug" text PRIMARY KEY NOT NULL,
	"approved" boolean NOT NULL,
	"updated_by" uuid,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exercise_demo_approvals_slug" CHECK ("exercise_demo_approvals"."demo_slug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);
--> statement-breakpoint
ALTER TABLE "exercise_demo_approvals" ADD CONSTRAINT "exercise_demo_approvals_updated_by_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;
--> statement-breakpoint
-- Beta 5.2 (owner, 2026-10-31): the 29 demos the owner checked on beta 5.1.1 start approved;
-- the cable fly (redone) and every new demo wait for the owner's approval in the admin panel.
INSERT INTO "exercise_demo_approvals" ("demo_slug", "approved") VALUES
  ('barbell-back-squat', true),
  ('barbell-bench-press', true),
  ('barbell-row', true),
  ('bulgarian-split-squat', true),
  ('conventional-deadlift', true),
  ('dumbbell-bench-press', true),
  ('dumbbell-curl', true),
  ('dumbbell-lateral-raise', true),
  ('dumbbell-row', true),
  ('goblet-squat', true),
  ('hammer-curl', true),
  ('hanging-leg-raise', true),
  ('hip-thrust', true),
  ('lat-pulldown', true),
  ('leg-extension', true),
  ('leg-press', true),
  ('overhead-press', true),
  ('overhead-triceps-extension', true),
  ('plank', true),
  ('pull-up', true),
  ('push-up', true),
  ('rear-delt-fly', true),
  ('romanian-deadlift', true),
  ('seated-cable-row', true),
  ('seated-dumbbell-shoulder-press', true),
  ('seated-leg-curl', true),
  ('standing-calf-raise', true),
  ('triceps-pushdown', true),
  ('walking-lunge', true)
ON CONFLICT ("demo_slug") DO NOTHING;
