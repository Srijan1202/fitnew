# Phase 6 — Progression & volume: implementation plan

**Status** DRAFT for owner approval · **Date** 2026-09-21 · **Prereq** Phase 5 accepted at `6daa648` (all 13 manual checks passed)
**Spec** MASTER-SPEC §31 Phase 6, §12.3 (landmarks), §12.4 (progression — implemented in core), §12.5 (deload), §12.6 (substitution), §16 (the `deload` / `progress-load` / `muscle-neglected` actions the TODAY engine already emits), §18 (recovery never silently changes the plan), §19 (AI boundary), §9.2 (`muscle_volume_weekly`), §10.1 (`GET /training/volume`)
**Builds on** ADR-005 (plan targets ≠ actuals), ADR-006 (local-first logging; `priorWork` shape)
**Nothing in this document is built.** Coding starts only after approval; every "DECISION NEEDED" in §12 is yours.

---

## 0. One-paragraph summary

Phase 5 recorded what the user did. Phase 6 turns that record into *what to do next*, deterministically: the existing `recommendProgression` (§12.4, six branches, already tested) runs over each lift's last three completed sessions and its target load, with a reason, becomes the number the set row opens with; a new volume engine counts weekly hard sets per muscle against the §12.3 landmarks, flags neglected muscles, and — together with the fatigue rule — decides when a deload should be *offered*. Nothing changes the plan silently: a deload is an offer the user accepts or declines; a recommended load is a pre-fill the user can revert with one tap. No LLM anywhere in this phase.

---

## 1. Scope

