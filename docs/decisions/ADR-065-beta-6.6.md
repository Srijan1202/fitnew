# ADR-065 — Beta 6.6: Leagues and co-owners

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

## Context

On 2026-11-24 the owner chose "Leagues + co-owners" for 6.6, and on 2026-11-25 they took every recommendation in the plan (`docs/phase-plans/beta-6.6-plan.md` §6):

| # | Answer |
|---|---|
| Q1 | League matches count active days per member. |
| Q2 | Clubs of 3 members or more can enter. |
| Q3 | Seasons are 4 weeks. |
| Q4 | One push at season end with the club's place, besides each match's result. |
| Q5 | Up to 2 co-owners, who can also remove members. |
| Q6 | One table; no divisions yet. |
| Q7 | Leagues and co-owners are folded into the unreleased 2026-11-20 policy. |
| Q8 | M1, M2 and M3; M4 only if small. |

## Decisions

| # | Decision |
|---|---|
| D1 | **The league (L1).** <br>• The owner or a co-owner enters a club of 3 or more (`league_clubs`). Leaving takes effect after the week. <br>• Seasons are 4 weeks, Monday to Sunday (`league_seasons`). Each Saturday (UTC) the round opens the season if needed and pairs every entered club without a match that week, once a week (`paired_week`). <br>• Pairing (core `community/league`) is like with like, by active days per member over the last 4 weeks. It avoids a rematch within the season, never pairs across a block between the owners, and gives a bye for an odd number or a club left without a partner. <br>• A league match is an ordinary 6.5 match, already accepted, that can't be called off (`club_matches.league_season_id`). <br>• A win is 3 points, a draw 1 and a bye 1 (`league_entries`). The table goes by points, then the average per match, then fewer matches, then the name; clubs level on all three share a place. <br>• Two days after the season's last Sunday, the places are kept and each member who allows Community notifications gets one push with the club's place (Q4). Seasons are kept a year. <br>• The table shows club names and results, never members. The last season's winner gets a mark by its name. |
| D2 | **Co-owners (L2).** <br>• The owner names up to 2 co-owners (`club_members.role`), and each is told. <br>• A co-owner renames the club, makes a new code, removes and lets back plain members, sets the challenge, plays matches, and enters or leaves the league. A co-owner can't name co-owners, pass the club, or remove the owner or another co-owner. <br>• When the owner leaves, the longest-standing co-owner takes over before the longest member. <br>• A block between a co-owner and another club's owner also stops a match. |
| D3 | **More (M1–M3).** <br>• **M1:** clock-safe tests. The workout screens pin the app's today to the device's date. The API volume test and the community run helper stay within today in Kolkata, so the suites pass at any hour. <br>• **M2:** a finished match, or the club's place in the league, is shared as a picture made on the phone through the share sheet, with club names and averages only. <br>• **M3:** `GET /community/clubs/:id/numbers` gives the club's month in totals (sessions, run km, active days) and its best week, shown at the top of the board. |
| D4 | **Admin.** Admin › Social shows the co-owners, whether each club is in the league, "Take out" (audited), and a League tab with the table. |
| D5 | **Privacy.** The 2026-11-20 policy, still unreleased, now names the league (club name, results and average seen by every league club) and co-owners (Q7), so everyone accepts once. `club_match_members` stays out of every download (`OTHER_PEOPLES`). |

## Consequences

- **Migration 0059** holds the role, the league tables and the season on a match. `paired_week` was added in place because 0059 was never released.
- **Release:** 6.6 needs the 2026-11-20 policy, which ships with 6.5, so the two release together:
  1. The API with migrations 0056–0059.
  2. The full APK, which carries 6.5's native package updates.
  3. The website with the policy and both posts.

  The plan's patch route (a Shorebird patch on 6.5) applies only if 6.5 ships first.
- **M4** (small upkeep) waits for the package dates in `docs/phase-plans/upkeep-2026-12-plan.md`.
