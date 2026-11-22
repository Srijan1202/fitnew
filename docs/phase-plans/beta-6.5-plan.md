# Beta 6.5 plan — Clubs together

**Status:** GO (2026-11-20). The owner answered §5:

| # | Answer |
|---|---|
| Q1 | **Club sharing follows friend sharing.** The kinds a person shares with friends also go to every club they are in. There is no separate club switch. |
| Q2 | **Calendar month** (recommended). |
| Q3 | **Club vs club in 6.5** (recommended). |
| Q4 | **One push when the challenge is reached, and one with a match result** (recommended). |

**What Q1 means for people who share today.** They agreed to "friends only" (policy 2026-11-12), so a post reaches their clubs only if both of these hold:
- it was written after they accepted the 6.5 policy, which everyone accepts once;
- it was written after they joined that club.

Nothing older is shown to clubs. Community settings says "friends and your clubs" from 6.5 on.

**Owner change (2026-11-22): the feed is on by default** (K0, §7). A member shares without opting in, and can opt out of any kind. This replaces 6.3's "off until chosen" (ADR-062 D2).

**Asked by the owner (2026-11-20):** "Clubs together": the club items the 6.3 plan left out ("Club feeds, club challenges and club vs club (C6, C7)"), from the final audit (`docs/audits/2026-11-11-final-audit.md` §7).

6.5 is a **full APK** in any case, because it carries the Flutter package updates (`docs/phase-plans/upkeep-2026-12-plan.md`).

## 1. What clubs have today

- **Clubs (5.8, ADR-057):** anyone can make one and share its 8-character code. A person makes up to 5 clubs and joins up to 20, and a club holds up to 500 members.
- **Club boards:** Week, Month and All time, ranked by sessions, run km, active days, streak or plan (6.2 and 6.3).
- **Owner tools (6.2):** rename, a new code, pass ownership, remove a member.
- **The feed (6.3):** friends only. Each kind (sessions, runs, records, streaks) is off until chosen. Cheers and nudges are friends only.

Club-mates who are not friends see each other on the club board and nowhere else.

## 2. What 6.5 builds

| # | Item | Server | App |
|---|---|---|---|
| K1 | **Club feed** | <ul><li>Sharing follows the friends feed (owner Q1): the kinds a member shares go to each of their clubs.</li><li>`GET /community/clubs/:id/feed` returns members' posts written after they joined the club and after they accepted the 6.5 policy. It covers the last 14 days, 20 a page, and leaves out people who are hidden or blocked either way.</li><li>The posts are the same stored posts as the friends feed (`community_posts`), so a kind that is not shared at all is never in a club.</li><li>Cheers extend to club-mates' posts (one per person per post, as now). The evening cheer summary counts them too.</li><li>Leaving a club, being removed, or switching a kind off hides the posts there at once. Nothing is copied.</li></ul> | <ul><li>A club gets **Feed · Board** halves.</li><li>While you share nothing, a card offers it: the same switches as the friends feed.</li><li>Community settings reads "Shared with your friends and your clubs".</li></ul> |
| K2 | **Club challenge (C6)** | <ul><li>`club_challenges`: the club, a metric (sessions, run km or active days), a target, and the period (Q2). There is one challenge at a time per club.</li><li>Only the owner sets it, changes the target or ends it early.</li><li>**No free text:** the title is made from the numbers ("200 sessions together in December"), so nothing needs moderating.</li><li>Progress is the sum of current members' counts in the period, from the same period counts as the Month board. Someone who leaves takes their part with them.</li><li>The target must be between 10 and 100,000. The app suggests last month's club total plus 10%.</li><li>When it is reached: `reached_at`, and the push from Q4.</li><li>Finished challenges are kept for 12 months, for a short history.</li></ul> | <ul><li>A progress bar at the top of the club, showing "143 of 200 sessions · 11 days left" and your own part.</li><li>The owner gets "Set a challenge" with the metric chips, a target and the suggestion.</li><li>The last 3 finished challenges show, reached or not.</li></ul> |
| K3 | **Club vs club (C7)**, if Q3 says 6.5 | <ul><li>`club_matches`: two clubs, one metric, one week (Monday to Sunday).</li><li>An owner challenges another club by its code. The other owner accepts or declines by the Sunday before. An unanswered challenge lapses.</li><li>The **score is the average per member**, so size does not decide it. The members are those in the club when the week starts (`club_match_members`), and someone who joins mid-week does not count.</li><li>It uses each member's own week counts (`community_week_stats`, then the week's history row).</li><li>A club has one match a week. A match against a club that has blocked you is refused: a block between the owners counts as a block between the clubs.</li></ul> | <ul><li>A match card in both clubs: "Hostel A 2.4 · 2.1 Gym B, sessions per member, 3 days left".</li><li>"Challenge a club" in club settings (owner only).</li><li>Accept and Decline for the other owner.</li><li>The result stays on the card for a week.</li></ul> |

