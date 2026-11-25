# Beta 6.6 plan — Leagues and co-owners

**Status:** GO (2026-11-25). The owner took every recommendation in §6:

| # | Answer |
|---|---|
| Q1 | League matches count **active days per member**. |
| Q2 | Clubs of **3 members or more** can enter. |
| Q3 | **4-week** seasons. |
| Q4 | **One push at season end** with the club's place, besides each match's result. |
| Q5 | **Up to 2 co-owners**, who can also remove members. |
| Q6 | **One table**, no divisions yet. |
| Q7 | Leagues and co-owners are **folded into the unreleased 2026-11-20 policy**, while 6.5 is unreleased. |
| Q8 | **M1, M2 and M3**; M4 only if small. |

**Asked by the owner (2026-11-24):** "6.6 Leagues + co-owners". These build on 6.5's club vs club and on the 6.5 plan's "Not in 6.5" list (leagues, C14; club roles beyond the owner).

6.6 comes after 6.5 is released (`docs/phase-plans/beta-6.5-plan.md` §8). It needs no new Flutter package and no native change, so it can ship as a **Shorebird patch** on 1.0.0-beta.6.5 (40). That holds only if it uses icons already in 6.5's font (`patch-icon-font`); otherwise it ships as a full APK.

## 1. What clubs have after 6.5

- **Clubs:** one owner each; members join with the code. The owner renames the club, makes a new code, passes it on, and removes or lets back members.
- **Club feed:** what members share, from after they joined.
- **Club challenge:** one a month, set by the owner. The title is made from the numbers.
- **Club vs club:** an owner challenges another club **by its code** to a week. The score is the average per member, and the other club sees only the name and the average.

**Two gaps 6.6 closes:**
- **Finding a rival:** you need another club's code, so most clubs never play a match.
- **One person runs everything:** if the owner is away, the club can't set a challenge, accept a match or remove someone.

## 2. What 6.6 builds

| # | Item | Server | App |
|---|---|---|---|
| L1 | **Leagues** | <ul><li>**Entering.** A club's owner (or a co-owner) enters it in the league. It must have at least 3 members (Q2). Leaving the league takes effect after the current week.</li><li>**Seasons.** 4 weeks, Monday to Sunday, back to back (Q3). `league_seasons` holds the season's dates.</li><li>**Pairing.** Each Saturday (UTC), every entered club without a match that week is paired for the coming week. The round pairs clubs with similar averages per member over the last 4 weeks, so a strong club meets a strong club. It avoids a rematch within the season, and never pairs clubs whose owners have blocked each other. With an odd number of clubs, one gets a bye: the club with the fewest byes, scored as a draw.</li><li>**Matches.** A league match is an ordinary 6.5 match (`club_matches`, with `league_season_id`), already accepted. Its metric is fixed for the league (Q1). A club that set up its own match that week sits the league week out, with no points.</li><li>**Points.** Win 3, draw 1, loss 0. The table orders clubs by points, then the average per member over the season, then the fewest matches.</li><li>**The table.** Every entered club sees it: each club's place, name, played, won, drawn, lost and points. Never members.</li><li>**One table** for now (Q6). Divisions come later, once enough clubs play.</li><li>**Season end.** The table is kept, and the winner is marked on its club for the next season. Each member of an entered club gets one push with the club's place (Q4).</li></ul> | <ul><li>A **League** card in the club: your place, points, this week's opponent (the 6.5 match card), and the top 5 plus your club. "See the table" opens the full one.</li><li>The owner or a co-owner gets "Enter the league" or "Leave the league", which says what entering shares.</li><li>A small "Season winner" mark beside the club's name for one season.</li></ul> |
| L2 | **Co-owners** | <ul><li>The owner names up to **2 co-owners** among the members (Q5). `club_members.role` is `member` or `co-owner`.</li><li>**A co-owner can** set, change and end the challenge, challenge clubs, accept or decline matches, enter or leave the league, rename the club, make a new code, and remove or let back members. They cannot remove the owner or another co-owner.</li><li>**Only the owner** names or drops co-owners and passes the club on.</li><li>**When the owner leaves,** the club passes to the co-owner who has been in it longest, then to the longest member, as now.</li><li>Every change is told to the person named. Removing a member stays as it is.</li></ul> | <ul><li>Club settings gets **Co-owners**: the owner picks up to 2 members, or drops one.</li><li>Members see "Owner" and "Co-owner" by those names on the board.</li><li>Co-owners get the owner's buttons on the challenge, match and league cards and in club settings, except co-owners and passing the club on.</li></ul> |

## 3. Data and privacy

