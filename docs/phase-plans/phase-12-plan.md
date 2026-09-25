# Phase 12 — Progress & Recovery: implementation plan

**Status** Approved by the owner (audit + decisions D1–D15, 2026-09-25) and implemented in one pass on `phase-12` from `2b7ece9`. Acceptance pending the S24 manual checks.
**Decision record** [ADR-018](../decisions/ADR-018-progress.md).

## 1. Scope

**In (MASTER-SPEC §31 Phase 12, §17, §13.2, §9.4, and the Phase 11 amendment):**
- trend on read; weight entry; measurements; PR history and estimated 1RM; adherence; training consistency; the volume heatmap (reusing `/training/volume`);
- `rebuild-derived` for the §9.4 caches;
- `calorie-adjust` in TODAY (band 55, engine `today-2`);
- the Market tab replaced by **Progress** (`/progress`, header **Progress & Recovery**), with device-only Health Connect recovery context.

**Out:**
- photos (deferred, D3 — needs the private bucket and signed URLs);
- Phase 13 recovery (logging, readiness, `recovery_logs`, `/recovery/*`, TODAY recovery fields, `low-readiness`);
- AI/Gemini; Firebase Analytics; notifications; export/delete; badges, streaks, a social feed; medical diagnosis; WHOOP/Oura; a limitations editor; a chart library; any new sync queue.

## 2. Build (one pass, dependency order)

1. **Core** `packages/core/src/progress/summary.ts` (window maths over the existing trend, Epley and ISO weeks); `recommend/engine.ts` `today-2` with `calorie-adjust`; `recommend/model.ts` `calorieAdjustmentFrom`; `nutrition/targets.ts` `adjustTargets`; `recommend/events.ts` evidence `target-adjusted`.
2. **Database** migration 0015: `measurement_site`, `body_measurements` (unique user/day/site, checks, cascade, soft delete), `exercise_prs (user_id, achieved_at)`, `calorie-adjust` in `today_action_kind` (placed at its band); a hand-written down that rebuilds the enum. `rebuild-derived.ts` + package script + CI step.
3. **Contracts** `progress.ts` (summary, weight and measurement writes); TODAY kind and reason; OpenAPI.
4. **API** `modules/progress` (repository, service, routes); TODAY: the assembler adds the adjustment fact; accepting a calorie-adjust action writes the new target row in the event's transaction; completion evidence.
5. **Mobile** `features/progress` (DTOs, API, repository with cache, providers, screen, trend chart, entry sheets); the shell and router; TODAY `calorieAdjust` (words, destination, evidence); Profile trend line; Home Body label.
6. **Docs** this plan, ADR-018, minimal MASTER-SPEC amendments, the phase report.

## 3. API

| Method | Path | Notes |
|---|---|---|
| GET | `/v1/progress/summary?window=30d\|90d` | Default 30d. 401 without a session; 422 for any other window. |
| POST | `/v1/progress/weight` | `{weightKg 30–300, date?}`; 201 new / 200 replaced; 422 future, > 30 days back, not a date. |
| POST | `/v1/progress/measurement` | `{site, valueCm 10–250, date?}`; the same date rules. |

All are scoped to the signed-in user, in the stored timezone, excluding soft-deleted rows. p95 < 300 ms.

## 4. Tests (mapped to the requirements)

- **Core:** EWMA against a hand-computed series; 9 vs 10 days; sparse history; the ≥ 7-day change; whole-history smoothing; measurements; adherence (ranges, no logs, target change, window edges); consistency (partial weeks, ISO week and year boundaries, no programme); Epley and best lifts; calorie-adjust (reuse, gate, 7-day limit, band, words, evidence); `adjustTargets`; Phase 11 vocabulary and persona snapshots updated for the new kind and version only.
- **Database:** 0015 up/down with data, constraints, uniqueness, cascade, soft deletion, the enum order; the rebuild reproduces all three caches exactly, restores a corrupted state and is idempotent.
- **API:** 401; isolation; empty history; 30d, 90d and a year; timezone either side of the date line; upsert and correction; validation, future dates and the 30-day boundary; measurement upsert; the core-equal trend; adherence; training; TODAY log-weight evidence from a Progress weight; calorie-adjust accept/complete/dismiss/stale; p95.
- **Flutter:** shell (Market removed, Progress tab); the page sections; the trend headline and the raw reading small; the 10-day gate text; no day-over-day text or red; empty, loading, unavailable; the offline cached summary and the offline write failure (nothing queued); weight and measurement entry; PRs; the heatmap equals the Volume screen's words; adherence and consistency; the recovery context; trend geometry; 360×640, S24, 200 % text; conformance; calorie-adjust card, words, accept and completion.
- **Regression:** every existing core, contracts, API and Flutter suite.

## 5. Acceptance criteria

- Every item above implemented and green; the trend is the headline wherever weight appears (Progress, Profile; Home's device reading labelled raw); no day-over-day figure anywhere; no weekly rate before 10 days.
- `rebuild-derived` reproduces the caches exactly; cross-user access is impossible; p95 < 300 ms; the full regression suite green; Market fully replaced; offline as D9.
- **S24 manual checks:**
  1. Progress replaces Market; back navigation works.
  2. 30 days of noisy weights produce a smooth trend.
  3. Raw points are visually de-emphasised.
  4. The fluctuation explanation appears.
  5. The weekly rate stays hidden before the 10-day gate.
  6. Weight save and correction upsert correctly.
  7. TODAY log-weight completion still works.
  8. Measurements save; ≥ 7-day changes display correctly.
  9. PR history and estimated 1RM appear.
  10. The heatmap matches Volume.
  11. Adherence and consistency match hand calculations.
  12. Health Connect sleep / resting heart rate are device-only, with no readiness score.
  13. The offline cached summary is labelled; writes fail clearly.
  14. No forbidden "since yesterday" UI remains.
  15. TODAY, MESS, food logging and workout sync regressions pass.
  16. Calorie-adjust: accepting creates the new target; dismissing changes nothing.
  17. Photos: not applicable (deferred, D3).
