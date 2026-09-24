# ADR-017 — TODAY: one server engine over the full UserModel, immutable persisted actions, product events, and a bounded device remainder

**Status** PROPOSED — owner decisions D1–D19 approved 2026-09-24; plan points P1–P7 approved; the core, API and API-correction gates approved. Becomes ACCEPTED with Phase 11's acceptance (S24 manual checks pending). See the amendments at the end.
**Date** 2026-09-24
**Phase** 11
**Affects**
- MASTER-SPEC: §16 (the TODAY engine and the device split), §9.2 (`recommendations`, `recommendation_events`), §10.1 (`/today`), §26.2 (personas), §31 Phase 11, §38 (on acceptance only).
- ADR-009: the Home device engine shrinks to the device-only rules.
- ADR-010: TODAY is deliberately not added to the AI context until Phase 14.

---

## Context

MASTER-SPEC Phase 11 is TODAY: assemble the full `UserModel`, wire the existing engine (`packages/core/src/recommend/engine.ts`), persist recommendations, and track events from day one. The TODAY screen shows the ranked actions.

What exists:
- **The core engine** already has the §16.1 bands, both mutual exclusions and the cap of 4. But its `Action` has no identity and no reason code, its nutrition is single numbers rather than Phase 8 ranges, and it reads steps the server never has.
- **Phase 6.5 (ADR-009)** built a Dart Home engine on the same bands. It exists because Health Connect data never leaves the phone (ADR-008, B4), and ADR-009 anticipated Phase 11 shrinking it to the rules that need device data.
- **Phase 10 (ADR-015)** decided mess plates are never stored.

## Decisions

1. **Scope (D1).** TODAY as specified. Saving or bookmarking mess plates is out.
2. **One engine, evolved (D17).** The existing core engine gains stable identity, a structured reason (`code` + `values`, the source of truth), a subject key, basis, an engine version, range-aware nutrition, and deterministic English `headline`/`detail` from a core wording table (D3). The bands and exclusions are unchanged. No LLM chooses or words an action (D3, D14).
3. **The server owns every rule it has authoritative data for (D2, D5, D13):** deload, start-workout, eat-protein, eat-meal, progress-load, muscle-neglected, rest-day, celebrate-pr, log-weight and injured-limitation.
   - **Device-only rules stay in Dart:** resume, sleep, steps and the Health Connect connection.
   - **Not built:** `calorie-adjust` (Phase 12), `hydrate` (no data; never fires), server-side `add-steps`, and `low-readiness` (Phase 13).
   - **No new rule families.** The Home-only `done` and `volume` cards are not promoted to server kinds.
4. **Immutable persisted actions (D4, D16).** One row per `(user_id, generated_for, kind, subject_key, content_hash)`.
   - A repeated `GET /today` with the same content reuses the id; changed content creates a new row.
   - A row stores the reason, headline, detail, basis, target, priority, first rank, `engine_version` and an input digest, but never the whole `UserModel`.
   - Rows are never updated. Retention is indefinite, and deleting a user cascades (D10).
5. **Events are product records, not analytics (D7, D15):** `shown`, `opened`, `accepted`, `dismissed`, `completed`.
   - Each is idempotent by `clientEventId`, and recorded at most once per recommendation.
   - Impossible transitions are rejected.
   - A dismissal hides that `(kind, subject)` for the rest of the local day.
   - A `completed` event is checked against server evidence.
   - Events are accepted only within the recommendation's local day plus a grace period.
   - No Firebase Analytics and no dashboards.
6. **Two endpoints only:** `GET /v1/today` and `POST /v1/today/actions/{id}/event`. Another user's action is a 404 (D12). The latency target is p95 under 300 ms server-side and under 1 s end to end, with a regression test (D18).
7. **Mobile (D2, D6, D8, D9).**
   - TODAY stays the Home surface. Server and device actions are merged by band, and at most 4 are displayed.
   - Eat actions open MESS or Nutrition; plates stay unstored.
   - **Offline:** no server action is presented as current. Only the device rules show, and cached day state appears only in non-decision UI.
   - **Events** queue in a new separate Drift `today_event_queue` (schema v3): FIFO, idempotent, backoff, at most 5 attempts, drained on reconnect, with 401 handled as the nutrition sync does. The workout and nutrition sync engines are not modified.
8. **Personas (D11).** 11 `UserModel` personas with snapshotted ranked output. `low-readiness` waits for Phase 13.
9. **Branch (D19).** `main` was fast-forwarded to the accepted Phase 10 (`2067b89`). `phase-11` branches from it, and is not merged until Phase 11 is accepted.

## Consequences

