-- Down for 0052_rolling_cycles (beta 6.1, F2). Hand-written: drizzle-kit is forward-only (§25).
-- Refused while any programme is a cycle: its days 8–14 and its dates have no weekday
-- to go back to. Switch those programmes to weekdays first (Training -> Schedule).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "programs" WHERE "schedule" = 'cycle') THEN
    RAISE EXCEPTION '0052 down: % programme(s) are cycles; switch them to weekdays first', (SELECT count(*) FROM "programs" WHERE "schedule" = 'cycle');
  END IF;
END $$;
ALTER TABLE "programs" DROP CONSTRAINT IF EXISTS "programs_schedule";
ALTER TABLE "program_days" DROP CONSTRAINT IF EXISTS "program_days_dow_range";
ALTER TABLE "program_days" ADD CONSTRAINT "program_days_dow_range" CHECK ("program_days"."day_of_week" BETWEEN 1 AND 7);
ALTER TABLE "programs" DROP COLUMN IF EXISTS "cycle_length";
ALTER TABLE "programs" DROP COLUMN IF EXISTS "cycle_start";
ALTER TABLE "programs" DROP COLUMN IF EXISTS "schedule";
