-- Reverses 0007_progression_volume. muscle_volume_weekly is a cache
-- (rebuildable by `db:rebuild-volume`); the deload columns hold at most a
-- week of state; exercise_rejections is a small signal table.
DROP TABLE IF EXISTS "muscle_volume_weekly";
DROP TABLE IF EXISTS "exercise_rejections";
ALTER TABLE "programs" DROP COLUMN IF EXISTS "deload_started_at";
ALTER TABLE "programs" DROP COLUMN IF EXISTS "deload_snoozed_until";
ALTER TABLE "programs" DROP COLUMN IF EXISTS "mesocycle_reset_at";
