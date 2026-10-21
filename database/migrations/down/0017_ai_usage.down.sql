-- Down for 0017_ai_usage (Phase 14, AI features). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the usage ledger and its two types. Nothing else references them.
DROP TABLE IF EXISTS "ai_usage";
DROP TYPE IF EXISTS "ai_route";
DROP TYPE IF EXISTS "ai_outcome";
