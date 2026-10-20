# Full project audit — 2026-10-20

**Scope:** the whole repository at `phase-13` `c729a83` (Phases 0–13): git and phase state, MASTER-SPEC conformance, security, database, API, mobile, CI, dependencies, docs, debt.
**Fixes:** branch `phase-13-audit-fixes` (from `c729a83`). Nothing is merged; `main` stays at `2b7ece9`.

## Findings and what was done

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | High | API dependencies with known advisories: `fastify` 5.2.1 (six high, incl. an auth bypass via malformed URLs), `drizzle-orm` 0.38.4 (SQL identifier escaping), `firebase-admin` 13.0.2 → `node-forge` (RSA signature verification), `@fastify/static` via swagger-ui; `pnpm audit`: 66 (4 critical, 28 high) | **Fixed.** `fastify` 5.12.7, `drizzle-orm` 0.45.4 (+ kit 0.31.11, no schema drift), `firebase-admin` 14.5.0 (no `node-forge`), swagger 9.9.2 / ui 6.1.2, `pino` 10.4.0, `next` 15.5.28, pnpm overrides for transitive patch versions → **no known vulnerabilities**. Malformed-URL probes against the running API were 401/404 before and after. |
| 1a | High (found while fixing) | drizzle 0.44+ wraps driver errors, so unique violations were missed: "second active session" and "set position taken" answered **500 instead of 409** | **Fixed** (`uniqueViolationOf` follows `cause`); unit + integration tests |
| 2 | High | The only real data (Docker volume `docker_fitos-pgdata`) had no backup | **Fixed:** `scripts/backup-local.ps1` (pg_dump, verified with pg_restore, keeps 14, outside the repo). First backup taken and restored into a scratch database: every table's row count matched. Nightly scheduling is one `schtasks` line (left to the owner). |
| 3 | High | No hosted backend (Phase 6.7 paused on GCP billing): the app works only on the PC's LAN, and every IP change needs a rebuild | **Not fixed** — needs the owner (billing; no GCP changes without approval) |
| 4 | High | §18 cap: the check-in alone bottoms out at 35 (the reduce band), so rest/escalation need a training or nutrition penalty | **Owner decision** (Phase 13) |
| 5 | Medium | Every user fixed to Asia/Kolkata: the phone never sent a time zone, and nothing let the user set one (open since Phase 2) | **Fixed:** the IANA zone is read from Android and sent at first sign-in (only in the server's accepted shape); Profile offers the phone's zone when it differs and changes it only on tap |
| 6 | Medium | Rate limit "120/min/user" was really per IP: a hostel's shared NAT address was one bucket for everyone | **Fixed:** per verified user (IP without one), counted after authentication, so junk tokens cannot open buckets; `/auth/session` stays 10/min/IP; `RATE_LIMIT_PER_MINUTE` configurable |
| 7 | Medium | Docs drift: §38 Phases 0–7 all unticked; 6.5/6.6 reports still "NOT complete"; §10.1 missing 13 built routes; `scripts/README` listing files that live elsewhere | **Fixed:** §38 reconciled (genuinely open items kept, with reasons); 6.5/6.6 status lines updated (originals kept); §10.1 amended; README corrected |
| 8 | Medium | CI: no OpenAPI drift check; Node 20 actions deprecated; `ubuntu-latest` moving to Ubuntu 26; Flutter floating on "stable" | **Fixed:** drift check; checkout/setup-node/setup-java @v5; `ubuntu-24.04`; Flutter pinned to 3.47.2 |
| 9 | Medium | The Phase 6.6 "orphan still parks" flake (teardown closing the database mid-drain) | **Fixed:** read-only `SyncEngine.idle`; the suite waits for it; 0 failures in 12 runs |
| 10 | Medium | Unowned spec endpoints: `/exercises/{id}/history`, `/nutrition/targets`, `/meta/config` | **Recorded** in §10.1; feature work for a phase to own (`/meta/config` before beta) |
| 11 | Low | Root `pnpm lint` stopped at the admin scaffold (`next lint` was interactive) | **Fixed:** ESLint 9 + `eslint-config-next`; root lint passes |
| 12 | Low | OpenAPI document declared 3.1.0 but wrote 3.0 `nullable` | **Fixed** by the swagger upgrade (proper 3.1 `type: [x, "null"]`); the Dart conformance sampler reads it |
| 13 | Low | Workout client ids unique globally (food logs per user) | **Not changed** — UUIDv4 collisions are not a practical risk; a constraint migration is not worth the churn |
| 14 | Low | Id-keyed workout writes rely on the service's ownership check (present and tested) | **Not changed** — noted for Phase 17 (defence in depth) |
| 15 | Low | Session summary computes tonnage on the phone (§30 edge, Phase 5) | **Not changed** — display of logged sets, accepted in Phase 5 |
| 16 | Low | §33 pre-caching: tomorrow's plan and the 200 most-used foods are not cached (tomorrow's mess menu is) | **Not changed** — feature work |
| 17 | Low | Flutter packages pinned behind latest; `sqlite3_flutter_libs` marked end-of-life; Kotlin Gradle Plugin warning from firebase plugins | **Not changed** — major upgrades need their own pass with device testing |
| 18 | Low | Phase 12 Progress & Recovery visual polish | **Deferred** by the owner until after Phase 13 |

Everything left open is tracked in the [backlog](../BACKLOG.md).

## What was confirmed solid

- **Secrets:** none in the working tree or anywhere in the 175 commits of history; `.gitignore` covers env files, keys and keystores.
- **Auth:**
  - Every `/v1` route requires a verified token; no route opts out.
  - The hook checks the matched route, and handlers also require a user.
  - `/docs` is off when hosted.
- **Database:**
  - 17 migrations, each with a tested hand-written down;
  - all eight §9.3 indexes present;
  - schema and migrations in sync.
- **§30:** no Dart implementation of server-owned rules.
- **CI on the Phase 13 head:** green on all three workflows.

## Verification of the fixes (local, all passing)

| Suite | Before | After |
|---|---|---|
| Core | 874 | 874 |
| Contracts | 79 | 79 |
| API | 455 | **460** (+ per-user rate limit ×2, unique-violation unwrapping ×3) |
| Flutter | 627 | **634** (+ time-zone channel ×4, sign-in ×1, Profile ×2) |

- **Static checks and builds:** root typecheck and ESLint (now including admin), every package build (admin included), `dart analyze --fatal-infos`, custom_lint and `dart format` are clean.
- **Dependencies:** `pnpm audit --prod` reports no known vulnerabilities.
- **Docker image:** the API image builds, and the upgraded modules load on Node 22.
- **Flake:** the Phase 6.6 orphan test passed 12 consecutive runs.
- **Backup:** written, then restored into a scratch database with every row count matching.
