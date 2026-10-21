## PHASE 13 — RECOVERY — ACCEPTED AND FROZEN

**Date** 2026-09-25 · **Branch** `phase-13` from `952ea73` (the accepted, frozen Phase 12 closeout) · **not merged**

**Status:** **ACCEPTED and FROZEN 2026-10-22** — the owner ran the S24 checks on the combined build (Phases 13–15) and reported them passed.
- §38 Phase 13 ticked; ADR-019 ACCEPTED. Frozen at `phase-13` @ `6a93ed4` (the S24 fixes); later work builds on top.
- Still open: the §18 readiness cap question (BACKLOG O2). Not merged into `main` (needs a separate approval).

**Commits**
- `2430b25` — core: `recovery/readiness.ts`, the deload `readiness` trigger, TODAY `today-3` with `low-readiness`, the persona, the Phase 13 plan
- `a62c7b8` — core fix: the rest day carries readiness without a programme too (found by the API suite)
- `b65290b` — contracts, migration 0016, the Recovery API, the escalation wired into the deload state, TODAY assembly, OpenAPI
- `0408da7` — mobile: the check-in card and readiness display, TODAY `lowReadiness`, the deload trigger
- plus the documentation commit: ADR-019, MASTER-SPEC amendments, this report
- a test commit: the Phase 11 API test's rest-day reason pin gains `readiness: null` (§16.2); no app change

**Implementation head:** `0408da7`.

**Decision record:** [plan](../phase-plans/phase-13-plan.md), [ADR-019](../decisions/ADR-019-recovery.md) (D1–D13).

### 1. BASELINE

- `phase-12` was closed out as accepted and frozen at `952ea73`: S24 passed (owner); ADR-018 ACCEPTED; §38 Phase 12 ticked with photos deferred; the Progress & Recovery visual debt recorded.
- `phase-13` was branched from it.
- `main` = `origin/main` = `2b7ece9`, untouched.
- **At the start:** migrations through 0015; Drift schema v3; core 842, contracts 75, API 438, Flutter 607.

### 2. WHAT MASTER-SPEC REQUIRES (and where it is)

| Requirement (§18, §31, §9.2, §10.1, §16, §26.2) | Built |
|---|---|
| `recovery_logs` (UNIQUE user/day) | migration 0016 |
| `GET /recovery/today`, `POST /recovery/log` (upsert on date) | `modules/recovery` |
| Readiness 0–100, deterministic, 5 capped penalties | `core/recovery/readiness.ts` |
| Bands ≥ 75 / 55–74 / 35–54 / < 35 and their effects | display advice; TODAY `low-readiness`; deload trigger |
| 3 days < 35 → deload check | deload trigger `readiness` (an offer) |
| Never silently changes the plan | the API test (§5 below) |
| `UserModel` and TODAY extended | `RecoveryState`, `accessories`, `today-3` |
| Rest day carries recovery status (§16.2) | `rest-day.values.readiness` |
| `low-readiness` persona (§26.2) | 12th persona, snapshotted |
| Recovery card ≤ 10 s, readiness display | Progress & Recovery → Recovery |
| Readiness backend-only (§30) | no Dart scoring anywhere |
| `/recovery/health-sync` | V2 — not built (404) |

### 3. IMPLEMENTATION

- **Core:**
  - `readinessOn`: sleep debt vs 7.5 h over 7 days; soreness; energy; the Phase 6 rep-decline and RIR-drift signals, with progression helpers exported and no rule changed; the Phase 12 adherence, reused.
  - `lowReadinessRun`: ending today, or yesterday before today's check-in.
  - `shouldOfferDeload` gains a third trigger, checked after fatigue and MRV.
  - TODAY `today-3`: `low-readiness` at 89 (informational); rest-day readiness; `trainingFromPlan` lists accessories.
- **Database (0016):**
  - `recovery_source` (`manual`); `recovery_logs` with range checks, an at-least-one-value check, unique per user and day, and a cascade;
  - `low-readiness` in `today_action_kind` at its band;
  - a hand-written down that rebuilds the enum.
- **API:**
  - `RecoveryRepository` (upsert with `xmax = 0` for created vs replaced, one statement).
  - `ReadinessAssembler` (check-ins, programme lifts with deload weeks excluded, and food read in parallel).
  - `RecoveryService` and routes.
  - `WorkoutService` takes the readiness source, so `/training/today`, `/training/volume`, deload accept, TODAY and the AI tools all read the same deload state.
  - TODAY assembles `recovery` and `compound` facts.
- **Mobile:**
  - `features/recovery` (DTOs, Dio API, repository with `cached_json`, providers, panel), placed in the Recovery section above the Phase 12 Health Connect context.
  - TODAY `lowReadiness`: eyebrow "TRAIN · RECOVERY"; the Training destination; never completed.
  - The deload `readiness` trigger, on the Training panel and in the TODAY facts.
  - The Phase 12 Health Connect note now reads "not part of readiness".

