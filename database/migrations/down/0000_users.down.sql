-- Down for 0000_users. Hand-written: drizzle-kit is forward-only (§25).
-- Pure DDL. The migration journal row is removed by the rollback tool, not
-- here, so this file stays a plain, reviewable inverse of the up.
DROP INDEX IF EXISTS "users_email_idx";
DROP TABLE IF EXISTS "users";
