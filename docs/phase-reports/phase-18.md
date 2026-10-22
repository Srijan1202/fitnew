## PHASE 18 — TEST HARDENING — IMPLEMENTATION COMPLETE, ACCEPTANCE PENDING

**Date** 2026-10-22 · **Branch** `phase-18` from `phase-17` (approval pending) · **not merged**

**Status:** **implemented and tested; NOT accepted, NOT frozen.**
- §38 Phase 18 is not ticked.
- ADR-024 is PROPOSED.

**Commits**
- `9c07015`: `packages/core` at 100 % branch coverage, with a CI gate
- `0a231c0`: Flutter integration flows and the API load test
- the documentation commit: this report, the plan, ADR-024, and the MASTER-SPEC and BACKLOG amendments

**Decision record:** [plan](../phase-plans/phase-18-plan.md), [ADR-024](../decisions/ADR-024-test-hardening.md) (D1–D5).

### 1. WHAT MASTER-SPEC REQUIRES (and where it is)

| Requirement (§31, §26) | Built |
|---|---|
| 100 % branch coverage on core | **100 % (2,296 of 2,296 branches)**, up from 95.08 %. Enforced: `vitest.config.ts` thresholds, and CI runs `test:coverage` |
| Persona fixtures, snapshots green | All 18 §26.2 personas, snapshotted (12 TODAY personas, 6 mess personas); green |
| Flutter integration tests (§26.4) | `test/integration/app_flows_test.dart`: full onboarding · a workout logged offline then synced · a mess meal logged |
| Load test, p95 < 500 ms at 50 rps | `pnpm --filter @fitos/api load:test`: **p95 222 ms at 50.0 rps, 0 failed** |
| Goldens for four components (§26.4) | **Deferred**: the components do not exist until the design-system pass (O4); recorded as BACKLOG E20 |

### 2. ACCEPTANCE (automated)

**Coverage**
- 46 new core tests cover refusals, fallbacks, empty inputs, tie-breaks, plural wording, cycle contradictions, quiet-hours moves and generator edge cases.
- Dead branches were removed where the invariant sits in the same function, with no behaviour change. Examples:
  - the calorie step that can never round to 0 (the tolerance floor makes it at least 110 kcal);
  - trend references to a list known not to be empty;
  - the always-present `Intl` parts.
- 19 hints and one region remain. Each states the invariant that makes its branch unreachable, for example: "only eligible dishes reach here, and dishVerdicts refuses one with no estimate".
- Two branches looked unreachable but were found by sweeping the generator's inputs, so they got tests, not hints:
  - the last-resort drop of a protected lift (a 15-minute session);
  - the drop of a compound (fat-loss sessions).
- The count-fill time limit was never hit in about 70,000 generator inputs, so it keeps a hint.

**Integration flows** (the whole app: router, auth gate, shell, real screens, in-memory database, scripted servers):

| Flow | What it proves |
|---|---|
| Full onboarding | Sign up → the seven screens by tap and typed text (the date picker included) → the server's plan → Start → TODAY. Each answer reaches the server in order and in its wire shape; only the required consents are sent |
| Workout offline → sync | The connection drops; the session starts from TODAY's card; three sets are logged and the session finished on the phone; the summary says pending and the server has nothing. The connection returns (a connectivity event, no tap) and the session reaches the server completed with its sets. **A negative control without the event fails**, so the sync really comes from the connection returning |
| Mess meal | Nutrition tab → today's mess strip → a dish → 3 pieces → Log. The request is a mess dish (no numbers sent); the server's snapshot (255–360 kcal) lands in the day; nothing is left queued |

**Load test**, on this PC (Postgres in Docker; client and server in one process, so the figures are an upper bound for the server)

Run: 50 rps for 60 s after a 5 s warm-up, 3,000 requests counted, 30 onboarded users, the per-user limit on.

| Endpoint | n | p50 ms | p95 ms | p99 ms |
|---|---|---|---|---|
| `/v1/today` | 750 | 175 | 272 | 318 |
| `/v1/training/today` | 374 | 135 | 232 | 265 |
| `/v1/mess/menu` | 374 | 66 | 123 | 138 |
| `/v1/training/volume` | 188 | 44 | 113 | 171 |
| `/v1/progress/summary` | 188 | 38 | 70 | 80 |
| `/v1/nutrition/foods/search` | 188 | 22 | 60 | 77 |
| `/v1/recovery/today` | 188 | 27 | 59 | 71 |
| `/v1/nutrition/today` | 374 | 33 | 53 | 70 |
| `/v1/user/profile` | 188 | 20 | 48 | 69 |
| `/v1/exercises` | 188 | 16 | 36 | 44 |
| **All** | **3,000** | **56** | **222** | **282** |

TODAY is the slowest screen, because it builds the user model and runs the engine on every read. It is still under half the budget.

### 3. TESTS

| Suite | Count | New for Phase 18 |
|---|---|---|
| core | 967 | 46 (three coverage files); coverage gate |
| contracts | 86 | — |
| API | 504 | — (the load test is a script; the suite still passes on the simplified core) |
| Flutter | 688 | 3 integration flows |

- TypeScript typecheck and lint: clean.
- `flutter analyze --fatal-infos`: clean.

### 4. WHAT CHANGES FOR YOU

Nothing in the app. No migration and no APK. The core changes remove only branches that could never run.

### 5. MANUAL CHECKLIST

1. Run the gate yourself:
   - `pnpm --filter @fitos/core test:coverage` prints `Branches : 100%`.
   - `pnpm --filter @fitos/api load:test` ends with `PASS` (it needs Docker Postgres running; about 2 minutes).
2. Optional: `flutter test test/integration` in `apps/mobile` runs the three flows (about 10 s).
3. Read the hints, if you want to check them: `grep -rn "v8 ignore" packages/core/src`. Each has its reason on the line above.

**Accept Phase 18 when you are satisfied with 1.** Then:
- ADR-024 becomes ACCEPTED;
- §38 Phase 18 is ticked;
- this report is updated.

No merge without your approval.

### 6. OPEN

- **E20:** goldens, with the design-system pass (O4).
- **E21:** re-run the load test against the hosted API (Phase 19, after O1).
- **Seen while testing:** Fastify warns that `disableRequestLogging` is deprecated (FSTDEP023). It works on Fastify 5 and must change before Fastify 6.
- **Still open from before:** O1, O2, O3, O5, O7, O8, O9, O10; approval of Phases 16 and 17.
