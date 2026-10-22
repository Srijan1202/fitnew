DROP INDEX "program_days_program_day";--> statement-breakpoint
ALTER TABLE "programs" ADD COLUMN "skipped_on" date;--> statement-breakpoint
-- ADR-030: DEFERRABLE (drizzle does not model it), so skipping a day can move
-- all seven days one weekday later in a single update.
ALTER TABLE "program_days" ADD CONSTRAINT "program_days_program_day" UNIQUE("program_id","day_of_week") DEFERRABLE INITIALLY IMMEDIATE;