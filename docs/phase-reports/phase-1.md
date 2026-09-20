# PHASE 1 COMPLETE — Authentication

**Date** 2026-09-20 · **Commits** `86eb6a6` (backend), `c161858` (Flutter), plus this report's commit
**Head** pushed to `origin/main` · **CI** all three workflows green on `c161858`

---

## IMPLEMENTED

Everything below was verified by executing it. Automated tests run against a
real Postgres 18 and scripted tokens; the production Firebase path was
smoke-tested against the dev project with the real service-account key.

**Backend**
- `users` table (§9.2) with the §9.1 conventions, as `database/migrations/0000_users.sql`
  from drizzle-kit, plus a hand-written `down/0000_users.down.sql` and a
  rollback tool that reverts the SQL *and* the journal row in one transaction.
  Verified up → idempotent re-up → DB-level unique on `firebase_uid` → down
  (table and journal both gone) → down again is a no-op → up re-applies.
- `firebase-admin` verification behind a `TokenVerifier` seam. Production
  verifies with `checkRevoked=true` so sign-out on one device invalidates a
  still-unexpired token on another. ADC on Cloud Run, key file locally.
- **Default-deny under `/v1`**: every route requires a Bearer token unless it
  opts out with `config: { public: true }`. A sweep test collects every
  registered `/v1` route via an `onRoute` seam and asserts 401 without a
  token, so a route added in any later phase is checked automatically.
- `POST /v1/auth/session` — idempotent; single-statement upsert using
  `(xmax = 0)` so two racing first-sign-ins cannot both insert or both
  believe they were first. Email refreshed from Firebase each time; timezone
  and locale never clobbered once set. `isNewUser` true exactly once.
- `DELETE /v1/auth/session` — revokes refresh tokens, 204.
- `/auth/session` rate-limited 10/min/IP (§10).
- Error handler now maps Fastify-wrapped Zod validation to 422 with details
  (was falling through to 500) and response-serialisation failures to a
  logged 500.
- `packages/contracts` joins the workspace with the wire shapes; OpenAPI 3.1
  exported to `packages/contracts/openapi.json` with `bearerAuth`.

**Flutter**
- Firebase public config via `--dart-define`; a build without it shows a
  plain message on the splash, never a native crash. Android only (ADR-003).
- `AuthInterceptor`: attaches Bearer, on 401 force-refreshes and retries
  **exactly once**, second 401 invalidates. `RetryInterceptor`: transient
  failures only, never a 5xx.
- `SecureSessionStore` (flutter_secure_storage): last ID token + session
  profile, so cold start is instant and offline; cleared in one call.
- `features/auth`: freezed `UserProfile` and `AuthState`, `AuthRepository`
  interface with zero business rules, `CredentialSource` wrapping
  `FirebaseAuth` + `GoogleSignIn` v7, `AuthRepositoryImpl` composing the §11
  flow, `AuthController` as `AsyncNotifier<AuthState>`.
- Screens: sign-in (email + Google), sign-up, forgot-password (never reveals
  whether an address exists), splash gate. §6 language throughout.
- go_router guard as a pure function `authRedirect(state, location)`; holds on
  the splash while restoring so a signed-in user never sees sign-in flash.
- `custom_lint` + `riverpod_lint` re-added (the Phase 0 conflict cleared
  upstream with `custom_lint 0.8.x`); `riverpod_lint` reports no issues and
  runs as a `ci-mobile` step.

## FILES

**created** — `packages/contracts/{package.json,tsconfig.json,eslint.config.js,vitest.config.ts,openapi.json,src/{index,auth,errors,auth.test}.ts}`;
`database/migrations/{0000_users.sql,down/0000_users.down.sql,meta/*}`;
`apps/api/{drizzle.config.ts,src/db/{schema.ts,schema/users.ts,migrate.ts,migrate.integration.test.ts},src/lib/token-verifier.ts,src/plugins/{auth.ts,auth.test.ts},src/modules/auth/{schemas,repository,service,service.test,routes,auth.integration.test}.ts,src/test/{fake-token-verifier,build-test-app}.ts,src/scripts/export-openapi.ts}`;
`apps/mobile/lib/core/{config/firebase_options.dart,errors/{failure,error_mapper,result}.dart,network/{dio_client,auth_interceptor,retry_interceptor}.dart,storage/secure_storage.dart,routing/guards.dart}`;
`apps/mobile/lib/features/auth/**` (domain 3, data 4 + 2 generated, presentation 8);
`apps/mobile/test/{support/fake_auth_repository.dart,core/{errors,network,routing}/*_test.dart,features/auth/*_test.dart}`;
`docs/phase-reports/phase-1.md`

