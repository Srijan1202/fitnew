## PHASE 11 — TODAY — IMPLEMENTATION COMPLETE, S24 ACCEPTANCE PENDING

**Date** 2026-09-25 · **Branch** `phase-11` from `main` at `2067b89` (the accepted Phase 10, fast-forwarded per D19) · **not merged**

**Status:** every implementation gate the owner approved is complete, and every automated gate passes locally. **The S24 manual acceptance has NOT been performed:** no device was attached to this PC over adb during the implementation session, and the checks need a person with the phone. So Phase 11 is **not accepted**, the §38 Phase 11 boxes are **not ticked**, and `phase-11` is **not frozen**. The APK and the LAN API are built and ready for the checklist below.

**Commits**
- `a91456d` — plan and ADR-017 (owner D1–D19; P1–P7 for review; no code)
- `bf961d5` — core TODAY engine (ADR-017): server `UserModel`, ten kinds incl. `injured-limitation` at 91, structured reasons, deterministic English, subject keys, basis, targets, content hash (rank excluded) and input digest, dismissal before the cap of 4, the 22:00 cut-off; pure event rules; 11 persona snapshots
- `aa653d1` — core corrections Q1 (`trainingFromPlan` in model assembly) and Q2 (`completed` requires `accepted`)
- `2b8b7ce` — contracts: `GET /v1/today`, `POST /v1/today/actions/{id}/event`
- `d91170a` — migration 0013: `recommendations`, `recommendation_events`
- `fa89eeb` — API: assembler, persistence by content identity, event endpoint, tests, OpenAPI
- `96aa3de` — API corrections: exact `clientEventId` replay vs 409 collision, the deterministic event order, deload evidence
- `67e4846` — delayed deload evidence: migration 0014 `deload_activations` (trigger on `programs`)
- `1b6e402` — mobile: TODAY on Home, the separate event queue, tests
- plus the docs commit with this report and the ADR-017 amendments

**Decision record:** [plan](../phase-plans/phase-11-plan.md) (D1–D19), [ADR-017](../decisions/ADR-017-today-engine.md) with its "Amendments during implementation" (P1–P7, Q1, Q2, the event order, 0014, D8 as amended, the queue as built).

### WHAT WAS BUILT

**Core** (`packages/core/src/recommend/`)
- `engine.ts`: `ENGINE_VERSION = 'today-1'`. Ten server-owned kinds and bands: deload 95, injured-limitation 91, start-workout 90, eat-protein 88 dinner / 80 otherwise, eat-meal 75, progress-load 72, muscle-neglected 68, rest-day 60, celebrate-pr 50, log-weight 45.
  - eat-protein XOR eat-meal; deload suppresses rest-day.
  - Range-aware nutrition: eat-protein when the protein HIGH end < 75 % of target; eat-meal when kcal left at the low end > 250.
  - No eat action from 22:00 local (21:59 eligible).
  - Dismissed `(kind, subject)` pairs are removed before the cap of 4; ties break by the fixed kind order.
  - The content hash excludes rank (P5).
- `model.ts`: `trainingFromPlan(exercises)` — an exercise ruled out by an active limitation never enters `increaseLoad` (Q1).
- `events.ts`: the P2 transition matrix (`completed` needs `accepted`; informational kinds are never completable) and P3 timing (5-minute skew, the local day through 03:00 the next, 7-day delivery).
- **Not built (as decided):** calorie-adjust, low-readiness, hydrate, server add-steps, resume as a server kind, workout-done, volume-ceiling, AI/Gemini, Firebase Analytics.

**Database**
- **0013:**
  - `recommendations`: immutable rows; unique `(user_id, generated_for, kind, subject_key, content_hash)`; stored first rank; payload; engine version; input digest; checks.
  - `recommendation_events`: unique `(user_id, client_event_id)` and `(recommendation_id, event)`; `occurred_at` and `received_at` kept separately.
  - Cascades from users and recommendations only.
- **0014:** `deload_activations`, appended by a trigger on `programs` whenever `deload_started_at` is set; running weeks backfilled; hand-written down. Phase 6 code and lifecycle are unchanged.

**API**
- **`GET /v1/today`:**
  - Assembles the `UserModel` in the stored timezone from `/training/today` (through `trainingFromPlan`), active limitations × contraindications, Phase 8 ranges, targets, logged slots, weigh-ins, PRs and today's dismissals.
  - Runs the engine and persists by content identity: repeat GETs return the same ids, changed content is a new row and old rows are kept.
  - Returns the current rank.
- **`POST /v1/today/actions/{id}/event`**, in this order:
  1. replay (200) or collision (409);
  2. ownership (404);
  3. P3 timing (422);
  4. the transition (422; a repeat of a recorded event is 200);
  5. completion evidence (422 `no-evidence`);
  6. insert (201).

  Events for one recommendation are serialised by a row lock.

