# scripts/

Reserved by spec §29.

- `rebuild-derived.ts` — Phase 12. Rebuilds every derived cache
  (`muscle_volume_weekly`, `daily_nutrition`, `exercise_prs`, `mess_*`) from
  source rows. Required by §9.4.
- `mirror-mess.ts` — Phase 9. Twice-daily MessIT mirror job (§14.6).
- `seed.ts` — Phase 3. **Lives at `apps/api/src/db/seed.ts`** (run as
  `pnpm --filter @fitos/api db:seed`): it needs the API's Drizzle schema and
  database client, and `scripts/` is not a pnpm workspace member. Moving it
  here means giving `scripts/` a package.json; that happens when
  `rebuild-derived.ts` (Phase 12) needs the same.

Empty at Phase 0.
