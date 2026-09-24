-- Down for 0014_deload_activations (Phase 11, TODAY delayed deload evidence). Hand-written:
-- drizzle-kit is forward-only (§25). Removes the trigger, its function and the history table;
-- programs and the Phase 6 deload lifecycle are untouched.
DROP TRIGGER IF EXISTS "programs_deload_activation" ON "programs";
DROP FUNCTION IF EXISTS "record_deload_activation"();
DROP TABLE IF EXISTS "deload_activations";
