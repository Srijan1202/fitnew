-- Phase 19 (ADR-027): undo 0022_premium. Premium requests go; users lose
-- their premium mark and profile picture (everyone is free again).
DROP TABLE IF EXISTS "premium_requests";
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_avatar_id";
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_premium_granted_by_users_id_fk";
ALTER TABLE "users" DROP COLUMN IF EXISTS "avatar_id";
ALTER TABLE "users" DROP COLUMN IF EXISTS "premium_granted_by";
ALTER TABLE "users" DROP COLUMN IF EXISTS "premium_since";
