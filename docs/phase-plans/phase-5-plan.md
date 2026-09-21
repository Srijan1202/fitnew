# Phase 5 — Workout logging: implementation plan

**Status** APPROVED — owner decisions recorded 2026-09-21 (§8) · **Date** 2026-09-21 · **Prereq** Phase 4 accepted at `0bebbf5`
**Spec** MASTER-SPEC §31 Phase 5, §9.2 (`workout_sessions`, `session_exercises`, `set_logs`), §10.1 (`/training/sessions*`, `/training/today`), §12.4 (progression, already implemented in core), §33 (offline), §39 offline flow, ADR-005 (plan targets ≠ actuals)
**Nothing in this document is built yet.** It is the approved spec Phase 5 is implemented against; the seven decisions in §8 are the owner's and are final for this phase.

**Boundary (owner, final):** Phase 5 records and summarizes what the user actually did. Progression recommendations, target-load recommendations and their reasoning, the volume engine, deload and neglect detection are **Phase 6** and must not appear here — not in the API, not in the engine, not in the UI.

---

## 0. One-paragraph summary

Phase 5 turns the plan into a log. A user opens today's session (or any day), taps a set to record it — reps, weight and RIR pre-filled from the plan target and from what they did last time — with a rest timer between sets, and finishes with a summary and any PRs. Every set is written locally first (drift) and queued; the queue drains on reconnect; server idempotency keys make replay safe, so a whole workout in airplane mode syncs cleanly. `planned_sets` stay the plan; `set_logs` are the truth about what happened. The carry-over from Phase 4 — editing the **number of sets** — lands here too. Progression *recommendations* (`recommendProgression`, target loads with reasons) stay in Phase 6 as the spec orders; Phase 5 pre-fills "last time", not "next time".

---

## 1. Scope

### In (spec §31 Phase 5 + owner carry-over)
1. **Session lifecycle** — start (from a program day, or an ad-hoc empty session), log, correct, complete, abandon. One active session at a time per user.
2. **Set logging with idempotency** — `clientSetId` per set, `clientSessionId` per session; batch accepted; replay creates one row.
3. **Local-first + sync queue** — drift schema for sessions/exercises/sets + `sync_queue`; optimistic UI; drain on reconnect with backoff (max 5); conflict rules of §33.
4. **Pre-fill** — each set opens with the plan target (reps/weight/RIR from `planned_sets`) and, when history exists, **the last logged performance for that exercise** ("last time: 60 kg × 10 @ 2").
5. **Rest timer** — per exercise, starts on set completion, in-app (foreground) with a local notification when the app is backgrounded.
6. **Drop sets and supersets** — `set_type = drop` sets under a working set; superset grouping of two adjacent exercises in a session with alternating set order.
7. **Session summary** — duration, sets, tonnage, per-muscle hard sets, PRs earned.
8. **History** — paginated list of completed sessions; detail view.
9. **PR detection at completion** — `exercise_prs` (`weight`, `reps`, `1rm_est`, `volume`) and `set_logs.is_pr`; `POST …/complete` returns the PRs earned. **Baseline performance (the first logged session of a lift) is not a PR.** (Approved §8.1; the table moves forward from §31 Phase 6.)
10. **Set-count editing** (owner carry-over, approved) — add/remove planned sets on the **day screen**, in the **builder and day editor**, and adding/removing sets **mid-session** in the active workout.
11. **`GET /training/today`** — today's prescription (day, exercises, per-set targets, last performance, any open session), cached offline.
12. **`mesocycle_week` advancement** — on the first completed session of a new ISO week, capped at 8 (approved §8.2).
13. **Ad-hoc sessions** without a programme day (approved §8.6) — same tables, same endpoints, same set logging, same summary and history; the only difference is `program_day_id IS NULL` and no pre-seeded exercises.

### Out (and where it goes)
- Progression recommendations / target loads with reasons, volume engine, `muscle_volume_weekly`, deload trigger, neglect detection → **Phase 6**.
- TODAY ranked actions (`start-workout`, `celebrate-pr`) → **Phase 11**; Phase 5 adds a plain "Start / Resume today's session" entry on the TODAY placeholder.
- Push/scheduled notifications → **Phase 15**; Phase 5's rest-timer notification is local only.
- Exercise substitution mid-session (§12.6) → Phase 6 with progression (it needs `establish-baseline` semantics). Phase 5 lets you **replace** an exercise in a session using the existing picker, with no load carried over.
- RPE — stored (column exists in §9.2) but not shown in V1 UI; RIR is the only effort input.

