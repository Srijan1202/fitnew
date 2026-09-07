/**
 * Drizzle schema root.
 *
 * Empty at Phase 0 by design — the first table is `users` in Phase 1 (§31).
 * Tables are added per phase, never speculatively, so every migration in git
 * corresponds to a feature that actually shipped.
 */

export {};