**Mobile** (`apps/mobile/lib/features/today/`, Home)
- **Home is the TODAY surface.** The server's actions are the cards, merged by band with the device-only rules (resume 92, sleep 65, steps 40, Health Connect 35), at most four.
  - Ties go to the server; the server's rank order is kept.
  - While a session is open on this phone, the server's start card gives way to resume.
- **P6:** the device copies of server rules, the done and volume cards and "More for you" are gone. The Today block still shows the workout state, and Training → Volume is unchanged.
- **Each server card** shows the eyebrow, the headline, the detail, the primary action and "Not today".
  - Tapping it opens the "why" sheet: headline, detail, facts from the reason's values, and the basis.
- **Destinations:**
  - start-workout → the session;
  - deload, injured-limitation, progress-load, muscle-neglected, rest-day → Training;
  - eat → MESS if configured (it opens on the same next meal), else Log food at the action's meal;
  - log-weight → Personal details;
  - celebrate-pr → the session summary (or History).
- **Events:**
  - `shown` once per action (ledger-deduplicated across rebuilds and restarts);
  - `opened` on a tap;
  - `accepted` on the primary action;
  - `dismissed` on "Not today" (the card goes at once and stays gone that day);
  - `completed` only once the server holds the evidence:
    - start-workout, progress-load, muscle-neglected: the day's completed session;
    - eat actions: the server's food day, by meal;
    - deload: the active deload;
    - log-weight: a weight saved in Personal details.

    Never on accept alone, never for informational kinds.
- **Offline (D8 as amended):**
  - The last valid plan is shown only for the same local date, labelled "Offline — showing your plan from HH:MM" (eyebrow "· OFFLINE"); responses queue.
  - An older cached plan is never shown. Without a cached plan: "Suggestions need a connection.", and the device suggestions remain.
- **Queue (D9):** Drift schema v3 has `today_event_queue` and `today_event_ledger`, drained by its own `TodayEventSync`.
  - FIFO; the same `clientEventId` and `occurredAt` on every retry.
  - 201/200 remove the entry; 409, 422 and 404 remove it at once (no endless retry).
  - Offline and 401 stop without spending an attempt, and drain again on reconnect, resume or the next sign-in.
  - Other failures back off 300 ms · 2ⁿ for five attempts, then the entry leaves.
  - The workout SyncEngine and the NutritionSyncEngine are unchanged (no diff).

### TESTS (local, all passing)

| Suite | Result |
|---|---|
| Core | **823** (13 files); demo walkthrough exits 0 |
| Contracts | **71** (11 files) |
| API | **421** (28 files) — includes TODAY **25** and migrations **24** (0013 and 0014 up/down with data) |
| Flutter | **581**, incl. Home TODAY 25, TODAY events and queue 19, engine and merge 13, conformance TODAY 5 |

- **Static checks:** TypeScript typecheck clean; ESLint (api, contracts) clean; `dart analyze --fatal-infos` clean; custom_lint clean; `dart format` clean.
- **Builds:** API build; LAN debug APK; release APK.
- **The API suite covers:**
  - access (401), vocabulary parity, first-day user, same ids on repeat GET, current vs stored rank, changed content = new row, dismissal, the cap of 4;
  - the Q1 conflict at the API;
  - timezone / local date, the 21:59/22:00 cut-off;
  - events: 201, replay 200, cross-user 404, the Q2 matrix, collisions 409, order, late replay, timing;
  - evidence for weight, eat, start-workout and deload, including the five delayed-deload cases;
  - p95.
- **The Flutter suite covers:**
  - first-day empty; rendering; max 4; current rank; reason rendering; server/device merge; dismissal;
  - navigation for every kind; opened, accepted, dismissed and completed; no completed before accepted; informational never completed;
  - offline cached and unavailable; the queue across restart; reconnect; duplicate replay; 409, 422, 401; the five attempts;
  - the v2→v3 upgrade keeping queued workout and food work;
  - 360×640 and S24 (412×915) at 100 % and 200 % text.

**Performance:** `GET /v1/today` p50 60–90 ms, p95 88–145 ms across runs (40 requests each) for a training user with history, targets and logs (limit 300 ms).

**GitHub CI:** **not independently verified** — the `gh` CLI is not installed on this PC, so the workflow results for `phase-11` could not be read here.

### BUILDS FOR THE S24

- **LAN API:** `docker compose up --build -d api` (development) rebuilt from `phase-11`; migrations 0013 and 0014 applied to the dev database (`pnpm --filter @fitos/api db:migrate`; 15 applied).
  - At `http://10.52.198.11:8080`, `/health` returns 200 and `/v1/today` returns 401 without a session.
