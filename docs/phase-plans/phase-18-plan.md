# Phase 18 — Test hardening: implementation plan

**Status:** Written from the audit on 2026-10-22 and implemented in one pass on `phase-18`, branched from `phase-17` (approval pending). Acceptance is pending the owner's review.
**Decision record:** [ADR-024](../decisions/ADR-024-test-hardening.md).

## 1. What MASTER-SPEC asks for

**§31 Phase 18**
- **Tasks:**
  - `packages/core` at 100 % branch coverage;
  - persona fixtures;
  - Flutter integration tests;
  - an API load test.
- **Acceptance:**
  - 100 % branch coverage on core decision functions;
  - every persona snapshot green;
  - p95 < 500 ms at 50 rps.

**§26.4**
- Goldens for four named components.
- Integration tests for three flows: onboarding, an offline workout then sync, and a mess meal.

## 2. Audit (2026-10-22)

| Item | State found |
|---|---|
| Core coverage | Not measured; 95.08 % of branches once `@vitest/coverage-v8` was added |
| Personas (§26.2) | All 18 present and snapshotted: 12 TODAY personas (`test/today-fixtures.ts`), 6 mess personas (`test/fixtures/personas/`) |
| Flutter integration | None |
| Goldens | None, and none of the four named components exist (the visual pass is deferred, O4) |
| Load test | None |

## 3. Decisions (ADR-024)

| # | Decision |
|---|---|
| D1 | `vitest.config.ts`: 100 % branch threshold; CI runs `test:coverage` |
| D2 | Order of handling: a test, then removing dead code where the invariant is local, then a hint stating the invariant |
| D3 | Whole-app flows under `flutter test` (they run in CI), not `integration_test` on a device |
| D4 | Goldens deferred until their components exist (E20 with O4) |
| D5 | The load test is a script on `<db>_test`: real HTTP, open-loop at 50 rps, 30 users, the real rate limit |

## 4. Build

1. **Core:**
   - `@vitest/coverage-v8` and `vitest.config.ts`;
   - three test files of edge cases;
   - behaviour-neutral simplifications;
   - documented hints;
   - CI on `test:coverage`.
2. **Mobile:**
   - `test/integration/app_flows_test.dart`, with three flows;
   - `workoutOverrides(connectivity:)`.
3. **API:** `src/scripts/load-test.ts` and `load:test`.
4. **Docs:**
   - this plan;
   - ADR-024;
   - the report;
   - amendments to §26.1, §26.4 and §31;
   - BACKLOG E20.
