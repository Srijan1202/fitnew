# Beta 6.7 plan — Community revamp

**Status:** GO (2026-11-27). The owner's answers:

| # | Answer |
|---|---|
| Q1 | **Three tabs:** Feed · Boards · Clubs, with People behind an icon. |
| Q2 | **Feed** opens first. |
| Q3 | Selected chips in the accent, **app-wide**. |
| Q4 | 6.7 ships **with 6.5 + 6.6**, in one APK. |
| Q5 | Not asked separately (the form takes four). Built as recommended: the small `now` field, no migration. |

**Asked by the owner (2026-11-27):** "work on ui revamp, specially focused on the community tab, but also check and see what we can change."

**How this was checked:** every Community screen was drawn at phone width (412 px, Cobalt) with a full set of sample data: friends, requests, suggestions, a feed, two clubs, a challenge, a match, the league and the month in numbers. Home, Training and Nutrition were drawn through the whole-app test harness. That harness gets the colours wrong, so only their layout was judged.

## 1. What the Community tab is now

- **Four tabs in a switch:** Friends · Feed · Clubs · World, under a "Community" app bar. No other main tab has an app bar.
- **The Friends tab has eight things on it,** top to bottom:
  1. friend requests;
  2. period chips (Week · Month · All time);
  3. metric chips, with a green "+" squeezed beside them;
  4. last week's podium;
  5. this week's board;
  6. people you may know;
  7. waiting for an answer;
  8. invite.

  The board, the reason to come back, sits in the middle of the people admin.
- **World repeats the board** with the same two chip rows, plus Everywhere | Country. So there are two copies of the board controls, one per tab.
- **Selected chips are green:** `ChoiceChip` takes `secondary`, which is pine. So are the "+" button and the club's share button. Everything else on Cobalt is blue, so a screen mixes two accents.
- **The podium is three columns of text.** First place is only told apart by colour.
- **The feed is a single card of one-line posts.** It's fine, but:
  - each kind (session, run, record, streak) looks the same;
  - "Cheer" sits as a word beside a heart, while a post with cheers shows the heart and a number, so the column jumps.
- **The clubs list shows only the name, members and code.** It doesn't show whether anything is happening in a club.
- **The club screen is one long stack**, in this order:
  1. the code card;
  2. the month in numbers;
  3. the challenge;
  4. the match;
  5. the league, with three text links stacked: See the table, Share our place, Leave the league;
  6. the board controls;
  7. the podium;
  8. the board.

  On a phone, the first screen is mostly the invite code, which a member uses once. The board starts about two screens down.
- **The join screen** reads well and only needs tightening.

## 2. What 6.7 changes in Community

| # | Change |
|---|---|
| R1 | **Three tabs: Feed · Boards · Clubs (Q1).** <br>• **People** moves behind an icon in the header, with the request count as a badge. It holds requests, friends, suggestions, waiting and invite, so nothing is lost. <br>• **Boards** is one board with a scope switch, Friends · Country · World, then one row of controls. Country and World show only when you're on the world board; otherwise a line offers to turn it on. <br>• The tab opens where Q2 says. |
| R2 | **Board controls in one row.** <br>• The period (Week, Month, All time) becomes a small dropdown at the start of the metric row, so the controls are one line instead of two. <br>• Selected chips use the theme's accent (A1). |
| R3 | **A real podium.** First place sits in the middle, raised, with the largest avatar. Second and third sit on either side, with medal colours from the palette (amber, ink60, oxide). Your own place line stays under it. |
| R4 | **Feed posts by kind.** <br>• Each post gets a small icon for its kind: dumbbell, run, trophy for a record, flame for a streak. <br>• Posts are grouped under Today, Yesterday and the date. <br>• The cheer is always a heart with a count, highlighted once you've cheered; there's no "Cheer" word, so the column stays put. |
| R5 | **Club cards with a "now" line (Q5).** <br>• Each club in the list shows a monogram in the club's colour, its members and your role. <br>• It also shows one line of what's on: this month's challenge as a thin bar (143 of 200 sessions), or this week's match score. <br>• Make and Join stay at the top. Your clubs come first, then the rest. |
| R6 | **The club screen leads with what's happening.** <br>• **The header:** the name, the season winner's mark, the members, your role, and an **Invite** button. Invite opens the code, QR and share sheet that the code card holds now. The code card goes. <br>• **First:** this week (the match or the league match) and this month (the challenge), side by side when both are on. <br>• **Then:** the month in numbers, a compact league row (place, points, the next opponent, and "Table ›"), and the board. <br>• **The league's three links** become a share icon on the card and a "Leave the league" item in the club's ⋯ menu. |
| R7 | **Empty states that lead somewhere.** <br>• No friends: invite and the QR. <br>• No clubs: make one or join with a code. <br>• Board empty this week: "Nothing counted yet this week", with what counts. <br>• Feed empty: what friends will see here, and the sharing settings. |
| R8 | **Join screen.** The same words in three short blocks (what others see, never shared, yours to control), with the button always in view. |