### 4. SYNC AND OFFLINE

- The check-in is **online only** and fails with: "You're offline. Check-ins are saved online only — nothing was stored."
- The last `/recovery/today` is cached and shown labelled: "Offline — showing your check-in from HH:MM". While cached, the check-in cannot be changed.
- No new queue. The workout SyncEngine, the NutritionSyncEngine, the TODAY event queue and the Drift schema have **no diff** against `952ea73`.

### 5. SECURITY AND THE PLAN

- Every query is scoped to the signed-in user.
- 401 without a session; 422 for an empty check-in, out-of-range values, the future, more than 7 days back, or not a date.
- Isolation is tested. Health Connect data is never sent: `source` is always `manual`, and the hint is never pre-filled.
- **"Low readiness never silently mutates the plan"** (§31) is tested at the API:
  - The planned sets, the programme's deload columns and `/training/today`'s exercises are **identical** before three poor check-ins, after them, after the `low-readiness` accept and with the deload offered.
  - Only `POST /training/deload/accept` changes anything.
  - Low readiness is informational: `completed` → 422 `not-completable`.

### 6. PERFORMANCE

- `GET /v1/recovery/today`:
  - Full suite: p50 20–29 ms, p95 32–36 ms. Isolated runs: p95 ≈ 94 ms.
  - 40 requests with two weeks of check-ins, training and food; limit 300 ms.
  - It was 250 ms before its reads were parallelised.
- `GET /v1/today`, now also assembling readiness: p95 92–100 ms (Phase 11/12: 88–234 ms).
- `GET /v1/progress/summary`: p95 16–27 ms.

### 7. TESTS (local, all passing)

| Suite | Result |
|---|---|
| Core | **874** (+32: penalties and caps, windows, the Phase 6 signals, adherence reuse, band boundaries 75/74/55/54/35/34, only-available-inputs, the run, the deload trigger order, TODAY `low-readiness`, rest-day readiness, accessories, the persona) |
| Contracts | **79** (+4) |
| API | **455** (31 files; +17: recovery **16**, migrations **26** with 0016 up/down with data; the Phase 11 rest-day pin updated for `readiness: null`) |
| Flutter | **627** (+20: panel, display, edit, offline, cache, Health Connect hint, layout at 200 %, TODAY words and facts, the deload panel, conformance, the Home destination) |

- **Static checks:** typecheck, ESLint (api, contracts), API build, `dart analyze --fatal-infos`, custom_lint and `dart format` are clean.
- **Pinned Phase 11/12 tests** (vocabulary, bands, version, persona list) were updated deliberately for `low-readiness` and `today-3` only. The snapshot diff is the new fields (`recovery`, `accessories`, `readiness: null`), the version and the hashes.
- **Defects found and fixed during the pass (each has a regression test):**
  - The rest-day words dropped readiness when there was no programme.
  - The Health Connect hint printed "40.0 min".
  - A readiness component row overflowed at 200 % text.

### 8. FLAGGED FOR THE OWNER — a consequence of §18's caps

The check-in alone can add at most 25 + 20 + 20 = **65** penalty points (sleep, soreness, energy), so its worst possible result is **35**. That is the "reduce" band, because §18 puts 35 in 35–54.

To reach "rest" (< 35), and so the three-day escalation, a training signal (performance drop) or a nutrition signal (adherence gap) must add at least 1 point.

Implemented exactly as §18 is written; nothing was changed to work around it. If poor sleep, soreness and energy alone should be able to escalate, that needs an owner decision (e.g. 35 counting as rest, or different caps).

### BUILDS FOR THE S24

- **LAN API:** `docker compose up --build -d api` rebuilt from `phase-13`; migration 0016 applied to the dev database (17 migrations, `recovery_logs` present).
  - At `http://172.16.205.231:8080`: `/health` returns 200; `GET /v1/recovery/today` and `POST /v1/recovery/log` return 401 without a session.
- **APK:** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, built with `.\tool\alpha.ps1 -ApiHostOverride 172.16.205.231` from `0408da7`.
  - The host was verified inside the APK and in `network_security_config.xml`.
  - On another network, rebuild with the current address.
