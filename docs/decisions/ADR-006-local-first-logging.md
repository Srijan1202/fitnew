# ADR-006 — Workout logging: local-first store, idempotent sync, and the Phase 5 API additions

**Status** ACCEPTED — decisions approved by the owner 2026-09-21 (Phase 5 plan §8)
**Date** 2026-09-21
**Phase** 5
**Affects** MASTER-SPEC.md §9.2 (`workout_sessions`, `session_exercises`, `set_logs`, `exercise_prs`), §10.1 (`/training/sessions*`, `/training/today`), §31 Phase 5, §33 (offline), ADR-005 (plan targets ≠ actuals)

---

## Context

Phase 5 is the retention-critical phase: a set must be logged in under
three seconds in a gym with no signal, and a whole workout logged in
airplane mode must reach the server exactly once on reconnect (§31
acceptance). §33 fixes the mechanism — write locally first, queue with a
client idempotency key, drain on reconnect — and leaves the details to
this phase. Four decisions came out of building it.

## Decisions

### 1. The phone's database is the source of truth for the session in progress

The active workout is read from drift (`local_sessions`,
`local_session_exercises`, `local_set_logs`) and only from there. Every
mutation writes a row and a `sync_queue` entry in one transaction, then
kicks the drainer; nothing on the tap path awaits the network. The
server's answers only ever **add** to the local rows (server ids, `is_pr`,
the summary, targets, last performance); they never delete a row the
phone holds, because that row may still be on its way up.

Sessions are addressed everywhere in the app by their **client id** —
routes, providers, the queue — since it exists before the server has heard
of the session.

### 2. Every client-created row carries the server's idempotency key

`clientSessionId`, `clientExerciseId`, `clientSetId` are UUIDs the phone
mints. On the server each is a UNIQUE index and every client-keyed insert
is `ON CONFLICT DO NOTHING` followed by a re-read, so a replayed request —
the queue drained twice, the app killed mid-drain — is a no-op at the
database, not merely in code. A client that seeds a session offline sends
its exercise ids in `POST /training/sessions` (`exercises[]`) so the
server adopts them and offline-logged sets replay cleanly.

### 3. The queue drains oldest-first, batches sets, folds edits, and parks failures

- Sets logged while a batch is still unsent are appended to it; a whole
  workout is a handful of requests. A batch that grew while in flight
  keeps what was not sent.
- A correction or deletion of a set the server has not seen is folded
  into the pending batch — no PATCH for a row that does not exist there.
  The same for an exercise whose `addExercise` is still queued.
- Offline and 401 stop the drain and charge nothing to the entry. Any
  other failure backs off (300 ms · 2ⁿ) for five attempts, then the entry
  is **parked** with its error and shown as "n not synced · Retry". Nothing
  is ever dropped.
- A session completed on another device answers 409; the batch is resent
  once with `merge: true` (§33's conflict rule).

### 4. What is stored, and where the phase stops

Migration `0006_workout_logging` adds the four §9.2 tables with these
deltas: `workout_sessions.status` (`active | completed | abandoned` — a
session never auto-completes, owner 8.5) and `program_id` (history
survives a day being edited away); `session_exercises.planned_exercise_id`
(ADR-005's soft link), `superset_group` (owner 8.3: adjacency grouping in
the active screen only) and `client_exercise_id`; `set_logs.planned_set_id`
and `deleted_at` (append-only: corrections update, mistakes soft-delete);
`exercise_prs` (owner 8.1: records in Phase 5, baseline is not a record).
One active session per user is a partial unique index, like
`one_active_program`. `programs.mesocycle_week` advances on the first
completed session of a new ISO week in the user's calendar, capped at 8
(owner 8.2); stateless and rebuildable from `completed_at`.

Beyond §10.1, five routes were needed: `DELETE …/sets/{setId}` (a
mis-tap), `POST …/exercises` and `PATCH …/exercises/{id}` (add, reorder,
superset, replace, remove mid-session), `POST …/abandon`, and
`GET /training/sessions/{id}`.

**The boundary is strict (owner):** Phase 5 records and summarizes what
the user did. Pre-fill (`prefillSet`) is a description — the plan's
target reps, last time's weight — never a recommendation. Progression,
target loads with reasons, the volume engine, deload and neglect
detection are Phase 6 and appear nowhere in this phase's API, engine or
UI.

## Consequences

- Phase 6 reads `set_logs` (working sets, `deleted_at IS NULL`, completed
  sessions) through the same `priorWork` shape `recommendProgression`
  already expects; it never reads `planned_sets`.
- Two devices are supported only through the merge rule; there is no live
  shared session.
- drift moved from 2.23.1 to 2.29.0 (its generator needs the analyzer the
  rest of the toolchain is on); `sqlite3` stays on 2.x with
  `sqlite3_flutter_libs` 0.5.42.
- On Windows the drift tests use `winsqlite3.dll`; CI is authoritative
  (owner 8.7). Windows Smart App Control in enforce mode blocks the
  unsigned `flutter_tester.exe` entirely — documented in
  `apps/mobile/README.md`.
