-- Down for 0013_today (Phase 11, TODAY). Hand-written: drizzle-kit is forward-only (§25).
-- Drops the TODAY recommendations and their events (events first: they reference recommendations),
-- then the four enum types 0013 created. Nothing else references these tables.
DROP TABLE IF EXISTS "recommendation_events";
DROP TABLE IF EXISTS "recommendations";
DROP TYPE IF EXISTS "recommendation_event";
DROP TYPE IF EXISTS "today_action_kind";
DROP TYPE IF EXISTS "action_target";
DROP TYPE IF EXISTS "action_basis";
