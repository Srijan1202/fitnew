# ADR-049 — Beta 4.9: race-day mode, watch cadence, watch runs in the background, more INDB dishes, the owner's three bugs

**Status:** PROPOSED. Owner, 2026-10-30: the 4.9 scope and its answers, then "go" on `docs/phase-plans/beta-4.9-plan.md`. Becomes ACCEPTED with the owner's check on the phone.
**Date:** 2026-10-30
**Phase:** 19 (beta 4.9)

---

## Bugs (the owner's, 7f83a18)

| # | Decision |
|---|---|
| A1 | **Rest is any day kept without training.** Blue is trained (a workout or a run). Green is rest: no training that day, but the streak kept (a meal logged, or a planned rest day). Grey is Skip today; an outline is missed. The legend reads "Trained · Rest · Skipped · Missed". Core `streakDayStatus`; the streak's count is unchanged. |
| A2 | **Running badges are medals with their figure** ("50 km", "5K 30′", "4 wk"…), in their group's colour: distance amber, speed blue, lifetime green, consistency violet. Dim with a lock until earned. Rewards keep their art. |
| A3 | **The weight graph is your weigh-ins.** A bold line through the actual readings with a dot on each; the trend is a thin dashed line behind it. The kg axis fits both. |

## Race-day mode

| # | Decision |
|---|---|
| R1 | **A Race goal** in the run setup: 5K, 10K, Half (21,097 m) or Marathon (42,195 m); a target time in hours, minutes and seconds (each distance has a default); Even or Negative split. The sheet shows the pace plan before the start. A plan's race run starts in race mode: its distance, at its time (or its pace range's middle), even. |
| R2 | **Negative splits** are the first half 2 % slower than the even pace and the second half 2 % faster: the same finish. Pure `RacePlan` (domain/race.dart): `paceAt`, `plannedAt`, `deltaAt`, `projectedFinish` (from 200 m), `kmSplits`, `finishFrom`. |
| R3 | **During the race** the live screen shows the pace to hold now (big), how far ahead (green) or behind (red) the plan, and the finish the pace so far gives. The voice adds "N seconds behind plan." / "ahead of plan." / "On plan." (within 2 s) to each km. The coach's target pace is the plan's ±5 s. |
| R4 | **After the race** the run's page has a result block: the time when the runner crossed the distance (inside the split that crosses it; "Not finished" more than 20 m short), the verdict ("32 s under target"), and each km against its plan. The share picture carries "5K · 32 s under target". |
| R5 | **Server:** `run_goal_kind` gains `race`; `runs.goal_target_seconds` (120–86,400) and `runs.goal_split` (`even`/`negative`), both present only on a race (`runs_race`). The contract's goal gains `targetSeconds` and `split`, required for a race. Migration 0041; its down deletes race runs and rebuilds the enum. The phone's database goes to schema 6 (two columns; an upgrade only adds). |

## Cadence

| # | Decision |
|---|---|
| C1 | **A watch run's average and max cadence** (steps a minute): from the watch's cadence records in the session, else its steps in the session over the moving minutes (no max then). Read only with Health Connect's steps permission (asked with the others when the switch goes on); a failed read leaves the cadence out, never the run. |
| C2 | Sent 60–250; a max under the average is the watch's error and left out. **Server:** `runs.cadence_avg`, `runs.cadence_max` (60–250, `runs_cadence`), only from the watch (a phone run with cadence is refused). Shown on the run's page under heart rate; in the export. |

## Watch runs in the background

| # | Decision |
|---|---|
| B1 | **Every 6 hours** (WorkManager: any network, battery not low) while the Running switch is on **and** Health Connect grants `READ_HEALTH_DATA_IN_BACKGROUND`. Running opening schedules or cancels it from those two. |
| B2 | **The same importer, without a screen.** `WatchImportWorker` starts the app's Dart at `watchImportMain` in a headless engine, with the Health Connect channel bound to the app (not an activity), and waits for "done" (at most 4 minutes). |
| B3 | **As whom:** Running remembers the FITOS user and the Firebase uid each time it imports; the background import runs only when the same Firebase user is still signed in, and the switch is still on. |
| B4 | **No database is opened in the background** (the app may hold it). The runs to leave out are the server's latest page; offline, nothing is sent. The one gap, a phone run not yet uploaded, is closed by Running opening as before. |
| B5 | **At most one notification a day,** low priority, on the Reminders channel: "Watch run added: 5.20 km · 26:10", or "N watch runs added". |
| B6 | **Settings say which applies:** "New watch runs come in every few hours, even with FITOS closed", or how to allow it. |
| B7 | **Privacy policy 2026-10-30.2** names the cadence and the background check ("it reads only runs"); everyone accepts once. The app, the doc, the website and the contract carry the same text and version. |

## More food

| # | Decision |
|---|---|
| F1 | Of INDB's 384 skipped dishes: 147 FITOS already has, 89 have no per-serving values, 65 are deep-fried of a kind CoFID cannot check, 32 disagree with their macros by more than 25 %, 15 have an implausible portion. None of those rules change. |
| F2 | **Whole dishes become a portion:** a cake of 600 kcal or more is served as a 1/8 slice, a pie 1/6, a dish or souffle dish 1/4. A smaller whole is one person's (a single fish pie, a souffle made four at a time) and is served whole. A jar, box, tin or bottle (pickles, chutneys) stays out. The portion passes the same energy and plausibility checks. |
| F3 | **25 dishes added:** lasagnes, savoury and sweet pies, souffles, mousse, handvo, tutti frutti cake and others. 1,839 → **1,864 foods** (655 INDB, 359 skipped). The search checks (p95 under 200 ms, the "paneer" order) stay green. |

## Release

- **API:** migration 0041, the `race` goal, cadence, policy 2026-10-30.2, the food seed (deploy with `-Seed`).
- **APK 1.0.0-beta.4.9 (build 27):** a full release, not a patch: a new permission, WorkManager and native code.
- **Website:** the blog post and the policy.
