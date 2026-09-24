# Phase 11 — TODAY: implementation plan

**Status** PROPOSED — decisions D1–D19 approved by the owner (2026-09-24); the points in §15 need the owner's review before any code.
**Date** 2026-09-24 · **Branch** `phase-11`, from `main` = `2067b89` (the accepted Phase 10, fast-forwarded per D19)
**Decision record:** [ADR-017](../decisions/ADR-017-today-engine.md)

Phase 11 is MASTER-SPEC's TODAY (§16, §31): the full `UserModel`, the server-side decision engine, persisted TODAY recommendations, recommendation events, TODAY on Home, and the persona fixtures. **Saving or bookmarking Phase 10 mess plates is out of scope (D1).** Deterministic throughout: no LLM chooses or words an action (D3, D14).

---

## 1. Scope and boundaries

**In:**
- `UserModel` assembly on the server;
- the evolved core engine (D17);
- `GET /v1/today`;
- `POST /v1/today/actions/{id}/event`;
- migration 0013 (`recommendations`, `recommendation_events`);
- Home merging server and device-only actions;
- a separate offline event queue;
- 11 personas.

**Out (owner):**
- saving mess plates;
- general food recommendations;
- AI/Gemini selection, wording or context (D14);
- Firebase Analytics (D15);
- readiness and recovery (Phase 13), and the `low-readiness` persona;
- Progress and trends, and `calorie-adjust` (Phase 12);
- notifications;
- budget;
- D18 "don't suggest this";
- any change to Phase 10 behaviour or UI;
- any change to the workout `SyncEngine` or the `NutritionSyncEngine`.

## 2. Who owns which rule (D2, D13)

| Kind | §16.1 band | Owner | Inputs (authoritative) |
|---|---|---|---|
| `deload` | 95 | server | `/training/today` deload state `offered` |
| `injured-limitation` | **91 (proposed, §15 P1)** | server | today's planned exercises with `substitution.trigger = 'limitation'` (active `user_limitations` × `exercise_contraindications`) |
| `start-workout` | 90 | server | scheduled day, not completed, no active session |
| `eat-protein` | 88 (dinner) / 80 | server | targets, day totals (ranges), logged slots, local hour |
| `eat-meal` | 75 | server | same |
| `progress-load` | 72 | server | today's exercises with progression `increase-load` |
| `muscle-neglected` | 68 | server | `/training/today` `neglected` |
| `rest-day` | 60 | server | no session today (or no programme) |
| `celebrate-pr` | 50 | server | `exercise_prs` achieved on the local date |
| `log-weight` | 45 | server | `body_metrics` (the latest reading) |
| resume (in-progress session) | 92 | **device** | the session open on this phone |
| sleep (recover) | 65 | **device** | Health Connect, never sent (B4) |
| steps (move) | 40 | **device** | Health Connect |
| Health Connect connect | 35 | **device** | the platform SDK |
| `calorie-adjust` | 55 | — | deferred to Phase 12 |
| `add-steps` | 40 | device only | the server never sees steps |
| `hydrate` | 30 | — | no authoritative data; never fires |

- **The Dart `HomeSuggestionEngine`** keeps only the four device rules.
- **Removed from Home** (per D13, which forbids promoting them to server kinds): `done` (70), `volume` (45), and the device versions of deload, start, protein, calories, neglect, rest-day and PR. The server now owns these.
- **Consequence to acknowledge (§15 P6):** Home no longer shows the "workout done" or "volume at ceiling" cards. The Today block still shows the workout as done, and Training → Volume is unchanged.

## 3. Core: the evolved engine (D3, D16, D17)

The engine is `packages/core/src/recommend/engine.ts`. It is evolved in place, not duplicated.

