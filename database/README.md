# database/

- `migrations/` — drizzle-kit output. Forward-only, SQL in git, reviewable (§25).
  Generated from `apps/api/src/db/schema/*.ts` via `pnpm --filter @fitos/api db:generate`.
- `migrations/down/` — hand-written inverse for each migration, `<name>.down.sql`.
  drizzle-kit does not produce these; the contract (rule 17) requires migrations
  verified in both directions, so each up ships with its down and a test proves
  up → down → up on a real Postgres.
- `migrations/meta/` — drizzle-kit's journal and snapshots. Committed; do not edit.
- `seeds/` — `exercises.json` (Phase 3), `foods.json` (Phase 7), `dev-users.json`.
  Reference data, not migrations: applied by `pnpm --filter @fitos/api db:seed`
  after migrating. The runner validates the file against `@fitos/contracts`
  (`exerciseSeedFileSchema`), then upserts by slug in one transaction and
  replaces each seeded exercise's muscles / alternatives / contraindications
  wholesale. Re-running is a no-op; `updated_at` moves only on a real change.
  Rows the file does not mention are left alone (admin-added, Phase 16).
  `apps/api/src/db/seed.test.ts` checks the file's integrity without a database.

Apply: `pnpm --filter @fitos/api db:migrate`
Roll back the last one: `pnpm --filter @fitos/api db:rollback`
Seed: `pnpm --filter @fitos/api db:seed`

Every migration must be backward-compatible with the previous app version
(expand → migrate → contract). Never drop a column in the same release that
stops writing to it.
