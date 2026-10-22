# scripts/

Reserved by spec §29.

- `backup-local.ps1` — audit 2026-10-20. Backs up the local database (the
  `docker_fitos-pgdata` volume, the only copy of the real data) with
  `pg_dump`, checks that `pg_restore` can read it, and keeps the newest 14 in
  `%USERPROFILE%\FitOS-backups` — outside the repo, because a dump holds
  personal data. Restore steps and a nightly Task Scheduler line are in its
  header.
- `rebuild-derived.ts` — Phase 12. **Lives at
  `apps/api/src/db/rebuild-derived.ts`** (`pnpm --filter @fitos/api
  db:rebuild-derived`; ADR-018 D15). Rebuilds the derived caches
  (`muscle_volume_weekly`, `daily_nutrition`, `exercise_prs`) from source
  rows. Required by §9.4.
- MessIT mirror — Phase 9. **Lives at `apps/api/src/modules/mess/mirror.ts`**
  (the in-process `mirror-timer.ts`, and `src/jobs/mirror-mess.ts` run as
  `pnpm --filter @fitos/api mess:mirror`); the twice-daily job of §14.6 (its Cloud Scheduler
  trigger waits for hosting — ADR-014).
- `seed.ts` — Phase 3. **Lives at `apps/api/src/db/seed.ts`** (run as
  `pnpm --filter @fitos/api db:seed`): it needs the API's Drizzle schema and
  database client, and `scripts/` is not a pnpm workspace member.

- `deploy.ps1` — Phase 19 (ADR-025). `-Target aws|gcp`: the same image to
  either cloud, through the target's own script.
- `aws/` — Phase 19. Owner-run scripts for the AWS beta: `deploy.ps1`,
  `rollback.ps1`, the one-time `bootstrap.ps1`, `set-parameter.ps1` (secrets
  through a hidden prompt). They reach the server only through Systems
  Manager and run `deploy/aws/server/` there. Stack: `infra/aws/`. Runbook:
  `docs/hosting/AWS.md`.
- `cloudrun/` — Phase 6.7. Owner-run release scripts for the hosted alpha
  (`deploy.ps1`, `rollback.ps1`), the Neon roles script and the Artifact
  Registry cleanup policy. Runbook: `docs/hosting/CLOUD-RUN.md`.
