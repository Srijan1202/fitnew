/**
 * Drizzle schema barrel. Tables are added per phase, never speculatively, so
 * every migration in git corresponds to a feature that actually shipped.
 *
 * This barrel lives BESIDE schema/, not inside it, on purpose: drizzle-kit's
 * loader is CommonJS and cannot resolve the `.js` re-exports Node ESM needs,
 * so drizzle.config.ts globs the leaf files in schema/ directly and never
 * touches this file. App code imports from here.
 *
 *   Phase 1  users
 */
export * from './schema/users.js';
