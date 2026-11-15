# Beta 6.4 plan — Gym helpers

**Asked by the owner (2026-11-15):** "lets go with this" — the audit's gym helpers (`docs/audits/2026-11-11-final-audit.md` §5: N1, N2, N3, N9).

## Owner's decisions (2026-11-15)

| # | Question | Answer |
|---|---|---|
| Q1 | When does the lock-screen rest countdown show? | **Only when FITOS is hidden:** the screen is locked or you left the app. In FITOS, the rest bar does the job. |
| Q2 | What bar and plates does the plate calculator use? | **Your gym's, in settings.** It starts as a 20 kg bar with 25, 20, 15, 10, 5, 2.5 and 1.25 kg plates. |
| Q3 | GPX export already exists (4.0, the run's Share screen). | **Dropped from 6.4.** |
| Q4 | How do the widget's water and session buttons work? | **Water is logged without opening FITOS.** Start today's session opens FITOS, already started. |

## What 6.4 builds (app only; no server change)

| # | Item | How |
|---|---|---|
| N2 | **Rest timer on the lock screen** | <ul><li>While a rest runs and FITOS is hidden, there is an ongoing notification: the exercise, a live countdown (Android's chronometer), and **+15 s** and **Skip**.</li><li>It shows on the lock screen. A notification about a set shows no weights.</li><li>The actions work without opening FITOS. A background handler moves the rest's end (kept on the phone), shows the countdown again, and moves or cancels "Rest over".</li><li>When FITOS is running, the change also reaches the open session at once.</li><li>Coming back to FITOS removes the countdown, and the rest bar picks up the new end.</li></ul> |
| N3 | **Plate calculator** | <ul><li>On a barbell exercise in the session, a plates button by the weight opens a sheet, for example "100 kg: 20 kg bar + 25 + 15 each side", drawn as plates.</li><li>The sheet says when a weight cannot be made exactly, and shows the nearest weights that can.</li><li>Training settings → **Bar and plates** sets the bar weight (10–25 kg) and which plates your gym has.</li><li>The maths is in the app, tested, with the fewest plates per side.</li></ul> |
| N1 | **Widget buttons** | <ul><li>The Actions widget becomes Log food · Water · Start session · Run · Log weight.</li><li>**Water** adds a 250 ml glass without opening FITOS. A native receiver keeps the taps per day on the phone and says "+250 ml · 1.25 L today".</li><li>FITOS adds them to the day when it next starts or comes back, then syncs as water always does. A tap before midnight counts on that day.</li><li>**Start session** opens FITOS straight into today's session, already started. If a session is running, it resumes that one. On a rest day, or once today's session is done, it opens the plan.</li></ul> |

### Upkeep in the same release
- **S10:** the `fast-xml-parser` override, once 5.12.0 is two weeks old (2026-11-17).
- **A7:** Flutter package updates within their current major versions, where the tests stay green.

### Release
- A full APK, 1.0.0-beta.6.4 (39), because the widget layout, a new receiver and the notification action receiver change the manifest.
- No migration. The minimum build stays at 37.
- The privacy policy does not change: nothing new leaves the phone.

## Not in 6.4
- Logging water from the notification shade, and starting a run from the widget without opening FITOS.
- Plates in pounds. The app is in kilograms.
