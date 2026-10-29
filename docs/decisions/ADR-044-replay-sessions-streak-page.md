# ADR-044 — Beta 4.4: route replay, pace colours, runs in the reminders, your own sessions synced, plans of 1–2 runs a week, Streak & rewards

**Status:** PROPOSED. The owner set the scope, answered the plan's questions and said "go" on 2026-10-29 (`docs/phase-plans/beta-4.4-plan.md`). Built on `phase-19`. Becomes ACCEPTED with the owner's acceptance of beta 4.4.
**Date:** 2026-10-29
**Phase:** 19 (beta 4.4)
**Affects:**
- ADR-038/039 (runs, plans, own sessions);
- ADR-021 (reminder copy);
- the beta 3.3 streak;
- ADR-043 D5 (the Rewards page).

---

## Decisions

| # | Decision |
|---|---|
| D1 | **Route replay** (`run_replay_screen.dart`, domain `replay.dart`). A run's page offers Replay when it has a route. |
| | • The route draws itself with a moving dot in 20 s whatever the run's length, on moving time (a pause takes no replay time). |
| | • Play/pause, a scrubber, ½× and 2×; at each moment the time, distance and pace (over the last 200 m). |
| | • The camera frames the whole route, with the road ahead faint. The map is redrawn about ten times a second. |
| | • On the phone only, from the run's own track. |
| D2 | **Pace colours.** The route on a run's page and in the replay is coloured by pace against that run's own average. It is cut into stretches of about 50 m (never across a pause), each smoothed with its neighbours, with ±15 % as the full scale: green faster, yellow the average, red slower. These are fixed map colours with a legend. The live map and the share picture keep one colour. The tile map gives each line its own colour (data-driven `line-color`); FITOS's drawn map paints the same stretches. |
| D3 | **Runs in the reminders (E27).** On a plan run's day, the workout reminder and the next morning's missed-session message use run words: 8 workout reminders and 5 missed-session messages, in both tones, under the same no-body-talk rules (`BANNED`, tested). `withRunning` reports the run weekdays and the planner's `runWeekdays` picks the run words for them; gym days keep the gym words. |
| D4 | **Your own sessions synced (E28).** The phone keeps its copy with an id per session, and a change is sent at once (`PUT`/`DELETE /running/my-workouts/{id}`, idempotent). What could not be sent waits in a small queue, sent before the next read; after that the account's list is the list, plus whatever is still waiting. Sessions from before 4.4 get an id and go up once. **Migration `0038`:** `running_workouts`, keyed by user and phone id, at most 50 a user (409 past that), gone with the account and in Download my data through the foreign key. |
| D5 | **Plans of 1 to 5 runs a week, for every distance** (owner, over the by-distance option). |
| | • **One run:** for a 5K or 10K it alternates a longer easy run and a faster session; for a half or a marathon it is the long run, building. |
| | • **Two runs:** the long run and a faster session (intervals and tempo in turn). |
| | • The beginner run/walk takes 1–3 days, and its week-8 time trial is always the week's last run. |
| | • A half or a marathon on 1–2 runs shows a warning, but the plan is still made. |
| | • `running_plans_days` is 1–5 (`0038`); its down migration removes plans of 1 or 2. |
| D6 | **One Streak & rewards page.** The Home streak card opens it (the ring still opens the plan), and so does Profile. At the top: the streak and the best, this week, and the last 4 weeks as a Monday-first grid of logged, rest, skipped, missed and today. Core's `streakDays`, by the streak's own rules, is sent as `GET /progress/streak` `days` (28). Below: every reward and when it unlocks (ADR-043 D5). |

## Consequences

- **4.4 is build 22, an APK through Update now,** signed with the release key. The API deploys first (`0038`); 4.3 phones ignore the new fields.
- **Field check on the S24:**
  - replay a run;
  - pace colours on a known run;
  - a built session survives a reinstall;
  - a run-day reminder;
  - the streak card opens the page;
  - a 1–2-run plan.
