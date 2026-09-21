-- Down for 0004_planned_sets_templates. Hand-written: drizzle-kit is forward-only (§25).
--
-- Postgres cannot remove a value from an enum type, so both types are
-- rebuilt with their 0003 value lists. Rows that can only exist under 0004
-- (template programmes) are removed first — they have no representation in
-- the older schema. Their days/exercises/sets cascade.
DELETE FROM "programs"
WHERE "source" = 'template'
   OR "split_type"::text IN (
     'bro-split', 'upper-lower-6', 'full-body-2', 'push-pull', 'two-muscle',
     'bodybuilding-5', 'full-body-3', 'upper-lower-4', 'push-pull-legs-6'
   );

DROP TABLE IF EXISTS "planned_sets";
ALTER TABLE "programs" DROP COLUMN IF EXISTS "template_slug";

ALTER TYPE "public"."program_source" RENAME TO "program_source_0004";
CREATE TYPE "public"."program_source" AS ENUM('generated', 'custom');
ALTER TABLE "programs"
  ALTER COLUMN "source" TYPE "public"."program_source" USING "source"::text::"public"."program_source";
DROP TYPE "public"."program_source_0004";

ALTER TYPE "public"."split_type" RENAME TO "split_type_0004";
CREATE TYPE "public"."split_type" AS ENUM('full-body', 'upper-lower', 'push-pull-legs', 'upper-lower-full', 'ppl-upper-lower', 'custom');
ALTER TABLE "programs"
  ALTER COLUMN "split_type" TYPE "public"."split_type" USING "split_type"::text::"public"."split_type";
DROP TYPE "public"."split_type_0004";
