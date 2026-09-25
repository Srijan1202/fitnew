## PHASE 12 — PROGRESS & RECOVERY — IMPLEMENTATION COMPLETE, S24 ACCEPTANCE PENDING

**Date** 2026-09-25 · **Branch** `phase-12` from `main` at `2b7ece9` (the accepted Phase 11) · **not merged** (merge only after acceptance and the owner's explicit approval)

**Status:** **implementation complete; NOT accepted, NOT frozen.**
- Every automated gate passes locally.
- The LAN API and the APK are built.
- The 17-item S24 manual acceptance has **not** been run: no device was attached to this PC.
- §38 Phase 12 is not ticked, and ADR-018 stays PROPOSED until the owner reports the S24 result.

**Commits**
- `7a8be3e` — core: `progress/summary.ts` (window maths on read), TODAY `today-2` with `calorie-adjust` at band 55, `calorieAdjustmentFrom`, `adjustTargets`, evidence `target-adjusted`; Phase 11 vocabulary tests and persona snapshots updated for the new kind and version only
- `0960067` — database, API and contracts: migration 0015 with a hand-written down; `rebuild-derived.ts` + script + CI step; `GET /v1/progress/summary`, `POST /v1/progress/weight`, `POST /v1/progress/measurement`; TODAY assembles and applies `calorie-adjust`; OpenAPI
- `c76d439` — mobile: the Progress tab replacing Market, the page, entry sheets, the offline cache, TODAY `calorieAdjust`, the Profile trend, the Home Body label; tests
- a test commit: two Profile trend-weight tests (a coverage gap found while writing this report; no app change)
- plus the documentation commit: plan, ADR-018, MASTER-SPEC amendments, this report

**Implementation head:** `c76d439` (the mobile commit). The commits after it add tests and documentation only; no app code changes.

**Decision record:** [plan](../phase-plans/phase-12-plan.md), [ADR-018](../decisions/ADR-018-progress.md) (owner D1–D15).

### WHAT WAS BUILT

**Core** (`packages/core/src/progress/summary.ts`, `recommend/`, `nutrition/targets.ts`)
- **Weight:** the existing EWMA (α 0.1) over the **whole** history, cut to the window.
  - The weekly rate comes from `summariseTrend` unchanged, so it is null before the 10-day gate.
  - The window change is given only across ≥ 7 days.
  - Nothing is stored.
- **Measurements:** the latest reading per site; its change against the earliest in the window, only across ≥ 7 days.
- **Adherence:** only days with at least one log, against the target in effect that day.
  - Protein is met when the day's high end ≥ target.
  - Calories are on target when the day's kcal range overlaps target ± 10 %.
  - Reported as n of m and a % (null when m = 0).
- **Consistency:** completed sessions per ISO week against the programme's planned days. The partial first and current weeks count only their days inside the window. Not capped; no streaks.
- **Best lifts:** the Epley maximum per lift in the window (ties → the earliest).
- **TODAY `today-2`:**
  - `calorie-adjust` at band 55, reason `calorie-target-off-trend` (`currentKcal`, `newKcal`, `deltaKcal`, `weeklyChangeKg`).
  - The fact comes from `calorieAdjustmentFrom`, which reuses `summariseTrend` and `recommendCalorieAdjustment` unchanged: a reliable trend only, at most once per 7 days, ±150 kcal.
  - Completable on the evidence `target-adjusted`.
- **`adjustTargets`** follows §13.1: protein unchanged, the fat floor, carbs the remainder, fibre 14 g/1000 kcal.

**Database** (migration **0015**)
- **`measurement_site`** enum; **`body_measurements`**:
  - unique `(user_id, measured_on, site)`;
  - date and 10–250 cm checks;
  - cascade from users; soft delete.
- **`exercise_prs (user_id, achieved_at)`** index.
- **`calorie-adjust`** added to `today_action_kind` at its band position (before `celebrate-pr`).
- **Hand-written down:** removes `calorie-adjust` recommendations and rebuilds the enum without the value. Tested up → down → up, with data.
- **`apps/api/src/db/rebuild-derived.ts`** (`pnpm --filter @fitos/api db:rebuild-derived`, plus a `ci-api` step after the seed):
  - rebuilds `daily_nutrition`, **every** `muscle_volume_weekly` week, and `exercise_prs` with `set_logs.is_pr`;
  - the PRs are replayed in `(completed_at, id)` order through the same `detectPRs`;
  - deterministic and idempotent.

**API** (`apps/api/src/modules/progress/`, TODAY)
| Method | Path | Behaviour |
|---|---|---|
| GET | `/v1/progress/summary?window=30d\|90d` | Default 30d; 401 without a session; 422 for any other window; the signed-in user only; stored timezone; soft-deleted rows excluded |
| POST | `/v1/progress/weight` | `{weightKg 30–300, date?}`; upsert on the local date; 201 new / 200 replaced; 422 for a future date, > 30 days back or not a date; **never recalculates the targets**; a weight for today is TODAY's `log-weight` evidence |
| POST | `/v1/progress/measurement` | `{site, valueCm 10–250, date?}`; the same date rules; upsert per site and day |

- **Personal details:** the accepted Phase 6.6 path is unchanged.
- **TODAY:**
  - The assembler adds the adjustment fact.
  - The `accepted` event of a `calorie-adjust` action inserts a **new** `nutrition_targets` row (reason `calorie-adjust`, effective the day it is accepted) in the event's transaction, after the event insert succeeds. The current row is never changed.
  - If the target changed since the action was generated, the event is refused: 409 `target-changed`, nothing written.
  - Dismissing changes nothing. `completed` requires that row.

**Mobile** (`apps/mobile/lib/features/progress/`, shell, TODAY, Profile, Home)
- **Shell:**
  - The fifth tab is **Progress** (`/progress`); the screen header is **Progress & Recovery**.
  - `/market` and `features/placeholders` were removed; nothing else referenced them.
- **One page**, for 30 d (default) or 90 d:
  1. **Weight:**
     - The trend weight is the headline.
     - One hand-drawn chart (`CustomPainter`, no chart library): the trend bold, raw readings as hairline ticks, ink only, no red.
     - The weekly rate appears only past the gate (before it: "After 10 days of readings (n so far)"). The window change is shown only across ≥ 7 days.
     - The fluctuation copy explains the daily swings.
     - A small "Health Connect: x kg · on this phone, not in the trend" line; that reading is never merged.
     - "Log weight" opens a sheet with a date up to 30 days back.
  2. **Measurements:** the latest reading per site with its ≥ 7-day change; "Add measurement".
  3. **Strength:** best estimated 1RM per lift and the PRs in the window.
  4. **Training volume:** the heatmap from `/training/volume` in the Volume screen's own words and colours.
  5. **Adherence:** protein and calories as "n of m logged days" and %.
  6. **Consistency:** sessions per ISO week against planned.
  7. **Recovery (information only):** the phone's Health Connect sleep and resting heart rate (Home's existing section, reused) and the existing under-six-hours advisory. No score, no logging, no server data.
