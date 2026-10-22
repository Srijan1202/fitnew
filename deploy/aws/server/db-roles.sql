-- FITOS beta (ADR-025): extensions and the two roles on RDS, as Neon had
-- them (scripts/cloudrun/neon-roles.sql). Run once by bootstrap.sh as the RDS
-- master user, with the two passwords passed as psql variables — generated
-- on the server, never typed, never shown.
--
--   fitos_migrator  owns the schema: migrations, the seed. Used only by jobs.
--   fitos_app       the running API: rows only, no DDL.
\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE ROLE fitos_migrator LOGIN PASSWORD :'migrator_password';
CREATE ROLE fitos_app LOGIN PASSWORD :'app_password';

DO $$
BEGIN
  EXECUTE format('GRANT CONNECT, CREATE, TEMPORARY ON DATABASE %I TO fitos_migrator', current_database());
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO fitos_app', current_database());
END
$$;

GRANT USAGE, CREATE ON SCHEMA public TO fitos_migrator;
GRANT USAGE ON SCHEMA public TO fitos_app;

-- Every table and sequence fitos_migrator creates is usable by fitos_app (rows
-- only). Default privileges are set as the creating role; the master user is
-- not a superuser on RDS but, since Postgres 16, holds ADMIN on roles it made.
GRANT fitos_migrator TO CURRENT_USER;
SET ROLE fitos_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO fitos_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO fitos_app;
RESET ROLE;
REVOKE fitos_migrator FROM CURRENT_USER;
