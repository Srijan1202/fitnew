# ADR-066 — Beta 6.7: Community revamp, and Progress and Recovery on Home

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

## Context

On 2026-11-27 the owner asked for a UI revamp "specially focused on the community tab, but also check and see what we can change". Every Community screen was drawn at phone width with sample data, and the plan (`docs/phase-plans/beta-6.7-plan.md`) was answered with every recommendation:

| # | Answer |
|---|---|
| Q1 | Three tabs: Feed · Boards · Clubs, with People behind an icon. |
| Q2 | Feed opens first. |
| Q3 | Selected chips in the accent, app-wide. |
| Q4 | 6.7 ships with 6.5 and 6.6, in one APK. |
| Q5 | The clubs list's `now` line, as recommended (not asked: the form takes four). |

While it was being built, the owner added: "i also want to move progress and recovery to the home page" (H1).

## Decisions

| # | Decision |
|---|---|
| D1 | **Community tabs (R1, A2).** <br>• Feed · Boards · Clubs, opening on the Feed. <br>• There is no app bar: the switch is on top, like Training and Nutrition, with **People** (badged with the request count) and settings beside it. <br>• **People** (`/community/people`) holds requests, the friends list (new: friends were only on the board before), people you may know, those waiting, and the invite. A friend-request push opens it. <br>• **Boards** is one board with Friends · country · World and one set of controls. The world note shows only on the country and world boards. |
| D2 | **Boards (R2, R3).** <br>• The period is a small menu at the start of the metric row, so the controls fit on one line. <br>• Last week's podium has first place in the middle, raised, on steps in gold, silver and bronze taken from the palette (amber, ink60, oxide). |
| D3 | **Feed (R4).** <br>• Posts sit under Today, Yesterday or the date. <br>• A small mark on each avatar shows the kind: dumbbell, run, trophy for a record, flame for a streak. <br>• The cheer is always a heart with its count, in a column of fixed width. |
| D4 | **Clubs (R5).** <br>• `GET /community/clubs` gives each club `now`: this week's match while it's on (the other club's name and both averages), else this month's challenge once started (total, target, days left), else null. No migration. <br>• The card shows a mark in the club's colour, members, your part, the winner's trophy, and that one line (with a bar for a challenge). The clubs you run come first. The code is no longer on the card. |
| D5 | **Club screen (R6, A4).** <br>• Under the name: the members, your part, and an **Invite** button that opens the code, the QR and the link in one sheet. The code card is gone. <br>• Then this week's match, the month's challenge, the month in numbers, the league and the board. <br>• The league card's three links became a share icon and one action row, with "Leave the league" in its ⋯ menu. <br>• The plan suggested the match and the challenge side by side; they stay stacked, because both cards carry their own actions and are too wide for half a phone. |
| D6 | **Empty states and joining (R7, R8).** <br>• An empty friends board and an empty feed offer "Find people". <br>• No clubs says what a club is. <br>• Joining shows the same words in three short blocks, with the consent line and Join Community pinned under the list. The words are unchanged. |
| D7 | **App-wide (A1, A3).** <br>• A chosen chip is in the accent on every screen (`chipTheme`, Barlow). Pine keeps its meaning: done, progress, records. <br>• `FitActionRow`: a card's first actions on one line, the rest in a ⋯ menu. <br>• Home's "Training volume" is the last line of the This week card. <br>• Home's next-move card keeps its outline: the test renders could not judge its colours, so it waits for the S24 pass. |
| D8 | **Progress and Recovery on Home (H1).** This supersedes ADR-058 T2 and T3. <br>• The Home tab is Today · Progress · Recovery on Training's switch, opening on Today (Home as it was). <br>• Nutrition is Food alone, with no switch. <br>• Home's sleep and readiness tiles and the check-in reminder open Home › Recovery; the weigh-in and the weekly recap open Home › Progress. <br>• The Progress and Recovery parts themselves are unchanged. |

## Consequences

- **Privacy:** what is shared, and with whom, is unchanged, so the privacy policy is untouched.
- **Server:** only `now` on the clubs list (contracts and OpenAPI).
- **Icons:** new icons (`today_outlined`, `sports_score`, `leaderboard_outlined`, `people_outline`, `person_add_alt`, `local_fire_department`) need the full APK. 6.7 ships with 6.5 and 6.6 in one APK, so the Shorebird icon-font limit does not apply.
