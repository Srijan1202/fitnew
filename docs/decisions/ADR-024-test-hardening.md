# ADR-024 — Test hardening: a 100 % branch gate with documented hints, whole-app integration flows, an in-process load test

**Status** PROPOSED. Written and implemented on `phase-18` on 2026-10-22. It becomes ACCEPTED when Phase 18 is accepted.
**Date** 2026-10-22
**Phase** 18
**Affects**
- MASTER-SPEC §26.1 (coverage), §26.4 (Flutter), §31 Phase 18, and §38 (ticked only on acceptance).

---

## Context

**§31 Phase 18 requires:**
- `packages/core` at 100 % branch coverage;
- complete persona fixtures;
- Flutter integration tests;
- an API load test.

**Acceptance:**
- 100 % branch coverage on core decision functions;
- every persona snapshot green;
- p95 < 500 ms at 50 rps.

**§26.4 asks for:**
- golden tests for `MetricDisplay`, `EstimateRange`, `LedgerRow` and `ConfidenceBar`;
- integration tests for three flows: full onboarding, a workout logged offline then synced, and a mess meal logged.

**Where things stood:**
- Core branch coverage was 95.08 %, with no coverage tool installed.
- All 18 §26.2 personas already existed and were snapshotted: 12 TODAY personas and 6 mess personas.
- The app had no integration tests and no golden tests.
- None of the four components named for goldens exist yet; the visual pass is deferred (BACKLOG O4).

## Decisions

| # | Decision |
|---|---|
| D1 | **Coverage is enforced, not just reported.** `packages/core/vitest.config.ts` runs v8 coverage over `src/**` with a 100 % branch threshold (functions, lines and statements at 95 %). CI runs `test:coverage`, so a new uncovered branch fails CI. The one file excluded holds only types. |
| D2 | **Every uncovered branch was handled in this order:** (1) a test that reaches it; (2) when an invariant in the same function makes it dead, the dead branch is removed (a `!` or a simpler expression) without changing behaviour; (3) only when the invariant lives elsewhere, a `/* v8 ignore next -- @preserve */` hint, with a comment above it stating that invariant. There are 19 hints plus one start/stop region. Two branches first judged unreachable proved reachable when inputs were swept: the last-resort drop of a protected lift (in a 15-minute session) and the drop of a compound (in fat-loss sessions). Both now have tests instead of hints. |
| D3 | **Integration tests drive the whole app inside `flutter test`, not `integration_test` on a device.** `test/integration/app_flows_test.dart` mounts `FitOSApp` (router, auth gate, shell, real screens and controllers, an in-memory database) with every server scripted. Each step is a tap, typed text or a connectivity event. They run in CI on every push; a device-only suite would not, because CI has no emulator. Offline-then-sync uses a real connectivity stream. A negative control proved the stream is what triggers the sync: without the event the test fails. |
| D4 | **Goldens wait for their components.** The four widgets do not exist. Writing goldens for screens still waiting on the visual pass would lock in pixels that are about to change. They land with the design-system pass (O4), recorded as BACKLOG E20. |
| D5 | **The load test is a script, not part of the suite.** `pnpm --filter @fitos/api load:test` runs on the isolated `<db>_test` database, sends real HTTP to the real app on a loopback port, and paces requests open-loop at 50 rps for 60 s after a 5 s warm-up. Requests rotate across the ten screens the app opens most, weighted towards TODAY, and over 30 onboarded users, so the real per-user limit of 120/min stays on. It fails on p95 ≥ 500 ms, on any failed request, or if fewer than 95 % of the target requests are sent. Client and server share one process, so the figures are an upper bound for the server. |

## Consequences

- A change that adds an untested branch to core now fails CI. A hint needs a stated invariant, which review can check.
- The integration flows add about 10 s to `flutter test`. They break when a step of these three flows changes, which is their purpose.
- The load test needs the local Postgres (Docker), so it does not run in CI. It has to be re-run against the hosted stack in Phase 19, where the network and Cloud Run cold starts change the numbers.

## Not in Phase 18

- Golden tests (E20, with O4).
- A load test against the hosted API (Phase 19, after O1).
