# ADR-025 — Beta hosting on AWS (Mumbai): one EC2 server with Docker and Caddy, RDS Postgres, Google Cloud kept as a second target

**Status:** PROPOSED. The owner chose this on 2026-10-22, and it is prepared on `phase-19`. Nothing has been created on AWS yet. It becomes ACCEPTED once the hosted acceptance checks (docs/hosting/AWS.md step 10) pass.
**Date:** 2026-10-22
**Phase:** 19 (beta)
**Supersedes:** ADR-012 for the beta's *location*. The Cloud Run design stays, ready to use as the second target. No ADR-012 decision about the app itself changes.
**Affects:**
- MASTER-SPEC §8.4 (hosting), §24 (secrets), §25 (DevOps), §27 (cost), §31 Phase 19;
- BACKLOG O1.

---

## Context

- The owner wants the beta on AWS, but able to move to Google Cloud "in one switch" later (2026-10-22).
- Owner answers:
  - their own domain for the API;
  - one small server running Docker;
  - RDS Postgres in Mumbai;
  - a new AWS account.
- The app was already close to cloud-neutral:
  - one Docker image that serves, migrates and seeds;
  - configuration only through environment variables;
  - plain Postgres through Drizzle (§28).
- One gap: the server's access to Firebase Admin. Cloud Run supplies it with no file; elsewhere it took a key file.

## Decisions

| # | Decision |
|---|---|
| D1 | **One EC2 instance** (`t3.small`, Amazon Linux 2023, `ap-south-1`) runs the API container and Caddy. **No SSH:** the owner reaches it only through Systems Manager. Automatic security updates; an Elastic IP; an alarm that moves it to healthy hardware if the host fails. The in-memory rate limits (ADR-012 D7) are exact on one server. |
| D2 | **RDS Postgres 18** (`db.t4g.micro`, encrypted, private subnets, reachable from the server only). 7 days of automatic backups. Deletion protection, and a final snapshot if the stack is deleted. RDS keeps the master password in Secrets Manager. Two roles, as on Neon: `fitos_migrator` (schema) and `fitos_app` (rows only). They are created by `bootstrap.sh` with passwords generated on the server that no one sees. |
| D3 | **HTTPS by Caddy** for `api.<domain>`, with a Let's Encrypt certificate it renews itself. Caddy replaces any client-sent `X-Forwarded-For`, so `TRUST_PROXY=1`. The app calls the domain only, so a move between clouds is a DNS change and no APK rebuild. |
| D4 | **Firebase from AWS without a key:** Google Workload Identity Federation trusts the server's AWS role. The credential file holds no secret (`type: external_account`). The API now accepts either kind of file (`credentialFileKind`). A service-account key in Parameter Store is the documented fallback. |
| D5 | **Secrets in SSM Parameter Store** (SecureString, under `/fitos/beta/`). The server role reads only that path. Rights to read the RDS master secret and write parameters exist only while `BootstrapMode=true`. The owner stores values through a hidden prompt (`set-parameter.ps1`), never on a command line or in the chat. |
| D6 | **Releases:** CI pushes the smoke-tested image to ECR with keyless GitHub OIDC; the `fitos-ci-publisher` role can only push to `fitos-api`. The owner releases with `scripts/aws/deploy.ps1`. On the server, `release.sh` runs: migrations as `fitos_migrator` → the new container beside the old → `/health` → Caddy switched by a graceful reload → an HTTPS smoke test → the old container removed. `rollback.ps1` serves the previous release again, without migrations. |
| D7 | **The mess fetch** uses the API's own timer (`MESS_MIRROR_INTERVAL_HOURS=12`). On one long-running server it needs no scheduler. The mirror's advisory lock makes the overlap during a release safe. |
| D8 | **Infrastructure as code:** all of it is in `infra/aws/fitos-beta.yaml` (CloudFormation): 23 resources, including the budget alerts and CloudWatch Logs (30 days). It is created and updated with one command and reviewed as one file. |
| D9 | **The second target:** `scripts/deploy.ps1 -Target aws|gcp`. The Google side is the existing Cloud Run runbook and scripts, unchanged. CI pushes to Artifact Registry as well, once its variables exist. A move is: release there → copy the database (`pg_dump`/restore, minutes at beta size, a short write pause) → change the DNS record. |

## Cost

`RESEARCH`, 2026-10-22. These are third-party price lists; confirm them in the AWS Pricing Calculator before creating the stack.

| Item | Per month (USD, about) |
|---|---|
| EC2 `t3.small` on demand (Mumbai) | 16.4 |
| Public IPv4 (the Elastic IP) | 3.7 |
| RDS `db.t4g.micro` Postgres (Mumbai) | 15 |
| EBS 20 GB + RDS storage 20 GB (gp3) | ≈ 4 |
| Secrets Manager (RDS master secret), CloudWatch Logs, ECR | ≈ 1–2 |
| **Total** | **≈ 40** |

- New AWS accounts (since 2025-07-15) get $100 in credits, and up to $200 with the onboarding tasks, for six months. Sources disagree on when the credits expire.
- That covers the beta's first months. Afterwards it is about $40 a month.
- The budget alerts default to $45.
- `UNVERIFIED`: whether the "Free plan" account type allows a `t3.small`. If it refuses, upgrade the account to the Paid plan (the credits still apply) or pick `t3.micro` (1 GB, tight).

## Consequences

**Good:**
- About the same cost as a VPS, with managed backups.
- Same-region database: no Mumbai↔Singapore round trips (ADR-012's accepted latency is gone).
- Exact rate limits.
- No server ports beyond 80/443.
- No keys anywhere: CI, the server and Firebase are all keyless.
- Rollback in seconds.

**Bad / accepted:**
- One server is one point of failure. Mitigations: automatic recovery on a host failure and a releases-only change path. Expect a few minutes of downtime if the instance itself dies; acceptable for a 20-user beta.
- Security updates are automatic, but rebooting for a kernel update is a manual step (runbook).
- About $40 a month after the credits, against about ₹0 on Cloud Run + Neon free.

## Verified locally (2026-10-22)

The server scripts were rehearsed against Docker on the owner's PC, with stand-ins for ECR (a local registry) and for Parameter Store and Secrets Manager. The database was Postgres 18 with SSL required. Results:
- bootstrap created the roles and refused a second run;
- a release with the seed served HTTPS through Caddy (`/health` 200, `/docs` 404, sign-in 401);
- a second release retired the first;
- a broken release never took traffic;
- a rollback without migrations worked;
- the app role has rows only (no `CREATE`).

**Not verifiable without the account:**
- the real ECR, SSM and CloudWatch calls;
- the Systems Manager round trip from `common.ps1`;
- the Let's Encrypt certificate for the real domain;
- the Workload Identity Federation token exchange.

These are acceptance step 10.

## Not in this decision

- Load-test the hosted stack (BACKLOG E21).
- Nightly logical dumps to S3 beyond RDS's automatic backups (Phase 20, "backup restore rehearsed").
- The admin panel's hosting (still local, §20 names Vercel).