---

## 2. Data model — migration `0006_workout_logging`

All per §9.2, with the deltas called out.

| Table | Columns | Notes |
|---|---|---|
| `workout_sessions` | `id`, `user_id`, `program_day_id` NULL (FK, `ON DELETE SET NULL`), `program_id` NULL, `started_at`, `completed_at` NULL, `duration_seconds` NULL, `notes` NULL, `client_session_id` UNIQUE, `deleted_at` NULL | **+`program_id`** so history survives a day being edited/removed. **+`status`** enum `active/completed/abandoned` — cheaper than inferring from nulls and lets "abandon" be explicit. |
| `session_exercises` | `id`, `session_id` (cascade), `exercise_id`, `order_index`, **+`planned_exercise_id` NULL (`SET NULL`)**, **+`superset_group` smallint NULL**, **+`client_exercise_id` UNIQUE** | `planned_exercise_id` is the soft link ADR-005 asked for; `client_exercise_id` makes offline-created exercises idempotent too. |
| `set_logs` | `id`, `session_exercise_id` (cascade), `set_index`, `set_type` (`warmup/working/drop/backoff`), `weight_kg` numeric(6,2) NULL, `reps` smallint, `rir` smallint NULL, `rpe` numeric(3,1) NULL, `is_pr` bool default false, `logged_at`, `client_set_id` UNIQUE, **+`planned_set_id` NULL (`SET NULL`)**, **+`deleted_at` NULL** | Append-only per §33; a correction is a PATCH, a mistake is a soft delete. CHECKs: `reps >= 0`, `rir BETWEEN 0 AND 5`, `weight_kg >= 0`, unique `(session_exercise_id, set_index, set_type)` among non-deleted rows (partial unique index). |
| `exercise_prs` | `id`, `user_id`, `exercise_id`, `pr_type` enum (`1rm_est/weight/reps/volume`), `value` numeric, `achieved_at`, `set_log_id` (cascade) | Derived cache per §9.4 — rebuildable by a script from `set_logs`. |
| indexes | `set_logs (session_exercise_id, set_index)`; `workout_sessions (user_id, started_at DESC) WHERE deleted_at IS NULL`; **partial unique** `workout_sessions (user_id) WHERE status = 'active'` (one active session per user, enforced by the database like `one_active_program`) | |

`programs.mesocycle_week` is already there; Phase 5 starts writing it. No change to `planned_*` tables: set-count editing uses the Phase 4 PATCH (`setCount` + `sets[]`, ids preserved).

Down script: drop the four tables and the two enums.

---

## 3. Contracts (`@fitos/contracts`) and API

### New schemas
`setTypeSchema`, `sessionStatusSchema`, `prTypeSchema`, `setLogSchema`, `sessionExerciseSchema` (with `sets[]`, the linked planned exercise's target, `lastPerformance` = the most recent completed session's working sets for this exercise), `workoutSessionSchema`, `sessionSummarySchema` (duration, working sets, tonnage, `hardSetsByMuscle`, `prs[]`), `startSessionRequestSchema` (`clientSessionId`, `programDayId?`, `startedAt`), `logSetsRequestSchema` (`sets: [{ clientSetId, sessionExerciseId | clientExerciseId, setIndex, setType, weightKg?, reps, rir?, loggedAt }]` — batch, 1–50), `patchSetRequestSchema` (any of weight/reps/rir/setType), `addSessionExerciseRequestSchema` (`clientExerciseId`, `exerciseId`, `plannedExerciseId?`, `orderIndex`, `supersetGroup?`), `completeSessionRequestSchema` (`completedAt`, `notes?`), `sessionListResponseSchema` (cursor pagination), `todayResponseSchema`.

