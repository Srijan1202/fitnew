# ADR-001 — Platform and hosting stack

**Status** Accepted
**Date** 2026-09-07
**Phase** 0
**Supersedes** nothing
**Sources** MASTER-SPEC.md §7 (Flutter), §8 (backend + hosting), §28 (student cloud), §29 (repo)

---

## Context

FitOS needs a mobile app, an HTTP API, a relational database and a small admin
surface, built by a student with no budget and no revenue, targeting Indian
users. Two constraints dominate every choice:

1. **Cost must be ₹0 during development and prototyping, with no expiry.** A
   large credit that runs out in 90 days is worth less than a small allowance
   that never does, because the project outlives the credit.
2. **The deterministic engines in `packages/core` must run in exactly one
   place.** Duplicated fitness logic across a Dart client and a TypeScript
   server is the single most likely way this codebase rots.

---

## Decision

### Client — Flutter

Flutter with **Riverpod 3.x**, **go_router**, **dio**, **drift** (SQLite) and
**freezed**. One codebase, 60fps custom UI, and a mature enough charting story
for §6's design language.

Riverpod over Bloc: compile-safe providers, no `BuildContext` dependency, less
boilerplate, and it doubles as the DI container so a second one (get_it) is
redundant.

drift is not optional. §33 requires a full workout to be loggable in airplane
mode, which needs a real local relational store with migrations, not a
key-value cache.

### The domain-layer rule

**`packages/core` is framework-free TypeScript that runs only on the backend.
It is never ported to Dart.**

A Flutter `domain/` layer holds entities and repository interfaces and *zero*
fitness business rules. Permitted client-side computation is exhaustively:
unit/format display, in-progress session set counts for display only, sorting
and filtering already-fetched lists, and form validation that mirrors
server-side validation.

If a calorie or progression formula is about to be written in Dart, the correct
move is to add an API endpoint instead.

*Why:* every number the product shows — targets, TDEE, trend, progression,
deload, volume, ranking, plate scoring — is a decision the user acts on. Two
implementations drift, and the drift is silent because both look plausible. One
implementation, 100% branch covered, is the only version of this that survives
contact with a second developer.

### Server — Node 22 + Fastify + Zod + Drizzle

Node because it runs `packages/core` unchanged; a Go or Python backend would
force a rewrite of the one asset that already works and is tested.

**Fastify over NestJS.** Nest's DI, decorators and module ceremony solve a
problem this project does not have: the domain logic is already isolated in
`packages/core`, so the framework only needs routing, validation and
serialisation. Fastify plus Zod gives typed validation and a generated OpenAPI
document with far less boilerplate and a faster cold start — and cold start is
a real cost on Cloud Run, not a benchmark curiosity.

**Zod as the single schema source.** One declaration produces runtime
validation, the TypeScript type, and the OpenAPI schema. Any other arrangement
lets the three drift apart.

**Drizzle over Prisma.** SQL-first, thin, excellent inference, tiny cold start,
and migrations are reviewable SQL files in git rather than an opaque engine.

**REST + OpenAPI 3.1, not GraphQL or tRPC.** There is no client-shaped-query
requirement; GraphQL would cost caching and machinery for nothing. tRPC's whole
benefit is end-to-end TypeScript, and our client is Dart.

### Hosting — Cloud Run + **Neon**, not Cloud SQL

This is the one deliberate departure from the originally preferred stack, and
the rest of that stack survives intact: Cloud Run, Firebase Auth, FCM,
Crashlytics, Analytics, Cloud Storage, Cloud Scheduler and Gemini all stay.

Verified 2026-09-07:

| Option | Free allowance | Expiry |
|---|---|---|
| Cloud Run | 2M requests/month, generous vCPU-s and GiB-s | Never |
| **Cloud SQL** | **None** | — |
| **Neon Free** | 0.5 GB/project, 100 CU-hours/month, scale-to-zero, no card | **Never** |
| Supabase Free | 500 MB, 50k MAU | Never, but **pauses after 7 days idle** |
| GCP trial | $300 | 90 days |

