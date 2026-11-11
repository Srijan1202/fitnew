# Final app and security audit — 2026-11-11

**Scope:** the whole project at `phase-19` `41fe815`, one day after beta 6.1 went out:
- code, tests and CI;
- the live servers (api.tryfitos.me, tryfitos.me, admin.tryfitos.me) and the AWS account, read-only;
- the Android app's settings;
- dependencies.

It follows `2026-11-10-audit.md`; findings closed there are not repeated.

**Asked by the owner:** "run a final complete app audit and security audit and also find what new features we can add and how we can improve friends and community and club tab".

The audit changed one line of one test (A9). Every other finding below is a proposal.

## 1. What is healthy

| Area | State |
|---|---|
| CI | Green on all four parts (core, API, admin, app) at `41fe815`. |
| Core | **100 % coverage**: 2,698 branches, 3,975 statements. |
| API | 723 tests: 722 passed on the full run. The one failure was a test that could fail by chance (A9, fixed); its file passes alone, 13 of 13. |
| App | `flutter analyze --fatal-infos` clean; the full test suite passes. |
| Production | API `/health` ok (database 1 ms, answer in 0.27 s). Website and admin answer 200. `version.json` says 6.1 (37); the minimum build is 37. |
| Release | 6.1 is live everywhere. 6.0 Patch 1 gives the forced-update screen the in-app download. |

## 2. Security: what was checked and holds

| Check | Result |
|---|---|
| Sign-in | Every `/v1` route needs a valid Firebase token unless marked public. Only two are public: `/meta/config` and the shared-programme page, which has its own per-address limit. A sweep test checks every new route. |
| Signed-out tokens | Tokens are checked for revocation on every request, so sign-out and account deletion take effect at once. |
| Identity | The user id comes only from the verified token, never from the body, query or a header. |
| Other people's data | 34 routes take an id in the path. The ones spot-checked (runs, saved meals, sessions, food logs, TODAY actions) all scope by the signed-in user, and 14 test files prove "another user's X is 404 or ignored". |
| Admin | Admin routes check the `role=admin` claim before validation, and changes are audited. Admins are made only by the local grant script. |
| Unauthenticated probes (live) | `/v1/admin/users`, `/v1/admin/flags`, `/v1/me/features`, `/v1/community/friends` → 401. `/docs`, `/metrics`, `/.env` → 404. |
| Rate limits | 120 a minute per user (per address when signed out); 10 a minute on sign-in; per-hour AI limits; per-day limits on friend requests (30), reports (10) and club actions (20). |
| Input | Every body, query and path is validated by zod with `.strict()`. No user value reaches raw SQL (the few `sql.raw` uses take constants). Upload routes have explicit size limits. |
| CORS | The API sends no CORS headers, so no other website can call it from a browser. |
| TLS | Let's Encrypt certificate valid to 2027-01-20, renewed by Caddy. TLS 1.1 is refused. HTTP redirects to HTTPS. |
| AWS network | The server accepts only ports 80 and 443. No SSH port and no SSH key. The database accepts only the API server's security group and is not public. |
| AWS data | The database is encrypted at rest with deletion protection on. The one S3 bucket blocks all public access. The server requires IMDSv2. |
| AWS account | No long-lived access keys exist. MFA devices are registered. |
| Secrets | None in tracked files. Every APK is scanned for secrets before it is handed over. Logs mask sensitive values (tested). |
| App | No cleartext traffic. Progress photos are excluded from cloud backup and device transfer. Widgets' receivers are not exported. Tokens are in secure storage. |
| App updates | The in-app update downloads only from `https://tryfitos.me/`, checks the SHA-256, and Android checks the signature. |
| AI | The programme builder sends no name, weight or history (tested). The model's answer is re-checked by core before use. |

## 3. Security findings