### In (§31 Phase 6 + spec sections it points at)
1. **Progression recommendations** — `recommendProgression` wired per exercise over Phase 5 history: action (`increase-load` / `add-reps` / `hold` / `reduce-load` / `deload` / `establish-baseline`), target load, rep target, RIR, **reason**. Bodyweight lifts get a reps-only rule (§4.1, DECISION §12.5).
2. **Target-load recommendations with reasons on `GET /training/today`** and on the session (§31 acceptance): the set row opens with the recommended load; the reason is one tap away; "last time" stays visible; one tap reverts to last time's weight.
3. **Volume management** — `packages/core/src/training/volume.ts`: weekly hard sets per muscle (working sets, 0.5 secondary, completed sessions, ISO week in the user's calendar), tonnage, comparison to MV / MEV / MAV / MRV with a status per muscle, four-week history; `muscle_volume_weekly` cache written on completion and rebuildable; `GET /training/volume`; a volume screen.
4. **Deload / recovery logic** — two triggers per §12.5: per-lift fatigue (rule 2) → that lift's recommendation is `deload`; programme-level deload week when fatigue shows on ≥ 2 lead lifts within 7 days **or** `mesocycle_week ≥ 6` with any muscle at/above MRV. A deload week is **offered**; accepted → the next 7 days' session seeds carry load ×0.9, sets ×0.6 (rounded, ≥ 1), RIR +2; afterwards `mesocycle_week` resets to 1 (§12.5). Declined → not re-offered for 7 days.
5. **Neglect detection** — a muscle the programme owns with no logged sets (primary or secondary) in the last 6 days (§16 band, `NEGLECT_DAYS = 6` already in the engine); exposed on `/training/volume` and `/training/today`; shown on the volume screen.
6. **PR detection** is done (Phase 5, owner 8.1); Phase 6 adds the in-session **PR moment** (the row turns pine-with-a-star the instant a logged set beats the prior best the server supplied) and the `newPrToday` input the TODAY engine expects.
7. **Consuming Phase 5 history** — one read path (§5) from `set_logs` through the `priorWork` shape into `SessionLog[]`; abandoned sessions, deleted sets and non-working sets never count.
8. **Exercise substitution (§12.6)** — the deterministic trigger set only: on `GET /training/today`, an exercise the user's current equipment/limitations no longer allow, or one they rejected twice, carries `substitution: { alternativeId, reason }` from `exercise_alternatives` (same pattern + primary muscle); the substitute starts at `establish-baseline` (no load carried). Rejection counting needs a small table (§7). DECISION §12.6 on whether to include this now.

### Out
- The TODAY ranked-actions engine assembly, `recommendations` persistence, events → **Phase 11** (Phase 6 only makes its inputs — `leadLiftProgression`, `neglectedMuscles`, `newPrToday`, the deload state — available on the API).
- Readiness / recovery card, sleep/soreness inputs, the "< 35 → rest day → deload check" escalation → **Phase 13**. Phase 6's deload uses only training data.
- Rephrasing reasons with an LLM → **Phase 14** (§19: allowed there, never here). Phase 6 reasons are the engine's strings, rendered verbatim.
- PROGRESS screen (trend weight, PR list, photos) → **Phase 12**; Phase 6 ships the volume screen only.
- Changing `planned_sets` because of a recommendation. The plan stays the plan (ADR-005); recommendations are per-session seeds. A user who wants the plan itself to move edits it (Phase 4 UI).

---

## 2. Rules-first architecture and where AI is allowed

| Concern | Where it lives | AI |
|---|---|---|
| Progression branch, target load, rep target, RIR | `packages/core/src/training/progression.ts` (exists; +bodyweight rule) | **never** |
| Weekly volume, landmark status, neglect | `packages/core/src/training/volume.ts` (new) | **never** |
| Deload offer decision, deload targets, mesocycle reset | `packages/core/src/training/deload.ts` (new) | **never** |
| Substitution trigger and pick | `packages/core/src/training/substitution.ts` (new) | **never** |
| Mapping rows → engine inputs, persistence, caches | `apps/api/src/modules/training/…` and `workout/…` | — |
| Rendering reasons, revert-to-last-time, accept/decline | Flutter | — |
| Rephrasing an engine reason in plainer words | not in Phase 6 (§19: Phase 14, draft-only, numbers must match the payload) | later |

Every recommendation carries `reason` (a string) and `basis: 'calculated' | 'logged'`; a recommendation without a reason is a bug (§12.4) and a contract test enforces `min(1)` on every reason field.

---

## 3. Core modules (pure functions, no I/O, no dates from the clock)

### 3.1 `progression.ts` — one addition, no change to the six branches
`recommendProgression` today returns `establish-baseline` whenever the last session has no loaded working set, which makes a bodyweight lift (push-ups, chin-ups) permanently baseline. Add branch 1b (**DECISION §12.5**): when every working set in the last session is unloaded (`weightKg` null/0) and `target.repMax` is a number, recommend `add-reps` with `weightKg: null`, `repTarget` = min(best reps + 1, repMax… or "beyond repMax: add a set / load it" as reason) — evaluated after rule 1, before rule 2. The existing tests stay untouched; new ones cover the branch.

### 3.2 `volume.ts` (new)
```ts
weeklyVolume(sets: readonly VolumeSet[], weekKey: string): Record<MuscleGroup, { hardSets: number; tonnageKg: number }>
  // VolumeSet = { localDate, exerciseId, primaryMuscles, secondaryMuscles, weightKg|null, reps, setType }
  // working only, 1.0 primary / 0.5 secondary, tonnage = weight×reps over loaded working sets
landmarkStatus(muscle, hardSets): 'none' | 'below-mv' | 'below-mev' | 'mev-to-mav' | 'above-mav' | 'at-mrv'
volumeReport(sets, weeks: string[], owned: MuscleGroup[]): per week × muscle { hardSets, tonnageKg, status, landmarks }
neglectedMuscles(sets, owned, today: localDate, days = 6): MuscleGroup[]   // owned muscles with no set (primary or secondary) in [today−days, today]
```
Landmarks come from `VOLUME_LANDMARKS` in `generator.ts` (already the §12.3 table).

### 3.3 `deload.ts` (new)
```ts
shouldOfferDeload(input: { mesocycleWeek; volume: this week's report; fatigued: exerciseId[] /* lifts whose recommendation is 'deload' in the last 7 days */; leadLifts: exerciseId[]; snoozedUntil: localDate|null; today }): { offer: boolean; reason: string; trigger: 'fatigue' | 'mrv' | null }
deloadTargets(planned: PlannedSetTarget[], lastLoad: number|null): PlannedSetTarget[]   // sets ×0.6 (round, ≥1), load ×0.9 (to 0.5 kg), rir +2 (≤5)
mesocycleAfterDeload(): 1
```
Lead lifts = the session's compound-pattern exercises (the `COMPOUND` set already in the generator).

### 3.4 `substitution.ts` (new, if §12.6 is in scope)
`needsSubstitution(exercise, kit, limitations, rejections)` → reason or null; `pickAlternative(exercise, alternatives, kit, limitations)` → the first alternative with the same movement pattern and first primary muscle the user can perform; null → "no alternative in the library" (honest, like Phase 4 shortfalls).

### 3.5 Boundaries that stay fixed
- `generator.ts`, `templates.ts`, `records.ts`, `session-summary.ts`, `prefill.ts`, `mesocycle.ts` are not modified, except `prefill.ts` gaining an optional `recommendation` input that wins over "last time" for the weight (the reps target follows the recommendation's rep range floor after an `increase-load`: "move to 65 kg and work back up from 6" → row opens at `repMin`; otherwise `repMax` as today). **DECISION §12.1.**
- Dates: every core function takes local calendar dates (`yyyy-mm-dd`) computed by the API in the user's timezone (as Phase 5's `localDate`).

---

## 4. How Phase 6 consumes Phase 5 history

One read, one mapping, reused everywhere:

```
set_logs ⨝ session_exercises ⨝ workout_sessions
  WHERE user_id = ? AND status = 'completed' AND sessions.deleted_at IS NULL
    AND session_exercises.removed_at IS NULL AND set_logs.deleted_at IS NULL
    AND set_type = 'working'
  ORDER BY completed_at DESC, set_index
→ WorkoutRepository.priorWork()          (exists)
→ toSessionLogs(prior, tz): per exercise, most recent last, ≤ 3 sessions
      { date: localDate(completedAt), sets: [{ weightKg: number|0, reps, rir }] }
→ recommendProgression({ history, target })   target = the planned exercise's repMin/repMax/targetRir/setCount/incrementKg
```
Rules of the read: abandoned sessions never count (already excluded by `status`); merged sets (§33) count like any other; a corrected set is read as corrected; drop/warm-up/back-off sets are shown but never feed progression or volume; a replaced movement mid-session is history for the *new* exercise id (no load carries over, §12.6). History is keyed by **exercise id**, so it follows a lift across programmes.

Volume reads the same rows over a four-week window (`completed_at ≥ start of ISO week − 3 weeks`), mapped to `VolumeSet` with the exercise's primary/secondary muscles from `exercise_muscles` (position order, 0005).

---

## 5. API and database

### 5.1 Migration `0007_progression_volume`
| Change | Purpose |
|---|---|
| `muscle_volume_weekly (user_id, iso_week text 'YYYY-Www', muscle_group, hard_sets numeric(5,1), tonnage_kg numeric(9,1), updated_at)` PK (user_id, iso_week, muscle_group) | §9.2 derived cache; written on `/complete`, rebuilt by `pnpm --filter @fitos/api db:rebuild-volume` (§9.4) |
| `programs.deload_started_at timestamptz NULL`, `programs.deload_snoozed_until date NULL`, `programs.mesocycle_reset_at timestamptz NULL` | the accepted deload week; the declined offer; where week counting restarts (§12.5 "then resets to 1") |
| `exercise_rejections (user_id, exercise_id, rejected_at)` (if §12.6 is in scope) | "user rejects an exercise twice" trigger |

Down: drop the table(s) and columns. `mesocycleWeekFrom` gains a `since` (dates before `mesocycle_reset_at` are ignored) — a parameter, not a rule change.

### 5.2 Endpoints
| Method | Path | Purpose |
|---|---|---|
| GET | `/training/today` | **extended**: each exercise gains `recommendation` (`action`, `weightKg`, `repTarget`, `targetRir`, `reason`, `basis`) and `priorBest` (`weightKg`, `repsAtBest`, `estimated1rm`) for the PR moment; response gains `deload: { state: 'none' \| 'offered' \| 'active', reason, until }` and `neglected: MuscleGroup[]`; `prefill` now follows the recommendation (DECISION §12.1) |
| POST | `/training/sessions` | **extended**: the seeded session carries the same `recommendation` / `priorBest` per exercise; during an active deload week, targets are deload targets |
| GET | `/training/volume` | `{ weeks: [{ isoWeek, muscles: [{ muscle, hardSets, tonnageKg, status, landmarks }] }], neglected, owned }` — current + 3 previous weeks |
| GET | `/training/progression/{exerciseId}` | the last three sessions and the recommendation for one lift, for the "why" sheet |
| POST | `/training/deload/accept` | **addition**: starts the deload week (sets `deload_started_at`) |
| POST | `/training/deload/decline` | **addition**: snoozes the offer 7 days |
| POST | `/training/sessions/{id}/complete` | **extended**: after records, upsert `muscle_volume_weekly` for that ISO week; if a deload week has elapsed (`deload_started_at + 7d ≤ completedAt`), close it and set `mesocycle_reset_at` (week → 1) |

`GET /today` (§10.1, Phase 11) is not built; the `UserModel` inputs it needs (`leadLiftProgression`, `neglectedMuscles`, `newPrToday`, deload) all exist on `/training/today` after this phase.

---

## 6. Flutter

- **Set rows open with the recommendation.** Weight = recommended load (or last time / plan when the action prescribes none); a small line under the exercise header: *"↑ 65 kg — you hit 12 on every set at 62.5"* (the engine's reason, verbatim, truncated to one line; tap → sheet with the full reason, the last three sessions, and **Use last time's weight** which reverts every pending row). Colour: pine for `increase-load`, ink for `add-reps`/`hold`, amber for `reduce-load`/`deload`, ink60 for `establish-baseline`.
- **PR moment**: when a logged set beats `priorBest` (weight, or reps at the best weight), the row's check turns pine with a ★ and the header says "PR" — a comparison against two server-supplied numbers, confirmed by the server's records at completion.
- **Deload offer**: a hairline panel on TODAY and on the plan's day header — *"Take a lighter week — reps have dropped three sessions running on your squat and bench"* — **Accept** / **Not now**. Accepted: the plan header reads "DELOAD WEEK · ends Sun", sessions seed with the lighter targets, the set rows show the original in ink35 beside the deload number. Never applied silently (§18 decision).
- **Volume screen** `/plan/volume` (from the plan's ⋯ menu and the TODAY panel): ten rows (muscles the programme owns first) × four ISO-week columns; each cell the hard-set count in the metric face on a hairline grid; status as a thin left rule — oxide below MV, amber below MEV, ink in MEV–MAV, amber above MAV, oxide at MRV — with the landmark numbers under each muscle; a "Not trained in n days" line per neglected muscle. No heatmap colour fills (§6.2: colour carries meaning only, three colours).
- **History detail** unchanged; the plan's Phase 4 editor unchanged.
- Offline: recommendations, prior bests and the deload state ride on the cached `today` response, so a session seeded with no signal still opens with them.

---

## 7. Tests

| Layer | Tests |
|---|---|
| core | volume: hand-calculated week (primary 1 / secondary 0.5, warm-up and drop excluded, ISO week split at Monday in the local calendar), every landmark boundary (MV−1, MV, MEV, MAV-low, MAV-high, MRV), tonnage, four-week report, neglect at exactly 6 days vs 5, owned-only · deload: the three-condition fatigue rule on 2 lead lifts fires, on 1 does not; MRV at week 6 fires, at week 5 does not; snooze suppresses; targets ×0.6/×0.9/+2 with rounding and floors; reset → 1 · progression: the six existing branches untouched + bodyweight add-reps · substitution: equipment lost, limitation added, rejected twice, no alternative · prefill with a recommendation (weight and reps floor) · determinism (same input, same output, snapshot) |
| contracts | recommendation/volume/deload/progression shapes; every `reason` non-empty |
| api (real PG) | `/today` carries a recommendation per exercise with a reason after one completed session (baseline before it); increase-load appears only when every working set hit `repMax` at ≤ target RIR (from real logged sessions); three declining sessions at the same load with RIR drift → `deload` on that lift, not an increase (§31 manual, automated); deload offer after fatigue on two lead lifts; MRV + week 6 offer; accept → seeds ×0.6/×0.9/+2, complete after 7 days → `mesocycle_week` 1; decline → no offer for 7 days; `/volume` equals a hand calculation from the sets logged in the test and the cache row matches; rebuild script reproduces the cache; neglect at 6 days; abandoned/deleted/drop sets never count; substitution on a lost equipment item; migration 0007 up/down |
| flutter | rows open with the recommended load and reason; revert to last time; PR moment on a beating set (and not on a tie); deload panel accept/decline; deload-week rows show original beside lighter; volume screen renders statuses and neglect; offline: cached today carries recommendations; conformance for every new shape |

Gate: all green (CI authoritative), lint/analyze/format/typecheck, migration both ways, Docker boot, APK.

## 8. Acceptance (spec §31 Phase 6 + owner)
- Target loads appear on `GET /training/today` with reasons — every exercise with history.
- Volume matches a hand calculation — the screen's numbers equal the sets you logged, weighted 1 / 0.5.
- Deload fires **only** on the three-condition rule (or MRV at week 6): log three declining sessions at the same load with RIR falling → a deload is *offered*, not a load increase; log two declining sessions → nothing.
- Manual: as above on a real phone; accept the deload → the next session opens lighter with the originals visible; decline → nothing changes and it does not nag for a week.

## 9. Implementation order (each green before the next)
1. Core: `volume.ts`, `deload.ts`, bodyweight branch, prefill-with-recommendation, (`substitution.ts`) + tests.
2. Migration 0007 (+down, tests), `db:rebuild-volume` script.
3. Contracts + `openapi.json`.
4. API: progression assembly in `/today` and session start; `/volume`; deload accept/decline; completion hooks; integration tests.
5. Flutter DTOs + conformance; set-row recommendation + revert; PR moment; deload panel; volume screen; offline path.
6. Full suites, Docker, migrate + rebuild local DB, APK.
7. Phase 6 report; ADR-007 (deload as an offer; volume cache; what "lead lift" means).

## 10. Risks and edge cases
- **Small histories**: one session → baseline everywhere; two → no fatigue possible (needs three). Reasons say so; nothing is invented.
- **Exercise changed mid-programme**: history follows the exercise id; a replaced lift starts at baseline by design (§12.6). A user who swaps barbell for dumbbell bench loses progression continuity — expected, stated in the reason.
- **Set-count edits (Phase 5)**: `clearedTopOfRange` requires `target.sets` working sets; after "+ Add set" the target is the *plan's* count — the recommendation reads the plan row, not the session's extra sets, so extras never block an increase.
- **Deload interplay**: a deload week's lighter loads must not read as a "decline" afterwards — sessions completed during `deload_started_at..+7d` are excluded from the fatigue comparison (they are history for volume, not for progression).
- **ISO-week edges**: a session completed Sunday 23:30 in Kolkata belongs to that week; the cache key uses the local date (as `mesocycle.ts` already does).
- **Two devices / merged sets**: volume counts merged sets; the cache is upserted on every completion, so a late merge is corrected by the next completion or the rebuild script.
- **Landmark table drift**: `VOLUME_LANDMARKS` is the single source (generator and volume engine share it); a test pins it to §12.3.
- **Unit ambiguity**: `weightKg` null vs 0 — null means "no load recorded", 0 means "bodyweight, deliberately"; the API stores what the client sends and the bodyweight branch treats both the same.

---

## 11. Explicit scope boundaries (restated)
- Deterministic only. No LLM call is introduced; the Gemini provider, `AI_ENABLED`, `AiDraft` stay unused until Phase 14.
- Nothing modifies `planned_sets` or `planned_exercises` on the user's behalf. Recommendations and deload targets are per-session seeds; the plan is edited only by the user.
- No recovery inputs (sleep/soreness) — Phase 13; no TODAY ranking — Phase 11; no PROGRESS screen — Phase 12.
- Phase 5 tables are read, never restructured; the only Phase 5 write is the volume cache upsert on completion.

---

## 12. DECISIONS NEEDED (your call before coding)

12.1 **Recommendation pre-fills the row** — recommended: the set row opens with the recommended load (and `repMin` after an `increase-load`, `repMax` otherwise), reason shown, one tap reverts to last time. Alternative: keep last time's weight in the row and show the recommendation as a note only.
12.2 **What starts a programme-level deload week** — recommended: fatigue (rule 2) on ≥ 2 lead (compound) lifts within 7 days, **or** `mesocycle_week ≥ 6` with any muscle at/above MRV (§12.5 verbatim). Alternative: any single lift's fatigue.
12.3 **Deload is an offer, never automatic** — recommended (§18's decision applied to training): Accept starts the week, Not now snoozes 7 days; per-lift `deload` recommendations still show on that lift regardless. Alternative: apply automatically at week ≥ 6 + MRV only.
12.4 **Deload week mechanics** — recommended: 7 days from acceptance; targets ×0.6 sets (round, ≥ 1), ×0.9 load (to 0.5 kg), +2 RIR (cap 5) as session seeds; `mesocycle_week` → 1 when the week ends; deload sessions excluded from the fatigue comparison.
12.5 **Bodyweight lifts** — recommended: a reps-only `add-reps` branch (never baseline forever); when reps exceed `repMax` the reason says "add a set or load it". Alternative: leave bodyweight lifts at baseline (known issue).
12.6 **Exercise substitution (§12.6) in Phase 6** — recommended: yes for the deterministic triggers (equipment lost, limitation added, rejected twice via a small `exercise_rejections` table) with an honest "no alternative" when the library has none; the UI is a one-line "Swap to X — why" with Accept. Alternative: defer to Phase 12/13.
12.7 **Neglect scope** — recommended: muscles the active programme owns (union of planned exercises' primary muscles), 6 days; a user with no programme gets none. Alternative: all ten muscles for everyone.
12.8 **Volume window on screen** — recommended: current ISO week + 3 previous, statuses by §12.3, no colour fills (three semantic colours only). Alternative: 8 weeks.
