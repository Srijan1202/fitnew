-- Down for 0019_admin (Phase 16, admin). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the audit log, the flags and the diet overrides, and the admin marks on foods and exercises.
DROP TABLE IF EXISTS "mess_dish_overrides";
DROP TABLE IF EXISTS "feature_flags";
DROP TABLE IF EXISTS "audit_logs";
ALTER TABLE "exercises" DROP COLUMN IF EXISTS "retired_at";
ALTER TABLE "exercises" DROP COLUMN IF EXISTS "admin_edited_at";
ALTER TABLE "foods" DROP COLUMN IF EXISTS "admin_edited_at";
