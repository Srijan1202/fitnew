# Beta 4.1 — plan, part 2: the voice coach, intervals, sprints and plans

**Date** 2026-10-28 · **Branch** `phase-19` · **Status:** the owner approved the scope in the 4.0 plan (R2) and answered the three questions on 2026-10-28 (the table below). Waiting for the go; no code before it.

Part 1 (`beta-4.1-updates-plan.md`) is code push plus in-app APK updates. Both parts ship together as beta 4.1.

## The owner's answers (2026-10-28)

| Question | Answer |
|---|---|
| Plans in 4.1 | **All four:** 5K (with a run/walk start), 10K, half marathon, marathon |
| A gym day and a run on the same weekday | **Allowed, with a warning.** Setup suggests days with no gym session; Today then shows both |
| Runs in the readiness score | **A running-load part is added to §18** (C6) |

---

## C1 — The voice coach

- **How it speaks:** the phone's own text-to-speech (`flutter_tts`). It works offline, in English, and turns music down while it speaks, then back up.
- **What it says, and when:**
  - **Every km** (owner default; 0.5 km or off in Running settings): "3 kilometres, 17 minutes 10. Last kilometre 5 40. Average 5 43."
  - **With a pace target:** "About 15 seconds fast, ease off a little" or "Pick it up a little". It speaks only when you're more than 10 s/km off for 30 s, and at most once a minute, so it doesn't nag.
  - **Start guidance:** in the first kilometre, if you're 15 s/km or more faster than your target or plan pace: "Easy start. Hold back for now, you'll thank yourself later." After two-thirds of the distance, if you're on target: "On track. Hold this or pick it up to the finish."
  - **Distance and time goals:** halfway, the last kilometre (or last 5 minutes), and "Goal reached".
  - **Pause and resume:** "Paused." / "Resumed."
- **Settings:** a voice switch (on by default), how often, and a test button.
- **Where the rules live:** the phone. This is §7.3's running exception again (ADR-038 D8): the cues must come in real time with no signal. They read only the live figures the phone already has; nothing new is kept.

## C2 — Interval workouts

- **A workout is a list of steps:**
  - warm-up and cool-down, each a time or a distance;
  - repeats: N × (work: a distance or time, at a pace zone or a pace; recovery: a time or distance, jog, walk or stand).
- **Ready-made sessions:**
  - 6 × 400 m;
  - 5 × 1 km;
  - 8 × 200 m strides;
  - 10 × 1 min on, 1 min off;
  - 3 × 2 km tempo.

  You can also build your own and save it.
- **During the run:**
  - the screen shows the step, what's left and the next step;
  - the coach calls each step ("Rep 3 of 6, 400 metres at 1 50") and counts down the last 10 s of a timed step;
  - the phone vibrates at every change.
- **What's kept:**
  - The run keeps the workout and where each step began and ended (`laps`: the times in its track). The phone needs no extra information for this.
  - The server works out each lap's distance, time and pace from the track (core), so the summary shows rep by rep.
  - Migration `0036`: `runs.workout` and `runs.laps` (jsonb, both null for a normal run).

## C3 — Sprints

- **The format:** reps of 60–400 m with a 3-2-1 countdown that starts the timer, a rest between reps, and a summary of each rep's time and the best.
- **Honest limit:** phone GPS is good to a few metres, so a 100 m time can be about ±0.5 s out. FITOS says so on the summary. 400 m is far more reliable.
- **Built on C2:** a sprint session is an interval workout with standing recoveries and the countdown.

## C4 — Plans: 5K, 10K, half marathon, marathon

- **Choosing a plan:**
  - the distance;
  - your level: a 5K for a beginner (run/walk from zero), otherwise from a recent race or time trial;
  - 3, 4 or 5 runs a week, and which days;
  - optionally, a goal time.
- **Pace zones:** Daniels' published VDOT equations, from your recent race (or goal time). They give easy, marathon, threshold, interval and repetition paces. A beginner 5K plan uses effort ("an easy pace you can talk at") until there's a first timed run.
- **Lengths and shape:**
  - 5K and 10K: 8 weeks;
  - half marathon: 12 weeks;
  - marathon: 16 weeks;
  - a long run, quality sessions (C2) and easy runs, with every fourth week easier;
  - the last 1–3 weeks taper.
- **Where it runs:**
  - The plan is built on the server in core, the same way the gym programme generator works (§12).
  - Each planned run is "Thursday: 6 km easy at 6:05–6:35" or "Tuesday: 5 × 1 km at 4:50".
  - **Start this run** loads its targets into the coach.
- **The week:**
  - Running shows this week's planned runs, done or still to do.
  - Today shows a planned run as today's session, and the evening reminder covers it like a gym session.
  - A plan run can be skipped (like Skip today, ADR-030) or moved to another day of the same week.
- **Stored:**
  - Migration `0036` adds `running_plans` (the plan and its settings) and `planned_runs` (date, kind, targets, the run that did it).
  - A run started from a planned run links to it; a run you do on its day matches it automatically.

## C5 — Runs count in the rest of FITOS

- **Today:** a planned run is a session (C4). A day with a saved run is an active day for the streak (beta 3.3's rule: something logged).
- **Weekly goal ring:** gym sessions and plan runs together count toward the week.
- **Missed session:** a planned run not done is "missed" the next morning, like a gym session. A rest day stays a rest day.
- **Recovery:** runs enter the readiness score (C6). Recovery also shows the last 7 days of running: distance and time.

## C6 — A running-load part in readiness (owner: changes MASTER-SPEC §18)

- **The measure:** running load is the minutes run, weighted by how hard each run was. The weight is effort ÷ 5 when the run has an effort, else 1. It is compared the standard way, acute against chronic:
  - acute: the last 7 days;
  - chronic: the average week over the last 28 days;
  - their ratio (ACWR).
- **The penalty:**
  - 0 up to a ratio of 1.3 (normal progression);
  - rising evenly to its cap of **10** at 1.8 and above (a sharp jump, the classic injury-risk zone).
- **Only when there's a base:** it applies only with at least 3 runs in the 28 days. Otherwise it is "not in the score: not enough recent running", like the other parts.
- **The formula:** readiness = 100 − sleep − soreness − energy − performance − adherence − **running load**, still floored at 0. The five existing parts keep their caps, so a heavy running week can lower an otherwise perfect day to 90.
- **Shown:**
  - Recovery's readiness breakdown gets a sixth bar, "Running load".
  - The advice line names it when it's the biggest part: "Your running jumped this week; keep today easy."
- **Older apps:** 4.0.x phones read the breakdown with the five known parts. The server sends the sixth part only to builds that know it, by build number, so a 4.0 phone never breaks. That build check is tested.
- **Not changed:** the bands (≥75 ready, …), the three-day low-readiness escalation and the deload offer all work as now, on the new total.

## Tests

- **core:**
  - VDOT and the pace zones against Daniels' published table (within 2 s/km);
  - plan generation (every distance and level, 3–5 days, taper, every fourth week easier);
  - lap figures from a fixture track;
  - all keeping the 100 % branch gate.
- **app:**
  - the coach's rules on recorded tracks (what it says, and when);
  - the interval engine through every step type;
  - the widget flows (plan setup, planned run, interval run);
  - TTS faked in tests.
- **Field runs on the S24:**
  - an easy run with the voice on and music playing;
  - one interval session;
  - one plan run from Today.

