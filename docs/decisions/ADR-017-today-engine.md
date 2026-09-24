# ADR-017 — TODAY: one server engine over the full UserModel, immutable persisted actions, product events, and a bounded device remainder

**Status** PROPOSED — owner decisions D1–D19 approved 2026-09-24. Plan points P1–P7 await the owner's review (see the [plan](../phase-plans/phase-11-plan.md) §15).
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
