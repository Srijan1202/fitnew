# Phase 13 — Recovery: implementation plan

**Status** Written from the audit on 2026-09-25 and implemented in one pass on `phase-13` from `952ea73` (the accepted, frozen Phase 12). Acceptance pending the S24 manual checks.
**Decision record** [ADR-019](../decisions/ADR-019-recovery.md).

## 1. What MASTER-SPEC asks for

- **§31 Phase 13:** recovery logging; a readiness score; the `UserModel` and TODAY engine extended with recovery fields.
  - DB `recovery_logs`; APIs `/recovery/today` and `/recovery/log`; UI: a recovery card (≤ 10 s to complete) and a readiness display.
  - Tests: readiness at each band boundary · **low readiness never silently mutates the plan** · missing recovery data degrades gracefully.
  - Acceptance: readiness computed only from available inputs · recommendations advisory and dismissible.
  - Manual: log poor recovery three days running; verify escalation to a deload check.
- **§18:**
  - The card: sleep hours, sleep quality, soreness, energy, stress (1–5), optional.
  - The deterministic readiness formula (100 minus five capped penalties) and its bands: ≥ 75 no change; 55–74 advisory note only; 35–54 suggest −1 set on accessories; < 35 suggest a rest day; if it persists 3 days, escalate to a deload check.
  - Recovery **never silently changes the plan**.
- **§9.2:** `recovery_logs` (`id`, `user_id`, `logged_on`, `sleep_hours`, `sleep_quality`, `soreness`, `energy`, `stress`, `source`), UNIQUE `(user_id, logged_on)`.
- **§10.1:** `GET /recovery/today`; `POST /recovery/log` (upsert on date); `/recovery/health-sync` is **V2** — not built.
- **§16.2:** a rest day carries recovery status (deferred from Phase 11).
- **§26.2:** the `low-readiness` persona (deferred from Phase 11).
- **§30:** the readiness score is backend-only; no Dart implementation.
- **§33:** recovery is not in the offline must-work list.
- **ADR-008/009/010:** Health Connect data stays on the phone.
- **ADR-018 D1:** Phase 13 builds recovery on the Progress & Recovery page.

## 2. Decisions taken from the spec (ADR-019)

