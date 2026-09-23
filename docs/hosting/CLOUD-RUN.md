# FITOS hosted alpha on Cloud Run — runbook (Phase 6.7)

The one-time setup for **Gate 6.7-3** and the routine for every later release.
Nothing here has been run yet. Decisions: `docs/phase-reports/phase-6.7.md` §1–2,
ADR-012. Commands are PowerShell (Windows PowerShell 5.1 is fine) with the
[gcloud CLI](https://cloud.google.com/sdk/docs/install) installed.

**Never** put a secret in a command line, a file, a commit or chat: secret
values are typed only into the Secret Manager console (step 6) and the Neon
SQL editor (step 5).

```powershell
$P  = 'fitos-dev-3208b'            # O1: the Firebase project hosts Cloud Run
$R  = 'asia-south1'                # Mumbai
$PN = gcloud projects describe $P --format='value(projectNumber)'
$RUNTIME = "fitos-api-runtime@$P.iam.gserviceaccount.com"
$JOBS    = "fitos-jobs@$P.iam.gserviceaccount.com"
$CI      = "fitos-ci-publisher@$P.iam.gserviceaccount.com"
```

| Name | What |
|---|---|
| `fitos-api-alpha` | Cloud Run service (the API) |
| `fitos-migrate-alpha`, `fitos-seed-alpha` | Cloud Run jobs, same image as the release |
| `fitos-backup-alpha` | Cloud Run job, nightly `pg_dump` (Gate 6.7-4) |
| `asia-south1-docker.pkg.dev/fitos-dev-3208b/fitos/fitos-api:<git sha>` | the image, pushed by CI |
| `fitos-api-runtime` / `fitos-jobs` / `fitos-ci-publisher` | service accounts |
| `fitos-gemini-api-key`, `fitos-db-url-app`, `fitos-db-url-migrator`, `fitos-consent-ip-salt` | Secret Manager |
| Neon `fitos-alpha` (AWS Singapore), roles `fitos_migrator`, `fitos_app` | database |

---

## One-time setup (Gate 6.7-3)

### 0. Sign in

```powershell
gcloud auth login
gcloud config set project $P
```

### 1. Billing and budget alerts (console)

1. Billing → link a billing account to `fitos-dev-3208b`. This moves the
   Firebase project to the **Blaze** plan; email and Google sign-in stay free.
   **Do not** start the $300 free trial (its 90 days run from activation).
2. Billing → Budgets & alerts → create a budget scoped to this project with
   alerts at **₹500, ₹2,000 and ₹5,000** (MASTER-SPEC §27).

### 2. APIs

```powershell
gcloud services enable run.googleapis.com artifactregistry.googleapis.com `
  secretmanager.googleapis.com iamcredentials.googleapis.com sts.googleapis.com `
  cloudscheduler.googleapis.com storage.googleapis.com --project $P
```

### 3. Artifact Registry

```powershell
gcloud artifacts repositories create fitos --repository-format=docker --location=$R `
  --immutable-tags --description='FITOS API images (Phase 6.7)' --project $P
gcloud artifacts repositories set-cleanup-policies fitos --location=$R `
  --policy=scripts/cloudrun/ar-cleanup-policy.json --no-dry-run --project $P
```

The policy keeps the three newest images (the free tier is 0.5 GiB; one image is ~130 MB).

### 4. Service accounts (never the default compute account, which has Editor)

```powershell
gcloud iam service-accounts create fitos-api-runtime  --display-name='FITOS API (Cloud Run runtime)' --project $P
gcloud iam service-accounts create fitos-jobs         --display-name='FITOS migrate / seed / backup jobs' --project $P
gcloud iam service-accounts create fitos-ci-publisher --display-name='GitHub Actions: image push only' --project $P

# Firebase Admin through Application Default Credentials — no key file anywhere.
# verifyIdToken(checkRevoked) and revokeRefreshTokens need this role.
gcloud projects add-iam-policy-binding $P --member="serviceAccount:$RUNTIME" --role=roles/firebaseauth.admin

# CI may push to the one repository and nothing else.
gcloud artifacts repositories add-iam-policy-binding fitos --location=$R `
  --member="serviceAccount:$CI" --role=roles/artifactregistry.writer --project $P
```

### 5. Neon `fitos-alpha` (console)

1. New project: name **`fitos-alpha`**, Postgres **18**, region **AWS Asia
   Pacific (Singapore)**. It's a new project; the existing dev project is not touched.
2. Compute: autoscaling **0.25 – 0.5 CU** (it keeps the 100 free CU-hours for ~400 active hours).
3. SQL editor, as the owner role: paste `scripts/cloudrun/neon-roles.sql`,
   replace the two password placeholders **in the editor** with freshly
   generated passwords, run it, and don't save it anywhere.
4. Connection details → **direct** (not pooled) host. Build the two
   connection strings **in your head / the secret form, not in a file**:
   `postgresql://fitos_app:<password 2>@<direct host>/<database>?sslmode=verify-full`
   and the same with `fitos_migrator` / password 1.

### 6. Secrets (console: Security → Secret Manager → Create secret)

| Secret | Value | Read by |
|---|---|---|
| `fitos-db-url-app` | the `fitos_app` connection string | runtime |
| `fitos-db-url-migrator` | the `fitos_migrator` connection string | jobs |
| `fitos-gemini-api-key` | a **new** key from Google AI Studio named "FITOS hosted" (O8) — not the PC's dev key | runtime |
| `fitos-consent-ip-salt` | 32 random bytes, generated below and pasted straight into the form | runtime |

```powershell
# Prints a salt once; paste it into the secret form, then clear the screen.
$b = New-Object byte[] 32; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
```

Access, per secret (a service account sees only its own):

```powershell
foreach ($s in 'fitos-db-url-app', 'fitos-gemini-api-key', 'fitos-consent-ip-salt') {
  gcloud secrets add-iam-policy-binding $s --member="serviceAccount:$RUNTIME" --role=roles/secretmanager.secretAccessor --project $P
}
gcloud secrets add-iam-policy-binding fitos-db-url-migrator --member="serviceAccount:$JOBS" --role=roles/secretmanager.secretAccessor --project $P
```

Keep at most 6 active versions in total (the free tier): after a rotation, **destroy** the old version.

### 7. GitHub → Artifact Registry, keyless (O5)

```powershell
gcloud iam workload-identity-pools create github --location=global --display-name='GitHub Actions' --project $P
gcloud iam workload-identity-pools providers create-oidc fitnew --location=global --workload-identity-pool=github `
  --issuer-uri='https://token.actions.githubusercontent.com' `
  --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref' `
  --attribute-condition="assertion.repository=='Srijan1202/fitnew' && (assertion.ref=='refs/heads/main' || assertion.ref=='refs/heads/phase-6.7')" `
  --project $P
gcloud iam service-accounts add-iam-policy-binding $CI --role=roles/iam.workloadIdentityUser --project $P `
  --member="principalSet://iam.googleapis.com/projects/$PN/locations/global/workloadIdentityPools/github/attribute.repository/Srijan1202/fitnew"
```

GitHub → repository → Settings → Secrets and variables → Actions → **Variables** (not secrets; these are identifiers):

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | `fitos-dev-3208b` |
| `GCP_WIF_PROVIDER` | `projects/<PN>/locations/global/workloadIdentityPools/github/providers/fitnew` |
| `GCP_CI_SERVICE_ACCOUNT` | `fitos-ci-publisher@fitos-dev-3208b.iam.gserviceaccount.com` |

The next push to `phase-6.7` runs `ci-api`, which tests, smoke-tests the
image and pushes `…/fitos/fitos-api:<commit sha>`. Take that full SHA as `$SHA`.

### 8. Jobs (same image, migrator credentials)

```powershell
$IMAGE = "$R-docker.pkg.dev/$P/fitos/fitos-api:$SHA"
gcloud run jobs create fitos-migrate-alpha --image $IMAGE --region $R --project $P `
  --service-account $JOBS --set-secrets DATABASE_URL=fitos-db-url-migrator:latest `
  --command node --args apps/api/dist/db/migrate.js,up --max-retries 0 --task-timeout 300
gcloud run jobs create fitos-seed-alpha --image $IMAGE --region $R --project $P `
  --service-account $JOBS --set-secrets DATABASE_URL=fitos-db-url-migrator:latest `
  --command node --args apps/api/dist/db/seed.js --max-retries 0 --task-timeout 300
gcloud run jobs execute fitos-migrate-alpha --region $R --project $P --wait
gcloud run jobs execute fitos-seed-alpha --region $R --project $P --wait
```

### 9. The service (first deploy — every setting lives here)

```powershell
gcloud run deploy fitos-api-alpha --image $IMAGE --region $R --project $P `
  --service-account $RUNTIME --allow-unauthenticated --ingress all `
  --cpu 1 --memory 512Mi --concurrency 40 --timeout 180 `
  --min-instances 0 --max-instances 2 --cpu-throttling `
  --set-env-vars 'NODE_ENV=production,LOG_LEVEL=info,FIREBASE_PROJECT_ID=fitos-dev-3208b,GEMINI_MODEL=gemini-3.6-flash,AI_TIMEOUT_MS=25000,AI_MAX_OUTPUT_TOKENS=2048,TRUST_PROXY=1' `
  --set-secrets 'DATABASE_URL=fitos-db-url-app:latest,GEMINI_API_KEY=fitos-gemini-api-key:latest,CONSENT_IP_SALT=fitos-consent-ip-salt:latest' `
  --startup-probe 'httpGet.path=/livez,httpGet.port=8080,periodSeconds=2,timeoutSeconds=2,failureThreshold=30'
```

- **Why these settings:**
  - `--cpu-throttling`: request-based CPU.
  - `--timeout 180`: an AI turn can reach ~125 s.
  - `max-instances 2` (O3): rate limits are per instance, so at most 2×.
  - No `PORT`: Cloud Run injects it.
  - No `GOOGLE_APPLICATION_CREDENTIALS`: the runtime identity is used.
- **If `--startup-probe` is refused by the installed gcloud:** console → the service → Edit & deploy new revision → Container → Health checks → startup probe HTTP `/livez`, port 8080.

### 10. Acceptance checks (Gate 6.7-3)

```powershell
$URL = gcloud run services describe fitos-api-alpha --region $R --project $P --format='value(status.url)'
foreach ($p in '/livez', '/health', '/docs', '/docs/json') {
  try { $c = (Invoke-WebRequest "$URL$p" -UseBasicParsing).StatusCode } catch { $c = [int]$_.Exception.Response.StatusCode }
  "$p $c"      # want 200, 200, 404, 404
}
```

- **`/v1/ai/status` with no token:** 401.
- **`http://` → HTTPS:** try `http://<run.app host>/livez` and record what Cloud Run does.
- **TRUST_PROXY:**
  1. Send `Invoke-WebRequest "$URL/livez" -Headers @{ 'X-Forwarded-For' = '6.6.6.6' }`.
  2. Read that request's log entry (`gcloud logging read 'resource.type="cloud_run_revision" AND jsonPayload.req.url="/livez"' --limit 3 --project $P`).
  3. Its `remoteAddress` must be **this PC's public IP**, not `6.6.6.6`. If it isn't, the hop count is wrong: redeploy with the value that yields the real client and record it.
- **Secrets as references only:** `gcloud run services describe … --format=yaml` shows `secretKeyRef`s, not values.
- **The key never logged:** Cloud Logging search for the first 8 characters of the new key returns nothing (search it in the console; don't paste the key anywhere else).
- **Latency (R1):** warm p95 of `/v1/training/today` measured from the S24 on mobile data.

---

## The hosted APK (Gate 6.7-2)

```powershell
cd apps\mobile
.\tool\hosted.ps1                                  # needs the service up: checks https://…/health first
.\tool\hosted.ps1 -SkipHealthCheck                 # before the first deploy
.\tool\hosted.ps1 -TargetPlatform android-arm64    # this PC: Smart App Control blocks the 32-bit ARM compiler
.\tool\hosted.ps1 -Install                         # then adb install -r on the S24
```

- **Where its settings come from:**
  - The Firebase values come from `apps/mobile/hosted.env`, falling back to `alpha.env` (same Firebase project).
  - `API_BASE_URL` comes from `hosted.env`. If it isn't set, the script derives Cloud Run's deterministic URL `https://fitos-api-alpha-<project number>.asia-south1.run.app`, where the project number is `FIREBASE_MESSAGING_SENDER_ID`.
- **After the first deploy:** confirm the derived URL equals `gcloud run services describe fitos-api-alpha --region asia-south1 --format='value(status.url)'`, or set it in `hosted.env`.
- **What it builds:** `FLAVOR=hosted`, version **1.0.0-alpha.2 (3)** at build time (`pubspec.yaml` unchanged, so the LAN build stays 1.0.0-alpha.1 (2)). Output: `buildpp\outputslutter-apkitos-hosted-1.0.0-alpha.2.apk`.
- **Refused:**
  - `http://`, IP addresses (including `10.0.2.2` / `127.0.0.1`), `localhost`, any port, and any path.
  - The script checks with the app's own rules (`tool/check_hosted_api_url.dart`); Gradle checks the same rules again, so a hand-run `flutter build` can't bypass them.
  - The generated network config allows **no** unencrypted HTTP at all.
- **Custom domain:** `https://api.tryfitos.me` later, with `-ApiBaseUrl` or `hosted.env`, once Firebase Hosting rewrites are set up. Not part of 6.7-2.

## Every release

1. Push to `phase-6.7` (later `main`); `ci-api` goes green and pushes the image.
2. `.\scripts\cloudrun\deploy.ps1 -Sha <full commit sha>` (add `-Seed` when
   `database/seeds` changed). It runs the migrate job, deploys a revision with
   **no traffic**, smoke-tests its tagged URL, and only then moves 100% of traffic.
3. Something wrong: `.\scripts\cloudrun\rollback.ps1` returns traffic to the
   previous revision (seconds). The database is not rolled back: migrations are
   forward-only and backward-compatible. A bad migration means a restore
   (Neon's 6-hour window or the nightly dump).

## Rotation

| Secret | Steps |
|---|---|
| Gemini key | AI Studio: new key → Secret Manager: add version → `deploy.ps1` (new revision reads `latest`) → revoke the old key → destroy the old version |
| Neon passwords | Neon: `ALTER ROLE … PASSWORD` in the SQL editor → add a version with the new connection string → deploy (app) / next job run (migrator) → destroy the old version |
| Consent salt | Only if leaked; affects only new consent hashes |

## Later (not Gate 6.7-3)

- **Gate 6.7-4:**
  - Restore the Phase 6.6 local data (O4) into `fitos-alpha`: a read-only `pg_dump` of local `fitos`, restored as `fitos_migrator`.
  - Add `fitos-backup-alpha` (a `postgres:18-alpine` job with a Cloud Storage volume, triggered nightly by Cloud Scheduler, bucket lifecycle 14 days).
  - Exact commands are added when that gate starts.
- **Custom domain `api.tryfitos.me`:** Firebase Hosting rewrites to `fitos-api-alpha`. Cloud Run's own domain mapping is not offered in `asia-south1`. Not configured until the owner asks.