**`UserModel` (server-assembled; the steps and the free-text fields go):**
```
localDate, hourOfDay, goal
training: {
  hasProgramme, isRestDay, sessionName|null, plannedSetCount, completedToday, activeSessionOpen,
  deload: { state: none|offered|active, trigger: fatigue|mrv|null },
  increaseLoad: [{ exerciseId, name, weightKg, repTarget }],          // today's exercises, plan order
  limitationSwaps: [{ exerciseId, name, bodyParts[], alternativeId|null, alternativeName|null }],
  neglected: [{ muscle, daysSince|null }],
  prsToday: [{ prId, exerciseName, prType, value, previous }],
  nextSession: { name, date } | null,                                   // for the rest-day action (§16.2)
}
nutrition: { targets: {kcal, proteinG}|null, eaten: {kcalLow, kcalHigh, proteinLow, proteinHigh},
             loggedSlots[], messConfigured }
body: { weighedToday, daysSinceWeighIn|null }
```

**The `Action` produced:**
```
{ kind, subjectKey, priority, basis, target,
  reason: { code, values },          // the machine-readable source of truth (D3)
  headline, detail }                 // deterministic English from a core wording table, never an LLM
```

**Rules, in the existing engine's order.** Priority bands and both exclusions are unchanged: eat-protein XOR eat-meal, and deload suppresses rest-day.

| Kind | Fires when | `subjectKey` | Reason code and values | Basis | Target |
|---|---|---|---|---|---|
| deload | `deload.state = offered` | `''` | `deload-offered {trigger}` | calculated | train |
| injured-limitation | a training day, not completed, and ≥ 1 of today's exercises contraindicated | first exercise id (plan order) | `exercise-contraindicated {exerciseName, bodyParts, alternativeName\|null, count}` | logged | train |
| start-workout | session today, not completed, no active session | `''` | `session-scheduled {sessionName, exerciseCount, minutes}` (minutes = sets × 3.5, rounded) | calculated | train |
| eat-protein | targets exist; a meal remains; **protein high end < 75 % of target**; hour < 22 | the meal slot | `protein-behind {slot, proteinTarget, proteinLow, proteinHigh, kcalLeftLow, kcalLeftHigh}` | calculated | eat |
| eat-meal | not eat-protein; a meal remains; **kcal left at the low end (target − eaten high) > 250**; hour < 22 | the meal slot | `meal-remaining {slot, kcalLeftLow, kcalLeftHigh, proteinLeftLow, proteinLeftHigh}` | calculated | eat |
| progress-load | a training day, not completed, and an exercise's progression is `increase-load` | first such exercise id | `load-increase-due {exerciseName, weightKg, repTarget}` | calculated | train |
| muscle-neglected | `neglected` not empty (the first, as today) | the muscle | `muscle-untrained {muscle, daysSince}` | logged | train |
| rest-day | no session today, not completed, deload not offered | `''` | `rest-day {nextSessionName\|null, nextSessionDate\|null, kcalTarget\|null, proteinTarget\|null, hasProgramme}` (§16.2: targets, next session, a walk; recovery status waits for Phase 13) | calculated | today |
| celebrate-pr | ≥ 1 PR today (the first by achieved time) | the PR id | `pr-today {exerciseName, prType, value, previous, count}` | logged | progress |
| log-weight | not weighed today, and the last reading ≥ 2 days ago (or none) | `''` | `weigh-in-due {daysSinceWeighIn\|null}` | calculated | progress |

Further rules:
- **"A meal remains"** uses the Phase 10 rule (`defaultRecommendationSlot`, boundaries 11/16/19): the first unlogged meal at or after the current hour's meal. If every such meal is logged, no meal remains.
- **No eat action from 22:00** local, matching the accepted Home rule J16. This is not new behaviour.
- **Ranking:** sort by priority, then a fixed kind order (the rule order above), so ties are deterministic. The cap is 4, applied **after** dismissal suppression (§6).
- **`ENGINE_VERSION = 'today-1'`.**
- **`contentHash`:** sha256 of the canonical JSON `{engineVersion, kind, subjectKey, reason, headline, detail, target, basis, priority}`. Rank is **not** part of it.
- **`inputDigest`:** sha256 of the canonical JSON of the `UserModel`. Only the digest is stored (D16).
- **Pure and deterministic.** The same `UserModel` always gives the same actions, hashes and digest.

## 4. Database (migration 0013; written only after this plan is approved)

