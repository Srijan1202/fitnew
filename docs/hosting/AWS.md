# FITOS beta on AWS (Mumbai): runbook (ADR-025)

This runbook sets up the beta on AWS:
- **Server:** one EC2 server runs the API image behind Caddy (HTTPS).
- **Database:** RDS Postgres.
- **Region:** everything is in `ap-south-1`, and everything is in one CloudFormation stack, `infra/aws/fitos-beta.yaml`.
- **Second target:** Google Cloud stays ready as the second target (`docs/hosting/CLOUD-RUN.md`).

**Rules**
- **You** run every step that creates something or costs money.
- AWS keys never go into the chat, a file in the repo, or a command line. Sign in with the CLI's own login (step 0), and type secrets only into `set-parameter.ps1`'s hidden prompt.
- The server has **no SSH**. Everything reaches it through Systems Manager.

| Step | What | Who |
|---|---|---|
| 0 | Account hygiene, the CLI login | you |
| 1 | Domain (`tryfitos.me`, already yours) | — |
| 2 | Create the stack | you (one command) |
| 3 | DNS record | you |
| 4 | Database bootstrap | you (one script) |
| 5 | Close the bootstrap rights | you (one command) |
| 6 | Settings and secrets | you (prompts) |
| 7 | Firebase without a key | you (gcloud) |
| 8 | CI publishes images | you (one GitHub variable) |
| 9 | First release | you (one script) |
| 10 | Acceptance checks | you + the phone |

---

## 0. Account and CLI (once)

1. In the AWS console (root user): turn on **MFA** for the root user.
2. **Your everyday user:** IAM → Users → Create user, e.g. `srijan-admin`.
   - Give it console access with a password, then turn on **MFA** for it.
   - Attach `AdministratorAccess` (the stack creates IAM roles) and `SignInLocalDevelopmentAccess` (the CLI login below).
   - **No access keys.** Stop using root.
   - Not IAM Identity Center: it needs an AWS Organization, and creating one moves the account to the paid plan and **ends the free credits at once**.
3. **Region:** Asia Pacific (Mumbai) `ap-south-1`.
4. **Plan:** a new account starts on the Free plan with credits, which limits it to some smaller instance types. If step 2 refuses `t3.small` or the database class, either:
   - upgrade directly to the **Paid plan** (Billing → upgrade). Not through Organizations. AWS says unused credits stay usable for up to 12 months from sign-up; or
   - stay on the Free plan with `InstanceType=t3.micro` (1 GB, tight). Ask first: the release script's memory limit needs lowering for it.
5. Install or update the **AWS CLI v2** to 2.32.0 or newer. Then, in PowerShell:
   ```
   aws login --profile fitos
   aws configure set region ap-south-1 --profile fitos
   aws sts get-caller-identity --profile fitos
   ```
   - `aws login` opens the browser; sign in as the IAM user. The CLI keeps short-lived credentials that refresh for up to 12 hours; run `aws login --profile fitos` again after that.
   - No key is ever written to a file.
   - The last command prints your account id; you need it in step 7.

**Cost:** about $40 a month after the credits (ADR-025 "Cost"). Check it in the AWS Pricing Calculator first.

## 1. Domain

You already own **`tryfitos.me`** (claimed in Phase 6.7, 2026-09-23). The API will be **`api.tryfitos.me`**. Nothing to buy; you add one DNS record in step 3, wherever `tryfitos.me`'s DNS is managed.

## 2. Create the stack

First, check that RDS offers Postgres 18 in Mumbai (it should print 18.x versions):
```
aws rds describe-db-engine-versions --engine postgres --query "DBEngineVersions[?starts_with(EngineVersion,'18')].EngineVersion" --profile fitos --region ap-south-1
```

Then, from `D:\dev\fit new`:
```
aws cloudformation deploy --template-file infra/aws/fitos-beta.yaml --stack-name fitos-beta `
  --capabilities CAPABILITY_NAMED_IAM --profile fitos --region ap-south-1 `
  --parameter-overrides ApiDomain=api.tryfitos.me AcmeEmail=you@example.com BudgetEmail=you@example.com
```
- Put your own address in place of `you@example.com`. (A `<placeholder>` breaks in PowerShell: `<` is an operator there.)
- It takes about 15 minutes; the database is the slow part.
- **If it fails:** list the cause with
  `aws cloudformation describe-stack-events --stack-name fitos-beta --profile fitos --region ap-south-1 --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" --output table`.
  A first deploy that fails ends in `ROLLBACK_COMPLETE`, which cannot be updated: after the fix, delete it
  (`aws cloudformation delete-stack --stack-name fitos-beta --profile fitos --region ap-south-1`, then `aws cloudformation wait stack-delete-complete` with the same options) and deploy again.
