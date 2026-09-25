# ADR-018 — Progress & Recovery: read-time progress over the user's own records, calorie-adjust as an advisory TODAY action, device-only recovery context

**Status** ACCEPTED — 2026-09-25, with Phase 12's acceptance (S24 manual checks passed). The screen's visual polish is deferred to a separate pass after Phase 13.
**Date** 2026-09-25
**Phase** 12
**Affects**
- MASTER-SPEC: §17 (Progress), §13.2 (trend and the adjustment policy), §9.2 (`body_measurements`; `progress_photos` deferred), §9.4 (`rebuild-derived`), §10.1 (`/progress/*`), §16.1 (`calorie-adjust` delivered), §31 Phase 12, §38 (on acceptance only).
- ADR-017: TODAY gains `calorie-adjust` (engine `today-2`); the Phase 11 behaviour is otherwise unchanged.
- ADR-008 / ADR-009: Health Connect data stays on the phone; Progress shows it as device context only.

---

## Context

MASTER-SPEC Phase 12 is Progress: the weight trend computed on read, measurements, PR history, adherence, signed-URL photos and `rebuild-derived`. The spec places Recovery (logging, the readiness score, `recovery_logs`, `/recovery/*`) in **Phase 13**. The Phase 11 amendment moved `calorie-adjust` (TODAY band 55) into Phase 12. The Market tab was a "coming soon" placeholder with no data behind it.

What already existed and is reused:
- `nutrition/trend.ts`: EWMA (α = 0.1), `summariseTrend` with its 10-day gate, `recommendCalorieAdjustment` (≤ once per 7 days, beyond tolerance only, ±150 kcal).
- Epley (`training/progression.ts`), PR detection (`training/records.ts`), the volume engine and `/training/volume`.
- `body_metrics`, `daily_nutrition`, `nutrition_targets`, `exercise_prs`, `muscle_volume_weekly`.

## Decisions (owner D1–D15)

1. **Recovery in Phase 12 is information only (D1).** The Progress & Recovery page shows the phone's Health Connect sleep and resting heart rate — the existing Home context, reused — with the existing under-six-hours advisory. No score, no logging, no server data. Phase 13 builds recovery on the same page.
2. **The tab and route (D2).** The fifth tab is **Progress** at `/progress`; the screen header reads **Progress & Recovery**. The Market tab, `/market` and the placeholder screen are removed (no data, API or deep link depended on them).
3. **Photos are deferred (D3).** They need a private Cloud Storage bucket, signed URLs and deletion duties (Phase 17) — a GCP change outside this phase's constraints. `progress_photos` and `POST /progress/photo` are not built; §17 calls photos optional.
4. **`calorie-adjust` is delivered (D4).**
   - Engine `today-2`; the kind sits at band **55** (between rest-day and celebrate-pr in the tie-break order), reason code `calorie-target-off-trend` with `currentKcal`, `newKcal`, `deltaKcal`, `weeklyChangeKg`.
   - The fact comes from core `calorieAdjustmentFrom`, which reuses `summariseTrend` and `recommendCalorieAdjustment` unchanged; the 7-day clock counts from the last target row this policy created.
   - **Advisory:** accepting the action (its `accepted` event) creates a **new** `nutrition_targets` row (reason `calorie-adjust`, effective the day it is accepted) by the §13.1 rules (`adjustTargets`: protein unchanged, the fat floor, carbs the remainder, fibre 14 g/1000 kcal). The current row is never changed. Dismissing changes nothing. If the target moved since the action was made, accepting is refused (409 `target-changed`) and nothing is written.
   - `completed` is proven by that row (evidence `target-adjusted`).
5. **Entering weight (D5).** `POST /progress/weight` upserts one reading per local day, up to 30 days back, never ahead, 201/200. It **never recalculates the targets** (they follow the trend through calorie-adjust). Personal details keeps its accepted Phase 6.6 behaviour. A Progress weight for today is also TODAY's `log-weight` evidence.
6. **Adherence (D6):** over days with at least one log, against the target in effect that day — protein met when the day's high end ≥ target; calories on target when the day's kcal range overlaps target ± 10 %. Returned as "n of m logged days" and a %.
7. **Consistency (D7):** completed sessions per ISO week against the active programme's planned days, the partial first and current weeks planning only their days inside the window. Not capped; no streaks.
8. **Windows (D8):** 30 days (default) and 90 days.
9. **Offline (D9):** the last summary per window is cached (`cached_json`) and shown labelled with its time; readings are online only and fail clearly. No new sync queue; the workout and nutrition engines are unchanged.
10. **Health Connect weight (D10)** is never merged into the trend; it may appear as a small "Health Connect: x kg" line.
11. **Measurements (D11):** waist, chest, arm, thigh, hip; centimetres (10–250); one per user, day and site (upsert).
12. **The trend gate (D12):** the existing `summariseTrend` is kept as it is (a 10-day calendar span).
13. **Trend everywhere (D13):** Profile shows the trend weight with the latest raw reading small; Home → Body labels its Health Connect weight as a raw device reading.
14. **The Phase 6.6 sync-test flake (D14)** is recorded, not fixed (unrelated accepted code).
15. **`rebuild-derived` (D15)** lives at `apps/api/src/db/rebuild-derived.ts` (`pnpm --filter @fitos/api db:rebuild-derived`, and a CI step on the seeded image), because `scripts/` is not a workspace package.

## What is computed where

- **Server, on read** (`packages/core/src/progress/summary.ts`): the trend points (the EWMA over the whole history, cut to the window), the weekly rate (null before the gate), window changes only across ≥ 7 days, the latest measurement per site and its ≥ 7-day change, adherence, consistency, the best Epley 1RM per lift in the window; PRs in the window from `exercise_prs`. Nothing derived is stored.
- **Phone:** draws the server's numbers; the one chart (trend bold, raw readings hairlines, ink only); the heatmap from `/training/volume` with the Volume screen's own words; the Health Connect context.

## Consequences

- **§17's anti-obsession rules are data rules and UI rules:** the contract has no day-over-day field and rejects a change shorter than 7 days; the page has no red and no streaks.
- **Home loses nothing.** Its Body block is only relabelled.
- **`rebuild-derived`** proves the three §9.4 caches are reproducible: `daily_nutrition`, every `muscle_volume_weekly` week (the Phase 6 script covered four), and `exercise_prs` with `set_logs.is_pr`, replayed in completion order through the same `detectPRs`. A set added to a session after it was completed is not re-scored by the live path, so a rebuild could differ there; the replay follows the completed-session order.
- **The engine version changed** (`today-2`), so every TODAY content hash changes once: existing actions become new rows on the next GET (rows are immutable; nothing is lost).
