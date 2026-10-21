-- Down for 0018_notifications (Phase 15, notifications). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the notification ledger, the push tokens and their two types. Nothing else references them.
DROP TABLE IF EXISTS "push_tokens";
DROP TABLE IF EXISTS "notifications";
DROP TYPE IF EXISTS "notify_status";
DROP TYPE IF EXISTS "notify_kind";
