# ADR-039 — Running (beta 4.1): the voice coach, sessions, sprints, plans and running load

**Status:** PROPOSED. The owner approved the scope (`docs/phase-plans/beta-4.1-running-plan.md`), answered its three questions and said "go" on 2026-10-28. Built on `phase-19`. Becomes ACCEPTED when the owner accepts beta 4.1 after the field runs on the S24.
**Date:** 2026-10-28
**Phase:** 19 (beta 4.1)
**Builds on:** ADR-038 (beta 4.0 running).
**Affects:**
- MASTER-SPEC §7.3 (ADR-038 D8's exception, extended to the coach);
- §9.2 (`running_plans`, `planned_runs`; `runs.workout` and `runs.lap_marks`);
- §10.1 (`/running/plans*`, `/running/planned/{id}`, `/running/workouts`);
- §11 (TODAY `start-run`);
- §12 (a second generator in core: running plans);
- §18 (a sixth readiness part, running load);
- ADR-021 (plan runs in the reminders);
- migration `0036_running_plans`;
- the phone database (schema 5).

---

## The owner's answers (2026-10-28)

| Question | Answer |
|---|---|
| Plans in 4.1 | **All four:** 5K (with a run/walk start), 10K, half marathon, marathon |
| A gym day and a run on the same weekday | **Allowed, with a warning** |
| Runs in readiness | **A running-load part is added to §18** |

## Decisions

| # | Decision |
|---|---|
| D1 | **The voice coach is the phone's.** It uses the phone's own text-to-speech (`flutter_tts`), offline and in English, and turns music down while it speaks. It calls splits every km or mile (or every half, a setting), with the split and average pace. With a pace target it says "a little fast" or "pick it up", only after 30 s more than 10 s/km off, and at most once a minute. It also gives start guidance in the first kilometre, the goal's halfway, last stretch and "goal reached", and pause and resume. Its rules read only the live figures the phone already has (ADR-038 D8's exception, `domain/coach.dart`); nothing new is kept. A switch, how often, and a test button are in Running settings. |
| D2 | **A session is a flat list of steps:** warm-up, work, recover and cool-down. Each step ends on a distance or a time and carries an optional pace range, an effort word, and rep *i of n*. Core's `running/workout.ts` defines the five ready-made sessions (6 × 400 m, 5 × 1 km, 8 × 200 m strides, 10 × 1 min, 3 × 2 km tempo), paced from the plan's zones when there is a plan and by effort words otherwise. At most 120 steps. |
| D3 | **Your own sessions stay on the phone.** "Build your own" (reps, a distance or a time, a pace zone or effort, the recovery jog, warm-up and cool-down) is saved in the phone's cache for the signed-in account. It runs offline and is not synced. Syncing is a later change if the owner wants sessions on a second phone (BACKLOG). |
| D4 | **During a session** the phone's `WorkoutRunner` moves through the steps by distance or time. The live screen shows the step, what's left and the next step, with a manual Next step. The coach calls each step and counts down the last seconds of a timed step into a rep, and the phone vibrates at every change. Auto-pause is off in a session: a standing recovery must not pause the run. A run restored after FITOS was closed picks its session up again. |
| D5 | **Laps are measured on the server.** The phone sends only where each step began and ended (`lap_marks`, times in the track). Core's `running/laps.ts` measures each lap's distance, time and pace on the track. The report lists them rep by rep, with the best rep. A sprint session (every rep 400 m or less) adds that phone GPS is good to a few metres, so a 100 m time can be about half a second out. |
| D6 | **Sprints** are a session made from three choices: reps (4–10), distance (60–400 m) and standing rest (60–180 s), between a 10-minute warm-up and a 5-minute cool-down. The coach counts "three, two, one" into each rep. |
| D7 | **Pace zones are Daniels' VDOT**, from a recent race or a goal time (`running/vdot.ts`). The VO₂ cost and %max-for-time are his published equations; VDOT is bounded to 20–90. Easy is 62–74 % of VDOT's velocity, threshold 88 %, interval 97.5 % and repetition 106 %; marathon is the predicted marathon pace. Tested against his table to within 2 s/km. |
| D8 | **Plans are built on the server, in core** (`running/plan.ts`), like the gym generator (§12). The lengths are 8 weeks for the 5K and 10K, 12 for the half and 16 for the marathon. Each plan has 3–5 runs a week on the runner's days, the long run on its day, quality sessions from D2, and easy runs. Every fourth week is easier and the last 1/1/2/3 weeks taper. Tempo grows 3 minutes a week to a cap. The beginner 5K is 8 weeks of run/walk, 3 days, by effort. One plan is active per user; a new one stops the old one (its done runs stay). A plan run can be skipped, un-skipped, or moved within its week. |
| D9 | **A run does a planned run once.** A run started from a planned run names it; any other run on a planned run's day matches it. Deleting the run plans it again. |
| D10 | **Today and TODAY.** Today's planned run is `start-run` (priority 87, reason `run-scheduled`, evidence `run-completed` from the server's runs), and it keeps the day from being a rest day. `ENGINE_VERSION` stays `today-3`: the change is additive, and older apps ignore a kind they do not know. A day with a run counts for the streak, plan runs count in the weekly ring, and a plan weekday is not a rest day. |
| D11 | **Running load, the sixth part of §18.** The measure is effort-weighted minutes: effort ÷ 5, or 1 without an effort. The acute load (7 days) is compared with the average week of the last 28 days. The penalty is 0 up to a ratio of 1.3, rising evenly to its cap of **10** at 1.8. It needs at least 3 runs in the 28 days; otherwise the part reads "not in the score: not enough recent running". readiness = 100 − the six parts, floored at 0, and the bands are unchanged. **Older apps:** the sixth part goes only to builds 18 and later, read from the `X-FITOS-Build` header every request now carries; the score is the same for every build. Recovery shows the part as a sixth bar, and the last 7 days of running. |
| D12 | **Reminders cover plan runs** with core's planner unchanged. A plan run's weekday is a training day named after the run ("Easy 5 km in about an hour"; "missed" the next morning). A weekday the gym also trains keeps the gym session's reminder: one a day, while Today shows both. A skipped plan run is a skipped day, and a day with any run counts as trained. On the phone, starting a run cancels today's reminder and saving one cancels "missed", as a gym session does. |

## Consequences

- Core: 1089 tests, 100 % branches. API: running plans, laps, TODAY, readiness and the reminders integration-tested.
- The reminder copy was written for the gym ("The barbell has been staring at the door"); on a run day a cheeky variant can read oddly. Run-specific variants would need a core change; that is in BACKLOG.
- Field runs on the S24 before acceptance: an easy run with the voice on and music playing, an interval session, and a plan run from Today.