| # | Decision |
|---|---|
| D1 | `recovery_logs` exactly per §9.2: `logged_on` as a local date string (the Phase 12 convention), `sleep_hours numeric(3,1)` 0–24, the four scales `smallint` 1–5, `source` enum with `manual` only (the V2 health sync adds its value). Every field is optional, but a row needs at least one (a check). Hard delete per §9.1 (not in the soft-delete list). Cascade from `users`. |
| D2 | `POST /v1/recovery/log`: upsert on the user's local date. `date` optional (default today), never in the future, at most 7 days back (readiness never looks further back). The row is **replaced** by what is sent. Returns 201 new / 200 replaced. `GET /v1/recovery/today`: today's log, today's readiness (or null) and the low-readiness run. |
| D3 | **Penalties** (all integers, computed on read, never stored): **sleep debt** = 10 × the mean nightly shortfall below 7.5 h over the check-ins of the last 7 local days, capped at 25; **soreness** = 5 × (soreness − 1), max 20; **energy** = 5 × (5 − energy), max 20; **performance drop** = 25 × (rep-decline points + RIR-drift points) / (2 × lifts assessed); **adherence gap** = 10 × (1 − (protein days met + calorie days on target) / (2 × judged days)). |
| D4 | **Performance drop** uses the Phase 6 signals, unchanged: a lift is assessed when trained in the 7 days up to the day with three comparable sessions (deload-week sessions excluded, as in Phase 6). **Rep decline** = working reps fell across the three at the same load; **RIR drift** = mean RIR fell at the same load. |
| D5 | **Adherence gap** is nutrition adherence (the §17 / Phase 12 definition: protein high end ≥ target; kcal range overlapping ±10 %) over logged days in the 7 local days **before** the day (today's eating is not finished). |
| D6 | **Only available inputs** (acceptance): readiness exists only for a day with a check-in. A component with no input contributes no penalty and is reported as not available. Sleep quality and stress are logged and shown but have no term in §18's formula, so they do not move the score. |
| D7 | **Bands:** ready ≥ 75 · advisory 55–74 · reduce 35–54 · rest < 35. The advice is deterministic English from core; there is no medical wording. |
| D8 | **Escalation:** readiness < 35 on 3 consecutive local days (ending today, or yesterday while today has no check-in yet) adds a third Phase 6 deload trigger, `readiness`. It feeds the existing **offer**: accept and decline, the 7-day snooze and the active week all keep their Phase 6 behaviour. The fatigue and MRV triggers are unchanged and checked first. |
| D9 | **TODAY:** engine `today-3`; kind `low-readiness` at band **89** (below start-workout 90, so the suggestion sits beside the session it is about); reason `readiness-low`. **Informational** (never completed; accepted or dismissed only). It fires on a training day that is not done: band reduce with accessories → "one fewer set on accessories" (subject `fewer-sets`); band rest → "consider resting" (subject `rest`). Nothing in the plan changes either way. The rest-day action carries the readiness (§16.2). |
| D10 | **Health Connect** is never sent: the card shows the phone's sleep reading as a hint and never pre-fills it; `source` is always `manual`. |
| D11 | **Mobile:** the check-in card and the readiness display go in the Recovery section of Progress & Recovery (ADR-018 D1). Writes are online only and fail clearly; the last `/recovery/today` is cached in `cached_json` and labelled. No new queue, and the workout/nutrition engines are unchanged. The rest of the Phase 12 page is untouched (its polish is deferred). |
| D12 | The 12th persona, `low-readiness`, is added and snapshotted. |
| D13 | Recovery data is not added to the AI context (Phase 14). |

## 3. Build (one pass, dependency order)

1. **Core:**
   - `recovery/readiness.ts` (penalties, score, band, advice, run length);
   - `training/progression.ts` exports its rep and RIR helpers (no rule change);
   - `training/deload.ts` gains the `readiness` trigger;
   - `recommend/engine.ts` `today-3` with `low-readiness`, a `RecoveryState` and training accessories;
   - `recommend/model.ts` `trainingFromPlan` accessories;
   - `recommend/events.ts` (informational);
   - personas and snapshots.
2. **Contracts:** `recovery.ts`; TODAY kind and reason; the deload trigger; OpenAPI.
3. **Database:** migration 0016 (`recovery_source`, `recovery_logs`, the `low-readiness` enum value) with a hand-written down; migration tests.
4. **API:**
   - `modules/recovery` (repository, readiness assembler, service, routes);
   - the deload state takes the low-readiness run, the same in `/training/today`, `/training/volume` and deload accept;
   - TODAY assembles the recovery state.
5. **Mobile:**
   - `features/recovery` (DTOs, API, repository with cache, providers, card, display) in the Progress Recovery section;
   - TODAY `lowReadiness`;
   - the deload `readiness` trigger in Training.
6. **Docs:** this plan, ADR-019, the MASTER-SPEC amendments, the report.

## 4. API

| Method | Path | Request | Response | Errors |
|---|---|---|---|---|
| GET | `/v1/recovery/today` | — | `{ date, log \| null, readiness \| null }` | 401 |
| POST | `/v1/recovery/log` | `{ date?, sleepHours?, sleepQuality?, soreness?, energy?, stress? }` (at least one value) | 201 / 200 `{ log }` | 401; 422 (no value, out of range, not a date, future, > 7 days back) |

Both are scoped to the signed-in user, in the stored timezone. p95 < 300 ms.

## 5. Tests (mapped)

- **Core:**
  - every penalty and its cap;
  - band boundaries 75/74, 55/54, 35/34;
  - missing inputs (each component alone, none);
  - sleep window edges;
  - the performance signals;
  - adherence reuse;
  - the escalation run (gaps, yesterday rule);
  - the deload `readiness` trigger and its order after fatigue/MRV, the snooze and the active week;
  - `low-readiness` (bands, training day only, accessories, dismissal, informational, words, rank 89);
  - rest-day readiness;
  - the persona;
  - determinism.
- **Database:** 0016 up/down with data; checks (range, at least one value), uniqueness, cascade, the enum order.
- **API:**
  - 401 and isolation;
  - upsert (201/200, replace);
  - validation and the date window;
  - the timezone either side of the date line;
  - readiness equal to core;
  - missing data;
  - three poor days → the deload offer (TODAY deload action with trigger `readiness`), accept → active, decline → snoozed;
  - **low readiness never mutates the plan** (`/training/today` identical before and after, and after accept/dismiss);
  - TODAY `low-readiness` accept/dismiss and no completion;
  - p95.
- **Flutter:**
  - the card (all five inputs, optional ones, save, edit);
  - the readiness display (band, advice, components, not-available inputs, the run);
  - offline cached and write failure;
  - the Health Connect hint (never sent);
  - TODAY `low-readiness` words, facts, navigation, no completion;
  - the deload `readiness` wording;
  - conformance;
  - 360×640 and S24 at 200 % text.
- **Regression:** every existing suite.

## 6. S24 manual checks

See the Phase 13 report.
