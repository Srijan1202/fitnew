# ADR-061 — Beta 6.2: Community that moves, and the final audit's fixes

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

On 2026-11-11 the owner said "do it for beta 6.2" to the final audit's suggestion (`docs/audits/2026-11-11-final-audit.md` §6) and answered the plan's questions (`docs/phase-plans/beta-6.2-plan.md`):
- App Links for invites;
- a removed member stays out until let back;
- a profile shows board data only;
- update the privacy policy for the new counts;
- Claude raises the backups.

## Decisions

| # | Decision |
|---|---|
| D1 | **Five boards (C11).** <br>• Sessions, distance, streak, `active-days` (days with a counted session or run) and `plan` (sessions done ÷ sessions planned up to today, at most 100 %). <br>• Core `community/board.ts` holds the rules: `boardKey`, `rankBy`, `keptPlanPct`, `plannedBetween`, `placesMoved`. The world board's SQL orders by the same keys. <br>• People with no plan are not on the plan board. On the world board, someone counts only once something counted this week. <br>• `community_week_stats` gains `active_days` and `planned`. |
| D2 | **Last week (C12).** <br>• `community_week_history` keeps each person's finished weeks, the newest 8. A week is written when that person's week rolls over, after the finished week is recounted from the records, so a late sync still counts. <br>• Each board carries `lastWeek`: the top three (who counted something), the viewer's place, and the places moved since the week before. |
| D3 | **A friend's or club-mate's profile (C4).** <br>• `GET /community/people/:userId` is for friends and club-mates only, and 404 for anyone else, for yourself and for blocks either way. <br>• It returns board data only: the streak, this week, the 4 weeks before, the clubs you share and "friends since". |
| D4 | **Club owner tools (C5, audit S3).** <br>• The owner can rename the club, make a new code (the old one stops working), pass ownership (the new owner gets a push) and remove a member. <br>• A removed member is kept out through `club_bans`: joining with the code is 403 `removed` until the owner lets them back. <br>• A member who is not the owner gets 403 `not-owner`. A non-member gets 404. |
| D5 | **Invite links and QR codes (C8, C15, owner Q1).** <br>• `https://tryfitos.me/c/<code>` and `/u/<handle>` are Android App Links. The intent filter sits on MainActivity with `autoVerify`. `/.well-known/assetlinks.json` lists the FITOS release key and the older debug key (rotation, ADR-043). <br>• MainActivity hands the link to Dart over `fitos/widget`, like a widget tap, so it waits until someone is signed in. The router never sees it, because deep linking stays off (5.1). <br>• Nothing happens until a tap: Join the club, or Ask to be friends. <br>• Without FITOS, the website page shows the code and how to get the app. <br>• The QR code is drawn on the phone with `barcode` (already there through `pdf`), always black on white. It holds only the link. |
| D6 | **A 7-day cooldown after a decline (S7).** <br>• `friend_declines` records it. Asking again inside 7 days answers "requested", stores nothing and sends no push. <br>• The table is "other people's" for the data download: the requester never learns who declined. Cancelling your own request is not a decline. |
| D7 | **Limits and load.** <br>• Handle search: 300 a day (S8). Owner actions: 60 a day. <br>• A member's week is recounted after `POST …/sessions/:id/complete`, `POST /running/runs` and `DELETE /running/runs/:id` (an `onResponse` hook on `/v1`, A2). The full recount runs hourly, not every 5 minutes. |
| D8 | **A verified token is trusted for 60 s (S9).** <br>• `VerifiedTokenCache` keys on a SHA-256 of the token and never keeps an entry past the token's own expiry. <br>• Sign-out, an admin role change and account deletion on this server forget the person's tokens at once. A revocation made elsewhere takes effect within a minute. |
| D9 | **Headers (S5, S6).** <br>• The API sends HSTS and `nosniff`. <br>• tryfitos.me enforces a CSP: its own files, plus the API for shared programmes. <br>• The admin panel enforces the parts that cannot break Google sign-in (`object-src`, `base-uri`, `frame-ancestors`, `form-action`). The full policy is report-only until a sign-in has been checked with it. <br>• Enforced in full on 2026-11-11, after the owner signed in and the panel's pages (Overview, Support, Exercise demos with their images) showed no violation. |
| D10 | **Backups (S2, owner Q5).** <br>• The free tier refuses more than one day of automatic backups. <br>• `deploy.ps1` takes a manual snapshot before every release. It keeps the newest three and deletes any older than 30 days (AWS.md). |
| D11 | **Privacy policy 2026-11-11.** <br>• Community names the new counts and the last 4 weeks. <br>• The owner can remove a member. <br>• Links and QR codes hold only a handle or code. <br>• Past weeks are in the download. <br>• "How long" says a snapshot is taken before each server update and deleted within 30 days. <br>The repo, the website and the app say the same, and everyone agrees again once. |
| D12 | **Not done.** <br>• S10 (`fast-xml-parser` 5.12.0) waits until the release is two weeks old: FITOS does not use the affected path. <br>• `patch.ps1` now repairs a worktree's paths for WSL (A8). |

## Consequences

- 6.2 is a full APK, because of the manifest's intent filter and the `barcode` dependency. The minimum build stays at 37: 6.2's API only adds things, so 6.1 keeps working.
- App Links verify only once the website's `assetlinks.json` is live. Until then, a link opens the website page.
- The past is counted with today's programme, as the streak already is (ADR-060, audit #19).