- **Offline:**
  - The last summary per window is cached in `cached_json` and shown labelled "Offline — showing your progress from <date>, HH:MM. Logging needs a connection."
  - Weight and measurement saves are online only and fail with a clear message that nothing was stored or queued.
  - No new queue; the workout SyncEngine, the NutritionSyncEngine, the Drift schema and the TODAY queue have **no diff** against `2b7ece9`.
- **TODAY:** `calorieAdjust` (eyebrow "EAT · TARGET", primary "Use N kcal", facts for current target, suggested, trend, change).
  - Accepting drains the event queue at once, refreshes the profile and the food day, and opens EAT.
  - `completed` fires only when the profile's current target row is the day's `calorie-adjust` row.
- **Trend everywhere:**
  - Profile shows the trend weight with the latest raw reading small.
  - Home → Body labels its Health Connect weight "Weight · raw (device)".
  - The day-over-day audit found none. The remaining "Yesterday" strings are date labels, and "this week vs last" is the accepted Volume screen.

### TESTS (local, all passing)

| Suite | Result |
|---|---|
| Core | **842** (+19 Phase 12: EWMA against a hand-computed series, 9 vs 10 days, sparse history, the ≥ 7-day change, whole-history smoothing, measurements, adherence ranges and target changes, consistency across ISO week/year boundaries, Epley and best lifts, calorie-adjust reuse/gate/7-day limit/band/words/evidence, `adjustTargets`); persona snapshots updated for `adjustment: null` and the version only |
| Contracts | **75** (+4) |
| API | **438** (30 files) — Progress **13** (401, isolation, empty, 30d/90d/a year, both sides of the date line, upsert and correction, validation, the 30-day boundary, measurement upsert, trend equal to core, adherence, training, TODAY evidence, p95); TODAY +2 (calorie-adjust accept → new row → complete; dismiss; stale 409); migrations **25** (0015 up/down with data, constraints, uniqueness, cascade, the enum order); rebuild-derived (exact reproduction of all three caches, a corrupted state restored, idempotent) |
| Flutter | **607** (+26: Progress screen 18, conformance Progress 4, Profile trend 2, calorie-adjust completion 1, calorie-adjust on Home 1) |

- **Static checks:** TypeScript typecheck clean; ESLint (api, contracts) clean; API build; `dart analyze --fatal-infos` clean; custom_lint clean; `dart format` clean (248 files, 0 changed).
- **The Flutter suite covers:**
  - the Profile trend line;
  - the tab (Market gone, Progress present); every section;
  - the trend headline with the raw reading small; the gate text; no day-over-day text or red;
  - empty, loading and unavailable; the offline cached summary and the offline write failure (nothing queued);
  - weight and measurement entry; PRs; heatmap parity with the Volume screen; adherence; consistency; the recovery context; the trend geometry;
  - 360×640 and S24 (412×915) at 100 % and 200 % text;
  - conformance of every Progress shape against the OpenAPI;
  - the calorie-adjust card, words, accept and completion.
