# ADR-063 — Beta 6.4: Gym helpers

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

## Context

On 2026-11-15 the owner chose "Gym helpers" for 6.4 and answered the plan's questions (`docs/phase-plans/beta-6.4-plan.md`):

| # | Question | Answer |
|---|---|---|
| Q1 | When does the rest countdown show? | Only while FITOS is hidden. |
| Q2 | Which bar and plates? | The gym's own, set in settings. |
| Q3 | GPX export? | Dropped: it has been on the run's Share screen since 4.0. |
| Q4 | The widget's water button? | It logs water without opening FITOS. |

## Decisions

| # | Decision |
|---|---|
| D1 | **Plates (N3).** <br>• `platesFor` finds the fewest plates per side for a weight. It counts in quarter-kilograms, so 1.25 kg plates are whole numbers. <br>• When the weight cannot be made, it shows the nearest weight below and above. <br>• The bar (10, 15, 20 or 25 kg) and the plate sizes the gym has are kept on the phone (`plates.v1`). They start as a 20 kg bar with 25, 20, 15, 10, 5, 2.5 and 1.25 kg plates. <br>• A plates button sits by barbell exercises in the session, and Profile → **Bar and plates** changes the set. <br>• Kilograms only. |
| D2 | **The rest on the lock screen (N2).** <br>• While FITOS is hidden, there is an ongoing, silent, public notification. Android's chronometer counts it down, and it carries **+15 s** and **Skip**. It removes itself when the rest ends, and "Rest over" fires as before. <br>• The actions are handled where the plugin delivers them, in FITOS or in its background isolate. They change the notifications themselves and tell the session in progress over an isolate port (`fitos.rest`). <br>• If FITOS is not running, there is no session to tell. <br>• Coming back to FITOS cancels both notifications. |
| D3 | **The widget's buttons (N1).** <br>• The Actions widget becomes Log food · **Water** · **Session** · Run · Log weight. <br>• **Water** goes to a native receiver. It keeps the glasses per day in the widgets' shared preferences (`flutter.widgets.water`) and gives the day's total in a toast, from the snapshot's water plus the glasses waiting. It refuses past 10 L. <br>• FITOS takes the glasses when it starts or comes back. Today's go through the water controller, so they are sent as the day's total. An earlier day's are sent as that day's total as the phone last knew it, and kept to send again if that fails. <br>• **Session** resumes a running session, or starts today's planned one and opens it. On a rest day, a done day or a skipped day, or with no programme, it opens the plan. |
| D4 | **Upkeep.** <br>• S10: `fast-xml-parser` pinned to 5.12.0. <br>• The admin panel moves to Next.js 16.4.5. Both releases are two weeks old. `pnpm audit` goes from 6 to 5 moderate findings, none high. <br>• A7 waits: every same-major Flutter package update is under two weeks old. |

## Consequences

- 6.4 is a full APK, 1.0.0-beta.6.4 (39), because of the widget layout, a new receiver and new icons. There is no server change and no migration. The minimum build stays at 37. The privacy policy does not change: nothing new leaves the phone.
- Water tapped with FITOS closed reaches the server only when FITOS next opens. Water is not on any board, so nothing else waits for it.
