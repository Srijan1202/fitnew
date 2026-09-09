# PHASE 0 COMPLETE — Foundation

**Date** 2026-09-09 · **Commits** `9c01016`, `d03f088`, `82fa060`, `499d757`, `fe34bd3`
**Head** `fe34bd3` pushed to `origin/main` · **CI** all three workflows green

---

## IMPLEMENTED

Everything below was verified by executing it, not by inspection.

- **pnpm monorepo** per §29. `packages/core` moved from the repo root into
  `packages/core/` — every file under `src/` verified byte-identical to its
  pre-move blob by hash comparison. No engine logic was altered in the move.
- **All six MessIT endpoints exist as fixtures** (§26.3). The two missing ones
  (`hostel-2-mess-1`, `hostel-2-mess-2`) were captured live on 2026-09-07,
  truncated 30 → 8 dates preserving four 14-day congruent pairs, and verified
  byte-identical to the live responses. Core suite 82 → **101 tests**.
- **`apps/api`** — Fastify 5 + Zod + Drizzle + pino, TypeScript strict.
  `GET /health` performs a real `select 1` and returns **503, not a cheerful
  200**, when Postgres is unreachable. §10 error envelope, pino redaction of
  email/token/weight, rate limiting, OpenAPI 3.1 at `/docs`.
- **`apps/admin`** — Next.js 15 App Router placeholder on the §6.2 tokens.
- **`apps/mobile`** — Flutter + Riverpod 3 + go_router, §6.2 tokens and §6.3
  type scale, `android/` and `ios/` platform folders. Zero fitness logic in
  Dart.
- **`packages/config`**, **`docker/`** (Postgres 16 + multi-stage Dockerfile),
  **three CI workflows**, **ADR-001** (stack), **ADR-002** (plate performance).
- **Plate search now meets its performance budget.** Two quadratic defects in
  `suggestPlates` removed; worst real menu went from 89,629ms to **16.1ms**
  against a 100ms target, with output verified byte-identical to the previous
  implementation.
- **Spec amended from live evidence** — §14.2 is now nine defects, with #1 and
  #3 corrected and #8/#9 added; §25 gained an Environment traps table.
- **Untracked the 1,063 `node_modules` files** that commit `9d08cc0` had
  committed, and added `.gitignore`, `.gitattributes` and `.dockerignore`.

## FILES

**created** — `pnpm-workspace.yaml`, `package.json`, `.npmrc`, `.gitignore`,
`.gitattributes`, `.dockerignore`, `README.md`; `packages/config/**` (3);
`apps/api/**` (17); `apps/admin/**` (7); `apps/mobile/**` (11 hand-written +
71 generated platform files); `docker/**` (3);
`.github/workflows/ci-{api,core,mobile}.yml`;
`docs/decisions/ADR-001-stack.md`, `docs/decisions/ADR-002-plate-search-performance.md`;
`docs/phase-reports/phase-0.md`;
`packages/core/test/fixtures/hostel-2-mess-{1,2}.json`;
READMEs for `database/`, `scripts/`, `packages/contracts/`, `apps/mobile/`

**moved** — `src/` → `packages/core/src/`; `test/` → `packages/core/test/`;
`package.json`, `tsconfig.json`, `README.md` → `packages/core/`;
`MASTER-SPEC.md` → `docs/`

**modified** — `packages/core/src/mess/recommend.ts` (scoped exception, Task 3
only); `packages/core/test/mess.test.ts` (+19 tests, perf comment);
`docs/MASTER-SPEC.md` (§14.2, §25); `apps/mobile/pubspec.yaml` (+ `.lock`);
`apps/mobile/analysis_options.yaml`; two Dart files (const + trailing comma)

## DATABASE

- migrations: **none** — the first is `users` in Phase 1
- tables: **none**. `docker/init/01-extensions.sql` creates `pgcrypto` and
  `pg_trgm` at first boot; verified present on Postgres **16.15**

## APIS

- `GET /health` — liveness plus a real database ping. Unauthenticated, so the
  §8.4 keep-warm job can reach it.
- `GET /docs` — OpenAPI 3.1 UI generated from the Zod schemas.

## TESTS

```
executed   pnpm test                              (root, all workspaces)
result     packages/core   101 passed, 0 failed
           apps/api          5 passed, 1 skipped   (integration test skips
                                                    without DATABASE_URL)
           with DATABASE_URL set against docker Postgres:
           apps/api          6 passed, 0 skipped

executed   pnpm typecheck                         clean in all 4 packages
executed   pnpm --filter @fitos/api lint          clean
executed   pnpm --filter @fitos/core demo         runs the full pipeline
executed   dart format --set-exit-if-changed .    0 changed
executed   dart analyze --fatal-infos             No issues found
executed   flutter test                           2 passed
executed   flutter run -d chrome                  launched, debug service attached
executed   dart run build_runner build            exit 0, 0 outputs (no annotations yet)
executed   docker compose up -d --build           postgres healthy, api started
executed   GET /health                            200 {"status":"ok",
                                                   "database":{"reachable":true,
                                                   "latencyMs":88}}
coverage   not measured — §31 sets 100% branch coverage as a Phase 18 gate
```

**CI on `fe34bd3`** — every step, not just the job conclusion:

| Workflow | Result |
|---|---|
| `ci-core` | **success** — typecheck, test, demo |
| `ci-api` | **success** — typecheck, lint, test against ephemeral Postgres, build, Docker build |
| `ci-mobile` | **success** (422s) — pub get, analyze, format check, test, **Build APK** |

## KNOWN ISSUES