- **`ADMIN` lint:** `pnpm lint` at the root still stops at `apps/admin`. Its Phase 0 scaffold has no ESLint config, so `next lint` asks an interactive question. This predates Phase 12 and is unchanged; the api and contracts lints were run directly.

**Defects found and fixed during the pass (with regression tests):**
- The entry sheet's date row overflowed by 1.1 px at 360×640 with 200 % text; it now wraps (the layout test covers it).
- The Profile weight line was first attached to the height row; it is now its own row. Two Profile tests cover the trend headline above the smaller raw reading, and the message shown before there is a trend.

**Performance (final run):** `GET /v1/progress/summary` p50 17.8 ms, p95 34.5 ms (a year of weights, 90 days of food and training); `GET /v1/today` p50 101.7 ms, p95 121.9 ms. The limit is 300 ms; 40 requests each.

**GitHub CI:** **not independently verified** — no `gh` CLI on this PC.

### BUILDS FOR THE S24

- **LAN API:** `docker compose up --build -d api` rebuilt from `phase-12`; migration 0015 applied to the dev database (16 migrations, `body_measurements` present, `calorie-adjust` in the enum).
  - At `http://172.16.205.86:8080`: `/health` returns 200; `/v1/progress/summary`, `POST /v1/progress/weight` and `/v1/today` return 401 without a session.
- **APK:** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, built with `.\tool\alpha.ps1 -ApiHostOverride 172.16.205.86` from `c76d439`. The commits after it change only tests and docs, not `lib/`, so the APK is current.
  - The host was verified inside the APK (`kernel_blob.bin`) and in the generated `network_security_config.xml` (cleartext only for that address).
  - 172.16.205.86 is the PC's current Wi-Fi address. On another network, rebuild with the current address; the code is the same.
- **Install:** `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (or `.\tool\alpha.ps1 -ApiHostOverride <address> -Install`).
- **Existing data:** the dev database keeps its users. Engine `today-2` changes every TODAY content hash once, so the first GET after the upgrade stores new action rows; old rows are kept.

### S24 MANUAL ACCEPTANCE — PENDING (17 items)

| # | Check | Result |
|---|---|---|
| 1 | Progress replaces Market; back navigation works | pending |
| 2 | 30 days of noisy weights produce a smooth trend | pending |
| 3 | Raw points are visually de-emphasised | pending |
| 4 | The fluctuation explanation appears | pending |
| 5 | The weekly rate stays hidden before the 10-day gate | pending |
| 6 | Weight save and correction upsert correctly | pending |
| 7 | TODAY log-weight completion still works | pending |
| 8 | Measurements save; ≥ 7-day changes display correctly | pending |
| 9 | PR history and estimated 1RM appear | pending |
| 10 | The heatmap matches Volume | pending |
| 11 | Adherence and consistency match hand calculations | pending |
| 12 | Health Connect sleep / resting heart rate are device-only; no readiness score | pending |
| 13 | The offline cached summary is labelled; writes fail clearly | pending |
| 14 | No forbidden "since yesterday" UI remains | pending |
| 15 | TODAY, MESS, food logging and workout sync regressions pass | pending |
| 16 | Calorie-adjust: accepting creates the new target; dismissing changes nothing | pending |
| 17 | Photos | not applicable (deferred, D3) |

**Notes for the run:**
- **Item 2:** the entry sheet allows 30 days back. Add a reading for each past day, or use a user who already has a history.
- **Item 16:** needs a reliable trend (≥ 10 days) that is off pace for the goal, and no `calorie-adjust` target in the last 7 days. Otherwise the card correctly does not appear.

### ACCEPTED-PENDING DEVIATIONS AND NOTES

- **Photos deferred (D3):** they need a private Cloud Storage bucket and signed URLs, a GCP change outside this phase. MASTER-SPEC §9.2 and §31 are amended.
- **`rebuild-derived` location (D15):** `apps/api/src/db/`, not `scripts/`, which is not a workspace package. MASTER-SPEC §9.4 is amended.
- **Profile and Home changes (D13):** the only edits to earlier accepted screens are the Profile trend line and the Home Body label.
- **Phase 6.6 flake (D14):** `automatic_sync_test.dart` "orphan still parks" fails intermittently on the accepted baseline as well. It is recorded in the Phase 11 report and not fixed here; it did not fail in the Phase 12 runs.

### DEFERRED / OUT OF SCOPE

- Phase 13 recovery: logging, the readiness score, `recovery_logs`, `/recovery/*`, TODAY recovery fields, `low-readiness`.
- Photos; AI/Gemini; notifications; export/delete; badges, streaks, a social feed; medical diagnosis; WHOOP/Oura; a limitations editor; a chart library.
