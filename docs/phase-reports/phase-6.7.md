## PHASE 6.7 — Hosted backend (Cloud Run) + external HTTPS access — IN PROGRESS

**Status:** Gate 6.7-0 **approved** (owner, 2026-09-23: O1–O8 as recommended; domain `tryfitos.me`
claimed, not configured). Gate 6.7-1 (server C1–C8) **implemented, awaiting owner approval** —
approved by the owner. Gate 6.7-2 (hosted mobile profile) **implemented, awaiting owner approval** —
see the Gate 6.7-2 section at the end. No cloud resource created; nothing merged.

**Branch** `phase-6.7` from the frozen Phase 6.6 commit `7f2b7c3` · **Not in MASTER-SPEC** (owner
instruction: an intermediate phase; Phase 7 remains *Food database*) · Supersedes the earlier
GCE e2-micro + Caddy proposal (owner decision 2026-09-23: Cloud Run).

---

### Verified external facts (2026-09-23)

| Fact | Value | Source |
|---|---|---|
| Neon Free — compute | 100 CU-hours / project / month; autoscaling up to 2 CU | [neon.com/docs/introduction/plans](https://neon.com/docs/introduction/plans) |
| Neon Free — storage | 0.5 GB / project; over the limit, inserts / updates / deletes fail | same |
| Neon Free — projects / branches | 100 projects; 10 branches / project | same |
| Neon Free — scale to zero | after 5 min; **cannot be disabled** | same |
| Neon Free — restore window | 6 hours (up to 1 GB-month), no charge | same |
| Neon Free — egress | 5 GB / project / month | same |
| Neon Free — over CU-hours or egress | "compute is suspended until the next billing period or until you upgrade" | same |
| Neon idle rule | suspends after 5 min with **no active queries**; idle connections do not keep it awake and are closed | [neon.com/docs/introduction/compute-lifecycle](https://neon.com/docs/introduction/compute-lifecycle) |
| Neon connections | 0.25 CU: 104 `max_connections`, 7 reserved → 97; the pooler runs PgBouncer in transaction mode and supports protocol-level prepared statements | [neon.com/docs/connect/connection-pooling](https://neon.com/docs/connect/connection-pooling) |
| Neon regions | 8 AWS regions, **no India region**; closest to Mumbai is `aws-ap-southeast-1` (Singapore) | [neon.com/docs/introduction/regions](https://neon.com/docs/introduction/regions) |
| Cloud Run in `asia-south1` (Mumbai) | available, **Tier 1** pricing | [cloud.google.com/run/pricing](https://cloud.google.com/run/pricing) |
| Cloud Run free tier (request-based) | 180,000 vCPU-s, 360,000 GiB-s, 2M requests per month per billing account, applied as a spending discount at Tier 1 prices | same |
| Cloud Run Tier 1 prices (request-based) | $0.000024 / vCPU-s · $0.0000025 / GiB-s · $0.40 / million requests; idle instances that aren't minimum instances aren't charged | same |
| Cloud Run jobs | instance-based billing, 1-minute minimum; free 240,000 vCPU-s + 450,000 GiB-s / month | same |
| Cloud Run egress | Premium tier; the 1 GiB/month free egress applies **within North America only** | same |
| Container contract | listen on `0.0.0.0:$PORT` (default 8080); in-memory filesystem (counts against memory); SIGTERM, then SIGKILL after **10 s**; with request-based billing, CPU only while requests run | [docs.cloud.google.com/run/docs/container-contract](https://docs.cloud.google.com/run/docs/container-contract) |
| Probes | default: a TCP startup probe; probes are billed for CPU/memory but not per request; HTTP probe paths are reachable from outside | [docs.cloud.google.com/run/docs/configuring/healthchecks](https://docs.cloud.google.com/run/docs/configuring/healthchecks) |
| Custom domains | Cloud Run domain mapping is **Preview** and **not available in `asia-south1`**; use a global external Application Load Balancer or Firebase Hosting | [docs.cloud.google.com/run/docs/mapping-custom-domains](https://docs.cloud.google.com/run/docs/mapping-custom-domains) |
| Firebase Hosting → Cloud Run | rewrites supported in `asia-south1` | [firebase.google.com/docs/hosting/cloud-run](https://firebase.google.com/docs/hosting/cloud-run) |
| Ingress `all` | the `run.app` URL is reachable from the internet; the default URL can be disabled later | [docs.cloud.google.com/run/docs/securing/ingress](https://docs.cloud.google.com/run/docs/securing/ingress) |
| `X-Forwarded-For` at Google's front end | appended to any value the client supplied; earlier entries are **not verified** | [cloud.google.com/load-balancing/docs/https](https://cloud.google.com/load-balancing/docs/https) |
| Artifact Registry | 0.5 GiB storage free per billing account; then ~$0.10 / GiB-month | [cloud.google.com/artifact-registry/pricing](https://cloud.google.com/artifact-registry/pricing) |
| Secret Manager free | 6 active secret versions, 10,000 access operations, 3 rotation notifications / month per billing account | [cloud.google.com/secret-manager/pricing](https://cloud.google.com/secret-manager/pricing) |

Not verified here, to confirm at the stated gate:
- Whether `http://…run.app` redirects to HTTPS (Gate 6.7-3, X4).
- The exact `X-Forwarded-For` shape on a `run.app` request (Gate 6.7-3).
- Cloud Logging's free ingestion allotment.
- Internet egress price from Mumbai.
- Firebase Hosting's rewrite timeout (relevant only when the domain arrives).
- Whether Neon Free offers an IP allow-list.

---

### 1. DECISIONS LOCKED (owner, 2026-09-23)

- **Hosting:** Google Cloud Run, `asia-south1`; minimum instances 0; maximum 2–3; request-based CPU; managed HTTPS on the `run.app` URL; rollback through revisions.
- **Database:** Neon Free, a dedicated project (e.g. `fitos-alpha`); no hosted data in any existing development database; no paid upgrade unless usage requires it.
- **AI:** Gemini, `gemini-3.6-flash`; the key stays on the server only.
- **Firebase:** keep `fitos-dev-3208b`; Firebase Auth unchanged.
- **Registry:** Google Artifact Registry.
- **Secrets:** Google Secret Manager; never in the image, the repo or the APK.
- **Deployment:** GitHub Actions may build, test and publish the image; deploys start manual; the repo holds no credential that can deploy to GCP.
- **Mobile:** the LAN alpha profile unchanged; a separate hosted profile, HTTPS only, rejecting HTTP and IP-literal URLs, showing the hosted host in the sign-in / diagnostic UI.
- **Health Connect:** stays on the device (Phase 6.6 B4).
- **Security:** Firebase auth at the application; public ingress; audit rate limiting and CORS (don't change them blindly); `/livez` checks only the process; `/health` is a database check, not a frequent probe; no public docs or Swagger in production; no secrets or sensitive payloads in logs.
- **Domain:** TBD (GitHub Student Pack later); the `run.app` URL until then.

### 2. DECISIONS STILL OPEN

| # | Decision | Options | Recommendation |
|---|---|---|---|
| O1 | GCP project for Cloud Run, Artifact Registry and Secret Manager | (a) `fitos-dev-3208b` itself; (b) a new project with cross-project IAM to Firebase | **(a).** The runtime identity then verifies Firebase tokens with no cross-project setup. Attaching billing moves the Firebase project to the **Blaze** plan; Auth for email / Google stays free, and budget alerts cover the rest. (b) isolates billing but adds a cross-project grant and an unverified API-quota path. |
| O2 | Neon region | Singapore (`aws-ap-southeast-1`, the closest to Mumbai; there is no India region) vs a US region | **Singapore**, with the latency measurement in Gate 6.7-3 as the check (R1) |
| O3 | Maximum instances | 2 or 3 | **2** (rate limits at most 2×, ≤ 10 database connections, bounded cost) |
| O4 | Data | (A) restore the Phase 6.6 local database into `fitos-alpha`; (B) start fresh | **(A)** if you want your history: IDs stay the same, so the phone's local copy stays consistent. (B) requires signing out or clearing app data before switching (§8). |
| O5 | Image publishing | (a) GitHub Actions → Artifact Registry through Workload Identity Federation, allowed only to push images to that one repository; (b) you build and push from the PC | **(a).** No stored key; the identity **can't deploy** (Artifact Registry writer only). |
| O6 | Backups | (a) a nightly `pg_dump` Cloud Run job + Cloud Scheduler writing to a Cloud Storage bucket, kept 14 days; (b) a manual weekly dump | **(a).** Neon Free keeps only 6 hours of restore history. |
| O7 | AI rate-limit key | keep per IP (what the code does now) or per user (what the docs say) | **Per user**, a small change in Gate 6.7-1 that fixes the mismatch between docs and code |
| O8 | Gemini key for hosting | reuse the dev key or a new key | **A new key**, so each can be revoked on its own; free tier only while you're the only user (§19.3) |

### 3. CLOUD RUN ARCHITECTURE

```
S24 ──HTTPS──> https://fitos-api-alpha-<hash>.asia-south1.run.app   (Google-managed TLS)
                 │  Cloud Run service fitos-api-alpha (asia-south1, min 0 / max 2, request-based CPU)
                 │  image asia-south1-docker.pkg.dev/<PROJECT>/fitos/fitos-api:<git-sha>
                 │  runs as fitos-api-runtime@<PROJECT>.iam.gserviceaccount.com
                 ├──> Neon fitos-alpha (aws-ap-southeast-1, Postgres 18, TLS, role fitos_app)
                 ├──> Gemini REST (key from Secret Manager, server only)
                 ├──> Firebase Admin (Application Default Credentials: the runtime identity, no key file)
                 └──  Secret Manager: secrets injected as env vars when an instance starts
Cloud Run jobs (same image): fitos-migrate-alpha · fitos-seed-alpha (role fitos_migrator)
                             fitos-backup-alpha (postgres:18-alpine → Cloud Storage bucket), Cloud Scheduler nightly
S24 → Health Connect → FITOS on the device (unchanged; never reaches Cloud Run or Gemini)
```

**Names:**
- **Service:** `fitos-api-alpha`.
- **Jobs:** `fitos-migrate-alpha`, `fitos-seed-alpha`, `fitos-backup-alpha`.
- **Artifact Registry:** Docker repository `fitos` in `asia-south1`; image `asia-south1-docker.pkg.dev/<PROJECT_ID>/fitos/fitos-api:<40-char git sha>`, with immutable tags and a cleanup policy (keep the 3 newest, delete untagged). The image is ~619 MB uncompressed, so the 0.5 GiB free tier holds only a few.
- **Service accounts:** `fitos-api-runtime`, `fitos-jobs`, `fitos-ci-publisher`.
- **Neon:** project `fitos-alpha`; roles `fitos_migrator` and `fitos_app`.
- **Backup bucket:** `<PROJECT_ID>-fitos-alpha-backups`.

**Service configuration (answers C, D):**

| Setting | Value |
|---|---|
| Ingress / authentication | `all` + allow unauthenticated (A, B) |
| CPU / memory | 1 vCPU, 512 MiB |
| Concurrency | 40 |
| Request timeout | 180 s |
| Instances | min 0, max 2 (O3) |
| Billing | request-based |
| Startup probe | HTTP `GET /livez` |
| Liveness probe | none |
| Environment (non-secret) | `NODE_ENV=production`, `LOG_LEVEL=info`, `FIREBASE_PROJECT_ID=fitos-dev-3208b`, `GEMINI_MODEL=gemini-3.6-flash`, `AI_TIMEOUT_MS=25000`, `AI_MAX_OUTPUT_TOKENS=2048`, `TRUST_PROXY=<hops, verified in 6.7-3>`. `PORT` is injected by Cloud Run and not set. |

- **Why the request timeout is 180 s:** an AI turn can make up to 5 model calls at 25 s each (~125 s), while the app waits 60 s.
- **Why the database pool stays at 5:** 2 instances × 5 connections = 10, well under Neon's 97.
- **A, B:** yes to public ingress, and yes to "allow unauthenticated". Cloud Run's own IAM check accepts only Google-signed identity tokens, not Firebase ID tokens, so authentication stays in the app: default-deny on `/v1`, Firebase verification with revocation. The unauthenticated routes are `/livez`, `/health`, and in production nothing else (docs off).
- **D:** `max-instances=2` is appropriate. One instance at concurrency 40 is far more than a closed alpha needs; the second covers a cold start overlapping a draining instance. 3 is acceptable, but multiplies per-instance rate limits by 3.

### 4. GCE → CLOUD RUN CHANGES (to the earlier proposal)

| Earlier (GCE) | Now (Cloud Run) |
|---|---|
| e2-micro VM in us-east1, static IP, standard disk, swap | Cloud Run service in `asia-south1`; no VM, disk, swap or IP |
| Caddy + Let's Encrypt, **domain required** | Google-managed HTTPS on `run.app`; **no domain needed now** |
| Caddy's 308 HTTP → HTTPS redirect | Cloud Run's behaviour on `run.app`, to verify (X4) |
| Custom domain via a DNS A record | **Domain mapping unavailable in `asia-south1`**; later via Firebase Hosting rewrites (free tier) or a global load balancer (paid). Decided when the domain exists. |
| VPC firewall 80/443, SSH over IAP, OS hardening, automatic upgrades, log rotation | Not applicable; no server to administer |
| `/etc/fitos/*.env` files (mode 600) | Secret Manager, injected as environment variables; the runtime identity can read only its own secrets |
| GHCR public image | Artifact Registry `asia-south1`, pushed through Workload Identity Federation (Artifact Registry writer only) |
| `deploy.sh` with automatic rollback | Owner-run deploy script: migrate job → `gcloud run deploy --no-traffic --tag` → smoke-test the tagged URL → shift traffic. Rollback = `update-traffic` to the previous revision. |
| One-off `docker run … migrate.js` on the VM | **Cloud Run Job** `fitos-migrate-alpha` (same image) |
| Nightly cron on the VM → Cloud Storage | Cloud Run Job + Cloud Scheduler (O6) |
| Neon AWS `us-east-1` next to the VM | Neon `aws-ap-southeast-1` (Singapore) next to Mumbai; there's no India region (O2) |
| `TRUST_PROXY` = the Caddy network | `TRUST_PROXY` = the verified hop count for Google's front end |
| Docker health check on `/livez` | Cloud Run startup probe on `/livez` |
| Rate limiter consistent (one process) | Per-instance counters: limits ≤ 2× with max 2 (E) |
| Firebase via the VM's attached identity | Firebase via the runtime identity (same code path, `applicationDefault()`) |
| Costs: possible IPv4 charge | Costs: egress outside North America, Artifact Registry over 0.5 GiB, etc. (§10) |
| S24 X13 "VM stopped" | S24 X13 "database unavailable": a revision given a wrong database secret gives 503s, then traffic goes back to the working revision |
| Always on, no cold start | Cold start (Cloud Run ~1–2 s, plus a Neon resume) on the first request after idle; measured (X15) |

Unchanged: the scope and phase boundaries, F1–F8, the mobile hosted profile, the secret-scan acceptance, the S24 matrix (X1–X17, adapted above), the cutover rule, and "nothing merged".

### 5. REPOSITORY COMPATIBILITY AUDIT (at `7f2b7c3`)

| Area | Finding | Compatible? |
|---|---|---|
| PORT | `env.ts` reads `PORT` (default 8080) | ✅ |
| Binding | `server.ts`: `listen({ host: '0.0.0.0' })` | ✅ |
| SIGTERM | `server.ts`: SIGTERM/SIGINT → `app.close()` → exit | ✅ Requests still running when the 10 s grace ends (a long AI turn) are cut off; the client sees an error. AI turns aren't queued work. |
| Statelessness | No sessions or caches in memory; the volume cache is in the database (`muscle_volume_weekly`) | ✅ |
| Filesystem | Runtime reads only the Firebase key file, and only when `GOOGLE_APPLICATION_CREDENTIALS` is set (not on Cloud Run). `migrate.ts` / `seed.ts` read `database/…` (jobs only). No runtime writes. | ✅ |
| In-memory state | `@fastify/rate-limit` counters (per instance, reset on cold start); Firebase Admin's public-key cache (harmless) | ⚠ (E) |
| Rate limiting | Global 120/min, `/auth/session` 10/min, AI 20/min, **all keyed by client IP** (no `keyGenerator`). The AI limit is documented as per-user. | ⚠ (E, O7) |
| `trustProxy` | `true`: trusts the whole `X-Forwarded-For` chain, whose first entry the client controls | ❌ **must change** (C2) |
| Background jobs | None (the only timer is the per-request AI abort) | ✅ fits request-based CPU |
| Long requests | AI turn up to ~125 s worst case; everything else short | ✅ with a 180 s timeout |
| WebSockets / SSE | None | ✅ |
| Docker image | Multi-stage, non-root, `node:22-alpine`, boots in CI; **no `database/` directory** in the runtime stage; ~619 MB (dev dependencies included) | ❌ for migrations (C1); size is acceptable |
| Health | `/health` pings the database (503 if unreachable); **no `/livez`** | ❌ (C4) |
| Database pool | postgres.js, max 5, idle 20 s, connect 10 s; connections opened lazily; Neon closes idle connections on suspend | ✅ The first query after a suspend is tested (X15, R3) |
| Database failure | A database connection error falls to the generic handler → **500 `INTERNAL`** | ❌ The app parks the queue (C5) |
| Migrations | Drizzle migrator via `tsx src/db/migrate.ts`, recording to `drizzle.__drizzle_migrations`; `dist/db/migrate.js` has the same command-line entry; files resolve to `/app/database/migrations/` | ✅ once `database/` is in the image (C1) |
| Seed | `dist/db/seed.js` command-line entry, idempotent by slug, one transaction | ✅ once `database/seeds` is in the image |
| Startup | `loadEnv` validates env and fails fast; Firebase Admin initialises at build time without a network call; the database is lazy | ✅ Cold start in a few seconds; the default probe allows 240 s |
| Firebase credentials | `applicationDefault()` when `GOOGLE_APPLICATION_CREDENTIALS` is unset | ✅ no code change |
| Production guards | `CONSENT_IP_SALT` silently defaults to a dev value; `/docs` + `/docs/json` registered always | ❌ (C3) |
| CORS | `@fastify/cors` installed but **not registered**: no `Access-Control-Allow-*` headers, so browsers can't read responses; the app isn't a browser | ✅ keep as is (audited) |
| Logging | pino JSON when `NODE_ENV≠development`. Redacts authorization, cookie, email, token, weight, weightKg, photo_path. The request log has method, URL, host, remote address and port only. | ✅ Cloud Run keeps stdout in Cloud Logging |

**Code changes required (NOT made).** Gate 6.7-1, server:
- **C1:** the runtime image includes `database/migrations` and `database/seeds`.
- **C2:** a `TRUST_PROXY` setting (number of hops, or a list of addresses). Required when `NODE_ENV=production`; when unset it keeps today's behaviour, so the LAN setup is unchanged.
- **C3:** in production, `CONSENT_IP_SALT` is required and `/docs` is not registered.
- **C4:** `GET /livez`, process-only, no database access.
- **C5:** Postgres connection-class errors (refused, reset, timed out, `57P01`/`57P03`/`53300`) answer **503 `UPSTREAM_UNAVAILABLE`**.
- **C6 (O7):** the AI limit keyed per user.
- **C7:** CI: in-image migrate / seed / boot smoke test with `NODE_ENV=production`, and an Artifact Registry push job that is skipped until the Workload Identity variables exist.
- **C8:** owner deploy / rollback scripts (PowerShell), the Cloud Run runbook, and ADR-012.

Gate 6.7-2, mobile:
- **C9:** hosted build profile.
- **C10:** 5xx / 429 handling as "temporary" (L).
- **C11:** the sign-in backend line for the hosted flavour.

No schema migration. No change to the sync architecture beyond C10's classification.

**E (rate limits across instances):** Yes, the in-memory limiter is per instance. With max 2 instances the effective ceilings are ≤ 2×: 240/min per IP, 20/min per IP on `/auth/session`, and 40/min on AI (per user after C6). Counters also reset on cold start. The smallest safe alpha answer is **no Redis**:
- cap at 2 instances;
- document the 2× bound;
- keep AI cost bounded by the upstream Gemini quota and budget alerts;
- revisit (a shared store or a load-balancer rate limit) at launch.

**F (persistent local filesystem):** Nothing depends on one. **G (process state that must survive a restart):** Nothing; only rate-limit counters, which may reset.

### 6. DATABASE / MIGRATION PLAN

- **Neon project `fitos-alpha`:** Postgres 18, `aws-ap-southeast-1` (O2).
  - Compute autoscaling 0.25–0.5 CU. At 0.25 CU, the 100 CU-h cover ~400 active hours a month.
  - Scale to zero after 5 minutes (fixed on Free).
  - The existing Neon dev project, local Docker `fitos` (the accepted 6.6 data) and `fitos_test` are **not touched**. Under O4(A), local `fitos` is only read by `pg_dump`.
- **Roles (J):**
  - Once, as the Neon owner: `CREATE EXTENSION pgcrypto, pg_trgm`.
  - `fitos_migrator` owns the schema: all data-definition changes, the `drizzle` migration table, the seed.
  - `fitos_app` gets `SELECT, INSERT, UPDATE, DELETE` on all tables and `USAGE` on sequences in `public`, plus `ALTER DEFAULT PRIVILEGES FOR ROLE fitos_migrator` so future tables inherit those grants. No schema-change rights, no access to the `drizzle` schema.
  - Two connection strings, each in its own secret. TLS required (`sslmode=verify-full` if postgres.js accepts it, otherwise `require`; tested in 6.7-3). The **direct** endpoint for both; the pooled endpoint is a fallback if connection churn appears.
- **Mechanism (H, I): Cloud Run Jobs.**
  - The chosen mechanism fits the repository as it is: the same image, credentials that stay in Secret Manager, logs in Cloud Logging, and nothing on the PC.
  - `fitos-migrate-alpha`: `node apps/api/dist/db/migrate.js up`.
  - `fitos-seed-alpha`: `node apps/api/dist/db/seed.js`.
  - Both use the new image's tag and run as `fitos-jobs`, which can read only the migrator secret.
  - The server never migrates at startup (the code already says so).
- **Order for every release:**
  1. CI pushes `fitos-api:<sha>`.
  2. `gcloud run jobs update fitos-migrate-alpha --image …:<sha>` and `execute --wait`. Idempotent; a failure **stops the release**.
  3. The seed job, only when `database/seeds` changed.
  4. `gcloud run deploy fitos-api-alpha --image …:<sha> --no-traffic --tag sha-<7>`.
  5. Smoke-test the tagged URL: `/livez` 200, `/health` 200, `/v1/ai/status` 401, `/docs` 404.
  6. `update-traffic --to-latest`.
- **Migration safety:**
  - Forward-only, expand → migrate → contract (spec §25), so the previous revision always runs on the new schema.
  - Before any release that contains a migration: an on-demand run of the backup job. Neon's 6-hour restore window is the second line.
  - Phase 6.7 itself applies `0000`–`0008` to an empty database and adds none.
- **Data cutover (O4):**
  - **(A)** `pg_dump --no-owner --no-privileges` of local `fitos`, restored into `fitos-alpha` as `fitos_migrator`, then grants re-applied. Counts are compared table by table.
  - **(B)** migrate + seed only.
- **Backups (O6):**
  - `fitos-backup-alpha` runs `postgres:18-alpine` with a Cloud Storage bucket mounted: `pg_dump -Fc` → `/backup/fitos-YYYY-MM-DD.dump`. It wakes Neon for ~1 minute per night, well under 1 CU-h a month.
  - Cloud Scheduler triggers it nightly; the bucket deletes objects after 14 days.
  - Acceptance includes a **restore drill** into a throwaway container or a Neon branch, never the dev database.

### 7. SECRETS PLAN

**Minimum Secret Manager secrets: 4 active versions, under the 6 free.** Destroy superseded versions after each rotation.

| Secret | Read by | Replaces | Rotation |
|---|---|---|---|
| `fitos-gemini-api-key` | `fitos-api-runtime` | `docker/.env` `GEMINI_API_KEY` (the dev key stays local) | On any exposure: add a version, redeploy, revoke the old key in AI Studio, destroy the old version |
| `fitos-db-url-app` | `fitos-api-runtime` | local `DATABASE_URL` | On exposure: reset the `fitos_app` password in Neon, add a version, redeploy |
| `fitos-db-url-migrator` | `fitos-jobs` | — | Same, for `fitos_migrator` |
| `fitos-consent-ip-salt` | `fitos-api-runtime` | the dev default | Only if leaked (affects only new consent hashes) |

- **Firebase Admin (answers question 11):** **no secret.** Cloud Run exposes the runtime identity through the metadata server; `GOOGLE_APPLICATION_CREDENTIALS` stays unset, so `applicationDefault()` is used (already implemented). Grant `fitos-api-runtime` the role `roles/firebaseauth.admin` on `fitos-dev-3208b`, which `verifyIdToken(…, checkRevoked)` and `revokeRefreshTokens` need. The local key in `apps/api/.secrets` never leaves the PC.
- **Secrets as environment variables:** revisions reference `latest`. A rotation takes effect on the next deploy (a new revision), which is deterministic.
- **Continuous integration:** Workload Identity Federation (O5). The GitHub repository **variables** (not secrets) hold the project number, pool and provider IDs, and the publisher account's email. The provider only accepts `Srijan1202/fitnew` on `phase-6.7`/`main`. `fitos-ci-publisher` has `roles/artifactregistry.writer` on the `fitos` repository **only**: it cannot deploy, read secrets or touch Cloud Run.
- **Never:** secrets in Git, the image (`.dockerignore` already excludes `.env`, `.secrets` and key patterns), the APK, logs or GitHub. Acceptance repeats the Phase 6.6 Gate 8 scans across git history, image layers, every APK entry and Cloud Logging.

### 8. MOBILE HOSTED PROFILE PLAN (answers M)

- **New `tool/hosted.ps1`** (sharing helpers with `alpha.ps1`, which is **unchanged**):
  - Reads a gitignored `hosted.env` (committed: `hosted.env.example`) with the same five Firebase keys plus `API_BASE_URL`.
  - **Refuses:** any scheme other than `https`; an explicit port other than 443; an IPv4 or IPv6 literal host; `localhost`, `10.0.2.2` or `127.0.0.1`. It also requires `/health` to answer 200 over HTTPS before building.
  - Build settings: `FLAVOR=hosted`, `--build-name=1.0.0-alpha.2 --build-number=3` (pubspec, and so the LAN build, unchanged).
- **Network security:** `build.gradle.kts` already writes a config with **no** cleartext exception when the scheme is `https`. Gate 6.7-2 verifies this on the APK (`base-config cleartextTrafficPermitted=false`, no `domain-config`), and verifies the LAN build's config is byte-identical to 6.6's.
- **UI:** the sign-in line `Backend <host> · FITOS <version>` appears for `alpha` **and** `hosted` (C11). For the hosted build, the host shown is the `run.app` host with no port. Profile's build line already shows flavour and host.
- **Same `com.example.fitos` package:** only one profile is installed at a time. Moving to a different package would need a new Firebase Android app, which would change auth config and is out of scope.
- **Switching** follows O4:
  - (A) Install the hosted APK over the LAN one.
  - (B) Sign out first (the 6.6 unsynced-work guard), then install.
  - Going back to LAN later is a development fallback only; the data would diverge.
- **L — how 502/503/504 behave (C10):**
  - A new failure type, `ServiceUnavailable`, named with the host ("FITOS isn't answering at <host> right now. It will retry.") covers:
    - 502 and 504;
    - a 503 without the API's own error format (Google's front end, no instance available);
    - a 503 in the API's own format (`UPSTREAM_UNAVAILABLE`, e.g. database unreachable after C5), keeping the server's message for screens that show it, such as the AI "took too long".
  - A 429 **without** the API's format (Cloud Run with no free instance) → `ServiceUnavailable`. The API's own 429 stays `RateLimited`.
  - `SyncEngine._fail`: `ServiceUnavailable` and `RateLimited` → `_Stop(retry: true)`, the same path as `Offline`. No attempt counted, never parked; the engine wakes itself after 15 s, backing off to 2 min.
  - The retry interceptor stays as is (never re-sends a POST that reached the server).
  - Tests:
    - 2 minutes of 502, then recovery → drains, 0 parked, 0 attempts;
    - the same for 503 and 504;
    - an own-format 503 keeps its message;
    - an own-format 429 waits;
    - a 500 is still an ordinary failure.

### 9. SECURITY AUDIT

| Area | Plan |
|---|---|
| Exposure | Ingress `all`; unauthenticated invocation allowed at the Cloud Run layer; application default-deny on `/v1` (unchanged); public routes are only `/livez` and `/health` (both rate-limited); `/docs` off in production (C3) |
| HTTPS | Managed TLS on `run.app`; the APK can't use cleartext (hosted profile guard + network config); HTTP→HTTPS behaviour verified (X4) |
| CORS | Audited: not registered, so browsers get no cross-origin read access. **Keep unchanged.** |
| Trusted proxy | C2: hop count verified in 6.7-3 by sending a spoofed `X-Forwarded-For` and checking that the logged `remoteAddress` is the real client IP |
| Rate limits | E: ≤ 2× with max 2 instances, reset on cold start, IP-keyed (on mobile data many users share one IP; acceptable for a closed alpha); AI per user (C6) |
| Authentication | Unchanged: Firebase ID token, revocation checked, sign-out revokes |
| Identities | Dedicated service accounts; **not** the default compute account (Editor). Runtime: secret access on its 3 secrets + `firebaseauth.admin`. Jobs: migrator secret only. CI: Artifact Registry writer on one repository. |
| Database | Neon public endpoint, TLS required, strong generated passwords, least-privilege `fitos_app`; IP allow-list not assumed on Free |
| Logging | Pino redaction unchanged; Cloud Run's platform request log records method, URL, status, latency and IP, no bodies or headers; query strings include exercise search terms (acceptable); the scan checks for 0 keys or tokens |
| Secrets | §7 |
| Gemini | Server-side only; per-user limit (C6) + upstream quota; **§19.3: free tier only while you're the only user; a paid tier before any other tester** |
| Health Connect | Unchanged; acceptance X16 re-proves that no health data leaves the phone |

### 10. COST / RISK AUDIT (answers O)

**Expected monthly cost at closed-alpha scale: ₹0 – ~₹100.**

| Item | Estimate | Notes |
|---|---|---|
| Cloud Run service | ₹0 | ~5k requests × ~0.3 s + ~300 AI turns × ~10 s ≈ 4,500 vCPU-s, against 180,000 free |
| Cloud Run jobs | ₹0 | migrate / seed occasionally + backup nightly ≈ 30 × 60 s |
| Artifact Registry | ₹0 up to 0.5 GiB | Keep 3 images; beyond that ~$0.10/GiB-month |
| Secret Manager | ₹0 | 4 of 6 free versions; access only at instance start |
| Cloud Scheduler | ₹0 | 1 job (free allowance per billing account, to verify) |
| Cloud Storage (backups, `asia-south1`) | a few paise | Always Free storage covers US regions only; a few MB a month |
| Internet egress from Mumbai | paise to a few ₹ | The free 1 GiB applies within North America only; alpha traffic ≪ 1 GiB |
| Cloud Logging | ₹0 expected | Free ingestion allotment (to verify); logs are small |
| Neon Free | ₹0 | Over 100 CU-h or 5 GB egress, compute is **suspended** (an outage, not a bill) |
| Firebase Auth | ₹0 | On Blaze if O1(a); email / Google sign-in free |
| Gemini | ₹0 on free tier (you only) | A paid tier is a condition for other testers |
| **Costs that can occur despite free tiers** | — | Minimum instances > 0 (idle billed); Artifact Registry over 0.5 GiB; more than 6 secret versions; extra Scheduler jobs; egress growth; a **global load balancer for the custom domain** (~US$18+/month; Firebase Hosting avoids this); Gemini paid tier; Neon Launch if usage requires it |
| Temporary credits | — | GCP $300 trial: **don't activate** (90 days from activation). Student Pack domain: 1 year. Azure / DigitalOcean credits: unused. |
| Guardrails | — | GCP budget alerts at ₹500 / ₹2,000 / ₹5,000 (spec §27); max-instances 2; Artifact Registry cleanup policy; no minimum instances |

**Risks:**

| # | Risk | Mitigation / acceptance |
|---|---|---|
| R1 | **Mumbai ↔ Singapore database latency** (~60 ms per round trip, several sequential queries per request) | Measure in 6.7-3: authenticated `/v1/training/today` warm p95 ≤ 1.5 s from the S24 on mobile data. If it fails, choose between Cloud Run and Neon both in a US region (Tier 1 as well) or accepting it. Not decided here. |
| R2 | Cold start (Cloud Run + Neon resume) makes the first request slow | Measured (X15); minimum instances stays 0 per the decision |
| R3 | The first query after Neon closes idle connections fails | Test X15; C5 makes it a 503 that the app waits out; fallback: the pooled endpoint or a shorter `max_lifetime` |
| R4 | Neon CU-hours used up (suspended until next month) | Nothing polls `/health`; autoscaling capped at 0.5 CU; weekly usage check; C5 + C10 turn an outage into waiting |
| R5 | The sync queue parks on a proxy or database outage (F1) | C5 + C10 + tests + X12/X13 |
| R6 | Spoofed `X-Forwarded-For` bypasses limits | C2 + a live verification |
| R7 | Per-instance rate limits | max 2; documented bound |
| R8 | Custom domain later needs a load balancer (cost) because domain mapping isn't in `asia-south1` | Plan Firebase Hosting rewrites (free, `asia-south1` supported) when the domain arrives; out of 6.7 scope unless the domain is ready |
| R9 | Blaze plan on the Firebase project (O1a) | Budget alerts; no paid Firebase products enabled |
| R10 | Image size vs the Artifact Registry free tier | Cleanup policy (keep 3); slimming the image is optional later |
| R11 | Gemini free-tier data use | §19.3 condition |
| R12 | Divergence from ADR-001 is now small (Cloud Run, as the spec says) | The region and the Singapore database are recorded in ADR-012; MASTER-SPEC untouched |

### 11. IMPLEMENTATION PLAN FOR GATES 6.7-1 THROUGH 6.7-6

| Gate | Scope | Objective acceptance |
|---|---|---|
| **6.7-1 Server Cloud Run readiness** (repo only) | C1–C8 | All suites green (core, contracts, API incl. new tests for C2–C6, mobile); CI green; the image **migrates, seeds and boots** with `NODE_ENV=production` in CI; `/livez` 200 with the database down; `/health` 503 with the database down; a database-connection error on `/v1` gives 503 `UPSTREAM_UNAVAILABLE`; `/docs` 404 in production; missing salt or `TRUST_PROXY` fails startup in production; with `TRUST_PROXY=1` a spoofed first `X-Forwarded-For` entry doesn't change `request.ip`; the image layer scan finds no secrets; the LAN `docker-compose.yml` still starts unchanged and the 6.6 behaviour holds |
| **6.7-2 Hosted mobile profile** (repo only) | C9–C11 | The new sync tests (§8 L) pass and all 320 existing mobile tests stay green; `hosted.ps1` refuses `http://`, `:8080`, IP literals, `localhost`; the hosted APK's network config has **no** cleartext anywhere; the LAN APK's config is identical to 6.6's; analyze, lint and format clean; CI green |
| **6.7-3 Cloud setup + first deploy** (owner runs the runbook; empty database) | O1 project + billing + budget alerts; enable APIs (Run, Artifact Registry, Secret Manager, IAM Credentials, Scheduler, Storage); service accounts + roles; Workload Identity Federation; Artifact Registry + cleanup; Neon `fitos-alpha` + extensions + roles; 4 secrets; migrate + seed jobs; service deploy | Over HTTPS from outside: `/livez` 200, `/health` 200, `/v1/ai/status` 401, `/docs` 404; `http://` → HTTPS (or recorded as-is); `TRUST_PROXY` verified with a spoofed header; the revision's env shows secret **references** only; the runtime account has exactly the listed roles; the key is in 0 log entries; R1 latency measured and recorded; tagged-revision deploy and one rollback performed successfully |
| **6.7-4 Data + backups** | O4 cutover; the backup job + Scheduler; a restore drill | Journal `0000`–`0008`; seeded exercise count equals local; (A) per-table row counts equal the dump; **local `fitos` counts unchanged before and after**; a backup object exists; the drill restores and counts match |
| **6.7-5 External S24 acceptance** (owner) | X1–X17 (§12), on the hosted APK | All pass, or each failure triaged; any failure in X9–X13 or X16 blocks the gate |
| **6.7-6 Final audit + report** | A Gate-8-style audit + cost after ≥ 3 days of billing + a no-regression check on the 6.6 LAN profile | CI green; secret scans at 0; billing within §10; the report lists what's verified and what's pending; **nothing merged** |

**Order:** 6.7-1 ∥ 6.7-2 → 6.7-3 → 6.7-4 → 6.7-5 → 6.7-6.

**S24 matrix X1–X17** (from the earlier proposal, adapted):
- X1: the install line shows the `run.app` host.
- X2: another Wi-Fi.
- X3: mobile data only.
- X4: `http://` to the `run.app` URL.
- X5: sign-in / sign-out with revocation.
- X6: open more than 1 hour, then used.
- X7: AI chat.
- X8: AI programme generation.
- X9: start → sets → complete; History and Home.
- X10: offline → online.
- X11: Wi-Fi ↔ mobile data switch mid-session.
- X12: a deploy during an open session.
- X13: database unavailable (a revision with a wrong database secret) → waits, not parked → traffic back → drains.
- X14: removed; duplicate of X12 under Cloud Run.
- X15: after more than 10 minutes idle (Cloud Run and Neon cold).
- X16: Health Connect stays on the device.
- X17: the LAN profile still works against local Docker.

### 12. EXACT USER ACTIONS REQUIRED

**Now (Gate 6.7-0):**
1. Approve or amend this report.
2. Answer O1–O8.
3. Optionally claim the GitHub Student Pack domain. Don't configure it.

**Later, at Gate 6.7-3 only after approval** (the runbook from 6.7-1 will list each command):
1. Attach a billing account to the O1 project and create budget alerts (₹500 / ₹2,000 / ₹5,000). Don't activate the $300 trial.
2. Install and authenticate the `gcloud` CLI on the PC (`gcloud auth login`), or run the runbook in Cloud Shell.
3. Create the Neon project `fitos-alpha` (Postgres 18, the O2 region) and give me nothing. You'll paste the two generated connection strings **directly into Secret Manager**, never into chat or files.
4. Create a new Gemini API key for hosting (O8) and put it **directly into Secret Manager**.
5. Run the runbook's commands for the service accounts, IAM, Workload Identity Federation, the registry, jobs and the service. Then add the three GitHub **repository variables** it prints. They are identifiers, not secrets.
6. Under O4(A): approve the one-time read-only `pg_dump` of the local `fitos` database.

---

### Gate 6.7-1 — Server Cloud Run readiness (C1–C8) — implemented 2026-09-23, awaiting approval

Commits: `d06ecf2` (server, C1–C6) · `a5d5f2e` (CI, C7) · `7cfb098` (runbook, ADR-012, scripts, C8)
· this report. Mobile untouched (Gate 6.7-2). `docker/docker-compose.yml` unchanged.

| # | Change | Where |
|---|---|---|
| C1 | Runtime image carries `database/migrations` + `database/seeds`; `node apps/api/dist/db/migrate.js up` / `seed.js` run from the image | `docker/Dockerfile.api` |
| C2 | `TRUST_PROXY` (hop count / `false` / address list); unset keeps Phase 6.6 (`true`) | `lib/env.ts`, `app.ts` |
| C3 | `NODE_ENV=production|staging` refuses the dev `CONSENT_IP_SALT` (or one < 16 chars) and a missing `TRUST_PROXY`; `/docs` + `/docs/json` not registered there | `lib/env.ts`, `app.ts` |
| C4 | `GET /livez` — process only, no database; `/health` unchanged (DB ping) | `modules/health/*`, `openapi.json` (+ `/livez`, additive) |
| C5 | Connection-class database errors (Node network codes, postgres.js `CONNECTION_*`/`CONNECT_TIMEOUT`, SQLSTATE `08xxx`, `57P01-3`, `53300`, followed through `cause`) → **503 `UPSTREAM_UNAVAILABLE`**; everything else still 500 `INTERNAL` | `db/errors.ts`, `plugins/error-handler.ts` |
| C6 | `/v1/ai/chat` 20/min keyed `user:<id>` at `preHandler` (after auth); unauthenticated requests are refused by auth first | `modules/ai/routes.ts` |
| C7 | CI: the image runs migrate twice (idempotent) + seed, must **refuse** to boot in production without salt / `TRUST_PROXY`, then serves in production mode (`/livez` 200, `/health` 200, `/docs` + `/docs/json` 404, `/v1/auth/session` 401); then the same image is pushed to Artifact Registry via keyless WIF — **skipped** until the three repository variables exist; job permission `id-token: write` | `.github/workflows/ci-api.yml` |
| C8 | Runbook (every Gate 6.7-3 command), ADR-012, `deploy.ps1` (image check → migrate job → no-traffic tagged revision → smoke on its URL → traffic, or stop), `rollback.ps1`, `neon-roles.sql`, Artifact Registry cleanup policy (keep 3) | `docs/hosting/CLOUD-RUN.md`, `docs/decisions/ADR-012-…`, `scripts/cloudrun/*` |

ACCEPTANCE (Gate 6.7-1 criteria from §11)
  - Suites: core **461**, contracts **35**, API **284** (240 → 284: +44 — `hosting.test.ts` 29,
    env 14, AI per-user 1), mobile **320** (Flutter container, with the regenerated `openapi.json`).
    Typecheck, lint (core / contracts / api), `flutter analyze --fatal-infos`, `dart format` clean.
  - **CI on `7cfb098`:** `apps/api`, `packages/core`, `apps/mobile` success; step "Docker image
    migrates, seeds and serves in production mode" success; the two Artifact Registry steps skipped.
  - Image built locally (133 MB compressed) and run against a throwaway Postgres 18: migrate ×2,
    seed (151 exercises), journal 9 rows; boot without salt / `TRUST_PROXY` refused naming both;
    production boot `/livez` 200, `/health` 200, `/docs` 404, `/docs/json` 404, auth 401; database
    stopped → `/livez` 200, `/health` 503. A real postgres.js `ECONNREFUSED` on `/v1/user/profile`
    answers 503 with no host, port or driver text in the body (test).
  - `TRUST_PROXY=1`: `X-Forwarded-For: 6.6.6.6, 203.0.113.7` → client `203.0.113.7`; rotating the
    spoofed entry still hits 429 at request 121 (test). Unset → `6.6.6.6` (Phase 6.6 behaviour kept).
  - AI: two users behind one IP — the first is refused at request 21 (429 `RATE_LIMITED`), the
    second still gets 200 (real Postgres test).
  - LAN no-regression: the image with the compose's environment (`NODE_ENV=development`, no salt,
    no `TRUST_PROXY`) boots, `/docs/json` 200, `/health` 200 — exactly as in 6.6.
  - `neon-roles.sql` run on Postgres 18 as a **non-superuser** owner (how Neon works): the first
    version failed (`permission denied to change default privileges`) and was fixed (the owner
    joins `fitos_migrator` for the two statements and leaves). Then: the image's migrate + seed as
    `fitos_migrator`; `fitos_app` can select / insert / update / delete and **cannot** create, alter
    or drop tables or read the `drizzle` journal; `pg_dump` as `fitos_migrator` works (backup path).
  - `deploy.ps1` / `rollback.ps1`: 0 parse errors (PowerShell 5.1 parser). **Not executed** — no
    `gcloud`, no cloud project yet (Gate 6.7-3).
  - Secrets: none added anywhere; `.dockerignore` unchanged; no secret value in any new file.

NOT VERIFIED YET (by design, later gates)
  - The Cloud Run hop count for `TRUST_PROXY` (runbook step 10, Gate 6.7-3) — `1` is the expected
    value, to be confirmed against real logs.
  - The Artifact Registry push step (needs WIF, Gate 6.7-3).
  - The app still treats a 503 / 502 / 504 as an ordinary failure — the mobile half of the
    outage handling is Gate 6.7-2 (C10).

---

### Gate 6.7-2 — Hosted mobile profile — implemented 2026-09-23, awaiting approval

Commits: `c2124e2` (mobile) · `b62a021` (runbook) · `5e7d780` / `0a8abbd` (this report) ·
`5ed2168` (CI: failing Flutter tests named as check-run annotations). Server, contracts,
`pubspec.yaml`, `tool/alpha.ps1` and MASTER-SPEC unchanged. No GCP resource, no DNS.

HOSTED CONFIGURATION
  - `FLAVOR=hosted`, built by `tool/hosted.ps1` from gitignored `hosted.env`. The Firebase values
    fall back to `alpha.env` (same project `fitos-dev-3208b`, sign-in unchanged).
  - `API_BASE_URL` defaults to Cloud Run's deterministic URL
    `https://fitos-api-alpha-<project number>.asia-south1.run.app`. The project number is
    `FIREBASE_MESSAGING_SENDER_ID`, and the URL is confirmed after the first deploy (Gate 6.7-3).
    `https://api.tryfitos.me` comes later via `-ApiBaseUrl` / `hosted.env`; not configured.
  - Version `1.0.0-alpha.2` (3) via `--build-name/--build-number`. The LAN build keeps
    `1.0.0-alpha.1` (2).
  - The address must be https, a DNS name with an alphabetic top-level label, no port (not even
    `:443`), no path / query / credentials. One rule set, `lib/core/config/hosted_api_url.dart`:
    - checked by the app at start-up (a bad hosted build stops on the splash with the reason and
      never initialises Firebase);
    - checked by the script (`tool/check_hosted_api_url.dart`);
    - mirrored by `android/app/build.gradle.kts`, which **refuses to build** a hosted APK
      otherwise.
  - Network security for https: `base-config cleartextTrafficPermitted=false`, no exceptions.
  - The sign-in "Backend <host> · FITOS <version>" line shows for `alpha` and `hosted` (not
    `local`). Profile's build line already shows flavour + host.

OUTAGE HANDLING (C10)
  - `ServiceUnavailable` is a subtype of `Offline`. It covers:
    - 502, 504;
    - 503 from the front end, or FITOS's own `UPSTREAM_UNAVAILABLE` (server message kept);
    - a 429 **without** the FITOS envelope (Cloud Run).
  - FITOS's own 429 (`RATE_LIMITED`) stays `RateLimited`, with the same message.
  - `SyncEngine`: `Offline` (now including `ServiceUnavailable`) and `RateLimited` →
    `_Stop(retry: true)`. No attempt spent, never parked, the engine wakes itself (15 s doubling
    to 2 min).
  - Genuine failures (500 and the rest) are counted and parked exactly as in 6.6.
  - Ordering, the KI-10 hold and 404 → ad-hoc: untouched.
  - The retry interceptor is unchanged: a 5xx POST is never re-sent blindly (tested: 1 request).

TESTS — mobile **374** (320 → 374; Flutter container), analyze `--fatal-infos`, custom_lint,
format clean.
  - URL rules and flavours (29): run.app and `api.tryfitos.me` accepted. Rejected: `http://`, `localhost`
    (+ subdomains), `127.0.0.1`, `10.0.2.2`, `192.168.x`, the LAN IP, IPv6, `0x7f.0.0.1`,
    `:443`, `:8080`, `:8443`, single-label hosts, paths, queries, credentials, empty.
    LAN `alpha` / `local` keep `http://<IP>:8080` (no problem reported).
  - Mapper (8): 502 / 503 / 504 / Cloud Run 429 → ServiceUnavailable naming the host; FITOS 429
    → RateLimited; FITOS 503 keeps its three messages; 500 → Unknown.
  - HTTP plumbing (7): the real Dio client + `DioWorkoutApi` against HTML / plain-text outage
    bodies, each sent once.
  - Sync (10): for each of Cloud Run 502, 503, 504, 429, FITOS 503 and FITOS 429, a full session
    waits through the outage with 0 attempts and 0 parked, retries by itself with backoff (fewer
    than 40 tries in 400 ms of test time), and after recovery syncs once with no Retry / `sync()`.
    Also covered:
    - the 500 contrast (still parks);
    - offline → Cloud Run 503 → back;
    - an outage starting mid-session (no duplicate sets);
    - the **S24 KI-10 queue under a 502 outage** (drains afterwards in the same order, 0 × 409,
      nothing parked).

BUILDS (this PC)
  - `tool\hosted.ps1 -SkipHealthCheck -TargetPlatform android-arm64` →
    `fitos-hosted-1.0.0-alpha.2.apk` (26.2 MB): `com.example.fitos` `1.0.0-alpha.2` (3), not
    debuggable, network config **cleartext false, no domain exception**, the run.app host
    compiled in, no LAN IP, no `10.0.2.2`.
  - Hosted script / Gradle refusals verified: `http://10.160.235.11:8080`, `https://10.0.2.2`,
    `https://api.tryfitos.me:443`, `https://localhost` → exit 1 with the reason.
  - LAN: `tool\alpha.ps1` (unchanged; its default debug build) → `/health` 200 at
    `10.160.235.11`, built. A LAN release build with `alpha.ps1 -Release`'s flags plus
    `--target-platform android-arm64` → `1.0.0-alpha.1` (2), not debuggable, cleartext **only**
    for `10.160.235.11` — identical to the Phase 6.6 Gate 8 inspection.
  - Secret scan of every entry of all three APKs: 0 × the backend Gemini key (compared, not
    printed), `GEMINI_API_KEY`, model hosts, private keys, service-account JSON, `postgres://`,
    `neon.tech`, `fitos_app` / `fitos_migrator`, Secret Manager names, `CONSENT_IP_SALT`.

INTENTIONALLY / NOT YET VERIFIED
  - **All-ABI release builds on this PC:** Windows Smart App Control now blocks Flutter's 32-bit
    ARM `gen_snapshot.exe` (the 6.6 builds passed). `android-arm64` builds fine, and the S24 is
    arm64. `hosted.ps1` defaults to all ABIs; `-TargetPlatform android-arm64` is the workaround.
    A Linux-container build was tried and could not reach Gradle's plugin repository from Docker.
    CI's `ci-mobile` builds the default debug APK on Linux.
  - The derived run.app URL: confirmed only after the first deploy (Gate 6.7-3).
  - Nothing on the S24 yet: hosted install, sign-in and live outage behaviour are Gate 6.7-5.
  - **One unexplained CI test failure.** `ci-mobile` on `0a8abbd` reported "373 tests passed,
    1 failed". The test couldn't be named: logs need a token; annotations give counts only.
    It did **not** recur:
    - CI on `5ed2168` passed (all three workflows);
    - the full suite passed 3× in a CPU-limited container (1.5 CPUs);
    - the timing-sensitive files (automatic sync + all new core tests) passed 8× at 0.5 CPU.
    Treated as an intermittent test, not fixed. `ci-mobile` now annotates any failing test with
    its name, file, line and error, so a recurrence is identifiable.
