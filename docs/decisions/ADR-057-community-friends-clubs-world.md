# ADR-057 — Beta 5.8: Community (friends, clubs and the world board)

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

The owner, 2026-11-08: "lets do F12 Friends / VIT leaderboard … for the next beta; dont just focus on VIT we have to make world level". The plan was approved the same day ("go"), with the recommendations:
- the boards rank consistency only;
- the world board is a separate choice, off by default;
- Community is free for everyone;
- the spec is amended.

## Context

MASTER-SPEC §35 ruled out leaderboards ("a comparison engine; high moderation cost"), and §37 listed opt-in friends accountability for later. This ADR amends §35. Community is allowed only under the rules below, and a social feed stays out.

## Privacy

| # | Decision |
|---|---|
| P1 | **Off until joined.** Joining is its own consent, `community`, recorded in `consent_records` with the policy version (it must be the current one). Nobody can see or find a person before they join. |
| P2 | **The purpose is given and withdrawn in Community** (join, leave). It is not in the Privacy screen's list: an app without Community would fail to read a purpose it does not know. The database enum gains the value (`STORED_CONSENT_TYPES`). |
| P3 | **What others see:** a handle the person picks (3–20 of a–z, 0–9, _), their profile picture, and an optional country. Never a name or email. |
| P4 | **Counts only:** gym sessions and run distance this week, and the current streak. Never weights, food, body data, photos, readiness, sleep, heart rate or routes. |
| P5 | **The world board is a separate choice**, off by default, and can be changed any time. A member who is not on it can still see it. |
| P6 | **Leaving is instant.** The profile, friendships, club places and counts go. A club the person made passes to its longest member, or goes when it has none. Blocks stay, because they protect the blocker. The consent is recorded as withdrawn. |
| P7 | Every table is owned by its person (CASCADE), so it is in Download my data and is deleted with the account. A club goes with its maker's account. |
| P8 | The policy gains a Community section (version `2026-11-08`), so everyone accepts it once. |

## What it does

| # | Decision |
|---|---|
| C1 | **Friends.** Add by handle, either from search or the share sheet's invite text. Both sides must accept, and asking someone who already asked you accepts. Up to 300 friends. |
| C2 | **Clubs.** Anyone can make one and share its 8-character code (no 0/O/1/I), so it works for a hostel, a gym or a running crew anywhere. Up to 5 made, 20 joined, and 500 members a club. |
| C3 | **Boards.** Friends (you and your friends), each club, and the world (top 100, worldwide or one country, with your own place when you are lower). They rank by gym sessions, or by run km when chosen. Equal counts share a rank. The week is Monday to Sunday in each person's own time zone. |
| C4 | **What counts** (`COUNTED_SESSION`, `COUNTED_RUN`). A gym session counts when it is completed with at least 6 sets and 15 minutes, at most one a day. A run counts when it is recorded by GPS or a watch, is at least 500 m, and has a pace between 2:50 and 20:00 per km. A phone treadmill run (typed in) never counts. The server counts from the synced records; the phone never sends a score. |
| C5 | **Counts table.** The counts sit in `community_week_stats`. The server recounts every member every 5 minutes, and the viewer whenever they open a board. A board of any size is then one indexed read. |
| C6 | **Pushes:** only "New friend request" and "Friend request accepted". The app opens Community on Friends. Nothing like "you were overtaken", and no red (§17). |

## Safety

| # | Decision |
|---|---|
| S1 | **Handles.** The pattern is checked; reserved names (fitos…, admin, support…) are refused; a short blocked-word list is checked after undoing letter swaps. Unambiguous words match anywhere, the others only at the start of a word, so "grapes" passes. Club names get the same word check. |
| S2 | **Block.** The blocked person cannot find, add or see the blocker, either way, and a friendship ends. Unblock is in Community settings. |
| S3 | **Report** a handle, a club name, cheating or harassment, with an optional note. |
| S4 | **Admin › People › Community:** reports (close them), members (hide from every board and search, or rename a handle), and clubs (delete). Every action is audited. |
| S5 | **Rate limits a day:** 30 friend requests, 20 club creations or joins, 10 reports. |
| S6 | **The admin's `community` switch.** When off, the server refuses Community and the app hides it. Leaving still works. |

## In the app

| # | Decision |
|---|---|
| A1 | **A Community screen** (`/community`), opened from a Home card and from Profile. At the top is Friends · Clubs · World, on the switch Training and Progress use. `FitModeSwitch` now takes any number of parts. |
| A2 | **Joining** says what others see, what is never shared, and what the person controls. Then come the handle, a searchable country list with flags, and the world-board switch. |
| A3 | **Community settings:** handle, country, world board, blocked people, Leave. |
| A4 | It uses only icons already in the 5.3 release's font, and has no new dependency, so it ships as a Shorebird patch. |

## Release

- **API:** migration 0048. The owner runs `deploy.ps1`.
- **Admin:** the Community page. The owner runs `admin.ps1`.
- **App:** a Shorebird patch to 1.0.0-beta.5.3 (build 33).
- **Then:** the owner checks the S24 and accepts.
