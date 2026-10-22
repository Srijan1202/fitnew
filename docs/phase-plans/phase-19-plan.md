# Phase 19 — Beta: implementation plan

**Status:** Owner decisions 2026-10-22. Built on `phase-19` (from `phase-18`, approval pending). The AWS stack exists; the first server release and the Play upload are waiting on owner steps.
**Decision records:**
- [ADR-025](../decisions/ADR-025-aws-beta-hosting.md): the server.
- [ADR-026](../decisions/ADR-026-beta-app.md): the app.

## 1. What MASTER-SPEC asks for (§31 Phase 19)

**Tasks:**
- staging → production hosting;
- Play Store internal testing;
- Crashlytics;
- billing alerts;
- a feedback channel.

**Acceptance:** an installable build, and a crash-free rate above 99% over one week with 20 real users.
**Manual:** 20 VIT students complete onboarding and log a week.

## 2. Owner decisions (2026-10-22)

| Topic | Decision |
|---|---|
| Cloud | **AWS** now, Google Cloud kept as a second target "in one switch" |
| Domain | `tryfitos.me` (already owned, Namecheap): the API is `api.tryfitos.me` |
| Server | One EC2 server with Docker (Caddy for HTTPS) |
| Database | RDS Postgres in Mumbai |
| AWS sign-in | An IAM user with `aws login`: no Organization (it would end the free credits), no access keys |
| Backups | 1 day: the Free plan refused 7 |
| Package | `me.tryfitos.app` |
| Crash reports | On by default, an off switch in Privacy & data |
| Feedback | An in-app form, read in the admin panel |

## 3. Build

1. **Server (ADR-025):**
   - `infra/aws/fitos-beta.yaml`;
   - `deploy/aws/server/*` (release, bootstrap, roles, Caddy);
   - `scripts/aws/*`, `scripts/deploy.ps1 -Target aws|gcp`;
   - CI pushes images to ECR;
   - the API accepts a federation credential for Firebase;
   - runbook `docs/hosting/AWS.md`.
2. **API (ADR-026):**
   - migration 0021 `feedback`;
   - `POST /v1/feedback`, `GET/PATCH /v1/admin/feedback`;
   - `/meta/config.minimumBuild` (`MIN_APP_BUILD`).
3. **Admin:** the Feedback page.
4. **App (ADR-026):**
   - `me.tryfitos.app`; upload-key signing; Crashlytics with the switch; policy 2026-10-22.2;
   - Send feedback; the minimum-build gate; `flagOn()`;
   - `hosted.ps1 -AppBundle` with a secret scan;
   - runbook `docs/hosting/PLAY.md`.
5. **Docs:**
   - this plan, ADR-025 and ADR-026;
   - the MASTER-SPEC §8.4 and §31 amendments;
   - BACKLOG O1, E1 and E18;
   - the report.

## 4. Owner steps, in order

1. **AWS** (AWS.md):
   - ~~the stack~~ done;
   - ~~DNS~~ done;
   - ~~bootstrap~~ done;
   - ~~`BootstrapMode=false`~~ done;
   - ~~settings~~ done;
   - Firebase federation (`gcloud`);
   - the GitHub variable `AWS_CI_ROLE_ARN`;
   - the first release.
2. **Play** (PLAY.md):
   - the upload key;
   - Firebase: register `me.tryfitos.app` with its SHA-1s;
   - Crashlytics on;
   - the Play Console account (US$25);
   - build the bundle;
   - the internal testing release;
   - testers.
3. **The §31 acceptance week** with 20 testers.