- **Migration 0059:**
  - `club_members.role` (`member` or `co-owner`; at most 2 co-owners per club);
  - `league_seasons` (dates);
  - `league_entries` (season, club, played, won, drawn, lost, points, byes, the season's final place);
  - `club_matches.league_season_id` (null for a match set up by hand).
- **Ownership:**
  - League entries and league matches belong to their club and go with it.
  - The data download walks a club's owner and co-owners' clubs, as for 6.5.
  - The other clubs in a match are seen by name only, as in 6.5. `club_match_members` stays in `OTHER_PEOPLES`.
- **Privacy policy** (Q7): what entering the league shares, which is the club's name, results and average per member, seen by every club in the league; and that co-owners can remove members and see the removed list.
- **Admin:**
  - Admin › Clubs shows the co-owners and whether the club is in the league.
  - The admin can take a club out of the league (audited).
  - Admin › Social gets a League view: the season, the table, and this week's pairs.

## 4. Release

1. **The API first:** migration 0059, deployed with `deploy.ps1`. The pairing round runs with the hourly community round, and acts only on Saturdays (UTC).
2. **The app:** a Shorebird patch on 6.5 (40) if the icon check passes, otherwise the full APK 1.0.0-beta.6.6 (41).
3. **The website post**, with `-Apk` only when it's a full APK.
- **Older apps:** the minimum build stays 37. A 6.5 app without the patch shows league matches as ordinary matches, and its owner can't enter the league.
- **The first season** starts on the first Monday after release.

## 5. Order of work (one commit each, pushed)

| # | Step |
|---|---|
| 1 | Core `community/league`: seasons, pairing by nearest average with no rematch and no block, byes, points and the table order. 100% branch coverage. |
| 2 | Migration 0059, its down file and the migration test. |
| 3 | L2 server: roles, the co-owner checks in every owner action, handing over on leaving, the tell, tests. |
| 4 | L1 server: enter and leave, the Saturday pairing in the round, league matches, points after each result, season end with its push, `GET /community/league`, tests, OpenAPI. |
| 5 | App L2: co-owners in club settings, the labels, the buttons. |
| 6 | App L1: the League card, the table, enter and leave, the winner mark. |
| 7 | Admin: co-owners and league in Clubs, the League view, taking a club out. |
| 8 | The privacy policy (Q7), ADR-065, the website post. |
| 9 | Checks: the API suite, the whole app, a debug APK, the icon check for a patch. |
| 10 | Release, on the owner's go. |

## 6. Questions for the owner

| # | Question | Recommended |
|---|---|---|
| Q1 | **What a league match counts:** one fixed metric, or the owner of the challenging club picks? | **Active days per member.** It is fair to gym-goers and runners alike, and the same in every week of the table. |
| Q2 | **Who can enter:** any club, or a minimum size? | **3 members or more**, so a club of one can't farm points. |
| Q3 | **A season:** 4 weeks, or a calendar month? | **4 weeks.** Matches are Monday to Sunday, so a season of whole weeks has no half-weeks. |
| Q4 | **Pushes:** besides each match's result (as in 6.5)? | **One at season end** with the club's place. Nothing for pairing or the table. |
| Q5 | **Co-owners:** how many, and can they remove members? | **Up to 2, and yes,** so a club is looked after when its owner is away. Only the owner names co-owners and passes the club on. |
| Q6 | **Divisions** (promotion and relegation)? | **Not yet.** One table, with pairing by similar averages. Divisions once about 30 clubs play. |
| Q7 | **The privacy policy:** 6.5's version (2026-11-20) is not released yet. Fold leagues and co-owners into it now, or make a new version for 6.6? | **Fold them in, if 6.5 is still unreleased when 6.6's server is ready**, so people accept once, not twice in a month. Otherwise a new version for 6.6. |
| Q8 | **More for 6.6 (§8):** which of M2–M4 come along? M1 needs no answer and is done first. | **M1, M2 and M3.** M4 only if it stays small. |

## 8. More for 6.6 (owner 2026-11-24: "plan and more")

| # | Item | What | Size |
|---|---|---|---|
| M1 | **Clock-safe tests** (no question) | Four tests fail between 00:00 and 05:30 IST, when it is Monday locally and still Sunday in UTC. Three are in `workout_screens_test.dart` (done today, and the two skip-today tests). One is in the API's `progression.integration.test.ts` ("volume equals a hand calculation", whose `daysAgo(0, 8)` falls into the week before). Each test gets one clock and one time zone, so it passes at any hour. The app's own behaviour does not change. | S |
| M2 | **Share a result** | After a match, or at season end, "Share" makes an image on the phone: the two clubs' names, the averages and the result, or the club's place in the table. It goes out through the share sheet, as the run card does. It carries no member names and no handles. Nothing is uploaded. | S |
| M3 | **The club in numbers** | A "This month" strip on the club's board: the club's counted sessions, run km and active days this month, and its best week so far. These are the same counts the boards use, as totals, never who. | S |
| M4 | **Small upkeep** | <ul><li>`tsx` upgraded past its deprecation warning (E16).</li><li>Any of the 5 moderate advisories (A4) with a fixed release at least two weeks old.</li><li>The Flutter packages that turn two weeks old by then.</li></ul> | S |

They come in this order: M1 first (in 6.5's checks too), then L2, L1, M3, M2 and M4.

## 7. Not in 6.6

- Divisions, promotion and relegation (Q6).
- Leagues by country or city.
- Comments and free-text titles, which still need moderation.
- Club roles beyond owner and co-owner.
