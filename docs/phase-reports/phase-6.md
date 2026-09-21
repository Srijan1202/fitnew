## PHASE 6 COMPLETE — Progression & volume

**Date** 2026-09-22 · **Branch** `phase-6` → `main` · **Commits** `ecc074f` (core), `6e5947e` (migration 0007, contracts, API), `fa7e77f` (mobile), `fe7e2b9` + `f57b254` (CI lint / test fixes), plus this report
**CI on `f57b254`:** ci-core ✓ (core 456 + contracts 33) · ci-api ✓ (165 on PG 18, image booted) · ci-mobile ✓ (187 tests, analyze, custom_lint, format, APK)
**Plan** [phase-6-plan.md](../phase-plans/phase-6-plan.md) (approved, owner decisions 12.1–12.8) · **Decision record** [ADR-007](../decisions/ADR-007-progression-and-volume.md)
**Boundary held:** deterministic / rules-first, no LLM anywhere in the path; `planned_sets` and `planned_exercises` are never modified automatically (a deload is computed on read and only after **Accept**; a substitution is applied only by the user's own PATCH); no recovery / sleep / soreness inputs; no TODAY ranked-action engine; no PROGRESS screen; no AI explanation or rephrasing — every reason on screen is the engine's own string.

IMPLEMENTED
  - **Core (`packages/core/src/training/`)** — `volume.ts` (`weeklyVolume` 1 / 0.5 primary /
    secondary, working sets of completed sessions only, ISO week in the local calendar;
    `landmarkStatus` against §12.3 MV / MEV / MAV / MRV; `recentWeeks`, `volumeReport`,
    `neglectedMuscles` with `NEGLECT_DAYS = 6`, `daysSinceTrained`); `deload.ts`
    (`shouldOfferDeload` — fatigue on ≥ 2 lead lifts in 7 days OR week ≥ 6 with a muscle at MRV,
    snooze respected; `deloadTargets` sets × 0.6 min 1, load × 0.9 to 0.5 kg, RIR + 2 cap 5;
    `deloadEndsOn`, `mesocycleAfterDeload`); `substitution.ts` (`needsSubstitution`,
    `pickAlternative`, `substitute` — same pattern + first primary muscle, performable,
    `REJECTIONS_TO_SUBSTITUTE = 2`, honest null); `progression.ts` branch 1b (bodyweight
    reps-only `add-reps`; the six existing branches untouched); `prefill.ts` takes a
    recommendation (`weightSource: 'recommendation'`, reps = repMin after an increase else
    repMax); `COMPOUND` exported from the generator. Pure functions, local dates, no I/O.
  - **Database — migration `0007_progression_volume`** (+ down, both verified):
    `muscle_volume_weekly (user_id, iso_week, muscle_group, hard_sets numeric(5,1), tonnage_kg
    numeric(9,1), updated_at)` PK (user, week, muscle); `exercise_rejections (id, user_id,
    exercise_id, rejected_at)`; `programs.deload_started_at`, `deload_snoozed_until`,
    `mesocycle_reset_at`. Dev DB migrated to 0007 (8 migrations) and the cache rebuilt from the
    owner's real Phase 5 sessions (`2026-W39`: chest 9 · shoulders 6.5 · triceps 6.5 · abs 1).
  - **Contracts** — `progressionRecommendationSchema` (action, weightKg, repTarget, targetRir,
    **reason** min 1, basis, sessionsConsidered ≤ 3), `priorBestSchema`, `substitutionSchema`
    (trigger, alternative | null, reason), `deloadStateSchema` (none / offered / active, trigger,
    reason, endsOn), `volumeResponseSchema` (4 ISO weeks × muscles with status + landmarks,
    owned, neglected, mesocycleWeek, deload), `progressionDetailSchema`; `recommendation`,
    `priorBest`, `originalTargets` on session and today exercises, `substitution` on today
    exercises, `mesocycleWeek` / `deload` / `neglected` on today; `setPrefillSchema.weightSource`
    gains `'recommendation'`. `openapi.json` regenerated.
  - **API — `apps/api/src/modules/workout/progression.ts`** `ProgressionAssembler`: history →
    `SessionLog`s (≤ 3 completed, deload-window sessions excluded) → `recommendProgression` per
    planned lift, `priorBest`, lead-lift fatigue + MRV offer → `deloadState`, `acceptDeload` /
    `declineDeload` (snooze 7 days) / `closeElapsedDeload` (week → 1, `mesocycle_reset_at`),
    `mesocycleWeek` since the reset, `volumeSets` / `volume` / `cacheWeek`, `neglected`,
    `substitutions` (kit, limitations, rejection counts). Service: `plannedView` (targets /
    originals / recommendation / prefill, deload-aware by the **session's own start**); `/today`
    and every session carry the new fields; `PATCH …/exercises/{id}` remove / replace records a
    rejection; `complete` caches the ISO week and closes an elapsed deload. Routes:
    `GET /training/volume`, `GET /training/progression/{exerciseId}`, `POST /training/deload/accept`
    (409 when none offered), `POST /training/deload/decline` — all default-deny. Script
    `pnpm db:rebuild-volume` rebuilds every user-week from `set_logs`.
  - **Flutter — set rows** open on the recommendation (75 kg × 6 when the engine says so); the
    exercise header carries the engine's line — `↑ 75 kg × 6 · 1 RIR — Every working set hit 12
    reps…` — one line, pine / ink / amber / ink60 by action; tap → sheet with the full reason,
    the last three sessions (`/training/progression/{id}`) and **Use last time's weight**, which
    reverts every pending row and leaves logged ones alone. **PR moment**: a working set heavier
    than `priorBest` (or more reps at the best weight) gets a ★ on its check and "PR" on the
    header the moment it is logged; a tie — including with an earlier set of the same session —
    never does; no prior best (baseline) never does. **Deload week**: header "DELOAD WEEK",
    "DELOAD · plan was 3 × 6–12 @ 80 kg" over the rows, each lighter row with the plan's
    original in ink35 beside it, two rows where the plan had three.
  - **Flutter — TODAY and the day screen**: `DeloadPanel` — offered: the trigger headline, the
    engine's reason, **Accept** / **Not now** (both call the server and re-read today / day /
    volume; nothing changes without the tap); active: "DELOAD WEEK · ends 28 Sep"; none:
    "Mesocycle week n". Neglect lines ("Calves: 9 days since a working set."). Day screen: the
    server's substitution under a planned lift — "SWAP TO DUMBBELL GOBLET SQUAT" + why + **Swap
    to …** (Phase 4 PATCH, id kept, weights cleared) or "NO ALTERNATIVE IN THE LIBRARY" with
    no button; "· week n" in the day's meta line.
  - **Flutter — `/plan/volume`** (plan ⋯ menu and TODAY "Weekly volume"): ten muscles down
    (owned first), four ISO weeks across, the current week's status as a 3 px left rule (oxide
    below MV / at MRV, amber below MEV / above MAV, ink in MEV–MAV) with a one-line status and
    the landmark numbers under each muscle; neglect lines; the deload panel; cached for offline.
  - **Offline**: recommendations, prior bests, originals and the deload state ride on the cached
    `today`; a session seeded with no signal opens on them. A Phase 5 cache without the new keys
    still parses (defaults).

FILES
  - created: `packages/core/src/training/{volume,deload,substitution}.ts`,
    `packages/core/test/phase6.test.ts`;
    `database/migrations/{0007_progression_volume.sql,down/0007_progression_volume.down.sql,meta/0007_snapshot.json}`;
    `apps/api/src/db/{schema/volume.ts,rebuild-volume.ts}`,
    `apps/api/src/modules/workout/{progression.ts,progression.integration.test.ts}`;
    `apps/mobile/lib/features/workout/presentation/{screens/volume_screen.dart,widgets/deload_panel.dart,widgets/recommendation_sheet.dart}`,
    `apps/mobile/test/features/workout/progression_ui_test.dart`;
    `docs/decisions/ADR-007-progression-and-volume.md`, `docs/phase-plans/phase-6-plan.md`
  - modified: `packages/core/src/training/{progression,prefill,generator}.ts`;
    `packages/contracts/src/{workout.ts,workout.test.ts}`, `packages/contracts/openapi.json`;
    `apps/api/{package.json,src/db/schema.ts,src/db/schema/training.ts,src/db/migrate.integration.test.ts}`,
    `apps/api/src/modules/training/service.ts`,
    `apps/api/src/modules/workout/{repository,service,routes,workout.integration.test}.ts`;
    `apps/mobile/lib/core/routing/router.dart`,
    `apps/mobile/lib/features/training/presentation/screens/workout_week_screen.dart`,
    `apps/mobile/lib/features/workout/{data/{workout_api,local_workout_repository}.dart,domain/entities/workout.dart (+ generated),domain/repositories/workout_repository.dart,presentation/controllers/workout_providers.dart,presentation/screens/active_session_screen.dart,presentation/widgets/{session_exercise_card,today_session_panel}.dart}`,
    `apps/mobile/test/{contracts/contract_conformance_test.dart,support/fake_workout_api.dart}`

DATABASE
  - migrations: `0007_progression_volume` (+ `down/0007_progression_volume.down.sql`)
  - tables: added `muscle_volume_weekly`, `exercise_rejections`; `programs` + `deload_started_at`,
    `deload_snoozed_until`, `mesocycle_reset_at`. `planned_*` untouched — deload targets are
    computed on read; a substitution goes through the Phase 4 PATCH.

APIS
  - GET `/training/today` — + `mesocycleWeek`, `deload`, `neglected[]`; per exercise
    `recommendation`, `priorBest`, `originalTargets`, `substitution`
  - POST `/training/sessions`, GET `/training/sessions/{id}` and every session response — per
    exercise `recommendation`, `priorBest`, `originalTargets`; `prefill.weightSource` may be
    `recommendation`
  - GET `/training/volume` — current ISO week + 3, per muscle hard sets / tonnage / status /
    landmarks / owned; `owned[]`, `neglected[]`, `mesocycleWeek`, `deload`
  - GET `/training/progression/{exerciseId}` — the lift's target, recommendation and last three
    sessions (404 unknown lift)
  - POST `/training/deload/accept` — apply the offered deload (409 when none is offered)
  - POST `/training/deload/decline` — snooze the offer seven days
  - PATCH `/training/sessions/{id}/exercises/{exerciseId}` — remove / replace now records a
    rejection (owner 12.6)

TESTS
  - executed: `pnpm --filter @fitos/core test` — **456 passed** (+28: volume hand-calculated week
    1 / 0.5, warm-up + drop excluded, ISO split at Monday; every landmark boundary; tonnage; four
    weeks; neglect at 6 vs 5 days, owned-only · deload fires on 2 lead lifts not 1, MRV at week 6
    not 5, snooze, targets ×0.6/×0.9/+2 with rounding and floors, reset → 1 · bodyweight add-reps,
    six branches untouched · substitution equipment / limitation / rejected twice / no
    alternative · prefill with a recommendation · determinism)
  - executed: `pnpm --filter @fitos/contracts test` — **33 passed** (+1 Phase 6 group)
  - executed: `pnpm --filter @fitos/api test` (real Postgres 18, `fitos_test`) — **165 passed, 0
    skipped** (+12: migration 0007 up / down; no history → establish-baseline with a reason,
    prefill empty; increase-load pre-fills the new load at repMin on today **and** on a started
    session; **§31 manual automated: three declining sessions at the same load with RIR falling →
    `deload` on that lift, never an increase; two → not yet**; fatigue on two lead lifts → offered,
    Not now → none for a week with the plan untouched, Accept → active, ×0.6 / ×0.9 / +2 with the
    originals kept and the plan row unchanged, a session started now is a deload session, a
    second accept is a no-op, completion after seven days → week 1 + `mesocycle_reset_at`; MRV +
    week 6 trigger; **volume equals a hand calculation**, the completion cache equals the live
    answer, `db:rebuild-volume` reproduces it, neglect = owned minus trained; substitution on lost
    equipment (same-kit alternative or honest null), rejected twice; `/progression/{id}` three
    sessions newest first + 404; abandoned session never feeds a recommendation, bodyweight →
    add-reps; default-deny ×4)
  - executed (CI, ubuntu — local `flutter test` is still blocked by Windows Smart App Control on
    the unsigned `flutter_tester.exe`; see README): `flutter test` — **187 passed**
    (+13: rows open on the recommended load and reps with the reason line in pine; the sheet
    shows the full reason and history, revert leaves the logged row alone; PR star on a heavier
    set, none on a tie, star again on more reps at the best weight; baseline never celebrates;
    deload week header, originals in ink35, two rows not three, amber line; TODAY offer → Not now
    clears → offered again → Accept → "ends 28 Sep"; volume screen four weeks, oxide rule + line
    below MV, landmark numbers, neglect, owned first; cached today carries the recommendation
    offline and seeds the session; Phase 6 conformance ×5 incl. a Phase 5 cache still parsing)
  - executed: `dart analyze --fatal-infos`, `custom_lint`, `dart format` — clean (local + CI)
  - executed: typecheck / lint clean (core, contracts, api)
  - executed: `flutter build apk --debug` — built (local; CI too)
  - executed: `docker compose up --build api` → `/health` 200; `GET /v1/training/volume`,
    `GET /v1/training/progression/{id}`, `POST /v1/training/deload/accept|decline` → 401
  - executed: local dev DB migrated to 0007 (8 migrations); `pnpm db:rebuild-volume` → "rebuilt
    4 user-weeks for 1 user(s)"
  - coverage: not measured — §18 gate

KNOWN ISSUES
  - Manual Android acceptance: **not yet executed** — checklist below for the owner.
  - The programme-level deload offer needs two *lead* lifts (compound patterns) fatigued within
    seven days; a body-part split whose day has a single compound cannot trigger it by fatigue
    until another day's lead lift also declines — by decision 12.2.
  - The MRV trigger reads the **current ISO week**; five heavy sessions straddling a Monday split
    across two weeks and do not trigger (the integration test states this honestly).
  - `priorBest.estimated1rm` is sent but the phone's PR moment uses weight and reps only (an
    e1RM comparison would be fitness logic in Dart); the server's records at completion remain
    authoritative and may add a `1rm_est` record the phone did not star.
  - The reason line is one line with an ellipsis; the sheet has the full text. The sheet's
    "last three sessions" needs a connection ("History needs a connection." offline).
  - Accept / Not now are online-only (they change what the server plans next); the button shows
    the failure and stays.
  - A substitution proposed on the day screen requires the server's `/today?dayOfWeek=` — with
    no signal the day renders from the plan without it.
  - `muscle_volume_weekly` is written for the completed session's week only; earlier weeks are
    filled by `db:rebuild-volume` (run once on the dev DB).

DEVIATIONS FROM SPEC
  - Four routes beyond §10.1 (`GET /training/volume`, `GET /training/progression/{exerciseId}`,
    `POST /training/deload/accept`, `POST /training/deload/decline`) — ADR-007.
  - `exercise_rejections` and `programs.deload_started_at / deload_snoozed_until /
    mesocycle_reset_at` beyond §9.2 — ADR-007 (owner 12.2–12.4, 12.6).
  - Deload targets are ×0.9 of the **last logged load**, not of the recommendation (which is
    already a reduction on a fatigued lift) — found in integration, ADR-007 §2.
  - The plan's §6 "history detail unchanged; Phase 4 editor unchanged" holds; the day screen
    gained a read-only substitution line and the deload panel, both fed by `/today`.

NEXT PHASE
  - Phase 7 per MASTER-SPEC — not started. Stop here for owner acceptance.
  - Blockers: none.

---

### Manual Android acceptance checklist (owner)

Preconditions: `docker compose up --build api`, dev DB at 0007 with `db:rebuild-volume` run,
the debug APK from `f57b254` on the device, signed in as the owner (Phase 5 history present).

1. **Baseline** — a lift never logged: the row opens with no weight; the header line reads
   "· … — First time…" in ink60; the sheet says "No completed sessions of this lift yet."
2. **Recommendation** — after last week's push day (real history): the bench row opens on the
   engine's load and reps; the header line starts with ↑ / + / = and a reason that matches what
   was logged; tap it → sheet with the full reason and the last sessions.
3. **Revert** — in the sheet, **Use last time's weight**: every pending row goes to last time's
   load, a logged row stays; the button does not reappear.
4. **PR moment** — log a working set heavier than the shown "Last time" best: the check turns
   to ★ and "PR" appears on the header at once. Log the same weight × same reps again: no star.
5. **Complete** → summary lists the record; the volume screen's current week grew by the sets
   logged (chest +1 per bench set, triceps +0.5).
6. **Volume screen** (plan ⋯ → Volume, and TODAY → Weekly volume): four ISO week columns, the
   current week's rule colour and line match the numbers (e.g. chest 9 → "In the productive
   range"), landmarks under each muscle, owned muscles first, a neglect line for any owned muscle
   untouched for six days.
7. **Neglect** — TODAY shows "<muscle>: n days since a working set." only for muscles the plan
   owns; a muscle outside the plan never appears.
8. **Deload offer (fatigue)** — on a test lift, log three sessions on different days at one load
   with reps falling and RIR falling (e.g. 10@3 → 9@2 → 8@1) on two compound lifts of the same
   day: TODAY and the day header show the offer with the reason naming both lifts.
9. **Not now** — the offer disappears; the plan's sets and loads are unchanged; it does not
   return the next day.
10. **Accept** — "DELOAD WEEK · ends <date>"; Start session: the header says DELOAD WEEK, each
    exercise shows "plan was …", rows carry ×0.6 sets / ×0.9 load / +2 RIR with the plan's
    original in grey beside them; the day screen's sets are still the plan's originals.
11. **Deload closes** — (dev DB: set `deload_started_at` eight days back) complete a session:
    the header is back to SESSION, "Mesocycle week 1" on TODAY.
12. **Substitution** — Profile → remove "barbell" from equipment: the day screen shows "SWAP TO
    …" with why under each barbell lift, or "NO ALTERNATIVE IN THE LIBRARY"; **Swap to …**
    replaces the lift in the plan (same row, weights cleared) and the line disappears. Restore
    the equipment.
13. **Rejected twice** — remove the same planned lift from two sessions: the day screen proposes
    a swap with "…removed it 2 times".
14. **Offline** — airplane mode, Start session from TODAY: rows still open on the recommended
    load with the reason; the volume screen shows the last fetched numbers.
15. **Nothing silent** — with an offer pending, log and complete a normal session: targets are
    unchanged, no deload applied.
