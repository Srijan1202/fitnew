## PHASE 19 — BETA ON AWS — IMPLEMENTATION COMPLETE, ACCEPTANCE PENDING

**Date** 2026-10-22 · **Branch** `phase-19` from `phase-18` (approval pending) · **not merged**

**Status:** **implemented, tested and live on the beta server; NOT accepted, NOT frozen.**
- §38 Phase 19 is not ticked.
- ADR-025, ADR-026, ADR-027, ADR-028, ADR-029 and ADR-030 are PROPOSED.

**Live:**
- `https://api.tryfitos.me` serves release `ca58df2`. Later commits change only the app and CI, so no redeploy is needed.
- Beta APK: **1.0.0-beta.3 (6)**, built at `cfe8aca`, tag `phase-19-beta-3`, SHA-256 `fba4e77a…c757`.
- **Beta 3.1** (2026-10-23): **1.0.0-beta.3.1 (7)**, built at `d6fa01a`, tag `phase-19-beta-3.1`, SHA-256 `d8d40876…db72`; API release `d6fa01a`. Fixes: sets open at last time's weight and reps, with the engine's step as a suggestion and an Apply button (ADR-007 amendment); the Training day shows last time; Done today; FITOS AI scope guard rails (ADR-010 amendment). On tryfitos.me (download and the post `/blog/beta-3-1/`) and GitHub. Improvements go into beta 3.2.

**Decision record:**
- [plan](../phase-plans/phase-19-plan.md);
- [ADR-025](../decisions/ADR-025-aws-beta-hosting.md) (AWS);
- [ADR-026](../decisions/ADR-026-beta-app.md) (the beta app);
- [ADR-027](../decisions/ADR-027-premium.md) (Premium);
- [ADR-028](../decisions/ADR-028-brand-themes.md) (brand themes);
- [ADR-029](../decisions/ADR-029-glass-blocks.md) (the glass look);
- [ADR-030](../decisions/ADR-030-skip-today.md) (skip today).

### 1. WHAT WAS BUILT

| Area | What | Commits |
|---|---|---|
| Hosting | AWS (ADR-025): CloudFormation stack `fitos-beta` in Mumbai, with one EC2 server (Docker, Caddy HTTPS), RDS Postgres 18, ECR and SSM parameters. Blue/green releases over SSM with no SSH. Google Cloud kept as a second target (`scripts/deploy.ps1 -Target aws\|gcp`). Firebase reached from AWS through Workload Identity Federation (no key). CI pushes images through GitHub OIDC | `af10abe`…`ada598f`, `81b7cc6`, `a4a5a0c`, `7b58cb4` |
| The beta app | Package `me.tryfitos.app`, crash reports (on by default, switch in Privacy & data), in-app feedback read in the admin panel, Play upload signing, a minimum-build gate | `f9d3cc9`, `0ee054b`, `177807b` |
| Premium | FITOS AI behind Premium. Requests from the AI tab and Profile, approved in the admin panel; admins are premium. Ten pictures (three premium) and a gold rim, higher AI limits, the weekly report, colour themes | `1008375`, `c6820b2` |
| Brand | The brand kit (`brand/`): logos, icons, favicons, headers, banners, palette, type, templates. The app follows it: FITOS Dark (default) and FITOS Light, Barlow, the kit's logo, launcher icon and splash | `1c6276a`, `0ed89d1` |
| The look | Rounded, translucent blocks with a lime glow on every screen except on Paper. Profile as grouped settings. Onboarding progress line | `86733d1`, `6aa7a80`, `de86ea8`, `5b78378` |
| Training | RIR no longer asked. **Skip today**: the week moves one day later; undo the same day | `f2c126f`, `ca75b1f`, `ca58df2` |
| Fixes | Greeting fits two lines; sheet polish; plugin upgrades (Firebase 5/7/6/17, secure storage 11, share/package info); arrows the font lacks; a cut-off Progress number; secret scan paths; CI actions on Node 24 | `b3a66ee`, `23b4ccc`, `12f436e`, `cfe8aca` |

Database migrations: 0021 feedback, 0022 premium and 0023 program skip, each with a down migration.

### 2. ACCEPTANCE (automated)

- **Beta server:**
  - `/livez`, `/health` and the database answer;
  - `/docs` is hidden (404);
  - requests without sign-in are refused (401);
  - releases are checked by `scripts/aws/deploy.ps1`.
