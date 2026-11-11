# Beta 6.2 plan — Community that moves, and the audit's fixes

**Asked by the owner (2026-11-11):** "do it for beta 6.2", after the final audit (`docs/audits/2026-11-11-final-audit.md`), whose §6 suggested this release.

## Owner's decisions (2026-11-11)

| # | Question | Answer |
|---|---|---|
| Q1 | How do invite links and the handle QR code reach the app? | **Android App Links:** the link opens FITOS directly. A phone without FITOS gets a website page with the download. |
| Q2 | Can a member removed from a club rejoin with the code? | **No, until the owner lets them back.** |
| Q3 | What does a friend's profile show? | **Board data only:** avatar, handle, country, streak, this week's counts, the last 4 weeks, shared clubs, "friends since". |
| Q4 | The privacy policy covers only this week's sessions and run distance, and the streak. | **Update the policy:** add active days, how much of the plan was kept, and the last 4 weeks of these counts. Everyone accepts the new version once. |
| Q5 | Raise database backups to 7 days? | **Yes, Claude makes the change.** The free tier refuses more than 1 day, so instead `deploy.ps1` takes a manual snapshot before every release and keeps the newest 3. A baseline snapshot was taken on 2026-11-11. |

## What 6.2 builds

### Community
| # | Item | Server | App |
|---|---|---|---|
| C5 | **Club owner tools** (audit S3) | `PATCH /community/clubs/:id` renames the club. `POST …/code` gives it a new code. `POST …/owner` passes ownership. `DELETE …/members/:userId` removes a member and keeps them out. `GET …/removed` and `DELETE …/removed/:userId` list removed people and let one back. A removed person who tries the code gets 403 `removed`. | A club settings sheet for the owner: rename, new code, members with Remove, removed people with Let back, pass ownership. |
| C8 | **Invite link** | — | Share `https://tryfitos.me/c/<CODE>` from the club. Opening it in FITOS shows "Join <club>?". |
| C15 | **QR code for your handle** | — | Community settings and Add a friend show a QR code of `https://tryfitos.me/u/<handle>`. The phone's camera opens FITOS on "Add @handle?". The QR is drawn with `barcode`, already in the app through `pdf`. |
| C4 | **Friend profile** | `GET /community/people/:userId`, for friends and club-mates only, otherwise 404. | Tap a person on a board or in Friends. Shows streak, this week, the last 4 weeks, clubs you share and "friends since", with Report, Block and Unfriend. |
| C11 | **More boards** | Two new board metrics alongside sessions and distance: `streak`, `active-days` (days with a counted session or run) and `plan` (sessions done ÷ sessions planned up to today, at most 100 %). People with no plan this week are not on the `plan` board. | A metric menu in place of the two-way toggle. |
| C12 | **Last week** | Each board gets `lastWeek`: the top 3 last week, your place last week and, on friends and club boards, how many places you moved since the week before. | A podium row above the board, and "You were 3rd last week, up 2". |

### Security and operations (from the audit)
| # | Item |
|---|---|
| S5 | A Content-Security-Policy on tryfitos.me (enforced). On admin.tryfitos.me, the parts that cannot break sign-in are enforced (`object-src`, `base-uri`, `frame-ancestors`, `form-action`); the full policy runs as report-only until a sign-in has been checked with it. |
| S6 | HSTS and `nosniff` on the API. |
| S7 | After someone declines your friend request, you cannot ask them again for 7 days. The app still says "requested" and no notification is sent. |
| S8 | Handle search: 300 a day per person. |
| S9 | A verified token is trusted for up to 60 s without asking Firebase again. Sign-out and account deletion on the server clear it at once. |
| S10 | Override `fast-xml-parser` to the patched 5.x. |
| S2 | A database snapshot before each release (see Q5). |
| A2 | Community counts are redone when a session completes or a run is saved. The full recount runs hourly, not every 5 minutes. |
| A8 | `tool/patch.ps1` repairs a worktree's paths for WSL by itself. |

### Data
- **Migration 0054:**
  - `community_week_stats` gains `active_days` and `planned`.
  - `community_week_history` keeps one row per person per past week, the last 8 weeks. It is written when a person's week rolls over, recounting the finished week first.
  - `club_bans`.
  - `friend_declines`.
- **Download my data and Delete account** cover the new tables.
- **Policy 2026-11-12:**
  - The Community section names the new counts and the last 4 weeks.
  - The QR code and links hold only the handle or club code.

### Release
- A full APK: the App Links manifest change and a new `barcode` dependency.
- The minimum build stays at 37: 6.2's API only adds things, so 6.1 keeps working.
- The website gets the `/c/` and `/u/` pages, `/.well-known/assetlinks.json` (the release key's fingerprint and the older debug key's), and the CSP.

## Not in 6.2
The activity feed, kudos, nudges and club challenges are 6.3 "Together" (audit §6). Leagues come later.
