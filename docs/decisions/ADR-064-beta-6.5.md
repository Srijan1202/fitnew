# ADR-064 — Beta 6.5: Clubs together

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

## Context

On 2026-11-20 the owner chose "Clubs together" for 6.5 and answered the plan's questions (`docs/phase-plans/beta-6.5-plan.md`). On 2026-11-22 they changed the feed to on by default.

| # | Question | Answer |
|---|---|---|
| Q1 | How does a club's feed get its posts? | It follows friend sharing: there is no separate club switch. |
| Q2 | How long does a challenge run? | A calendar month, each member's own month in their own time zone. |
| Q3 | Club vs club? | In 6.5. |
| Q4 | Which pushes? | One when a challenge is reached, and one with a match's result. Nothing else. |
| Q5 | The feed on by default: for members who joined earlier too? | Yes, every one of them, once, from agreeing to the 2026-11-20 policy, even those who had turned kinds off. |

## Decisions

| # | Decision |
|---|---|
| D1 | **The club feed (K1).** <br>• A club's members see what each member shares in the feed, with the same kinds as friends see (Q1). <br>• Safeguard: a post reaches a club only if it was made after the person joined that club and after they agreed to the 2026-11-20 policy (`CLUB_FEED_FROM_POLICY`). <br>• Club-mates can cheer. Leaving a club takes your posts out of it at once. <br>• `GET /community/clubs/:id/feed`. The club opens on **Board \| Feed**. |
| D2 | **The feed on by default (K0, owner 2026-11-22).** <br>• This replaces ADR-062 D2. Joining shares every kind (session, run, record, streak) from that moment. <br>• A member who joined earlier has every kind switched on once, in the round, from first agreeing to the 2026-11-20 policy. This includes kinds they had turned off (Q5). `community_profiles.feed_defaulted` (migration 0057) marks it done, so a later choice stays. <br>• The join screen says so before **Join**, and so do Community settings ("Shared with your friends and your clubs") and the policy. The "Share your activity" card shows only to someone who turned every kind off. |
| D3 | **The club challenge (K2).** <br>• Only the owner sets it: sessions, run km or active days, with a target of 10 to 100,000. It is for their month or the next. <br>• There is no free text: the title is made from the numbers ("200 sessions together in December"). <br>• There is one open challenge per club (`club_challenges`, migration 0056). Each member's part is counted in `refreshOne` over the month in their own time zone (`club_challenge_parts`). The club's total is the parts of its current members, so someone who leaves takes their part with them. <br>• The round marks it reached and sends the one push (Q4) to members who allow Community notifications. It closes the challenge two days after the month ends (when the month is over in every time zone). Finished challenges are kept a year, and the club shows its last three. <br>• The owner can change the target until it is reached, or end it early. The owner is suggested a target from the club's last 4 weeks plus 10%. |
| D4 | **Club vs club (K3).** <br>• An owner challenges another club, by its code, to next week (Monday to Sunday). The other owner accepts before the week starts, or declines; an unanswered challenge lapses. <br>• A club has one match a week. A block between the owners refuses it. <br>• The members are fixed when the week starts (`club_match_members`, migration 0058). <br>• The score is the average per member, from each member's own week, so size does not decide it. The other club shows only its name and its average, never who: `club_match_members` is in the download's `OTHER_PEOPLES` and is deleted when the match ends. <br>• Two days after the Sunday, the result is kept and each member gets the one push (Q4) from their club's side. The result stays a week. |
| D5 | **Admin.** Admin › Social › Clubs shows each club's open challenge and its latest match, in words. |
| D6 | **Upkeep.** <br>• drift 2.35.4, drift_dev 2.35.3 and sqlite3 3.9.1 (from 22 November), and go_router 18.1.4 and synchronized 3.6.1+1 (from 23 November). <br>• A unique violation is found under drizzle's wrapper (`uniqueViolationOf`) everywhere in Community, so a race on a handle or a club code is a 409, not a 500. |

## Consequences

- **Release:** the API comes first, with migrations 0056, 0057 and 0058 through `deploy.ps1`. Then the full APK 1.0.0-beta.6.5 (40), which carries sqlite3's native build and the package updates due by then, then the website with `-Apk`. The minimum build stays 37.
- **Older apps:** they keep working. A member on an older app sees no club feed, challenge or match, but still counts towards them.
- **Policy 2026-11-20:** everyone agrees to it once. Until they do, a person's posts stay out of clubs and their sharing is not switched on.
- **Q5 against the recommendation:** I recommended switching on only members who had never touched the switches. The owner chose everyone. The policy says it plainly, and anyone can turn any kind off again.