### Endpoints (§10.1; additions marked)
| Method | Path | Idempotency | Purpose |
|---|---|---|---|
| POST | `/training/sessions` | `clientSessionId` | Start. Seeds `session_exercises` from the day's `planned_exercises` (with `planned_exercise_id`), returns the session with targets + last performance. A second call with the same key returns the same session (200, not 409). A different key while another session is `active` → **409 `SESSION_ACTIVE`** with the active session's id. |
| POST | `/training/sessions/{id}/sets` | `clientSetId` (batch) | Log 1–50 sets. Replay = same rows, 200. Rejected (409 `SESSION_COMPLETED`) if the session is completed **unless** the sets' `loggedAt` precede `completedAt` and the client sends `merge: true` — the §33 "completed on another device" merge. |
| PATCH | `/training/sessions/{id}/sets/{setId}` | — | Correct reps/weight/RIR/type. |
| DELETE | `/training/sessions/{id}/sets/{setId}` | — | **Addition**: soft delete a mis-tapped set. |
| POST | `/training/sessions/{id}/exercises` | `clientExerciseId` | **Addition**: add an unplanned exercise / replace mid-session. |
| PATCH | `/training/sessions/{id}/exercises/{exId}` | — | **Addition**: reorder, set `supersetGroup`, remove (`removed: true`). |
| POST | `/training/sessions/{id}/complete` | — | Finish: `status=completed`, duration, PR detection, `mesocycle_week` rule, returns `sessionSummary`. Already completed → 200 with the same summary (idempotent). |
| POST | `/training/sessions/{id}/abandon` | — | **Addition**: `status=abandoned`; sets are kept for history but never count toward PRs/volume. |
| GET | `/training/sessions` | — | History, cursor-paginated (`?before=<startedAt>&limit=20`), completed only by default (`?status=`). |
| GET | `/training/sessions/{id}` | — | **Addition**: one session with sets and summary. |
| GET | `/training/today` | — | Today's day (or "rest"), exercises with per-set targets and last performance, the active session if any. Also `?dayOfWeek=` so the day screen can prefill any day. |

Rate limits unchanged (120/min). Every route default-deny; the existing sweep test extends to the new ones.

### Server rules
- **Idempotency** is a unique index + `ON CONFLICT DO NOTHING RETURNING` re-read: never a read-then-write race.
- **Only `working` sets** feed PRs (and, in Phase 6, volume). Warm-up/drop/back-off are stored, shown, and excluded.
- **PR detection** (`packages/core/src/training/records.ts`, pure): for each working set with weight, compare against the user's prior best for that exercise: `weight` (heaviest at ≥1 rep), `reps` (most reps at ≥ prior best weight), `1rm_est` (Epley, already in `progression.ts`), `volume` (session tonnage for the exercise). First session of an exercise sets baselines and is **not** a PR (a baseline is not an achievement). Returns `{ prType, value, previous, setLogId }[]` with a reason string.
- **Last performance** = the most recent *completed* session's working sets for the same `exercise_id` (not planned-exercise id, so it follows a lift across programmes).

---

## 4. Core engine additions (`packages/core`, deterministic, dependency-free)

4.1 `training/records.ts` — PR detection as above; `estimate1RM` reused. Tests: each `pr_type`, baseline-not-PR, ties are not PRs, drop/warm-up excluded.
4.2 `training/session-summary.ts` — `summarizeSession(sets, exercises, catalogue)` → duration, working sets, tonnage, `hardSetsByMuscle` (primary 1, secondary 0.5 — the same weighting the generator already uses), exercises completed / skipped. Hand-checkable; tests against a fixture.
4.3 `training/prefill.ts` — `prefillSet(plannedSet, lastPerformance)` → the numbers the set row opens with: plan target reps (`repsMax` today), weight = last time's working weight if there is one else the planned weight (may be null), RIR = plan. **No progression logic** — that is Phase 6's `recommendProgression`; this is "what you did", not "what to do".
4.4 `training/mesocycle.ts` — `nextMesocycleWeek(program, completedSessions)`: the week advances when a session is completed in a later ISO week than the last advance, capped at 8; Phase 6's deload resets it to 1. Pure function of timestamps; tests for week boundaries and same-week repeats. (Approved §8.2.)

The existing `progression.ts` is untouched; its `SessionLog` shape (`weightKg, reps, rir`) is what `set_logs` will be mapped to in Phase 6.

