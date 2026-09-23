-- Phase 6.7 — Neon project `fitos-alpha`: extensions and the two roles.
--
-- Run ONCE in the Neon console SQL editor, connected to the project's
-- database as its owner role (neondb_owner). Replace the two placeholders IN
-- THE EDITOR with freshly generated passwords (a password manager, 32+
-- characters). Never save the filled-in text anywhere, never paste it into
-- chat, never commit it. The passwords then go into Secret Manager inside the
-- two connection strings (see docs/hosting/CLOUD-RUN.md, step 5).
--
-- Roles created by SQL are NOT members of neon_superuser, unlike roles made in
-- the console — that is the point: the running API gets data access only.

-- gen_random_uuid() (pgcrypto) and trigram search (pg_trgm), as
-- docker/init/01-extensions.sql does locally.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Schema owner: migrations (and the `drizzle` journal schema), the seed, the
-- one-time restore (O4) and the nightly pg_dump. Used only by Cloud Run jobs.
CREATE ROLE fitos_migrator LOGIN PASSWORD '<GENERATED PASSWORD 1>';

-- The running API: read and write rows, nothing else — no DDL, no drizzle.
CREATE ROLE fitos_app LOGIN PASSWORD '<GENERATED PASSWORD 2>';

-- current_database() so this works whatever the database is called.
DO $$
BEGIN
  EXECUTE format('GRANT CONNECT, CREATE, TEMPORARY ON DATABASE %I TO fitos_migrator', current_database());
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO fitos_app', current_database());
END
$$;

GRANT USAGE, CREATE ON SCHEMA public TO fitos_migrator;
GRANT USAGE ON SCHEMA public TO fitos_app;

-- Every table / sequence fitos_migrator creates from now on (migrations,
-- the restore) is usable by fitos_app — rows only.
--
-- Default privileges can only be set by (a member of) the role that will
-- create the objects. The owner is not a superuser on Neon; since Postgres 16
-- it holds ADMIN on roles it created, so it joins fitos_migrator for these two
-- statements and leaves again. (Found by running this on Postgres 18 as a
-- non-superuser owner, Gate 6.7-1.)
GRANT fitos_migrator TO CURRENT_USER;
SET ROLE fitos_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO fitos_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO fitos_app;
RESET ROLE;
REVOKE fitos_migrator FROM CURRENT_USER;