- **§30** stays true: every decision computable from server data is made on the server. The Dart remainder is ordering over device-only data, as ADR-009 allowed.
- **Home loses** the Phase 6.5 `done` and `volume` cards and the "More for you" suggestion list (plan P6). The workout status and the volume screen remain.
- **Every displayed server action is explainable** after the fact from its immutable row, even though engine replay is not required.
- **The acceptance rate** (§22's product metric) can later be computed from `recommendation_events` without any analytics SDK.
- **`injured-limitation`** needs a §16.1 band. It is proposed at 91 (plan P1) and becomes part of §16.1 only on the owner's approval.

## Amendments during implementation (owner-approved, 2026-09-24/25)

These record what the owner approved or corrected after the plan, and what the implementation settled within those decisions. Nothing here adds a rule family.

1. **P1–P7 approved as specified.** `injured-limitation` is at priority 91 and fires only with a valid swap; the 22:00 local eat cut-off stands (21:59 eligible, 22:00 not).
2. **Q1 — limitations and progression.** Core `trainingFromPlan(exercises)` (in `recommend/model.ts`) is the only place the split is made: an exercise ruled out by an active limitation never enters `increaseLoad`, so a ruled-out lift with a load increase due and a valid swap gives `injured-limitation` and no `progress-load`. The API assembler calls it; nothing re-derives either list. The engine keeps one limitation rule.
3. **Q2 — `completed` requires `accepted`;** `opened` is never required. Informational kinds (rest-day, celebrate-pr, injured-limitation) cannot be completed. A consequence: `dismissed` after `completed` is rejected as `accepted-and-dismissed`, because core checks that first; the `after-completed` code is no longer reachable. It is still a 422.
4. **Event processing order (API correction gate):**
   1. authenticate;
   2. `clientEventId` replay or collision, scoped to the user;
   3. an exact replay (the same action, event and `occurredAt` instant) → 200 with the original, even after the timing window;
   4. any other reuse → 409 (`different-action`, `different-event`, `different-occurred-at`); an unrelated event is never returned;
   5. ownership → 404;
   6. P3 timing for new events → 422;
   7. the transition → 422 (a repeat of an event already recorded → 200 with it);
   8. completion evidence → 422 `no-evidence`;
   9. insert → 201.
5. **Deload evidence (migration 0014).** Phase 6 keeps only the current deload week in `programs.deload_started_at` and clears it when the week closes. A Phase-11-owned table `deload_activations` keeps every activation. It is appended by a trigger on `programs` whenever `deload_started_at` is set, backfilled for running weeks, with a hand-written down migration. No Phase 6 code or lifecycle changed. A deload `completed` needs an activation that falls:
   - after the action existed;
   - no earlier than its `accepted` event, and no later than the `completed` event itself, both with the 5-minute skew.

   So a stale week, or one activated after the fact, never counts, while a completion delivered late (inside the 7-day window) after the week closed still has its evidence.
6. **Offline (D8, amended by the owner's final rules).** Offline, Home shows the last valid plan **only if it is for the same local date**. It is labelled ("Offline — showing your plan from HH:MM"; the card eyebrow reads "· OFFLINE") and is never presented as a fresh decision. Responses to it are recorded and queued. A cached plan from an earlier day is never shown; without one, Home says "Suggestions need a connection." and keeps the device-only suggestions.
7. **Mobile queue (D9), as built.**
   - Drift schema v3 adds two tables:
     - `today_event_queue`: FIFO; a row leaves on 201/200, and at once on 409, 422 or 404;
     - `today_event_ledger`: one row per (action, event) recorded on this phone.
   - The ledger is what makes `shown` go once per action however often Home rebuilds or restarts, and what hides a dismissed card at once.
   - Offline and 401 stop without spending an attempt; other failures back off 300 ms · 2ⁿ for 5 attempts, then the entry leaves.
   - Every retry reuses the event's `clientEventId` and `occurredAt`.
   - A separate `TodayEventSync` drains it; the workout SyncEngine and the NutritionSyncEngine are unchanged.
8. **`completed` on the phone** is sent only once the server already holds the evidence, read from server answers:
   - start-workout, progress-load, muscle-neglected: the day's completed session;
   - deload: its active state;
   - eat actions: the server's food day, by meal;
   - log-weight: a weight Personal details just saved.

   It is never sent on accept alone, and never for informational kinds.
9. **One display rule on the phone:** while a session is open on this phone, the server's `start-workout` card gives way to the device `resume` card — the session it asks for is already running. Otherwise the phone draws the server's actions in the server's rank order, merged with the device suggestions by band (ties to the server), at most four.