**`recommendations`:**
- **Identity columns:** `id` uuid PK; `user_id` (→ users, ON DELETE CASCADE); `generated_for` date (the local day); `kind` (enum `today_action_kind`, the 10 server kinds); `subject_key` text NOT NULL DEFAULT `''`.
- **Ranking columns:** `rank` smallint (the rank when first generated; §15 P5); `priority` smallint; `basis` (enum `logged | calculated | estimated`); `target` (enum `train | eat | progress | today`).
- **Content columns:**
  - `payload` jsonb: `{ reason: {code, values}, engineVersion, inputDigest }`;
  - `engine_version` text;
  - `input_digest` char(64);
  - `headline` text; `detail` text;
  - `content_hash` char(64);
  - `created_at`.
- **Constraints and indexes:**
  - UNIQUE `(user_id, generated_for, kind, subject_key, content_hash)`: the D4 identity;
  - INDEX `(user_id, generated_for)`;
  - CHECK that the hashes are 64 hex characters and that `rank` is 1–4.
- **Rows are never updated** (immutable).

**`recommendation_events`:**
- **Columns:** `id` uuid PK; `recommendation_id` (→ recommendations, ON DELETE CASCADE); `user_id` (→ users, ON DELETE CASCADE; denormalised for ownership and indexing); `event` (enum `shown | opened | accepted | dismissed | completed`); `client_event_id` uuid; `occurred_at` timestamptz (client time); `received_at` timestamptz DEFAULT now().
- **Constraints and indexes:**
  - UNIQUE `(user_id, client_event_id)`: idempotency;
  - UNIQUE `(recommendation_id, event)`: each event at most once per recommendation (§5);
  - INDEX `(user_id, received_at)`.
- **No foreign keys** to food logs, mess dishes or menus.
- **Retention:** indefinite. Deleting a user cascades both tables (D10).

## 5. API (D12, D18)

**`GET /v1/today`** (sign-in required; the normal rate limit)
- Assembles the `UserModel` (§3) and runs the engine.
- Drops any action whose `(kind, subject_key)` was **dismissed** today, then keeps the top 4.
- Upserts rows with insert … ON CONFLICT DO NOTHING on the D4 identity, then reads back the ids. Identical content gives the same id; changed content gives a new row.
- **Response:** `{ date, generatedAt, engineVersion, actions: [{ id, kind, subjectKey, rank, priority, basis, target, reason: {code, values}, headline, detail }] }`. `rank` is the current rank, 1–4.
- **Always 200.** A first-day user with no data gets a rest-day or start-workout action, or none. Returns 401 without a session.
- **Performance:** p95 under 300 ms server-side, pinned by an integration test.

**`POST /v1/today/actions/{id}/event`** (sign-in required)
- **Request** (strict): `{ clientEventId: uuid, event: shown|opened|accepted|dismissed|completed, occurredAt: ISO datetime }`.
- **Replay:** returns 201 with the event when new, and 200 with the stored event on a replay of the same `clientEventId`.
- **Duplicates:** a second event of the same kind for the same recommendation, with a new `clientEventId`, also returns 200 with the event already stored. So `shown` is recorded once (D7).
- **404** if the recommendation doesn't exist or belongs to another user (D12; existence is never revealed).
- **422 — validation:** an unknown event, a malformed id or a bad timestamp.
- **422 — a transition that can't happen:**
  - any event before `shown`;
  - `accepted` together with `dismissed` (they exclude each other);
  - `opened`, `accepted` or `completed` after `dismissed`;
  - `dismissed` after `completed`;
  - `completed` on a kind that can't be completed, or without evidence (next item).
- **422 — outside the window:** `occurredAt` outside `[created_at − 5 min, end of generated_for + grace]` (§15 P3), or the request arrives more than 7 days after the end of `generated_for`.
- **Completion evidence**, checked on the server when `completed` arrives (D7):
  - start-workout: a session completed on `generated_for`;
  - deload: the deload is now `active` (accepted);
  - eat-protein / eat-meal: a food log in `subject_key`'s slot on `generated_for`;
  - progress-load: a session completed on `generated_for` containing that exercise;
  - muscle-neglected: a session completed on `generated_for` with that muscle as a primary;
  - log-weight: a `body_metrics` reading dated `generated_for`;
  - rest-day, celebrate-pr and injured-limitation are informational and **can't be completed** (§15 P4).

