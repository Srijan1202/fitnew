# Beta 4.4 — plan: route replay, running loose ends, plans with 1–2 runs a week, one Streak & rewards page

**Date** 2026-10-29 · **Branch** `phase-19` · **Status:** the owner picked the scope (and added R5, 1–2 runs a week) and answered the questions on 2026-10-29 (the table below). Waiting for the go; no code before it.

## The owner's answers (2026-10-29)

| Question | Answer |
|---|---|
| Scope | **Route replay; running loose ends (E27, E28); the streak and the rewards on one page** |
| Streak + rewards | **One "Streak & rewards" page**, opened from the Home streak card and from Profile |
| Replay length | **About 20 s for any run**, with play/pause, a scrubber, ½× and 2× |
| Pace colours | **Yes**, on the run's map and in the replay; the share picture keeps one colour |
| Runs a week | **1 to 5 for every plan** (today 3 to 5); a clear warning for a half or a marathon on 1 or 2 |

Not in 4.4: the Galaxy Watch, more badges, Google Play (the owner's account first).

---

## R1 — Route replay

- **Where:** "Replay" on a run's page (outdoor runs with a route).
- **What it shows:**
  - the run draws itself on the map with a moving dot, in about 20 seconds whatever its length;
  - play/pause, a scrubber, ½× and 2×;
  - at every moment, the run's time, distance and pace there;
  - the map follows the dot, and a pause in the run shows as a short gap.
- **On the phone only:** the replay reads the run's own track (the phone already has it). Nothing new is sent or kept.
- **Offline:** FITOS's own drawn route replays the same way.

## R2 — Pace colours on the route

- **On the run's map:** the route is coloured by pace, relative to that run's own average. Faster than average is greener, slower is warmer (amber, then oxide), with a small legend ("faster · average · slower").
- **Where:** on the run's page and in the replay.
- **Not changed:** the share picture and the live map keep one colour.
- **How:** the pace of each stretch is smoothed over about 50 m, so GPS noise does not paint stripes. The rules are in the app's run maths, with tests.

## R3 — Running loose ends

- **E27, run-specific reminder lines:** on a plan run's day, the reminders talk about the run ("Easy 6 km today. Shoes on?") instead of reusing the gym lines. These are new run variants in core's `notify/copy.ts`, in the same Cheeky tone, with tests.
- **E28, your own sessions synced:**
  - the sessions you build go to your account, so a new phone (or a reinstall) keeps them;
  - **migration `0038`:** `running_workouts` (user, the phone's id, name, steps), at most 50 a user, gone with the account and in Download my data;
  - `GET /running/my-workouts` and `PUT`/`DELETE /running/my-workouts/{id}`;
  - the phone keeps its copy for offline use and syncs it like runs;
  - the sessions already on the phone are uploaded once, and nothing is lost.

## R4 — One "Streak & rewards" page

- **Opened from:** tapping the streak card on Home, and Profile → Rewards (now "Streak & rewards").
- **At the top:**
  - the current streak and the best;
  - this week's ring (sessions done against the plan);
  - the last 4 weeks as a grid of days, showing logged, rest day and missed. A day counts when a workout or meal is logged, and rest days count, as now.
- **Below:** every reward and when it unlocks, as in 4.3 (streak, running, Premium).
- **The server:** `GET /progress/streak` gains `days`, the last 28 local days and what each was. 4.3 phones ignore it.

## R5 — Plans with 1 or 2 runs a week

- **Choosing a plan** offers 1, 2, 3, 4 or 5 runs a week for every distance. The beginner run/walk 5K offers 1, 2 or 3.
- **The week's shape** (core `running/plan.ts`):
  - **1 run:** the week's key run. Every fourth week stays easier, and the taper is as now.
    - 5K and 10K: it alternates a longer easy run and a faster session (intervals or tempo).
    - Half and marathon: it is the long run, building week by week.
  - **2 runs:** the long run and one faster session (or two run/walks for the beginner).
  - **3–5:** as now.
- **Honest about it:** a half or a marathon on 1 or 2 runs a week shows a warning when chosen: "With so few runs a week, a half marathon is much harder to finish well. 3 or more is better." The plan is still made.
- **Stored:** `running_plans.days_per_week` allows 1–5 (migration `0038`, checked); `createPlanRequest` allows 1–5.
- **Tests:** core makes every distance at 1 and 2 runs, with the taper and the easier fourth week; the API accepts 1–5; the app offers them and shows the warning.

## Release

- **4.4 is build 22, an APK through Update now,** signed with the release key (ADR-043).
- **The API deploys first** (`0038`, `days`). 4.3 phones keep working.
- **Field check on the S24:**
  - replay a run;
  - the pace colours look right on a known run;
  - a built session survives a reinstall;
  - on a plan run's day, the reminder talks about the run;
  - the streak card opens the new page.
