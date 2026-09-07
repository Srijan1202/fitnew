# scripts/

Reserved by spec §29.

- `rebuild-derived.ts` — Phase 12. Rebuilds every derived cache
  (`muscle_volume_weekly`, `daily_nutrition`, `exercise_prs`, `mess_*`) from
  source rows. Required by §9.4.
- `mirror-mess.ts` — Phase 9. Twice-daily MessIT mirror job (§14.6).
- `seed.ts` — Phase 3.

Empty at Phase 0.