## 6. Mobile (D2, D6, D8, D9)

- **TODAY stays Home.** There is no new tab, and the Home visual language is kept.
- **Data:**
  - `TodayApi.get()` fetches `GET /v1/today` with hand-written DTOs (ADR-004), checked by conformance tests;
  - `todayProvider` is fetched on Home load, pull-to-refresh and resume, and invalidated when the food log drains, a session completes or the weight is saved.
- **Merge:** server actions and the four device rules are converted to `Suggestion`s and sorted by band. Ties go to server actions first, then the fixed rule order. **The carousel shows at most 4.** "More for you" no longer lists suggestions (§15 P6).
- **Destinations:**
  - train → Training / the day;
  - eat → MESS at the slot when a mess is configured (D6), else Nutrition → log;
  - log-weight → Profile → Personal details (the weight field);
  - celebrate-pr → the session summary;
  - rest-day → Training.
  - Plates are never stored (ADR-015).
- **Events** (§15 P2):
  - `shown` when a server card is first actually rendered in the carousel, once per recommendation id, deduplicated locally;
  - `opened` when the card is tapped, which opens its "why" sheet (headline, detail, basis);
  - `accepted` from the card's primary button, which then navigates;
  - `dismissed` from "Not today";
  - `completed` when the flow reached from that action finishes (session completed, food log saved, weight saved, deload accepted). The server checks the evidence.
  - Device-only cards get no events.
- **Offline (D8):** no server actions are shown offline, and no cached action is ever presented as current. The carousel shows the device-only rules, with a line saying "Suggestions need a connection". The cached plan and day state still show in the non-decision parts of Home.
- **Queue (D9):** a new Drift table `today_event_queue` (schema v3) with `clientEventId`, `recommendationId`, `event` and `occurredAt`.
  - Drained FIFO by a new small `TodayEventSync`, with backoff and at most 5 attempts, draining on reconnect.
  - 401 is handled the same way the nutrition sync does.
  - A 422 drops the entry; a 404 drops it.
  - Neither existing sync engine changes.

## 7. Persona fixtures (D11)

- **The 11 personas** live in `packages/core/test/fixtures/today-personas/`: `beginner-muscle-gain`, `intermediate-fat-loss`, `advanced-strength`, `recomposition`, `non-vit-home`, `rest-day`, `deload-due`, `calorie-deficit`, `calorie-surplus`, `first-day-no-data`, `injured-limitation`.
- **Snapshot contents:** each is a frozen `UserModel` with its full ranked output snapshotted (kinds, subjects, reasons, headlines, hashes and digest).
- **Not included:** `low-readiness` is deferred to Phase 13 and not pretended.
- **Unaffected:** the 7 Phase 10 food personas stay as they are.

## 8. Tests (owner list)

- **Core:**
  - the 11 personas;
  - every band;
  - both exclusions;
  - cap 4 after suppression;
  - deload always first when present;
  - determinism;
  - content-hash identity (same content gives the same hash; any value change gives a new hash; rank excluded);
  - reason codes and values for every kind;
  - basis;
  - injured-limitation;
  - range-aware eat-protein (high end < 75 %) and eat-meal (low-end kcal left > 250);
  - the 22:00 cut-off;
  - the rest-day content;
  - the wording table has an entry for every code.
- **Contracts:** strict query, event request and response schemas; the event, kind, basis, target and reason-code enums; OpenAPI regenerated; Dart conformance.
- **API:**
  - access: 401; 404 across users;
  - identity: the same ids on a repeated GET; a new row after a food log changes content; dismissal suppresses for the day;
  - edge cases: a first-day user with no data; the timezone at local midnight (`generated_for` flips);
  - events: 201 then 200 replay; a duplicate `shown` returns 200; 422 validation; every forbidden transition; completion evidence for each kind; the window;
  - p95 under 300 ms.