---

## 5. Flutter

### 5.1 Local database (drift) — `lib/core/db/`
Tables mirroring the server: `sessions`, `session_exercises`, `set_logs`, plus `sync_queue (id, endpoint, method, payload json, client_key, attempts, next_attempt_at, created_at, last_error)`. Server ids stored alongside client ids once known. `drift_dev 2.23.1` added (pinned, same as `drift`); generated code committed like freezed's.

**Test host requirement (approved §8.7):** drift tests use `NativeDatabase.memory()`, which needs a native SQLite on the machine running `flutter test`. CI (Ubuntu) has it and **CI is authoritative**. On Windows, `sqlite3.dll` must be on `PATH`; `apps/mobile/README.md` gets a "Running the drift tests on Windows" section (where to download, where to put it, how to verify). Tests fail loudly with that instruction, never skip silently.

### 5.2 Local-first repository + sync
`WorkoutRepository` (domain) with a drift-backed implementation: every write goes to SQLite and the queue **synchronously** (no network on the tap path); a `SyncDrainer` (Riverpod) listens to `connectivity_plus` and app-resume, drains FIFO with exponential backoff (300 ms · 2ⁿ, max 5 attempts, then parked with `last_error` and surfaced as "n sets not synced · Retry" — never silently dropped). Responses reconcile server ids into the local rows. 409 `SESSION_COMPLETED` → resend with `merge: true` (§33). 401 → pause; the auth interceptor already handles refresh/sign-out.

