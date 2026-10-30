# Beta 4.9 plan: the owner's three bugs, background watch runs, cadence, race day, more food

**Owner, 2026-10-30.** Bugs reported from 4.8 with screenshots; 4.9 scope chosen. Decisions taken with the owner:
- **Rest day:** any day without training is green.
- **Weight graph:** actual readings with a faint trend line.
- **Badges:** a medal with its number.
- **Features:** all four.

**Status:** built 2026-10-30 after the owner's "go" (ADR-049); release awaits the owner.
**Shape:**
- the API (one migration);
- an APK 1.0.0-beta.4.9 (build 27), because of a new permission and background work;
- the website and blog.

---

## A. Bugs

| # | Bug | Fix |
|---|---|---|
| A1 | **Rest days still not green** (4.8 showed green only on the programme's rest weekdays, and only when you did not train) | **Blue is trained** (a workout or a run). **Green is rest:** no training that day, but the streak kept (a meal logged, or a planned rest day). Grey is Skip today; an outline is missed. The legend says "Trained · Rest · Skipped · Missed". Core `streakDayStatus`, tested; the streak's count is unchanged. |
| A2 | **Running badges look empty** (a generic icon in a ring) | **A medal with its figure:** "50 km", "5K 30′", "Half 2h", "4 wk", "3×", "Plan". Each is in its group's colour: distance, speed, lifetime, consistency. Dim with a lock until earned; filled when earned. Rewards keep their art (icon, theme, picture). |
| A3 | **The weight graph is drawn from the trend, not the readings** | **A bold line through your actual weigh-ins, a dot on each.** The trend is a thin dashed line behind it. The kg axis fits both. The trend figure above stays. |

## B. Galaxy Watch runs in the background

- **When:** every 6 hours (Android's WorkManager, on any network, battery not low), plus when Running opens, as now. The phone imports the watch's new runs through the same `WatchImporter`: once, not doubled, signed in as you.
- **Permission:** Health Connect's background read (`READ_HEALTH_DATA_IN_BACKGROUND`). It is asked for when the Running settings switch is on and Health Connect supports it. Without it, imports happen only when Running opens, as in 4.5, and the settings say so.
- **A quiet notification** "Watch run added: 5.2 km · 26:10" when one comes in, at most once a day, on the existing notification channel.
- **The privacy policy** gains a line: runs may be read in the background while the switch is on. That means a new policy version and one re-accept.

## C. Cadence from the watch

- **Average and maximum cadence** (steps per minute) on watch runs. Read from Health Connect's cadence records in the session; without those, from the watch's steps during the session, divided by the moving minutes.
- **Server:** migration **0041** adds `runs.cadence_avg` and `runs.cadence_max` (checked 60–250). They are sent with a watch run, shown on the run's page next to heart rate, and included in the export.

## D. Race-day mode

- **Starting it:**
  - from the plan's race run (its distance, and the plan's goal time or race time if set);
  - or as a new **Race** goal in the run setup: a distance (5K / 10K / half / marathon / any) and a target time.
- **A pacing plan before the start:** even or negative splits. With negative splits the first half is 2 % slower and the second 2 % faster. The plan is shown per km and can be adjusted.
- **During the race:**
  - a big screen with the current km's target pace;
  - ahead or behind plan in seconds, in green or amber;
  - the time projected at the current pace;
  - the coach's voice calls ahead or behind at each km.
- **After the race:** a race result card with the time against the target, each km against plan, and best efforts. It is shared with the existing share card.
- **Server:** `RUN_GOAL_KINDS` gains `race`, with the distance and target seconds (contract + check). A race run on the plan's race day marks the race done, as it already does.

## E. More food

- **Re-examine INDB's 384 skipped dishes.** Admit those that pass the existing checks (ADR-036): energy from macros within ±10 %, or ±15 % for fried; plausible per-piece energy.
- **New rule for whole-dish units** (cake, pie, loaf…): a serving of one portion (a slice: 1⁄8 of a cake, 1⁄6 of a pie) instead of skipping them.
- **The count** is reported in ADR-049. The search ranking checks (p95 < 200 ms, the "paneer" order) stay green.

## F. Release

1. **API:** 0041 and the `race` goal kind.
2. **APK 4.9 (27):** new permission, WorkManager, race mode.
3. **Website:** blog and policy.

**Field check:**
- a rest day is green;
- a watch run arrives without opening FITOS;
- cadence shows on a watch run;
- a 5K in race mode;
- a newly added dish can be found by search.