**Cloud SQL is rejected.** Its smallest instance runs continuously and costs
roughly $10–30/month from the first day and forever. That is the single largest
avoidable line item in the entire design, and it buys nothing an MVP needs. At
zero revenue it is the cost most likely to kill the project outright.

**Supabase is rejected** for a different and more disqualifying reason: the free
tier pauses a project after 7 days of inactivity. An app that is dead on Monday
morning because nobody opened it over the weekend is not a product.

**Neon is chosen.** Standard Postgres, scales to zero, ₹0, no credit card, and a
free plan that does not expire.

### Accepted trade-offs

- **Cold start.** Neon's free-tier scale-to-zero cannot be disabled, so the
  first query after idle adds a few hundred ms. Combined with a Cloud Run cold
  start, a worst-case first request may reach ~1.5–2s. Mitigation: Cloud
  Scheduler pings `/health` every 5 minutes during Indian waking hours, which
  keeps both warm. This must be watched against the 100 CU-hours/month budget
  (roughly 3 hours/day of active compute).
- **0.5 GB storage.** Assumed ample for low thousands of users. Body photos go
  to Cloud Storage and never into the database.

### Portability is the actual insurance

The real hedge against any free tier changing is that nothing here is locked in:
plain Postgres, a containerised Node app, no proprietary datastore. **No
GCP-only service that would create lock-in may be adopted** — no Firestore, no
Datastore, no App Engine-specific APIs. Migrating to Cloud SQL, DigitalOcean or
Azure is a `pg_dump` and a connection-string change, which is why the Azure for
Students and DigitalOcean credits are worth holding as migration insurance
rather than spending now.

### Repository — pnpm monorepo

Justified by two real sharing requirements, not by fashion: `packages/core` is
consumed by the API (and potentially the admin panel), and `packages/contracts`
must stay in lockstep with both the API and the generated Dart client.

`apps/mobile` sits inside the repo as a normal directory and is **not** a pnpm
workspace member — Flutter has its own resolver.

---

## Consequences

**Good**
- ₹0 through development, prototype and small beta, with no expiry date.
- Business logic exists once, in a package that is already 100% deterministic
  and tested.
- Migration to any other Postgres host is a deploy, not a rewrite.

**Bad / accepted**
- Two cold starts on the critical path for the first request after idle.
- A keep-warm job consumes free-tier compute budget that must be monitored.
- Cloud Run free-tier applicability outside Tier-1 US regions is unverified
  (see below) and may force a latency compromise.

**Costs deferred, not avoided**
- Past ~0.5 GB or ~1,000 users, Neon Launch (~₹1,800/month) becomes necessary.
- AI is the dominant variable cost at scale and is controlled separately by
  rate limits, a token budget and the `AI_ENABLED` kill switch.

---

## Open questions this ADR does **not** resolve

Both are flagged in §36 as requiring a human decision, and both are deliberately
left open here rather than assumed:

1. **Does the Cloud Run always-free tier apply identically in `asia-south1`
   (Mumbai)?** Mumbai minimises latency for the VIT wedge, but free-tier
   applicability outside Tier-1 US regions is unverified. Must be confirmed
   before the first deploy. Fallback is `us-central1`, accepting roughly 200ms
   of additional latency.
2. **Does iOS ship in V1?** This determines whether Apple Sign-In is required
   and whether the ~₹8,000/year Apple Developer cost is incurred.

---

## Alternatives considered and rejected

| Alternative | Why not |
|---|---|
| Cloud SQL | No free tier; ~$10–30/month forever from day one |
| Supabase | Free project pauses after 7 days idle |
| Firestore | GCP lock-in; the data model is relational |
| NestJS | Ceremony without benefit; slower cold start |
| Prisma | Heavier runtime and cold start than Drizzle |
| GraphQL | No client-shaped-query need; worse caching |
| tRPC | Benefit is TS end-to-end; the client is Dart |
| React Native | Flutter gives better control over the custom UI in §6 |
| Porting core to Dart | Duplicated business logic — the failure this design exists to prevent |
