# ADR-007 — Progression & volume: recommendations with reasons, deload as an offer, ISO-week volume cache, deterministic substitution

**Status** ACCEPTED — decisions approved by the owner 2026-09-21 (Phase 6 plan §12, decisions 12.1–12.8)
**Date** 2026-09-21
**Phase** 6
**Affects** MASTER-SPEC.md §9.2 (`muscle_volume_weekly`, `exercise_rejections`, `programs.deload_*`), §10.1 (`/training/volume`, `/training/progression/{exerciseId}`, `/training/deload/*`), §12.3 (volume landmarks), §12.4 (progression), §16 (neglect), §18 (deload), §31 Phase 6, ADR-005 (plan targets ≠ actuals), ADR-006 (logging)

---

## Context

Phase 5 recorded what the user did and deliberately recommended nothing.
Phase 6 turns that history into a next load with a reason on every planned
lift, decides when a lighter week is due, and shows weekly hard sets per
muscle against the §12.3 landmarks — all deterministic, all in
`packages/core`, all explained. The owner fixed the eight open questions
before a line was written; this record captures how they were built and
the two consequences that only showed up in integration.

## Decisions

### 1. A recommendation is a row pre-fill plus a reason, never a modification (12.1, 12.3)

`recommendProgression` (§12.4, six branches + the new bodyweight
reps-only branch 1b) runs on the server over the last three **completed,
non-deload** sessions of the lift (`ProgressionAssembler.toSessionLogs`).
Its answer rides on `GET /training/today` and on every session as
`recommendation {action, weightKg, repTarget, targetRir, reason, basis,
sessionsConsidered}` and is folded into `prefill` with `weightSource:
'recommendation'` (reps = repMin after an increase, else repMax). The row
opens on it; the reason is the engine's text verbatim; one tap reverts to
last time's load. `planned_sets` and `planned_exercises` are never
written by the engine — the plan the user edits in Phase 4 stays theirs.

### 2. Deload is an offer with two triggers, one acceptance and one closing rule (12.2–12.4)

Offered when (a) ≥ 2 lead lifts (compound patterns) completed in the last
7 days each resolve to `deload` — three declining sessions at the same
load with RIR falling — or (b) `mesocycle_week ≥ 6` and any owned muscle
is at/above MRV this ISO week. The offer carries its trigger and reason.
**Accept** stamps `programs.deload_started_at`; **Not now** stamps
`deload_snoozed_until` seven days out. While active, targets are computed
on read — sets × 0.6 (min 1), load × 0.9 of the last logged working load
rounded to 0.5 kg, RIR + 2 capped at 5 — and the plan's originals are
returned beside them (`originalTargets`). Deload sessions are excluded
from the fatigue comparison, so a lighter week cannot re-trigger itself.
The first completion after the seven days closes it: `deload_started_at`
cleared, `mesocycle_reset_at` set, `mesocycle_week = 1`; from then the
week counts distinct ISO weeks trained since the reset.

*Integration consequence:* the deload load must be ×0.9 of **what was
last lifted**, not of the engine's recommendation — a fatigued lift's
recommendation is already ×0.9, and using it double-discounted (80 → 65
instead of 72). Fixed and covered by the accept test.

### 3. Volume is computed on read and cached per ISO week; the cache is rebuildable (12.8)

`weeklyVolume` counts working sets of completed sessions — 1 per primary
muscle, 0.5 per secondary, warm-up and drop sets excluded, deleted sets
and abandoned sessions never — bucketed by ISO week in the user's
calendar. `GET /training/volume` answers the current week and the three
before from `set_logs` directly (four weeks is cheap and always right);
`muscle_volume_weekly` is written on every completion for the
completed week and by `pnpm db:rebuild-volume` for every user-week, so
a future dashboard or Phase 12 can read it without recomputing. The
cache never feeds a decision the live query could contradict.

### 4. Substitution is deterministic and honest (12.6)

`substitute` proposes an alternative for a planned lift when the user's
kit no longer covers its equipment, a limitation now excludes it, or it
has been removed/replaced from a session twice (`exercise_rejections`,
written by the session PATCH). The alternative comes from
`exercise_alternatives`, must share the movement pattern and first
primary muscle and be performable; when nothing qualifies the answer says
so (`alternative: null` with the reason) rather than guessing. Accepting
is the Phase 4 day PATCH from the phone — same id, new `exerciseId`,
weights cleared — so the plan changes only by the user's hand.

### 5. Neglect is owned-muscle-only with a six-day threshold (12.7)

A muscle counts as neglected when the active programme owns it (it is a
primary or secondary muscle of any planned exercise) and no working set
touched it in the last six days. Muscles outside the programme are never
nagged about. Shown on TODAY and the volume screen; not ranked, not
actioned (Phase 11).

## Consequences

- Three tables/columns beyond §9.2: `muscle_volume_weekly`,
  `exercise_rejections`, `programs.deload_started_at /
  deload_snoozed_until / mesocycle_reset_at` (migration 0007, with down).
- Four routes beyond §10.1: `GET /training/volume`,
  `GET /training/progression/{exerciseId}`, `POST /training/deload/accept`,
  `POST /training/deload/decline`.
- The phone computes nothing: the PR moment compares a logged set against
  two server numbers (`priorBest.weightKg`, `repsAtBestWeight`); colours,
  rules and lines are display only.
- Phase 5's prefill `weightSource` gained `'recommendation'`; a Phase 5
  cached `today` without the new keys still parses (defaults).
- Not done, by decision: no LLM, no recovery/sleep/soreness inputs, no
  TODAY ranking, no PROGRESS screen, no AI rephrasing of reasons.