**modified** — `pnpm-workspace.yaml`; `apps/api/{package.json,src/app.ts,src/lib/env.ts,src/lib/env.test.ts,src/plugins/error-handler.ts,src/modules/health/*.test.ts}`;
`apps/mobile/{pubspec.yaml,pubspec.lock,analysis_options.yaml,README.md,lib/{main,app}.dart,lib/core/config/env.dart,lib/core/routing/router.dart,lib/features/today/**,test/widget_test.dart}`;
`.github/workflows/ci-mobile.yml`; `database/README.md`

**removed** — `apps/api/src/db/schema/index.ts` (barrel moved beside `schema/`), `packages/contracts/README.md`

## DATABASE

- migrations: `0000_users` (up via drizzle-kit; down hand-written; both verified on PG 18.6)
- tables: `users` — `id uuid PK`, `firebase_uid text UNIQUE NOT NULL`, `email text`,
  `timezone text NOT NULL DEFAULT 'Asia/Kolkata'`, `locale text NOT NULL DEFAULT 'en-IN'`,
  `created_at/updated_at timestamptz NOT NULL DEFAULT now()`, `deleted_at timestamptz`;
  index on `lower(email)`. **No password column.**

## APIS

- `POST /v1/auth/session` — exchange a verified Firebase ID token for an app session; creates the row on first call, returns it thereafter; `{ user, isNewUser }`
- `DELETE /v1/auth/session` — sign out; revokes every refresh token for the caller; 204
- Both: Bearer required (default-deny), 10/min/IP, §10 envelope on 401/422/429

## TESTS

```
executed   pnpm test                  (root)
           packages/contracts     7 passed
           apps/api              38 passed   (+ 45 total with contracts)
           packages/core        101 passed   (unchanged)
executed   DATABASE_URL=… pnpm --filter @fitos/api test
           apps/api              45 passed, 0 skipped   (migrations 7, auth routes 9 on real PG 18)
executed   flutter test           47 passed
executed   dart run custom_lint   No issues found
executed   pnpm typecheck / lint  clean;  dart analyze --fatal-infos  clean;  dart format  0 changed
executed   real firebase-admin against fitos-dev-3208b:
             POST /v1/auth/session, no token   → 401 UNAUTHENTICATED
             POST /v1/auth/session, junk token → 401 UNAUTHENTICATED (not 500)
coverage   not measured — §18 gate
```

Spec §31 Phase 1 test requirements, each satisfied:

| Requirement | Where |
|---|---|
| token verification valid / expired / malformed | `plugins/auth.test.ts` (+ revoked, unknown, 6 header-parsing cases) |
| user created on first sign-in only | `auth.integration.test.ts`, `service.test.ts` |
| every protected route returns 401 unauthenticated | `plugins/auth.test.ts` default-deny sweep |
| Flutter auth controller unit tests | `auth_controller_test.dart` (12) |

**CI on `c161858`:** `ci-core` success · `ci-api` success (45/45, 0 skipped on the PG 18 service) · `ci-mobile` success (codegen freshness, analyze, format, 47 tests, **APK built**)

## KNOWN ISSUES

1. **The manual acceptance has not been executed.** "Sign up → sign in →
   token persists across restart → sign out clears it, on a physical device"
   needs an Android app registered in the Firebase console, its config values
   passed as `--dart-define`, a SHA-1 registered for Google Sign-In, and a
   device or emulator — none of which exist on this machine (no Android SDK).
   Every automated path that the manual cycle exercises is tested; the cycle
   itself is yours to run. Instructions in `apps/mobile/README.md`.
2. **Time zone is not sent by the client in Phase 1.** See deviations.
   Every user gets the server default `Asia/Kolkata`, which is correct for the
   entire V1 wedge but must become explicit in Phase 2.
