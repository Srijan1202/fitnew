# ADR-062 — Beta 6.3: Community that talks

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

## Context

On 2026-11-12 the owner chose the final audit's "Community that talks" ideas (`docs/audits/2026-11-11-final-audit.md` §7: C1, C2, C3, C13, C16). They answered the plan's questions (`docs/phase-plans/beta-6.3-plan.md`):
- **Feed:** friends only, off until chosen.
- **Kudos:** one evening summary.
- **Suggestions:** a count only, opt-out.
- **Boards:** Week, Month and All time on every board, all time from joining.

## Decisions

| # | Decision |
|---|---|
| D1 | **The feed is stored posts (`community_posts`), one per event.** <br>• A post is a counted session (the day's name), a counted run (its metres), a lift record (the lift's name, plus how many more lifts had one), a run record (the longest distance it was a best for) or a streak milestone. <br>• A unique `(user, kind, ref)` makes posting repeatable. `ref` is the session or run id, or the milestone with the streak's first day. <br>• Posts are written by the 6.2 recount after a sync and by the hourly round. They are never written from what the phone sends. |
| D2 | **Nothing is shared until chosen (owner Q1).** <br>• `community_profiles.feed` lists the kinds shared: `session`, `run`, `record`, `streak`. `feed_since` keeps when each was switched on. <br>• Only events after that moment are posted, at most 2 days back for a late sync. A run counts from when it ended. <br>• Switching a kind off deletes its posts. <br>• A post goes with its session or run, and after 30 days. <br>• The feed shows 14 days, 20 posts a page, for accepted friends who are not hidden or blocked. |
| D3 | **Kudos (owner Q2).** <br>• One per person per post, on friends' posts only. <br>• Your own posts show who cheered (at most 10 names). <br>• Every 15 minutes the server looks for kudos not yet told. Between 19:00 and 23:00 local time, once a day, it sends "@asha and 2 others cheered you." and marks them told. <br>• With notifications off, they are marked told and nothing is sent. |
| D4 | **Nudges.** <br>• You can nudge a friend only when they have counted nothing for 3 local days (today included), and only once a week per friend. `community_nudges` keeps the last time per pair. <br>• The message is fixed, so nothing needs moderating. <br>• A person gets at most one nudge notification a day; later nudges show only at the top of the Feed for 3 days. <br>• The profile says `can`, `active` or `sent`. |
| D5 | **Month and all time (owner Q4).** <br>• `community_period_stats` keeps each member's `week`, `month` (from the 1st) and `all` (from the day they joined Community) counts, written with the week's counts. Every board reads it, so each period is one indexed read. <br>• The streak is the current one in every period. Last week's podium is for the week only. <br>• Leaving and rejoining starts all time again. |
| D6 | **Suggestions (owner Q3).** <br>• Friends of friends and club-mates, ordered by friends in common, then a shared club. <br>• Never someone already a friend or asked either way, declined either way, blocked either way, hidden, dismissed, or who switched "Suggest me" off. <br>• A suggestion shows a count or the shared club's name, never which friends. <br>• A dismissal is "other people's" in the data download (`OTHER_PEOPLES`). |
| D7 | **Settings and limits.** <br>• `suggest` and `notify` start on. `notify` covers kudos and nudges only; friend requests push as before. <br>• Limits: 500 cheers a day and 30 nudges a day. |
| D8 | **The app.** <br>• Community has four parts: Friends \| Feed \| Clubs \| World. Friends still opens first. With four parts the switch drops its icons and uses smaller labels. <br>• Kudos and nudge notifications open the Feed. <br>• Week, Month and All time chips sit above the metric chips on every board. <br>• "People you may know" shows in Friends, five at a time. <br>• A friend's profile has Nudge. |
| D9 | **Privacy policy 2026-11-12.** The Community section names the feed, cheers, nudges, suggestions and the month and all-time counts. Everyone agrees again once. |

## Consequences

- Migration 0055 copies this week's counts into the period table, so boards are not empty after the release. Month and all time fill on the first round.
- The minimum build stays at 37. The 6.2 app ignores the new fields, and a board without `period` is the week.
- The API is released first. The app can be a Shorebird patch on 6.2, since there is no manifest or dependency change.
