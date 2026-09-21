-- Reverses 0005_exercise_muscle_position. The seed order is recoverable by
-- re-running `db:seed` after migrating up again; nothing else depends on it.
ALTER TABLE "exercise_muscles" DROP COLUMN "position";
