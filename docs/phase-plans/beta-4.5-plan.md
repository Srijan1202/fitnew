# Beta 4.5 — plan: Galaxy Watch runs, and more running badges

**Date** 2026-10-30 · **Branch** `phase-19` · **Status:** the owner chose the scope and answered every question on 2026-10-30 (the table below). Waiting for the go; no code before it.

## The owner's answers (2026-10-30)

| Question | Answer |
|---|---|
| Watch runs | **Imported automatically** from Health Connect (Samsung Health shares the Galaxy Watch's runs), with a switch in Running settings |
| Heart rate | **Yes:** average and max on the run; the privacy policy is updated and accepted once |
| New badges | **Speed, lifetime distance and consistency** |
| Rewards | **Two:** 1,000 km unlocks a **Mileage** theme; a 5K under 20 min unlocks a **Bolt** app icon. The rest are badges only |

---

## W1 — Galaxy Watch runs, through Health Connect

- **How they arrive:** the Galaxy Watch records a run in Samsung Health, and Samsung Health shares it with Health Connect. FITOS reads it from there. FITOS already reads steps and calories from Health Connect (Phase 6.5), so this is one more kind of record, not a new connection.
- **What is read, only with your permission:**
  - running exercise sessions (start, end, title);
  - their distance;
  - heart rate during them;
  - the route, when Samsung Health shares one.

  Each is asked for once, in Health Connect's own screen. Without the route permission, or for a run with no route (a treadmill run on the watch), the run comes in without a map: distance, time, pace and heart rate only.
- **When:** each time Running opens, and in the background with the existing health refresh. It covers the last 30 days the first time, then whatever is new.
- **Not doubled:**
  - a watch run that overlaps a run FITOS recorded on the phone, by more than half its time, is skipped;
  - each imported run keeps Health Connect's id, so it is never imported twice, even after a reinstall.
- **On the run:**
  - a "Galaxy Watch" mark in the history and on the run's page;
  - average and max heart rate on the run's page.

  The run counts like any other: totals, best efforts and replay (with a route), badges, the streak, and the plan's run for that day.
- **Settings:** Running settings → "Import runs from Galaxy Watch" (on by default once Health Connect is allowed). Turning it off stops new imports and keeps the runs already in.
- **Stored (migration `0039`):** `runs` gains:
  - `source` (phone | watch);
  - `external_id`, unique per user;
  - `hr_avg` and `hr_max`.

  A watch run may be outdoor without a track (the check allows it only for `source = watch`). The API takes them through the same `POST /running/runs` with the new fields, so it stays idempotent.
- **Honest limits:**
  - **Routes:** some Samsung Health versions do not share a route; then there is no map, said plainly on the run.
  - **Timing:** a run appears once Samsung Health has synced it to the phone, sometimes a few minutes after the watch.
  - **Testing:** your Galaxy Watch 4 is the field test.

## B1 — More running badges (core `running/efforts.ts`, kept in `user_rewards` like the others)

| Group | Badges | Earned by |
|---|---|---|
| Speed | 5K under 30, 25 and 20 min; 10K under 60 and 50 min; half under 2 h; marathon under 4 h | your best effort at that distance (needs a run with a route) |
| Lifetime | 50, 100, 250, 500 and 1,000 km | every run's distance added up, treadmill and watch included |
| Consistency | a run in each of 4 weeks in a row; 3 runs in one week; finishing a running plan | runs by ISO week (Monday to Sunday); a plan is finished when its race run is done |

- **Dates and history:**
  - each badge is dated by the run that earned it;
  - past runs count;
  - like the others, a badge stays if that run is deleted.
- **Rewards:**
  - 1,000 km unlocks the **Mileage** theme (dark, deep orange);
  - a 5K under 20 min unlocks the **Bolt** app icon (the F with a lightning streak);
  - each is chosen in Profile.

  The icon is a new launcher entry, which is one reason 4.5 is an APK.
- **Where they show:**
  - Running → Badges in groups;
  - Streak & rewards with when each unlocks ("12.4 km to go", "your best 5K is 23:10");
  - "Badge earned" after the run that earns one.
- **Older phones:** the new badge ids are sent only to build 23 and later, as 4.2 did for the first badges.

## Privacy

- **Policy:** the policy gains the watch runs and heart rate read from Health Connect, with your permission, kept with the run, in Download my data, and deleted with the account. Its version becomes `2026-10-30.1`, so everyone accepts once.
- **Not changed:** FITOS reads only running sessions and what belongs to them. Nothing is written to Health Connect.

## Release

- **4.5 is build 23, an APK through Update now:** it carries new Health Connect permissions and a new launcher icon. The API deploys first (`0039`).
- **Field check:**
  - a run recorded on the Galaxy Watch 4 appears in FITOS by itself, with heart rate and, if shared, its map;
  - it is not doubled with a phone run;
  - past badges appear;
  - a theme or icon unlocks when earned.

## Separately: the streak grid's dates

The fix ("dates not visible") is a Shorebird patch to 4.4, built from `87f9c52`. It is published when the owner says so.
