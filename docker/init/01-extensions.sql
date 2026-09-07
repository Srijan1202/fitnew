-- Extensions the schema needs later. Created at first boot so a developer never
-- hits "function gen_random_uuid() does not exist" mid-migration.
--   pgcrypto  -> gen_random_uuid() for every id (§9.1)
--   pg_trgm   -> trigram index on foods.name for search (§9.3, Phase 7)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
