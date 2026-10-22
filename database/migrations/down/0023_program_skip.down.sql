-- Phase 19 (ADR-030): undo 0023_program_skip. The skip date goes; the
-- weekday rule is a plain unique index again (the days keep where they are).
ALTER TABLE "programs" DROP COLUMN IF EXISTS "skipped_on";
ALTER TABLE "program_days" DROP CONSTRAINT IF EXISTS "program_days_program_day";
CREATE UNIQUE INDEX IF NOT EXISTS "program_days_program_day" ON "program_days" USING btree ("program_id","day_of_week");