- **The Free plan** refused 7 days of database backups on the first deploy (2026-10-22); the template keeps 1 (see Maintenance).
- Other parameters have defaults:
  - `InstanceType=t3.small`, `DbInstanceClass=db.t4g.micro`, `MonthlyBudgetUsd=45`;
  - `GitHubRepository=Srijan1202/fitnew`;
  - `CreateGitHubOidcProvider=true` (set it `false` only if the account already has GitHub's provider).

Print the outputs (keep this window):
```
aws cloudformation describe-stacks --stack-name fitos-beta --query "Stacks[0].Outputs" --output table --profile fitos --region ap-south-1
```

## 3. DNS

Where `tryfitos.me`'s DNS is managed, add:
- **Type:** `A`
- **Name:** `api`
- **Value:** the **ElasticIp** output
- **TTL:** 300

Caddy gets the HTTPS certificate on the first release, once this record resolves. Check that it resolves with `nslookup api.tryfitos.me`.

## 4. Database bootstrap (once)

```
.\scripts\aws\bootstrap.ps1
```
On the server, this:
- creates `fitos_migrator` and `fitos_app` on RDS, with passwords generated there;
- stores the two connection strings and a fresh consent salt in Parameter Store.

You never see or type a database password. If you run it a second time, it refuses.

## 5. Close the bootstrap rights

```
aws cloudformation deploy --template-file infra/aws/fitos-beta.yaml --stack-name fitos-beta `
  --capabilities CAPABILITY_NAMED_IAM --profile fitos --region ap-south-1 --parameter-overrides BootstrapMode=false
```
After this, the server can no longer read the RDS master secret or write parameters. The other parameters keep their values.

## 6. Settings and secrets

```
.\scripts\aws\set-parameter.ps1 -Name FIREBASE_PROJECT_ID -Value fitos-dev-3208b
.\scripts\aws\set-parameter.ps1 -Name GEMINI_API_KEY        # hidden prompt
```

**FITOS AI and the beta (O7):** the free Gemini tier was approved for the alpha only. Until you decide on O7, turn AI off for the beta:
```
.\scripts\aws\set-parameter.ps1 -Name AI_ENABLED -Value false
```
- Any other API setting works the same way: `-Name AI_CHAT_PER_HOUR -Value 60`, and so on.
- A setting takes effect on the next release.

## 7. Firebase without a key (Google side, `gcloud`)

The server proves who it is with its AWS role; Google trusts that role for one service account that may manage Firebase users.
- **Project number:** the `FIREBASE_MESSAGING_SENDER_ID` in `apps/mobile/alpha.env`.
- **AWS account id:** from step 0.

```
$P = 'fitos-dev-3208b'; $N = '<project number>'; $A = '<aws account id>'
gcloud services enable iamcredentials.googleapis.com sts.googleapis.com --project $P
gcloud iam workload-identity-pools create fitos-aws --location=global --display-name="FITOS on AWS" --project $P
gcloud iam workload-identity-pools providers create-aws aws --location=global --workload-identity-pool=fitos-aws --account-id=$A --project $P
gcloud iam service-accounts create fitos-api-aws --display-name="FITOS API on AWS" --project $P
gcloud projects add-iam-policy-binding $P --member="serviceAccount:fitos-api-aws@$P.iam.gserviceaccount.com" --role=roles/firebaseauth.admin
gcloud iam service-accounts add-iam-policy-binding "fitos-api-aws@$P.iam.gserviceaccount.com" --project $P `
  --role=roles/iam.workloadIdentityUser `
  --member="principalSet://iam.googleapis.com/projects/$N/locations/global/workloadIdentityPools/fitos-aws/attribute.aws_role/arn:aws:sts::${A}:assumed-role/fitos-beta-server"
gcloud iam workload-identity-pools create-cred-config "projects/$N/locations/global/workloadIdentityPools/fitos-aws/providers/aws" `
  --service-account="fitos-api-aws@$P.iam.gserviceaccount.com" --aws --enable-imdsv2 --output-file=fitos-aws-wif.json
.\scripts\aws\set-parameter.ps1 -FirebaseCredential .\fitos-aws-wif.json
Remove-Item .\fitos-aws-wif.json
```
- `fitos-aws-wif.json` holds no secret, but keep it out of the repo anyway.
- **Fallback** if federation fails: create a key for `fitos-api-aws` in the console and store it with `-FirebaseCredential <key.json>`, then delete the downloaded file.

## 8. CI publishes images

GitHub → the repository → Settings → Secrets and variables → Actions → **Variables** → New:
- **Name:** `AWS_CI_ROLE_ARN`
- **Value:** the **CiPublisherRoleArn** output

From the next push to `main` or a `phase-*` branch, ci-api pushes the smoke-tested image to ECR as `fitos-api:<commit sha>`. The role can push there and do nothing else.

## 9. First release

```
.\scripts\deploy.ps1 -Target aws -Sha <the commit's full sha> -Seed
```
This:
1. checks the image is in ECR;
2. on the server: migrations → the seed → the container → `/health` → Caddy (HTTPS) → smoke;
3. from the PC: `/livez` 200, `/health` 200, `/docs` 404, `/docs/json` 404, `POST /v1/auth/session` 401.

**If HTTPS fails on the first release:** the DNS record is not resolving yet. Wait, then run the same command without `-Seed`.

## 10. Acceptance checks

1. `https://api.tryfitos.me/health` in a browser: `"database":{"reachable":true,...}`.
2. **The hosted APK:**
   ```
   cd apps\mobile
   .\tool\hosted.ps1 -ApiBaseUrl https://api.tryfitos.me -Install
   ```
   Sign in, onboard, log a set and a meal.
3. **Firebase from AWS works:** sign out in the app. This revokes the session through Firebase Admin, which proves step 7. Signing in again works.
4. **Logs:** CloudWatch → Log groups → `/fitos/beta/api`. There is one stream per release, plus `caddy`.
5. **Budget:** Billing → Budgets → `fitos-monthly` exists.
6. **Mess:** after 12 hours, today's mess menu shows in the app.

**Accept ADR-025 when 1–5 pass.**

---

## Every release

```
.\scripts\deploy.ps1 -Target aws -Sha <sha>          # -Seed when reference data changed
.\scripts\aws\rollback.ps1                            # back to the previous release, no migrations
```
- Migrations are forward-only and backward-compatible, so a rollback never needs a down migration.
- A release that fails its checks never takes traffic.

## Maintenance

- **Security updates** install by themselves.
- **Kernel updates** need a reboot. Check, then reboot during a quiet hour; the containers restart on their own:
  ```
  aws ssm send-command --instance-ids <InstanceId> --document-name AWS-RunShellScript --parameters 'commands=["needs-restarting -r || true"]' --profile fitos --region ap-south-1
  aws ec2 reboot-instances --instance-ids <InstanceId> --profile fitos --region ap-south-1
  ```
- **Before a risky migration:** RDS console → the database → Actions → Take snapshot.
- **Backups:** RDS keeps **1 day** of automatic backups (the Free plan refused 7) and can restore to any minute in the last day. Anything older needs a manual snapshot: take one before a risky migration and before a release that changes data, and keep it. Manual snapshots stay until you delete them, and their storage is charged. After an upgrade to the Paid plan, raise `BackupRetentionPeriod` in the template to 7; it changes in place.

## Switching to Google Cloud

The image and database schema are the same on both clouds, and the app only knows the domain. So a switch is:

1. Set up Cloud Run once (`docs/hosting/CLOUD-RUN.md`). Its database can be Cloud SQL or Neon.
2. Release the same commit there: `.\scripts\deploy.ps1 -Target gcp -Sha <sha>`.
3. Pause writes:
   ```
   .\scripts\aws\set-parameter.ps1 -Name RATE_LIMIT_PER_MINUTE -Value 1
   ```
   then release again with `-SkipMigrate`.
4. Copy the data. Run `pg_dump` as `fitos_migrator` on the AWS server, then `pg_restore` into the new database. It takes minutes at beta size; the exact commands get written when a switch is planned.
5. Point the `api` DNS record at the Cloud Run side. A Cloud Run custom domain needs a load balancer or Firebase Hosting in `asia-south1` (CLOUD-RUN.md "Later").
6. Once traffic has moved, delete the AWS stack.

## Tear down

Turn off the database's deletion protection in the RDS console, then:
```
aws cloudformation delete-stack --stack-name fitos-beta --profile fitos --region ap-south-1
```
RDS takes a final snapshot first. Delete it in the RDS console when it is no longer wanted; it costs storage until then.
