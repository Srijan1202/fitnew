# FitOS

A personal fitness operating system for Indian gym-goers, wedged at VIT Vellore
students living in hostels. It answers one question every day: **what should I
do next?**

The authoritative specification is [`docs/MASTER-SPEC.md`](docs/MASTER-SPEC.md).
Where this README and the spec disagree, the spec wins.

**Status: Phase 0 (foundation) complete.** No product features are implemented.

---

## The one rule

> Every number — calorie targets, TDEE, weight trend, load progression, deload
> timing, plate selection, action ranking — is computed by tested TypeScript in
> `packages/core`, never by a language model, and never in Dart.

If Flutter needs a computed value, add an API endpoint. A calorie or progression
formula written in Dart is a specification violation, not a shortcut.

---

## Layout

```
apps/
  api/        Fastify + Zod + Drizzle + pino. Node 22. Deploys to Cloud Run.
  admin/      Next.js App Router. Deploys to Vercel. Built in Phase 16.
  mobile/     Flutter + Riverpod + go_router + dio + drift. NOT a pnpm workspace.
packages/
  core/       The deterministic domain layer. 101 tests. Preserve, don't rewrite.
  config/     Shared tsconfig + eslint.
  contracts/  Reserved. Joins the workspace in Phase 1.
database/     Drizzle migrations and seeds. Empty until Phase 1.
docs/         MASTER-SPEC.md, decisions/ (ADRs), phase-reports/
scripts/      rebuild-derived.ts, mirror-mess.ts, seed.ts. Empty at Phase 0.
docker/       docker-compose.yml (Postgres 16) + Dockerfile.api
```

## Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Node | 22+ | api, admin, core |
| pnpm | 9.15.4 | everything except mobile |
| Docker | any recent | local Postgres |
| Flutter | 3.24+ stable | mobile only |

## Getting started

```bash
pnpm install

# Local Postgres 16 on :5432, with pgcrypto and pg_trgm created at first boot.
pnpm db:up

cp apps/api/.env.example apps/api/.env
pnpm dev:api                       # http://localhost:8080
curl localhost:8080/health         # 200 once Postgres is up, 503 when it isn't
```

OpenAPI UI is served at `/docs`.

```bash
pnpm test          # every workspace package
pnpm typecheck     # strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes
pnpm test:core     # the domain layer alone
```

Flutter is separate, as it does not participate in pnpm:

```bash
cd apps/mobile && flutter pub get && flutter run
```

## Notes that will save you time

- **`/health` returns 503 when the database is unreachable, deliberately.** A
  health check that reports `ok` during an outage is worse than none.
- **`packages/core` is preserve-only.** Its parser is hardened against seven
  real defects in live MessIT data; "simplifying" it re-breaks them. Read the
  comments before changing anything there.
- **Mess nutrition is estimated, always as a range with a confidence.** There is
  no `formatPoint` function, on purpose.
- **The diet classifier fails safe.** An unrecognisable dish stays `unknown`, and
  `unknown` is excluded from vegetarian plates. This asymmetry is deliberate: a
  false "non-veg" hides one menu item, a false "veg" breaks someone's dietary
  commitment.
