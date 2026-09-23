# ADR-012 — Hosted closed alpha on Cloud Run (Mumbai) with Neon (Singapore)

**Status** ACCEPTED for Phase 6.7 (owner, Gate 6.7-0, 2026-09-23)
**Date** 2026-09-23
**Affects** ADR-001 (stack), MASTER-SPEC §8.4 (hosting), §24 (secrets), §25 (DevOps), §27 (cost) — MASTER-SPEC itself is not edited (owner instruction: Phase 6.7 is an interim phase)

## Context

Phase 6.6's closed alpha ran against the owner's PC over the LAN, with the
address compiled into the APK. Phase 6.7 moves the API to a hosted
backend that the S24 can reach from any network over HTTPS, without changing
what the app does. ADR-001 already chose Cloud Run + Neon; its two open
questions were the region and the free tier outside Tier-1 US regions.

Verified 2026-09-23 (sources in `docs/phase-reports/phase-6.7.md`):
- `asia-south1` is a **Tier 1** Cloud Run region, and the request-based free tier applies.
- Neon has **no India region**; Singapore is the closest.
- Neon Free: 100 CU-h and 0.5 GB per project; scale to zero after 5 minutes (can't be disabled); a 6-hour restore window.
- Cloud Run domain mapping is Preview and not offered in `asia-south1`.

## Decision

1. **Where it runs:**
   - Cloud Run service `fitos-api-alpha`, `asia-south1`, in project `fitos-dev-3208b`.
   - Settings: request-based CPU, 1 vCPU / 512 MiB, concurrency 40, timeout 180 s, min 0 / max 2 instances.
   - Public ingress; application-level Firebase authentication, as on the LAN.
   - Startup probe on the new process-only `GET /livez`. `/health` stays a database check and is never polled on a schedule, so Neon can sleep.
2. **Database:** Neon project `fitos-alpha`, AWS Singapore, Postgres 18.
   - `fitos_migrator` owns the schema and is used only by jobs.
   - `fitos_app` has row access only and is used by the service.
   - Existing development databases are untouched. The Phase 6.6 data is restored once (O4).
3. **Releases:**
   - CI pushes the smoke-tested image to Artifact Registry through Workload Identity Federation. The CI identity may **only** push images.
   - The owner releases with `scripts/cloudrun/deploy.ps1`: migrate job (same image) → a revision with no traffic → smoke on its tagged URL → traffic.
   - Rollback moves traffic to the previous revision.
   - Migrations are forward-only and backward-compatible; never run at server boot.
4. **Secrets:**
   - Four Secret Manager secrets, each readable only by the identity that needs it.
   - Firebase Admin uses the runtime identity (Application Default Credentials); no key file exists in the cloud.
   - A hosted server **refuses to boot** without a real `CONSENT_IP_SALT` and an explicit `TRUST_PROXY`.
5. **Client address:** `TRUST_PROXY` is a hop count. Google's front end appends to a client-supplied `X-Forwarded-For`, so trusting the whole chain (Phase 6.6's `true`, harmless on the LAN) would let a caller choose its own rate-limit key.
6. **Unavailable is not a bug:** an unreachable database answers **503 `UPSTREAM_UNAVAILABLE`**, not 500. The app's handling of 502/503/504 as temporary is Gate 6.7-2.
7. **Rate limits stay in memory** (no Redis):
   - Per instance, so ≤ 2× with max 2 instances, and reset on cold start.
   - The AI chat limit is keyed per user (O7).
8. **No published docs:** `/docs` and `/docs/json` aren't registered in hosted environments.

## Consequences

**Good:**
- About ₹0 a month at alpha scale.
- No server to patch.
- HTTPS without a domain.
- One image serves, migrates and seeds.
- Rollback in seconds.
- The LAN setup is unchanged: `NODE_ENV=development` keeps every Phase 6.6 default.

**Bad / accepted:**
- **Mumbai ↔ Singapore database latency** (~60 ms per round trip, several per request): measured in Gate 6.7-3 against a warm p95 ≤ 1.5 s. The alternative, if it fails, is both services in a US region.
- **Cold starts:** Cloud Run plus a Neon resume make the first request after idle slower.
- **Loose rate limits:** per-instance counters allow up to 2×.
- **Blaze plan:** the Firebase project moves to Blaze when billing is attached.
- **Custom domain** `api.tryfitos.me` needs Firebase Hosting rewrites later: not configured in this ADR.

**Revisit at launch:** separate staging/production projects (spec §25), a shared rate-limit store or edge limits, image slimming, the region pairing.