3. **Dart DTOs are hand-written**, not generated from OpenAPI. See deviations.
4. The `users.deleted_at` column exists per §9.2 but nothing sets or reads it
   yet. Phase 17's DPDP delete must remove the row, not set this.
5. `apps/mobile/ios/` remains unmaintained (ADR-003).

## DEVIATIONS FROM SPEC

All deliberate; each with the reason.

- **Migrations live in `database/migrations/` (§29), not `apps/api/src/db/migrations/` (§8.3).**
  The two sections disagree. §29 is the repository layout and the rebuild and
  backup tooling outside `apps/api` need the files, so §29 wins.
- **Down migrations are hand-written.** drizzle-kit is forward-only (§25) but
  rule 17 requires both directions verified. Each up ships with a `down/`
  file and a rollback tool that also removes the journal row, and a test
  proves up → down → up on real Postgres.
- **The schema barrel sits beside `schema/`, not inside it.** drizzle-kit's
  loader is CommonJS and cannot resolve the `.js` re-exports Node ESM needs;
  the config globs leaf files and never touches the barrel.
- **`isNewUser` added to the `/auth/session` response.** §10.1 does not list
  it. It is what lets the client route into onboarding once (Phase 2) without
  a second round-trip.
- **Time zone validation does not use `Intl.supportedValuesOf`.** That list
  is CLDR-canonical (`Asia/Calcutta`, `Europe/Kiev`) and rejects the modern
  IANA names devices actually send. Shape check + `Intl.DateTimeFormat`
  acceptance instead; value stored as sent. Found by the first test.
- **`userProfileSchema.email` is `z.string()`, not `.email()`.** Zod's regex
  rejects addresses Firebase accepts (`a@b.c`); re-validating on the way out
  meant a valid Firebase account could fail to create a session. Firebase is
  the authority.
- **The client does not send a time zone.** `DateTime.now().timeZoneName` on
  Android is an abbreviation (`IST`) the server correctly rejects, and Dart
  cannot produce an IANA name without a platform channel. Sending nothing and
  taking the server default is right for every V1 user; `flutter_timezone`
  plus an explicit profile setting is Phase 2 work.
- **Locale is sanitised client-side.** `Platform.localeName` can be
  `en_US_POSIX` or `zh_Hans_CN`; `deviceLocaleTag()` sends `language[-REGION]`
  or nothing. A locale must never be why a sign-in fails.
- **Firebase config via `--dart-define`, not `flutterfire configure`.** The
  generated file hard-codes one project into source; three projects (§25)
  from one codebase need it injected at build time.
- **Dart DTOs hand-written (§7.1 says openapi-generator).** One endpoint does
  not justify the Java toolchain the generator needs; the OpenAPI document is
  exported and committed so the generator can be wired in Phase 2 with a diff
  to check against. Recorded as the deviation it is.
- **`riverpod_lint` runs via `dart run custom_lint`, not as an analyzer
  plugin.** The legacy `plugins:` key is deprecated in Dart 3.13 and trips
  `--fatal-infos`; the CLI is the stronger guarantee anyway.

## NEXT PHASE

- **Phase 2: Profile, goals & targets** — progressive onboarding (§32, ≤7
  screens), profile/goal/diet/allergy/limitation/preferences/consent tables,
  `computeTargets` wired from `packages/core`, recomposition + maintenance
  goals added to core with tests, onboarding state machine, 18+ gate,
  protein ≤ 2.2 g/kg test.

**Blockers:**

1. **The Phase 1 manual acceptance should be run first** — a phase is not
   complete while its acceptance is unexecuted, and Phase 2's onboarding
   starts from `isNewUser`, which only a real sign-in produces. Register the
   Android app in Firebase, pass the defines, run the cycle on a device.
2. **§36 Q2 — Cloud Run free tier in `asia-south1`** — still open; gates the
   first deploy, not Phase 2.
3. Neon dev database has not yet had `0000_users` applied. Not blocking (local
   Docker is the dev target), but worth doing so the cloud schema matches:
   `DATABASE_URL=<neon direct string> pnpm --filter @fitos/api db:migrate`.