## 3. Data and privacy

- **Migration 0056** (done): `club_challenges` and `club_challenge_parts`.
- **Migration 0057** (K3 and K0):
  - `club_matches` and `club_match_members`;
  - `community_profiles.feed_defaulted`;
  - the feed default switched to every kind.
- **Ownership:**
  - A challenge and a match belong to their club, and go with it.
  - Sharing is part of the membership row, so it goes when the person leaves.
  - Data download: a member's own challenge parts are theirs. The download walks a club owner's clubs (as it already does for their members), so the owner's download also holds the club's challenges and matches. Nothing is marked `OTHER_PEOPLES`.
- **Privacy policy:** a new version, which everyone accepts once (as in 6.2 and 6.3). It names:
  - that the kinds shared now reach your clubs as well as your friends, from accepting this version and from joining each club;
  - challenges (the club total and each member's part, shown to the club);
  - and with K3, matches (the club's average shown to the other club; no names cross).
- **Admin:**
  - Club reports already exist.
  - Admin › Clubs shows a club's current challenge and match.
  - Deleting a club takes them with it.

## 4. Release

1. The API comes first (migrations 0056 and 0057). It deploys with `deploy.ps1`, which takes the snapshot and clears the old ones.
2. Then the full APK 1.0.0-beta.6.5 (40), carrying the package updates due by then.
3. Then the website post, deployed with `-Apk`, which announces it.
- The minimum build stays 37. Older apps ignore the new endpoints, and their club screen keeps working.

## 5. Questions for the owner

| # | Question | Recommended |
|---|---|---|
| Q1 | **Club sharing:** is a club feed off until each person switches it on per club, or does it follow their friends sharing? | Off until chosen, per club, as the friends feed is. |
| Q2 | **Challenge period:** a calendar month, or a length the owner picks (1 to 4 weeks)? | Calendar month: it matches the Month board, and each member's month runs in their own time zone. |
| Q3 | **Club vs club:** in 6.5, or later? | In 6.5. It is the other half of what was asked. |
| Q4 | **Pushes:** what does a member get? | One push when the club's challenge is reached, and one with a match's result. Nothing for progress, and no "you're behind". |

## 6. Not in 6.5

- Comments, and free-text challenge titles. Both need moderation.
- Leagues (C14).
- Club roles beyond the owner (co-owners).

## 7. Owner change (2026-11-22): the feed on by default (K0)

**Asked:** "change that feed to be auto in: the person does not have to opt in, he can opt out."

| | Today (6.3) | From 6.5 |
|---|---|---|
| A new member | Shares nothing until they switch a kind on | Shares every kind (sessions, runs, records, streaks) from joining. Community settings switches any kind off. |
| What they are told | Policy: "Each kind is off until you turn it on" | The join screen says, before **Join**, that friends and clubs will see these posts and that any of them can be turned off in Community settings. The policy says the same. |
| Switching off | Deletes that kind's posts | The same |

**Members who joined before 6.5** (owner Q5, 2026-11-22: **on for everyone**):
- Every earlier member gets every kind switched on **once, from the moment they accept the 2026-11-20 policy**. That includes people who had turned kinds off. Nothing from before that moment is posted.
- After that one switch-on, their own changes stick as usual.
- The policy they accept says so in plain words: "If you were already in Community, sharing is switched on for every kind when you agree to this version, even if you had turned some off; you can turn any off again."

**Built as:**
- Migration 0057 adds `community_profiles.feed_defaulted` (false for everyone already in Community).
- Joining stores every kind, with `feed_since` = now and `feed_defaulted` = true.
- In the round, a member with `feed_defaulted = false` who has a consent row at version 2026-11-20 or later gets every kind, with `feed_since` = that consent's time, and `feed_defaulted` = true.
- `FEED_KINDS` stays the same list. The 6.3 "Share your activity" card in the feed shows only to someone who switched everything off.
- **Policy 2026-11-20** (not released yet, so amended in place): "Each kind is on from when you join, or for members who joined earlier, from when you agree to this version, unless you turned it off; you can turn any off at any time."

## 8. What is left (2026-11-22)

**Done** (on phase-19, merged into main at 76c3761):
- Policy 2026-11-20.
- The K1 club feed on the server.
- The K2 core rules and migration 0056.

**In order, one commit each:**

| # | Step | Detail |
|---|---|---|
| 1 | Package updates due | drift 2.35.4, drift_dev, sqlite3 (22 Nov). go_router, synchronized (23 Nov). shared_preferences and objective_c (25 Nov). |
| 2 | K2 server | <ul><li>`GET`, `POST`, `PATCH` and `DELETE /community/clubs/:id/challenge`.</li><li>Parts counted in `refreshOne`.</li><li>After `refreshAll`: totals, the reached push, closing once the month is over everywhere, deleting closed challenges after 12 months.</li><li>Integration tests and the OpenAPI export.</li></ul> |
| 3 | K0 server | <ul><li>Migration 0057 `feed_defaulted`.</li><li>Joining shares every kind.</li><li>Every earlier member switched on once, as in §7.</li><li>The policy text amended in the repo, app and website.</li><li>Tests.</li></ul> |
| 4 | K3 server | <ul><li>Migration 0057 (with K0): `club_matches` and `club_match_members`.</li><li>Challenge a club by code; accept or decline.</li><li>One match a week, refused across a block.</li><li>The per-member average, and the result push after the week.</li><li>Tests and OpenAPI.</li></ul> |
| 5 | App: K0 and K1 | <ul><li>The join screen's sharing line.</li><li>Settings switches on, "Shared with your friends and your clubs".</li><li>Club **Feed · Board** halves.</li><li>Cheers in a club.</li><li>The new policy to accept.</li></ul> |
| 6 | App: K2 | The challenge bar, your part, the last 3 finished, and the owner's "Set a challenge" sheet. |
| 7 | App: K3 | The match card, "Challenge a club", Accept and Decline. |
| 8 | Package updates due | archive, image (28 Nov). Firebase, material_ui (30 Nov). flutter_local_notifications 23 with AGP 9.1.1 and compileSdk 37 (2 Dec). |
| 9 | Admin | Admin › Clubs shows the current challenge and match. |
| 10 | Docs | ADR-064 and the website post (not deployed). |
| 11 | Checks | The whole app (analyze, format, every test), the API suite, the Kotlin and a debug APK in WSL, CI. |
| 12 | Release (owner's go) | <ol><li>The API with `deploy.ps1` (0056, 0057).</li><li>`admin.ps1`.</li><li>The full APK 1.0.0-beta.6.5 (40).</li><li>The website with `-Apk`, which announces it.</li></ol> |

**Outside 6.5:** `snapshots.ps1` about 2026-12-08 (deleting on the owner's yes; deadline 2026-12-11), and the S24 checks for 6.0–6.4.

## 9. Owner's answer (2026-11-22)

| # | Question | Answer |
|---|---|---|
| Q5 | **Members who joined before 6.5:** switch their sharing on too? | **On for everyone**, once, from when each accepts the 2026-11-20 policy, including people who had turned kinds off (recommended was: only those who never touched the switches). The policy says so plainly, and anyone can turn kinds off again. |