Nothing in R1–R8 changes what is shared or with whom, so the privacy policy is untouched.

## 3. What else can change (A, across the app)

| # | Finding | Change |
|---|---|---|
| A1 | Selected chips are green (pine) on every Cobalt screen. There are 20 files with chips. | Selected chips use the accent everywhere, through one `chipTheme` in `FitTheme` (Q3). Pine keeps its meaning: done, progress, records. |
| A2 | Community is the only main tab with an app bar. Training and Nutrition start with their switch, and Home starts with the greeting. ADR-046 says one header. | Community starts with its switch, like Training and Nutrition. Its settings and People icons sit at the right of the switch row. |
| A3 | Home's "Training volume" is an outlined button floating between the This week card and Train with friends. The next-move card is outlined while the blocks around it are glass. | "Training volume ›" goes inside the This week card. The next-move card becomes glass with an accent edge. |
| A4 | Stacks of text links with large gaps: the league card, and the challenge card's "Change the target · End it". | One shared `FitActionRow`: up to two text buttons on one line, the rest in a ⋯ menu. |

Only Home's layout could be judged outside Community, so A2–A4 are the safe set. A screen-by-screen pass on the S24 after 6.7 will find more.

## 4. Server

- **R5 only:** `GET /community/clubs` adds `now` per club. It's null, or `{ kind: 'challenge', total, target, unit }`, or `{ kind: 'match', us, them, daysLeft }`. It's read from the existing tables, so there's no migration. Contracts and OpenAPI are updated.
- Nothing else changes on the server.

## 5. Release

6.5 and 6.6 aren't released yet, and they go out as one full APK. 6.7 can join that same release (Q4). It needs no new package and no native change.

If 6.7 comes later instead, it can be a Shorebird patch only if it uses icons already in the release font (`patch-icon-font`). The new kind icons (R4) would have to be checked against it.

## 6. Questions for the owner

| # | Question | Recommended |
|---|---|---|
| Q1 | Community tabs: **Feed · Boards · Clubs, with People behind an icon**, or keep the four tabs and only polish them? | Three tabs |
| Q2 | Which tab opens first? | **Feed**, the most alive. Boards is the alternative. |
| Q3 | Selected chips in the accent: **app-wide**, Community only, or keep green? | App-wide |
| Q4 | Release: **with 6.5 + 6.6** (one APK), or after them? | With them |
| Q5 | The clubs list's "now" line needs a small server field (no migration). Build it? | Yes |

## 7. Order of work (one commit each, pushed)

1. A1, the chip theme, and A4, `FitActionRow`, the shared pieces.
2. R1 and A2: the tab structure, the header and the People screen.
3. R2 and R3: board controls and the podium.
4. R4: the feed.
5. R5: server `now`, then the clubs list.
6. R6: the club screen.
7. R7 and R8: empty states and the join screen.
8. A3: Home.
9. Tests and screenshots of every changed screen for the owner, then analyze, the full app suite, the API suite and the APK build.

## 8. Not in 6.7

- No new Community features: no comments, no photos, no group chat.
- No theme or palette changes beyond A1.
- Training, Nutrition and AI screens aren't redesigned. They get a review after this.