| # | Severity | Finding | Proposal |
|---|---|---|---|
| S1 | **High (before public launch)** | **FITOS AI still runs on Gemini's free tier (O7).** On the free tier Google may use what is sent to improve its models. 6.1 sends more than before (the builder's answers, 5.4's food context). The policy says so, but it is the largest privacy gap. | Move to the paid tier or Vertex AI before any user outside the beta group. Owner decision O7. |
| S2 | **Medium** | **Database backups are kept for 1 day only**, on a single server in one zone. A bad migration or a deletion noticed after 24 hours cannot be undone. | Raise RDS backup retention to 7 days (a few rupees a month at this size). Take a manual snapshot before each release with a migration. |
| S3 | **Medium** | **A club owner has no control over their club.** They cannot remove a member, rename the club or change its code. If a code leaks, anyone can join and see the members' handles and weekly counts; the only remedy is a report to the admin. | Owner tools: remove a member, new code, rename, pass ownership. See §6. |
| S4 | Medium | **APKs carry the PC's Android debug key as their v1/v2 signature** (the FITOS release key is v3, by rotation). On Android 8 and older only the debug key counts. Its password is the well-known `android`, so the file itself is the secret, and it is copied into WSL. | Keep the debug keystore backed up and private like the release key. When Android 8 support is dropped, sign with the release key alone. A Play release would use Play App Signing. |
| S5 | Low | **No Content-Security-Policy** on tryfitos.me or admin.tryfitos.me. Both are static and React escapes output, so nothing is exploitable today; a CSP limits the damage if a dependency were ever compromised. The admin panel matters more: an admin's token is in that page. | Add a CSP header in each site's Caddy file (`default-src 'self'`, plus Firebase's hosts for the admin panel). |
| S6 | Low | **The API sends no HSTS or `nosniff` header** (the two sites do). The app only ever uses HTTPS, so the risk is small. | Add `Strict-Transport-Security` and `X-Content-Type-Options` to the API site in `Caddyfile.tmpl`. |
| S7 | Low | **A declined friend request can be sent again at once.** Declining deletes the request, so the same person can ask up to 30 times a day, each with a push. Blocking stops it. | After a decline, refuse a new request from the same person for 7 days (silently, as "requested"). |
| S8 | Low | **Handle search can be walked.** Any member can list handles by two-letter prefix, 10 at a time, within the general 120 a minute. Handles are public by design, but a full list is easy to collect. | A per-day search limit (for example 300), like the other Community limits. |
| S9 | Low | **Every request asks Firebase whether the token was revoked.** It is the safer choice, but each request waits on Google, and a Firebase outage becomes a FITOS outage. | Cache "not revoked" per token for 60 seconds. Sign-out then takes up to a minute to bite. |
| S10 | Low | `pnpm audit`: **6 advisories (5 moderate, 1 low), none high.** New since yesterday: `fast-xml-parser` 5.11.1 under firebase-admin → @google-cloud/storage (FITOS does not use Cloud Storage). | Override `fast-xml-parser` to ≥ 5.12.0. The other five have no patched version in the same major (BACKLOG A4). |
| S11 | Info | `/health` is public and shows the server's uptime. Harmless, but it tells an observer when the server last restarted. | Drop `uptimeSeconds` from the public answer, or leave it. |
| S12 | Info | The app asks for `REQUEST_INSTALL_PACKAGES` (the in-app update). Google Play would refuse it. | For a Play build, remove the permission and the in-app update (Play updates the app itself). |
| S13 | Info (owner) | Legal items before a public launch are still open (O10): the DPDP duties, a named grievance contact, the breach process. | Owner, with a lawyer. |

## 4. App and operations findings

| # | Severity | Finding | Proposal |
|---|---|---|---|
| A1 | Medium | **Everything runs on one small server** (t3.small) in one zone, with a single-zone database. A server fault means the app is down until it is rebuilt. Fine for a beta. | Before a public launch: an uptime alarm on `/health` (CloudWatch or UptimeRobot), and a written restore drill. Multi-AZ later. |
| A2 | Medium | **Community recounts every member every 5 minutes, one at a time**, each with a streak calculation. At 50 members it is nothing; at 5,000 the loop would not finish inside its 5 minutes. | Recount a person when they sync a session or a run, and keep the timer only as an hourly catch-up. |
| A3 | Low | The forced-update screen had no in-app download (found by the owner on release day). | **Fixed** in `41fe815` and 6.0 Patch 1. 6.1 phones get it with the next 6.1 patch or release. |
| A4 | Low | Build with FITOS AI has still not been called against the real Gemini (yesterday's #2 and #24). | Owner: allow FITOS AI on a phone, then one live call. |
| A5 | Low | `main` is 14 commits behind `phase-19` (6.0, 6.1 and the fixes). | Owner: merging needs your go. |
| A6 | Low | S24 field checks are pending for 4.5–4.9.1, 5.0–5.1.1 and 5.8–6.1; ADR-045 to ADR-060 stay Proposed until then. | Owner. |
| A7 | Low | Flutter packages are a minor version behind, and four plugins still apply the Kotlin Gradle Plugin, which a future Flutter will refuse (firebase_auth, firebase_core, firebase_crashlytics, flutter_tts). | BACKLOG E5: one upgrade pass before the next Flutter upgrade. |
| A8 | Low | A worktree made with absolute paths cannot be read from WSL, so a patch to an older release failed until `git worktree repair --relative-paths`. | Note it in `tool/patch.ps1`'s header, or have the script do it. |
| A9 | Low | **A test that failed by chance.** The admin support-lookup test checked that the answer did not contain "500" (the hidden meal's calories). The answer holds random ids and timestamps, which now and then contain "500"; it failed once in this audit's full run. | **Fixed:** it checks that no `kcal` field is in the answer. |
| A10 | Info | The two timing tests in the API suite can still fail on a busy PC (yesterday's #7). | Read a failure there as "the PC was busy" first. |

## 5. New features worth adding

Ordered by value for the effort. S, M and L are small, medium and large.

| # | Feature | Size | Why |
|---|---|---|---|
| N1 | **Home-screen quick log**: a widget button and a notification action for "log water" and "start today's session". | S | The widgets exist since 5.0; this makes them do something. |
| N2 | **Rest timer on the lock screen** as an ongoing notification with +15 s and Skip. | S | The most-asked gym feature in every tracker; the app already schedules notifications. |
| N3 | **Plate calculator**: tap a barbell weight to see which plates go on each side. | S | Pure core maths, no server. |
| N4 | **Body measurements** (waist, chest, arms, hips) with a trend, beside weight. | M | Progress photos and weight exist; measurements complete the picture and feed the monthly PDF. |
| N5 | **Barcode scan for packaged food** (Open Food Facts, open licence). | M | Closes much of the food-database gap (E13) for packaged items without licensing work. |
| N6 | **Supersets and circuits** in a session: pair two exercises, one rest after both. | M | Common in real programmes; the AI builder could then use them to fit a short session. |
| N7 | **Deload weeks**: FITOS proposes a lighter week after 4–6 hard ones, from readiness and the volume trend. | M | The readiness and volume numbers exist; this turns them into advice. |
| N8 | **Wear OS companion**: start a session or run and log sets from the Galaxy Watch. | L | 4.5 reads the watch through Health Connect; a real watch app is the step after. |
| N9 | **Export to Strava or a GPX file** for runs. | S (GPX), M (Strava) | Runners expect it; GPX needs no account or API key. |
| N10 | **Cycle-aware training for people who menstruate**: an optional phase note on TODAY. | M | Opt-in health data with its own consent; valued where offered. |
| N11 | **Year in FITOS**: a yearly shareable card, from the monthly report's numbers. | S | Built almost entirely from 6.1's monthly report. Timely for December. |
| N12 | **iOS build.** | L | The code is Flutter; it needs an Apple account, HealthKit in place of Health Connect, and App Store review. |

## 6. Improving Friends, Clubs and the Community tab

**What exists today (5.8–5.9):** join with a handle and consent; friends by handle; blocks and reports; clubs joined by an 8-character code; three weekly boards (friends, a club, the world) by gym sessions or run kilometres. A board holds counts only.

**What is missing:** after the first look, there is little reason to open the tab again. A board changes slowly, nothing happens between people, and a club is only a list.

### Give people something to do to each other

| # | Idea | Size | Notes |
|---|---|---|---|
| C1 | **Activity feed**: "@asha finished Push day", "@ravi ran 5.2 km", "@meera set a squat record". | M | Opt-in per kind in Community settings, off by default. It shows the event, never weights unless the person turns that on. |
| C2 | **Kudos**: one tap on a feed item, with one push a day at most ("3 friends cheered your run"). | S | Needs C1. The cheapest way to make the tab feel alive. |
| C3 | **Nudge a friend** who has not trained in 3 days: one set message, once a week per friend. | S | A fixed message, so no moderation is needed. |
| C4 | **Friend profile**: tap a friend to see their streak, this week's counts, their badges and their avatar. | S | Everything shown is already on a board or earned in Rewards. |

### Make clubs worth joining

| # | Idea | Size | Notes |
|---|---|---|---|
| C5 | **Owner tools**: remove a member, new code, rename, pass ownership. | S | Also security finding S3. Do this first. |
| C6 | **Club challenges**: the owner sets a goal for the month ("200 sessions together", "500 km"), with a shared progress bar. | M | A shared goal works better than a ranking for people at the bottom of a board. |
| C7 | **Club vs club**: two clubs, one week, average per member so size does not decide it. | M | Fits VIT hostels and gym groups. |
| C8 | **Invite link**: `tryfitos.me/c/CODE` opens the club in the app, or the download page. | S | The website already serves shared programmes this way. |
| C9 | **Club badge and colour** picked by the owner from a fixed set. | S | No uploads, so nothing to moderate. |
| C10 | **Share a programme to the club**: pin one shared-programme code as "the club's plan". | S | Reuses share codes; a coach's club becomes useful. |

### Make the boards fairer and more interesting

| # | Idea | Size | Notes |
|---|---|---|---|
| C11 | **More metrics**: streak, active days, and "kept my plan" (sessions done ÷ planned). | S | "Kept my plan" lets a 3-day lifter beat a 6-day one, so beginners can win. |
| C12 | **Last week's podium** and a "you moved up 4 places" line. | S | Needs last week's counts kept, which the stats table can hold. |
| C13 | **Monthly and all-time boards** beside the weekly one. | S | |
| C14 | **Leagues**: groups of 30 on the world board, top 5 move up each week. | L | Keeps a world board meaningful once it has thousands of people. Later. |

### Finding people

| # | Idea | Size | Notes |
|---|---|---|---|
| C15 | **QR code for your handle**, scanned with the in-app camera. | S | Faster than spelling a handle in a gym. |
| C16 | **"Friends of friends" and club-mates as suggestions.** | S | No contacts upload, so no new privacy ground. |

### Safety and scale, alongside

- S3 (owner tools), S7 (cooldown after a decline) and S8 (search limit) from §3.
- A2: recount on sync, not every 5 minutes.
- If C1 is built: a feed is new personal data shown to others. It needs a line in the privacy policy, its own switches, and blocks must hide feed items both ways.

### Suggested order

1. **6.2 "Community that moves":** C5, C8, C4, C11, C12, C15, with S7, S8 and A2.
2. **6.3 "Together":** C1, C2, C3, C6.
3. **Later:** C7, C9, C10, C13, C16, then C14 when the world board is large.

## 7. Checks run

- Core: `pnpm test:coverage`.
- API: full `vitest run` against `fitos_test`.
- App: `flutter analyze --fatal-infos`, full `flutter test`.
- CI: GitHub check runs at `41fe815`.
- Repo: `pnpm audit`; greps for public routes, raw SQL, body limits and path parameters.
- Live: response headers, CORS probe, unauthenticated probes, TLS certificate and version, `/health`, `/meta/config`, `version.json`.
- AWS (read-only): security groups, RDS settings, EC2 metadata options, S3 public-access blocks, IAM access keys and MFA.
- Android: manifest permissions, exported components, backup rules.

## 8. Status after beta 6.2 (built 2026-11-11, not released)

The owner said "do it for beta 6.2". The plan is `docs/phase-plans/beta-6.2-plan.md` and the decisions are ADR-061.

| # | Status |
|---|---|
| S2 | **Changed.** The free tier refuses more than 1 day of automatic backups (`FreeTierRestrictionError`). Instead, `deploy.ps1` takes a manual snapshot before every release, keeps the newest 3 and deletes any older than 30 days. A baseline snapshot was taken on 2026-11-11. The privacy policy says so. |
| S3 | **Built:** club owner tools (rename, new code, pass, remove and keep out until let back). |
| S5 | **Built:** a CSP on tryfitos.me (enforced). On the admin panel, the safe parts are enforced and the full policy is report-only until a sign-in has been checked with it. |
| S6 | **Built:** HSTS and `nosniff` on the API, live from the next API release. |
| S7 | **Built:** a 7-day cooldown after a decline. |
| S8 | **Built:** 300 handle searches a day. |
| S9 | **Built:** a 60-second cache of verified tokens, cleared on sign-out, a role change and account deletion. |
| S10 | **Waiting:** `fast-xml-parser` 5.12.0 was published 2026-11-03. It goes in once it is two weeks old; FITOS does not use the affected path. |
| A2 | **Built:** a member is recounted when they finish a session or save or delete a run; the full round runs hourly. |
| A8 | **Built:** `tool/patch.ps1` repairs a worktree's paths for WSL. |
| C4, C5, C8, C11, C12, C15 | **Built** (§6). |
