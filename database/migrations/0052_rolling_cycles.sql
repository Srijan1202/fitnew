ALTER TABLE "program_days" DROP CONSTRAINT "program_days_dow_range";--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "schedule" text DEFAULT 'week' NOT NULL;--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "cycle_start" date;--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "cycle_length" smallint;--> statement-breakpoint
ALTER TABLE "program_days" ADD CONSTRAINT "program_days_dow_range" CHECK ("program_days"."day_of_week" BETWEEN 1 AND 14);--> statement-breakpoint
ALTER TABLE "programs" ADD CONSTRAINT "programs_schedule" CHECK (("programs"."schedule" = 'week' AND "programs"."cycle_start" IS NULL AND "programs"."cycle_length" IS NULL) OR ("programs"."schedule" = 'cycle' AND "programs"."cycle_start" IS NOT NULL AND "programs"."cycle_length" BETWEEN 2 AND 14));