-- Beta 3.5: undo 0031_meal_reminders. Postgres cannot drop an enum value, so
-- the meal reminders' rows go and the type is rebuilt without them.
DELETE FROM "notifications" WHERE "kind"::text IN ('meal-breakfast', 'meal-lunch', 'meal-dinner');
ALTER TYPE "public"."notify_kind" RENAME TO "notify_kind_old";
CREATE TYPE "public"."notify_kind" AS ENUM('workout-reminder', 'missed-session', 'protein-gap', 'streak-at-risk', 'weigh-in', 'recovery-checkin', 'weekly-recap', 'comeback');
ALTER TABLE "notifications" ALTER COLUMN "kind" TYPE "public"."notify_kind" USING "kind"::text::"public"."notify_kind";
DROP TYPE "public"."notify_kind_old";