- **APK:** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, built with `.\tool\alpha.ps1 -ApiHostOverride 10.52.198.11` from the mobile commit `1b6e402`.
  - The host was verified inside the APK (`kernel_blob.bin`, `network_security_config.xml`).
  - A release-like `app-release.apk` was also built.
  - 10.52.198.11 is the PC on the S24 hotspot. If the PC is on another network, rebuild with the current address.
- **Install:** `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (or `.\tool\alpha.ps1 -ApiHostOverride <address> -Install`).

### S24 MANUAL ACCEPTANCE — NOT YET RUN

Each check needs the owner on the S24. Record PASS/FAIL per line. If one fails, it gets fixed with a regression test, the APK is rebuilt and the check is rerun.

**Setup notes (dev database):**
- **Limitations** have no editor in the app yet. For check 2, add one on a body part that contraindicates a lift on today's session, e.g.:
  ```
  docker exec fitos-postgres psql -U fitos -d fitos -c "insert into user_limitations (user_id, body_part, note) select id, 'knee', 's24' from users where display_name = '<you>'"
  ```
  Remove it afterwards.
- **A deload offer** is computed from real logged training. It needs one of:
  - three sessions in a week with falling reps at the same load on two lead lifts;
  - week ≥ 6 with a muscle at MRV.

  Check 6 is "where practical". The automated API suite covers the offer → accept → activate → complete path and the delayed path.

**Checks:**

| # | Scenario | What to check | Result |
|---|---|---|---|
| 1 | Training day | TODAY loads; the start card shows; tap it (why sheet) → Start workout → the session opens → finish it; the server records shown, opened, accepted, completed | pending |
| 2 | Injured limitation | With the limitation set: a "TRAIN · LIMITATION" card names the lift and its swap; no progress-load card for that lift; open / See the swap → Training | pending |
| 3 | Progress load | After a session at the top of the range: the progress card names the lift and the next load; open → Training; complete a session containing it → completed | pending |
| 4 | Nutrition | Protein and meal cards follow the ranges; none from 22:00 local; the card opens MESS (or Log food); logging that meal → completed | pending |
| 5 | Rest day | The rest-day card (next session, targets); accept or Not today; never completed | pending |
| 6 | Deload | Where practical: the deload card; accept → activate the week in Training → completed; delayed path per the API suite | pending |
| 7 | PR | After a record today: the RECORD card; opens the summary; informational (never completed) | pending |
| 8 | Weight | The log-weight card → Personal details → save a weight → completed; the card leaves | pending |
| 9 | Event persistence | Close and reopen: no second `shown`, no duplicate events (check `recommendation_events`) | pending |
| 10 | Offline | Airplane mode: today's cached plan with the Offline line; tap Not today (queued); kill and reopen; network back → it uploads once | pending |
| 11 | Dismissal | Not today → the card goes and does not come back that local day, even after refresh | pending |
| 12 | Cap | Never more than four cards | pending |
| 13 | Server/device split | No done, volume or "More for you"; no forbidden kinds; sleep, steps and Health Connect cards still appear when their data says so | pending |

A useful query while checking:
```
docker exec fitos-postgres psql -U fitos -d fitos -c "select r.kind, e.event, e.occurred_at, e.received_at from recommendation_events e join recommendations r on r.id = e.recommendation_id order by e.received_at desc limit 20"
```

### DEVIATIONS AND OPEN POINTS

1. **`after-completed` is unreachable** since Q2. Core checks `accepted-and-dismissed` first, and a completed action is always accepted. It is still a 422; core is unchanged.
2. **"Materially different" `occurredAt` means any different instant** (the same instant in another offset is an exact replay).
3. **A reused client id on another user's (or an unknown) action is 409, not 404.** It is decided only from the caller's own stored event and reveals nothing about the id.
4. **Offline display follows the owner's final rules**, which amend the plan's D8 line "no server actions shown offline": the same-day cached plan is shown, labelled.
5. **The phone hides the server's start card while a session is open on it** (resume takes its place). This is the only display reconciliation; it adds no rule.
6. **`resume`** is kept as the existing device-only rule (plan D2); it is not a server kind.
7. **Limitations have no editor in the app** (a pre-existing gap, not Phase 11 scope); S24 check 2 needs the SQL fixture above.
8. **Tests changed for P6:** the Phase 6.5 Home engine tests for the rules the server now owns were replaced by a test that they no longer fire on the device, plus merge tests. The Phase 6.5 Home screen tests now drive the server start card. The Phase 8 drift-upgrade test checks the current schema version instead of the literal 2.
9. **The in-memory test database closes Drift streams synchronously** (a test-only factory), so widget tests that mount Home with the ledger stream do not leave a pending timer.
