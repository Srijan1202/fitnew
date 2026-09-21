## PHASE 5 COMPLETE — Workout logging

**ACCEPTED by the owner 2026-09-21** — all 13 manual Android acceptance checks passed. No further Phase 5 changes.

**Date** 2026-09-21 · **Branch** `phase-5` → `main` · **Commit** `b874431` (everything, fast-forwarded from `phase-5`), plus this report
**CI on `b874431`:** ci-core ✓ (core 428 + contracts 32) · ci-api ✓ (153 on PG 18, image booted) · ci-mobile ✓ (174 tests, analyze, custom_lint, format, APK)
**Plan** [phase-5-plan.md](../phase-plans/phase-5-plan.md) (approved, owner decisions 8.1–8.7) · **Decision record** [ADR-006](../decisions/ADR-006-local-first-logging.md)
**Boundary held:** Phase 5 records and summarizes what the user did. No progression recommendations, no target-load reasoning, no volume engine, no deload, no neglect detection — those are Phase 6 and appear nowhere in this phase's engine, API or UI.

IMPLEMENTED
  - **Core (`packages/core/src/training/`)** — four deterministic modules, no dependencies:
    `records.ts` `detectPRs` (weight / reps at the best weight / Epley 1RM / session volume;
    working sets only; the first session of a lift is a baseline, not a record; ties are not
    records; every record has a reason); `session-summary.ts` `summarizeSession` (duration,
    sets, tonnage, hard sets per muscle at 1 / 0.5, skipped exercises); `prefill.ts`
    `prefillSet` (the plan's target reps, last time's weight when there is one else the plan's,
    the plan's RIR — a description, never a recommendation); `mesocycle.ts` `mesocycleWeekFrom`
    (distinct ISO weeks trained in the user's calendar, ≥1, ≤8 — owner 8.2). `progression.ts`
    untouched.
  - **Database — migration `0006_workout_logging`** (+ down, both verified): `workout_sessions`
    (`status` active/completed/abandoned — owner 8.5, `program_id`, `client_session_id` UNIQUE,
    partial unique `one_active_session`), `session_exercises` (`planned_exercise_id`,
    `superset_group`, `client_exercise_id` UNIQUE, `removed_at`), `set_logs` (`set_type`,
    `planned_set_id`, `is_pr`, `client_set_id` UNIQUE, `deleted_at`, partial unique live
    position, CHECKs), `exercise_prs` (owner 8.1). Dev DB migrated to 0006.
  - **Contracts** — `workout.ts`: vocabularies, `setLogSchema`, `sessionExerciseSchema` (targets,
    prefill, last performance, sets), `workoutSessionSchema`, `sessionSummarySchema`,
    `personalRecordSchema`, `todayResponseSchema`, history list, and every request body
    (`startSessionRequestSchema` with client-seeded `exercises[]`, batch `logSetsRequestSchema`
    with `merge`, set/exercise patches, complete). `plannedSetSchema.id` added so a logged set can
    name the target it fulfilled. `openapi.json` regenerated.
  - **API — `apps/api/src/modules/workout/`** — `GET /training/today` (day, per-set targets,
    prefill, last performance, active session, done-today), `POST /training/sessions`
    (idempotent on `clientSessionId`, 201/200, 409 naming the active session, seeds from the day
    or from the client's own exercise ids), `POST …/sets` (1–50, idempotent per `clientSetId`,
    `ON CONFLICT DO NOTHING` + re-read, `merge:true` for a session completed elsewhere, 409 on a
    taken position), `PATCH`/`DELETE …/sets/{setId}` (correct / soft-delete), `POST …/exercises`
    and `PATCH …/exercises/{id}` (add, reorder, superset, replace, remove), `POST …/complete`
    (records via core, `is_pr`, mesocycle week, summary; idempotent), `POST …/abandon`,
    `GET /training/sessions` (cursor pagination, own sessions only), `GET /training/sessions/{id}`.
    All default-deny (sweep test). The PR route ordering bug class from Phase 4 is covered:
    subqueries use raw table names (drizzle leaves single-table selects unqualified).
  - **Flutter — local-first logging (§33)** — `core/db/app_database.dart` (drift 2.29:
    `local_sessions`, `local_session_exercises`, `local_set_logs`, `sync_queue`, `cached_json`);
    `LocalWorkoutRepository` (every write = row + queue entry in one transaction, then a kick;
    reads stream from the phone; `today()` network-first with the cached answer offline);
    `SyncEngine` (FIFO, batches sets, folds edits/deletes into unsent batches, `merge:true` on
    completed-elsewhere, offline/401 stop without charging attempts, five attempts with
    300 ms·2ⁿ then **parked** with Retry — never dropped; reconcile adds server ids / records /
    summary and never deletes local rows); `SyncCoordinator` drains on connectivity return, app
    resume and sign-in; sign-out wipes the local database.
  - **Flutter — screens** — `/plan/session/:clientSessionId` **active workout**: exercise cards
    (first incomplete one open), every set a row pre-filled from the server's prefill (or the row
    above beyond the plan), **one tap logs it** and starts the rest timer, logged rows in pine and
    still editable/un-loggable, "Last time: 70×10 70×9 70×8", **+ Add set**, **Drop set**,
    **Superset with next** (adjacency label, owner 8.3), Replace, Remove, + Add exercise, Discard;
    sticky footer with elapsed, sets done / planned, the rest countdown (−15 / +15 / skip) and
    **Finish**; Android back asks and keeps the session; a sync pill shows "n to sync" / "n not
    synced · Retry". **Rest timer** 90 s compounds / 60 s isolation with per-exercise override
    (shared_preferences), wall-clock based, local notification when backgrounded
    (`flutter_local_notifications` 19.4, exact when permitted else inexact; desugaring enabled).
    `/plan/session/:id/summary` (time, sets, kg moved at once; records and hard sets per muscle
    once synced, said honestly until then). `/plan/history` + `/plan/history/:serverId`. **Day
    screen**: Start session / Resume · n min / Start empty session (rest day), seeded from the
    server day or — with no signal — from the plan itself; **set-count editing** (owner
    carry-over): "+ Add set" and per-set × on the plan, ids preserved on save; ⋯ menu: History,
    Start empty session. **TODAY**: one panel — today's session with Start / Resume / Done for
    today → summary.
  - Ad-hoc sessions (owner 8.6) use the same tables, endpoints, screen, summary and history.

FILES
  - created: `packages/core/src/training/{records,session-summary,prefill,mesocycle}.ts`,
    `packages/core/test/logging.test.ts`; `packages/contracts/src/{workout.ts,workout.test.ts}`;
    `database/migrations/{0006_workout_logging.sql,down/0006_workout_logging.down.sql,meta/0006_snapshot.json}`;
    `apps/api/src/db/schema/workout.ts`, `apps/api/src/modules/workout/{repository,service,routes,workout.integration.test}.ts`;
    `apps/mobile/lib/core/db/app_database.dart` (+ generated), `apps/mobile/lib/features/workout/**`
    (entities, `workout_api.dart`, `local_workout_repository.dart`, `sync_engine.dart`,
    `workout_providers.dart`, `rest_timer.dart`, screens `active_session`, `session_summary`,
    `history`; widgets `session_exercise_card`, `rest_bar`, `sync_pill`, `start_session_button`,
    `today_session_panel`); `apps/mobile/test/features/workout/{local_workout_repository,active_session_screen}_test.dart`,
    `apps/mobile/test/support/{fake_workout_api,workout_overrides}.dart`;
    `docs/decisions/ADR-006-local-first-logging.md`, `docs/phase-plans/phase-5-plan.md`
  - modified: `packages/contracts/src/{training.ts,index.ts}`, `packages/contracts/openapi.json`;
    `apps/api/src/{app.ts,db/schema.ts,db/schema/enums.ts,db/migrate.integration.test.ts,modules/training/{repository,service,training.integration.test}.ts,test/build-test-app.ts}`;
    `apps/mobile/{pubspec.yaml,android/app/build.gradle.kts,android/app/src/main/AndroidManifest.xml,README.md}`,
    `apps/mobile/lib/{app.dart,core/errors/{failure,error_mapper}.dart,core/routing/router.dart,features/today/presentation/screens/today_placeholder_screen.dart,features/training/{domain/entities/program.dart,presentation/screens/workout_week_screen.dart,presentation/widgets/{exercise_card,set_row}.dart}}`,
    `apps/mobile/test/{widget_test.dart,contracts/contract_conformance_test.dart,core/routing/app_shell_test.dart,features/training/workout_screens_test.dart}`;
    `.github/workflows/ci-{core,api,mobile}.yml` (run on `phase-*` branches; ci-core now also typechecks, lints and tests `@fitos/contracts`)

DATABASE
  - migrations: `0006_workout_logging` (+ `down/0006_workout_logging.down.sql`)
  - tables: added `workout_sessions`, `session_exercises`, `set_logs`, `exercise_prs`; enums
    `session_status`, `set_type`, `pr_type`. `programs.mesocycle_week` now written on completion.
    No change to `planned_*` (set-count editing uses the Phase 4 PATCH).

APIS
  - GET `/training/today` — today's day with per-set targets, prefill, last performance, active session, done-today (cached offline by the client)
  - POST `/training/sessions` — start (idempotent on `clientSessionId`; 409 with `activeSessionId`)
  - GET `/training/sessions` — history, cursor-paginated (`before`, `limit`, `status`)
  - GET `/training/sessions/{id}` — one session with sets and summary
  - POST `/training/sessions/{id}/sets` — log 1–50 sets (idempotent on `clientSetId`; `merge`)
  - PATCH `/training/sessions/{id}/sets/{setId}` — correct a set
  - DELETE `/training/sessions/{id}/sets/{setId}` — soft-delete a set
  - POST `/training/sessions/{id}/exercises` — add an exercise (idempotent on `clientExerciseId`)
  - PATCH `/training/sessions/{id}/exercises/{exerciseId}` — reorder / superset / replace / remove
  - POST `/training/sessions/{id}/complete` — finish: records, mesocycle week, summary (idempotent)
  - POST `/training/sessions/{id}/abandon` — abandon (kept for history, never a record)

TESTS
  - executed: `pnpm --filter @fitos/core test` — **428 passed** (+22: records ×7, summary ×3, prefill ×6, mesocycle ×6)
  - executed: `pnpm --filter @fitos/contracts test` — **32 passed** (+6)
  - executed: `pnpm --filter @fitos/api test` (real Postgres 18, `fitos_test`) — **153 passed, 0 skipped**
    (+15: migration 0006 up/down + CHECKs + cascades; start idempotent / seeded ids / 409 active /
    ad-hoc; batch replay ×3 + position clash + foreign exercise; patch + soft delete + re-log;
    reorder / superset / replace / remove; complete → summary, baseline no PR, replay same, merge,
    records once, ties not records; abandon excluded; mesocycle ISO weeks + Kolkata boundary + cap 8;
    history pagination + ownership; today ×4; default-deny ×11)
  - executed (CI, ubuntu — local `flutter test` is blocked by Windows Smart App Control on the
    unsigned `flutter_tester.exe`; see README): `flutter test` — **174 passed**
    (+28: **airplane-mode session syncs each set exactly once, in order, batched**; interrupted
    drain replays without duplicates; survives a repository restart; unsynced set amended in its
    batch / patched once synced; unsynced delete folded / synced DELETE; completed-elsewhere
    merge; parked after five failures + Retry; offline burns no attempts; today cache; active
    session: prefill + last time, one-tap log + rest 1:30 + pill, +15 / skip, correct / un-log,
    add set, drop set, superset, leave keeps session, finish → summary → records after sync,
    discard, add exercise via picker, 60 s isolation rest; day screen: add / remove set with ids
    kept, last set cannot be removed, Start seeds from the plan offline then Resume, rest day
    empty session + History menu; Phase 5 contract conformance ×6)
  - executed: `dart analyze --fatal-infos`, `custom_lint`, `dart format` — clean (local + CI)
  - executed: typecheck / lint clean (core, contracts, api)
  - executed: `flutter build apk --debug` — built (local, with desugaring + notifications plugin; CI too)
  - executed: `docker compose up --build api` → `/health` 200, `/v1/training/today` 401, `POST /v1/training/sessions` 401
  - executed: local dev DB migrated to 0006 (7 migrations applied)
  - coverage: not measured — §18 gate

KNOWN ISSUES
  - Manual Android acceptance: **executed and passed (13/13), owner sign-off 2026-09-21.**
  - Local `flutter test` on the owner's Windows machine is blocked since 16:13 today by Windows
    **Smart App Control** (enforce mode) on the unsigned `flutter_tester.exe` — an OS policy, not
    a repo fault. ci-mobile is authoritative (owner 8.7) and green. `winsqlite3.dll` covers the
    drift native requirement on Windows; documented in `apps/mobile/README.md`.
  - The rest-timer notification is exact only when Android grants exact alarms
    (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`); otherwise inexact, which Android may delay.
  - An exercise added mid-session from the picker shows `incrementKg` 2.5 and no secondary
    muscles until the server's answer arrives (the catalogue row comes back on sync).
  - Summary on the phone before sync shows time / sets / kg moved only; records and hard sets per
    muscle are the engine's and appear once synced (stated on screen).
  - `session_exercises.superset_group` is set from the active screen only; the plan has no
    superset concept (owner 8.3).
  - `set_logs.rpe` exists per §9.2 but is never written; RIR is the only effort input in V1.
  - Two devices: supported only via the §33 merge rule; no live shared session.

DEVIATIONS FROM SPEC
  - Five routes beyond §10.1 (`DELETE …/sets/{setId}`, `POST …/exercises`, `PATCH …/exercises/{id}`,
    `POST …/abandon`, `GET /training/sessions/{id}`) — ADR-006.
  - `workout_sessions.status` / `program_id`, `session_exercises.planned_exercise_id` /
    `superset_group` / `client_exercise_id`, `set_logs.planned_set_id` / `deleted_at` beyond §9.2;
    `exercise_prs` pulled forward from §31 Phase 6 (owner 8.1) — ADR-006.
  - drift 2.23.1 → 2.29.0 (its generator needs the analyzer the toolchain is on); `sqlite3` stays
    on 2.x with `sqlite3_flutter_libs` 0.5.42; `drift_dev`, `uuid`, `flutter_local_notifications`,
    `timezone`, `riverpod` (explicit, same version) added and pinned.
  - `plannedSetSchema.id` (optional) on the Phase 4 read shape, so logged sets can reference their
    target.
  - `ci-core` now covers `@fitos/contracts`, which had no CI before; workflows also run on
    `phase-*` branches.

NEXT PHASE
  - Phase 6: Progression & volume — wire `recommendProgression` over `set_logs`, the volume
    engine (`packages/core/src/training/volume.ts`), `muscle_volume_weekly`, deload trigger
    (resets `mesocycle_week`), neglect detection, target loads with reasons on `GET /training/today`.
  - Blockers: none. The `priorWork` shape the API already builds is what `recommendProgression`
    consumes.