### 5.3 Screens (all in `features/training`; no new tabs)
- **Day screen (existing `/plan`)** gains: "Start session" (or "Resume · 12 min") at the top of a training day; "+ Add set" under the last set row and a per-set remove (long-press or swipe) — the owner's carry-over; both go through the existing day PATCH with ids preserved.
- **Active workout `/plan/session/:id`** (root navigator, bar hidden, `PopScope` → "Leave? Your sets are saved" — never loses data): the same exercise cards, every set row gets a **done** tap that logs it with the pre-filled numbers (edit first if needed), turns the row pine, and starts the rest timer; "last time" shown in ink60 under the target; **+ Add set**, **Drop set**, **Superset with next**, Replace, Skip exercise; sticky footer: elapsed time, sets done / planned, rest countdown; "Finish" → summary. Optimistic: nothing waits for the network; an unsynced-count pill appears only when something is queued.
- **Rest timer** (approved §8.4): default 90 s for compound patterns, 60 s for isolation, with a per-exercise override remembered on the device (shared_preferences — a trivial flag); −15 / +15, skip; foreground countdown; when backgrounded, a local notification fires at zero (`flutter_local_notifications`, pinned — the Phase 15 push stack is separate).
- **Ad-hoc session** (approved §8.6): "Start empty session" from the plan's ⋯ menu and from a rest day; exercises added via the picker; identical active screen, summary and history entry.
- **Summary `/plan/session/:id/summary`**: duration, sets, tonnage, hard sets per muscle, PRs in pine, "Done".
- **History `/plan/history`** (from the plan's ⋯ menu): sessions list (date, name, sets, duration, PRs) → detail.
- **TODAY**: one panel — today's session name and "Start" / "Resume" / "Done ✓" — replacing the current "Your training plan" button.

### 5.4 Contract conformance
Hand-written DTOs per ADR-004; `contract_conformance_test.dart` extended for every new schema.

---

## 6. Tests

| Layer | Tests |
|---|---|
| core | records: each `pr_type`, baseline-not-PR, ties, non-working excluded · summary vs hand calculation (secondary 0.5) · prefill: plan-only, history-present, null weight · mesocycle: same week, next week, 8-cap, ISO boundary (Sun→Mon) |
| contracts | every new schema round-trips; batch bounds; unknown keys rejected |
| api (real PG, `fitos_test`) | start idempotent (same key → same session) · second active session → 409 · replaying a batch creates one row per `clientSetId` · out-of-order / duplicate batches · PATCH / soft DELETE · complete: PRs returned once, replay returns same summary, `mesocycle_week` rule · merge into a completed session (§33) · abandon excludes from PRs · history pagination and ownership (never another user's session) · `/training/today` on a training day, a rest day, with an active session · default-deny sweep · migration 0006 up/down |
| flutter | drift: write → queue → drain → reconcile · **offline: log a full session with connectivity off, reconnect, every set reaches the fake server exactly once, order preserved** · replay-safe on app kill mid-drain · conflict 409 → merge · widget: tap-to-log pre-fills and turns pine, edit-then-log, add set / drop set / superset ordering, rest timer countdown + skip, Leave keeps sets, summary shows PRs, history list → detail · set-count editing on the day screen persists via PATCH with ids kept · TODAY start/resume states · conformance |
| perf | a widget test asserting a set is persisted locally within one frame of the tap (the "<3 s median" acceptance is verified manually with timestamps in the log) |

Gate: all green, lint/analyze/format/typecheck, Docker boot, migration both ways, APK.

---

## 7. Acceptance (spec) + manual checklist (draft)
- **Airplane mode**: start a session offline, log every set, finish → summary appears; re-enable network → server session matches set for set (checked via `GET /training/sessions/{id}`).
- Median set logging < 3 s (tap → row confirmed): timed over 10 sets.
- Previous performance pre-filled on the second session of the same exercise.
- Replay: kill the app mid-drain, reopen → no duplicate sets on the server.
- Set count: add a 5th set to bench on the day screen → survives reopen; remove it → gone.
- PR: beat last week's top set → the summary names it; repeat the same → no PR.

---

## 8. DECISIONS — approved by the owner 2026-09-21

| # | Decision | Approved |
|---|---|---|
| 8.1 | PRs in Phase 5 | **Yes.** `exercise_prs` + `set_logs.is_pr` now; `/complete` returns PRs earned; baseline performance is not a PR. |
| 8.2 | `mesocycle_week` rule | **Advance on the first completed session of a new ISO week, capped at 8.** Phase 6's deload resets it to 1. |
| 8.3 | Supersets | **Lean adjacency-based supersets in the active workout screen** (alternating set order); no plan-level supersets. |
| 8.4 | Rest timer | **90 s compounds / 60 s isolation, per-exercise override; in-app timer plus a local notification when backgrounded.** |
| 8.5 | Session end | **Explicit `abandoned` status. Sessions never auto-complete.** |
| 8.6 | Ad-hoc sessions | **In scope**, on the same session/set/history infrastructure as programme-day sessions. |
| 8.7 | Drift tests on Windows | **Accepted**: `sqlite3.dll` on PATH, documented clearly; CI remains authoritative. |

**Boundary restated (owner):** Phase 5 records and summarizes what the user actually did. No progression recommendations, no target-load recommendations or reasoning, no volume engine, no deload, no neglect detection — Phase 6.

**Carry-over confirmed:** set-count editing on the day screen, in the builder/day editor, and mid-session.

## 9. Implementation order (each step green before the next)
1. Core: `records.ts`, `session-summary.ts`, `prefill.ts`, `mesocycle.ts` + tests.
2. Migration 0006 (+down, migration tests), drizzle schema.
3. Contracts + `openapi.json`.
4. API: repository → service → routes; integration tests incl. idempotency, merge, sweep.
5. Flutter: DTOs + conformance; drift schema + `drift_dev`; local repository + sync queue + drainer + tests (offline first — the critical case).
6. Flutter UI: day-screen set-count editing → active workout → rest timer → summary → history → TODAY entry.
7. Full suites, Docker boot, migrate + seed local DB, APK.
8. Phase 5 report in the §39 format; ADR-006 (local-first logging, sync, and the five API additions) recording where this phase goes beyond §10.1/§9.2.

## 10. Risks
- **Sync edge cases** (kill mid-drain, clock skew on `loggedAt`) — mitigated by client-side ids for everything and server-side ordering by `set_index`, not time.
- **drift/sqlite3 upgrade** (pubspec TODO) — stay on drift 2.23.1 / sqlite3_flutter_libs 0.5.42 for Phase 5; upgrade is a separate, tested change.
- **Two devices** — supported only through the §33 merge rule; no live multi-device session.
- **Scope size** — Phase 5 is the retention-critical phase and the largest so far; every item in §1 is approved scope, so if it must shrink that is a new owner decision, not a quiet cut.
