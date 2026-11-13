# Beta 6.3 plan — Community that talks

**Asked by the owner (2026-11-12):** the "Community that talks" ideas from the final audit (`docs/audits/2026-11-11-final-audit.md` §7):
- an opt-in activity feed;
- one-tap kudos, with at most one push a day;
- a fixed "nudge a friend" message;
- monthly and all-time boards;
- friends-of-friends suggestions.

## Owner's decisions (2026-11-12)

| # | Question | Answer |
|---|---|---|
| Q1 | Who sees the feed, and is sharing on until switched off? | **Friends only, and off until chosen.** Sessions, runs, records and streak milestones each have their own switch in Community settings. |
| Q2 | How is kudos' one push a day sent? | **One evening summary,** around 19:00 in the person's time zone ("3 friends cheered you today"). Kudos show in the app at once. |
| Q3 | What do suggestions show, and can people stay out of them? | **A count only, never names:** "2 friends in common", or the club you share. "Suggest me to others" is on, and anyone can switch it off. |
| Q4 | Where do the monthly and all-time boards appear, and where does all time start? | **Week, Month and All time on the friends, club and world boards.** All time counts from the day someone joined Community. |

## What 6.3 builds

| # | Item | Server | App |
|---|---|---|---|
| C1 | **Activity feed** | <ul><li>`community_posts` holds one row per event: a counted session ("finished Push"), a counted run ("ran 5.2 km"), a record (a lift's name, or a run distance such as 5K), and a streak milestone (7, 14, 30, 50, 100 days and so on).</li><li>Posts are written after a session or run syncs (the 6.2 `onResponse` hook), and again in the hourly round.</li><li>Only kinds the person shares are written, and only events after the kind was switched on.</li><li>Switching a kind off deletes its posts.</li><li>A deleted session or run takes its post with it.</li><li>Posts are kept 30 days.</li><li>`GET /community/feed` returns friends' posts and your own, newest first, 20 a page, from the last 14 days.</li><li>Posts never show weights, sets, routes, times of day or food.</li></ul> | <ul><li>A **Feed** half, first in Community.</li><li>A card offers sharing while it is off.</li><li>Posts can be cheered.</li><li>Nudges received show at the top.</li></ul> |
| C2 | **Kudos** | <ul><li>`POST` and `DELETE /community/feed/:postId/kudos`: friends' posts only, one per person per post.</li><li>Your own post lists who cheered.</li><li>Every 15 minutes, a person with uncounted kudos who has not had a kudos push today gets one summary push between 19:00 and 23:00 local time.</li><li>It is skipped when they switched Community notifications off.</li></ul> | <ul><li>A cheer button with a count.</li><li>"Cheered by @asha and 2 others" on your own posts.</li></ul> |
| C3 | **Nudge a friend** | <ul><li>`POST /community/friends/:userId/nudge`: friends only.</li><li>Only when the friend has had no counted session or run for 3 days.</li><li>Once a week per friend.</li><li>A fixed message: "@asha nudged you: time to move. A short session counts."</li><li>At most one nudge push a day per person. Later nudges show in the app only.</li><li>The person profile says whether a nudge can be sent.</li></ul> | <ul><li>A **Nudge** button on a friend's profile.</li><li>"Nudged by @asha" at the top of the Feed for 3 days.</li></ul> |
| C13 | **Month and All time** | <ul><li>Each board takes `period=week\|month\|all`.</li><li>`community_period_stats` keeps each member's week, calendar month and since-joining counts, written with the week's counts.</li><li>The streak is the current streak in every period.</li><li>Last week's podium shows on Week only.</li></ul> | Week, Month and All time chips beside the metric chips. |
| C16 | **Suggestions** | <ul><li>`GET /community/suggestions` returns friends of friends and club-mates: not already friends, not asked either way, not blocked or hidden, and only people who allow suggestions.</li><li>Ordered by friends in common, then clubs shared.</li><li>Each suggestion shows a count, or the shared club's name, never which friends.</li><li>`DELETE /community/suggestions/:userId` hides one for good.</li></ul> | "People you may know" in Friends, with Add and ✕. |

### Settings (on the Community profile)
- `feed` lists the kinds shared. It starts empty.
- `suggest` starts on.
- `notify` starts on. It covers the kudos summary and nudges; friend-request pushes stay as they are.

### Data and privacy
- **Migration 0055:**
  - New tables: `community_posts`, `community_kudos`, `community_nudges`, `community_suggestion_dismissals` and `community_period_stats`.
  - New profile columns: `feed`, `feed_since`, `suggest`, `notify` and `kudos_pushed_on`.
  - The migration fills the week's period rows from `community_week_stats`.
- **Data download:**
  - Everything belongs to its person (CASCADE). Kudos on your posts are in your download, since the app shows you who cheered.
  - A dismissed suggestion is "other people's" (`OTHER_PEOPLES`): the dismissed person never learns about it.
- **Privacy policy 2026-11-12:**
  - The feed: what is shared, with friends only, each kind off until chosen, kept 30 days.
  - Kudos: who cheered, and the evening summary.
  - Nudges, named.
  - Suggestions: counts only, opt-out.
  - Month and all-time counts since joining.
  - Everyone accepts the new version once.
- **Leaving Community** deletes posts, kudos given, nudges, dismissals and period counts.

### Release
- The API comes first.
- 6.3 can be a Shorebird patch on 6.2 (no manifest or dependency change), unless the build needs otherwise.
- The minimum build stays at 37. 6.2 apps keep working: the new board fields are additions, and `period` defaults to week.

## Not in 6.3
- Comments on posts. Free text needs moderation, so the fixed cheer is the only reply.
- Club feeds, club challenges and club vs club (C6, C7).
- Leagues (C14).