- **Install:** `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. No device was attached to this PC.

### 9. S24 MANUAL ACCEPTANCE — PENDING

On the Phase 13 APK and the LAN API (migration 0016 applied):

| # | Check |
|---|---|
| 1 | Progress & Recovery → Recovery: with nothing logged today the check-in card shows; Save is disabled until one answer; the card is done in about 10 s |
| 2 | Save → the readiness score, band and advice, each component (with "Not answered" / "Not enough recent training" / "No food logged this week" where true) and the summary line |
| 3 | "Change today's check-in" opens with the saved answers; changing one replaces the day (the score updates) |
| 4 | A good check-in (8 h, soreness 1, energy 5) shows Ready; a moderate one Advisory; a poor one 35 (Go lighter) |
| 5 | Answer only one question → readiness from that alone; the rest say not answered / not available |
| 6 | A training day with readiness 35–54 → Home TODAY "Readiness N: one fewer set on accessories" naming today's accessories; tap → Training; the session's sets are unchanged |
| 7 | Readiness < 35 (needs a training or food signal — §8) → "consider resting"; "Not today" hides it for the day |
| 8 | Three days running under 35 → Training shows "DELOAD OFFERED · LOW READINESS THREE DAYS RUNNING"; Home shows the deload card; Recovery says a lighter week is offered; nothing changes until Accept; Decline hides it for 7 days |
| 9 | Accept the readiness deload → the lighter week starts (Phase 6 behaviour) |
| 10 | Health Connect connected: the sleep hint shows "Health Connect: x h y min last night — on this phone, not sent"; the sleep field stays "—" until tapped |
| 11 | Airplane mode: the last check-in shows labelled offline with its time; Save fails with the offline message; nothing appears after reconnecting unless saved again |
| 12 | Reconnect → pull to refresh → live again; the check-in can be changed |
| 13 | A rest day: the TODAY rest-day card says "Readiness today: N." |
| 14 | Sign out and in as another user → no check-in or readiness from the first user |
| 15 | Regression: TODAY (Phase 11), calorie-adjust and weight (Phase 12), MESS, food logging and workout logging/sync behave as before |

**Seeding for items 7–8** in one sitting: the dev database allows check-ins up to 7 days back. Days before today can be added for the test account (`<email>` is the account's), for example:

```sql
insert into recovery_logs (user_id, logged_on, sleep_hours, soreness, energy)
select id, current_date - d, 3, 5, 1 from users, generate_series(1, 2) d where email = '<email>'
on conflict (user_id, logged_on) do nothing;
-- and a missed-nutrition week so the score drops below 35 (§8):
insert into daily_nutrition (user_id, local_date, kcal_low, kcal_high, protein_low, protein_high, item_count)
select id, to_char(current_date - d, 'YYYY-MM-DD'), 300, 400, 5, 10, 1 from users, generate_series(1, 9) d where email = '<email>'
on conflict do nothing;
```

Today's poor check-in is then made on the phone. Remove the seeded rows afterwards if wanted.

### 9a. S24 RUN — FINDINGS SO FAR (owner, 2026-10-21)

- **Defect, fixed (`b0fb566`):** the check-in saved and changed correctly, but Home's Recovery blocks read only Health Connect, so a check-in's sleep still showed "No data yet".
  - They now fall back to the check-in's sleep ("From your check-in") and show the readiness tile.
  - Regression tests added.
- **Redesign, done at the owner's request (`d46f944`):** the Progress & Recovery page was "ugly and cluttered", so the parked Phase 12 polish was picked up.
  - **Layout:** sections in reading order with Records last and collapsed; metric tiles; a taller chart with axes; a panel instead of a squeezed line for one reading; measurements, strength, nutrition and consistency in their own blocks.
  - **Unchanged:** the §17 rules hold, and so does the app's design system (§6; no card soup).
  - **Still app-wide:** outlined buttons and chips elsewhere in the app keep Material's rounded default; this page squares its own.
- **Gates after both:** Flutter 632/632, analyze, custom_lint and format are clean.
  - The known Phase 6.6 sync-test flake still occurs on this branch; its fix is on `phase-13-audit-fixes`.
- **New APK:** built for the then-current LAN address; the remaining checklist items continue on it.

### 10. KNOWN ISSUES, DEFERRED, OUT OF SCOPE

- **Known:**
  - the §8 cap consequence (flagged);
  - the Phase 6.6 `automatic_sync_test` flake (pre-existing, recorded in Phase 11; it did not fail in these runs);
  - root `pnpm lint` still stops at `apps/admin` (no ESLint config since Phase 0).
- **Deferred:**
  - **Phase 12 Progress & Recovery UI requires a later visual redesign/polish pass** (after Phase 13 is accepted);
  - photos (ADR-018 D3);
  - `/recovery/health-sync` (V2).
- **Out of scope:** AI/Gemini (recovery is not in the AI context), notifications, streaks/badges, medical wording, WHOOP/Oura, HRV.

### 11. GIT

- `phase-13` is pushed (head: the documentation commit after `0408da7`); `main` = `origin/main` = `2b7ece9` with no Phase 13 commits; nothing merged.
- GitHub CI is not verified from this PC (no `gh`).