- **Migration:** 0013 up and down with data; the unique and index constraints; the cascades.
- **Flutter:**
  - the merge and the cap of 4;
  - server-first tie order;
  - event emission and the local `shown` deduplication;
  - the offline queue (queue, reconnect drain, 401 recovery, 422 and 404 dropped);
  - offline showing no server actions;
  - layouts at 411×891 and 360×640, with 100 % and 200 % text.
- **Manual on the S24:** a training day; a rest day; a deload-due state; an action's events end to end; offline behaviour; reconnect and the event drain.

## 9. MASTER-SPEC amendments

Made with this plan, limited to recording the approved decisions:
- **§31 Phase 11:** the scope notes (D1, D5, D11, D14, D15);
- **§16:** the server/device split (D2);
- **§9.2:** the table columns as built (D4, D16).

The §16.1 `injured-limitation` band is added only after the owner approves P1. §38 Phase 11 stays unticked.

## 10. Implementation order

1. This plan and ADR-017, after the owner's review of §15.
2. **Core:** the engine evolution, the wording table, the personas and tests.
3. **Contracts:** the schemas and OpenAPI.
4. **API:** migration 0013; the `UserModel` assembler (reusing the workout, nutrition, profile, limitations and PR services); `today` routes, service and repository; tests.
5. **Mobile:** DTOs and conformance; the merge; the Dart engine reduced to the device rules; events; queue (Drift v3); offline behaviour; tests.
6. **Docs:** ADR-009 reconciliation note, the report.
7. All gates, CI, the APK, the S24 checks. Phase 11 is not called complete before all of them pass (owner).

## 11. Acceptance criteria

- TODAY renders in under 1 s end to end; `/today` p95 is under 300 ms.
- The ranked output matches all 11 persona snapshots exactly.
- Both exclusions and the cap of 4 hold.
- Deload is first when offered.
- Every action carries a reason code, values and a basis.
- The same ids come back on repeated GETs.
- Events are recorded idempotently, including after being offline, and impossible transitions are rejected.
- There is no cross-user access (404).
- Migration 0013 works up and down.
- The S24 checks (§8) pass.

## 12–14. Risks, dependencies, out of scope

- **Risk: removing `done` and `volume` from Home** changes accepted Phase 6.5 behaviour (P6).
- **Risk: completion reporting** touches the success points of existing flows (P2). It only enqueues an event; nothing visible changes.
- **Risk: the two engines drifting:** a test pins the device bands against core's `PRIORITIES`.
- **Dependencies:** Phases 6, 8 and 10, and Phase 6.5's Home.
- **Out of scope:** §1.

## 15. Points for the owner's review (not covered by D1–D19)

- **P1 — the `injured-limitation` band.** §16.1 has no band for it; it appears in the spec only as a persona.
  - **Proposal: 91.** It fires only on a training day when today's plan contains an exercise the user's active limitation contraindicates. It sits just above start-workout (90), so the safer swap is seen before starting, and below deload (95).
  - The kind is added to the §16.1 table on approval.
- **P2 — the event UX.** Card tap → `opened` (the "why" sheet); the primary button → `accepted` and navigate; "Not today" → `dismissed`; the destination flow succeeding → `completed`, carried from the action that opened it. This adds a primary button and a "Not today" control to the carousel card, in the existing visual language.
- **P3 — the grace period.**
  - An event's `occurredAt` may run to **03:00 the next local day** (late-night use).
  - Queued events may **arrive up to 7 days** after the recommendation's day (offline drain).
  - Anything else is rejected with 422, and the client drops it.
- **P4 — `completed` on informational kinds.** rest-day, celebrate-pr and injured-limitation can't be completed (422). Accepted or dismissed are their meaningful responses.
- **P5 — `rank` on an immutable row.** The row keeps the rank from its first generation, and the API returns the current rank. Rank is not in the content hash, so a re-rank alone never makes a new row.
- **P6 — Home consequences of D2 and D13.**
  - The `done` and `volume` cards disappear; the Today block still shows the workout as done, and Training → Volume remains.
  - "More for you" stops listing suggestions, because of the cap of 4 displayed; Health Connect "connect" competes by its band (35).
- **P7 — the eat actions' hour cut-off.** No eat action from 22:00 local, as the accepted Home rule does today.
