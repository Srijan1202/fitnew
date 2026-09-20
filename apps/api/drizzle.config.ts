import { defineConfig } from 'drizzle-kit';

/**
 * Migrations live in database/migrations/ at the repo root (§29), not inside
 * the API package, because §9.4's rebuild-derived script and the nightly
 * pg_dump job (§24) need them too and neither lives in apps/api.
 *
 * `strict` and `verbose` so drizzle-kit asks before anything destructive and
 * prints the SQL it is about to run. Migrations are forward-only (§25);
 * companion down scripts are hand-written alongside each one.
 */
export default defineConfig({
  dialect: 'postgresql',
  // The COMPILED schema, not src. drizzle-kit's loader is CommonJS and cannot
  // resolve the `.js` extensions ESM source needs between leaf files; the
  // build output has real .js files that resolve. `pnpm db:generate` builds
  // first so this is never stale.
  schema: './dist/db/schema/*.js',
  out: '../../database/migrations',
  dbCredentials: {
    url: process.env['DATABASE_URL'] ?? 'postgres://fitos:fitos@localhost:5432/fitos',
  },
  strict: true,
  verbose: true,
});