- **CI on `phase-19`:** green on every suite (api, core, admin, mobile). The image is pushed to ECR on each commit.
- **Skip today, against real Postgres:**
  - every day moves one weekday, keeping its id and order;
  - today is marked skipped, and tomorrow brings today's session;
  - undo restores the week;
  - refused when already skipped, when a session is open, or after training today;
  - 404 without a programme.
- **Migration 0023:** the weekday rule is a deferrable constraint, seven days move in one update, and the down migration restores the index.
- **Reminders:** no workout reminder on a skipped day, and no "missed session" the next morning.

### 3. TESTS

| Suite | Count |
|---|---|
| core | 975, branch coverage **100 %** (2,363 branches) |
| contracts | 86 |
| API | 529 |
| Flutter | 722 |

- TypeScript typecheck and ESLint: clean.
- `flutter analyze --fatal-infos`: clean.

### 4. WHAT CHANGES FOR YOU

- Install beta 3 over beta 2; your data stays.
- The first launch may take a moment online to reload your profile: the secure-storage upgrade can't read the old cached copy.
- After that, you may notice:
  - the app opens in FITOS Dark;
  - RIR is gone from the set rows;
  - Profile has a new layout;
  - the Training tab's ⋯ menu has **Skip today** on training days.

### 5. MANUAL CHECKLIST (S24, beta 3)

1. **Install:** install over beta 2. You stay signed in, your data is there, and the launcher icon is the lime F on black.
2. **Themes:** Profile → Appearance.
   - FITOS Dark, FITOS Light and Paper: text is readable everywhere.
   - Paper is flat, with no rounded blocks.
   - On a premium theme (Night), the text and the tab bar are readable.
3. **The look:** walk the tabs (Home, Training, AI, Nutrition, Progress) and Profile. Blocks are rounded and glow lime, nothing is cut off, and the greeting fits.
4. **Training:**
   - log a set: there's no RIR control;
   - the recommendation line reads like "↑ 75 kg × 6".
5. **Skip today:** on a training day, Training → ⋯ → Skip today → confirm.
   - Today shows **Skipped**, naming tomorrow's session.
   - Home's workout tile says Skipped.
   - **Undo skip** puts the week back.
   - Skip again, then check tomorrow that the week continues from there.
6. **Premium:**
   - as a free user, the AI tab shows the request;
   - after approval in the admin panel, the chat works;
   - the gold rim and premium pictures appear.
7. **Feedback:** Profile → Send feedback. It appears on the admin panel's Feedback page.
8. **Crash reports:** Privacy & data → the switch is on by default and can be turned off.
9. **Onboarding:** with a new account, the thin lime progress line fills step by step.
10. **Sheets:** open a few (portion, mess dish, Premium). Each has a grab handle and rounded fields.

**Accept Phase 19 when you're satisfied.** Then:
- ADR-025 to ADR-030 become ACCEPTED;
- §38 Phase 19 is ticked;
- this report is updated.

No merge without your approval.

### 6. OPEN

- **Published:** the GitHub pre-release `phase-19-beta-3` with the APK (SHA-256 checked after upload).
- **Your steps:** Play Console: the upload key, the account and internal testers ([PLAY.md](../hosting/PLAY.md)).
- **Website:** built in a separate repository (`D:\dev\fitos-website`). CloudFront needs AWS to verify the account first, so for now the API server's Caddy serves `tryfitos.me` too: the Caddyfile imports `sites/*.caddy` (`3578736`), and the website repository's `deploy\deploy.ps1` publishes the site and the APK over Systems Manager. It goes live once the domain's new A record (→ the Elastic IP) is published. Its `/privacy/` page is the privacy policy URL that Play needs.
- **Before a public launch** (privacy policy, §23): the DPDP obligations, a named contact and grievance officer, and FITOS AI off Google's free tier (O7).
- **Waiting on others:** firebase_auth, firebase_core and firebase_crashlytics still apply the Kotlin Gradle Plugin in their newest versions (a Flutter build warning). FCM keeps `getToken` until server push (O9) moves to installation IDs.
- **Later:** admin controls on the website (an in-browser `/admin` calling `/v1/admin/*`; needs CORS); a rolling-cycle programme mode (ADR-030 option 3).
- **Still open from before:** O2, O3, O5, O7, O8, O9, O10; approval of Phases 16, 17 and 18.