1. **The Flutter SDK is installed at `D:\New folder\flutter`** — a path with a
   space, which breaks the native-assets hook runner
   (`'D:\New' is not recognized`). A junction at `D:\flutter` is the current
   workaround and all Flutter verification went through it. Not a repo defect,
   but it will recur on any new machine; recorded in §25.
2. **`packages/contracts` is an empty reserved directory** and not yet a
   workspace member. It joins in Phase 1 when `/auth/session` gives it a schema.
3. **Font binaries for Anton and Archivo are not in the repo**, so the theme
   falls back to the platform sans-serif. The `fonts:` block in `pubspec.yaml`
   is commented out and ready.
4. **`custom_lint` and `riverpod_lint` are absent** — they cannot co-resolve on
   this toolchain and are IDE-only. TODO in `pubspec.yaml` names Phase 1.
5. **`sqlite3_flutter_libs` is pinned to the 0.5.x line**, which is superseded
   by `package:sqlite3` 3.x. Correct for drift 2.23.1 (which needs sqlite3 2.x);
   TODO points at Phase 5.

## DEVIATIONS FROM SPEC

**From the live capture** (all now folded into §14.2 itself):

- **§14.2 #1 was wrong as written.** "Half the endpoints are stale" does not
  generalise: on 2026-09-07 both women's endpoints served a complete, sorted
  September 1–30 while two men's endpoints were August-only. Staleness is
  per-endpoint and unpredictable — which strengthens the case for mirroring
  (§14.6) rather than weakening it.
- **§14.2 #3 was too narrow.** The women's special mess labels *both* `Veg :`
  and `Non Veg :`, and all three spacing variants occur in one file, including
  `"Non Veg :Pepper Chicken Gravy"`.
- **Two new defects**, now #8 and #9: a trailing space inside a labelled dish
  (`"Veg : Chettinad Veg Biriyani "`) and a period inside a name
  (`"Veg. Cutlet (2 Nos)"`).
- §14.3's 14-day cycle was **confirmed** on both new endpoints (16 congruent
  pairs each, full days byte-identical).

**Mine, all deliberate:**

- **`packages/core/src/mess/recommend.ts` was modified** under the scoped
  exception granted for Task 3. No other engine file was touched, and scoring,
  candidate selection, serving caps and pruning are unchanged.
- **Dependency versions moved off my original Phase 0 pins.** Those pins were
  written before any SDK existed to resolve them and several were mutually
  incompatible. Every replacement was chosen by the resolver and pinned back
  exactly from the lockfile: `path` 1.9.1, `freezed_annotation` 3.1.0,
  `flutter_lints` 6.0.0, `build_runner` 2.15.1, `freezed` 3.2.3,
  `json_serializable` 6.11.2, `sqlite3_flutter_libs` 0.5.42, `zod` 3.25.76.
  The four protected pins — `flutter_riverpod` 3.0.0, `go_router` 14.6.2,
  `dio` 5.7.0, `drift` 2.23.1 — are untouched, and
  `pub upgrade --major-versions` was never run.
- **`apps/mobile/web/` was created and then removed.** It was the only way to
  execute `flutter run` on a machine with no Android SDK; §35 puts a web app out
  of scope, so it is not in the repo. The regeneration command is in
  `apps/mobile/README.md`.
- **Added `.gitignore`, `.gitattributes`, `.dockerignore` and untracked
  `node_modules`** — not in the task list, but 1,063 dependency files were
  tracked and would have grown with every commit.

## §31 PHASE 0 ACCEPTANCE — status

| Criterion | Executed? | Result |
|---|---|---|
| `pnpm test` passes at root | yes | **PASS** — 101 core + 6 api |
| `packages/core` tests green, `tsc` clean | yes | **PASS** — 101 tests, clean |
| `docker compose up` serves `/health` 200 | yes | **PASS** — 200, latency 88ms |
| `flutter run` shows a themed placeholder | yes | **PASS** — launched on Chrome |
| CI green | yes | **PASS on push to `main`** — see caveat |

**Caveat, stated plainly:** §31 words the last criterion as "CI green **on a
PR**". All three workflows ran and passed on a direct push to `main`. Their
triggers include `pull_request`, but no pull request has been opened, so the PR
path itself is configured and not yet exercised.

**Two Phase 0 tasks from §31 remain outstanding, and both are the human's:**

1. **Create the cloud projects** — three Neon projects (dev/staging/prod), three
   Firebase projects, and a GCP billing account attached (required for the Cloud
   Run free tier since 2026-02-03). Expected env vars: `DATABASE_URL` per
   environment, `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`.
2. **Verify Cloud Run free-tier applicability in `asia-south1`** — §36 open
   question 2, and a hard gate before the first deploy.

So: **every acceptance criterion that can be executed without the human's cloud
accounts has been executed and passed.** Phase 0 is not signable-off as fully
complete until items 1 and 2 above are done.

## NEXT PHASE

- **Phase 1: Authentication** — Firebase Auth (email + Google), `firebase-admin`
  verification plugin, `users` table and first migration, `POST/DELETE
  /auth/session`, Flutter auth flow with secure token storage, dio refresh
  interceptor and go_router guards.

**Blockers that must be answered first:**

1. **Cloud projects must exist** (above). Phase 1 cannot verify token
   verification without a real Firebase project.
2. **§36 open question 2 — Cloud Run free tier in `asia-south1`.** Fallback is
   `us-central1` at roughly 200ms extra latency for Indian users.
3. **§36 open question 3 — does iOS ship in V1?** Determines whether Apple
   Sign-In is required in Phase 1 and whether the ~₹8,000/year Apple Developer
   cost is incurred. `ios/` exists, but nothing iOS-specific has been built.
