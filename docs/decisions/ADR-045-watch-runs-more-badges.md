# ADR-045 — Beta 4.5: Galaxy Watch runs through Health Connect, and more running badges

**Status:** PROPOSED. The owner chose the scope, answered the plan's questions and said "go" on 2026-10-30 (`docs/phase-plans/beta-4.5-plan.md`). Built on `phase-19`. Becomes ACCEPTED with the owner's acceptance of beta 4.5.
**Date:** 2026-10-30
**Phase:** 19 (beta 4.5)
**Affects:**
- Phase 6.5 / ADR on Health Connect (read only);
- ADR-038/042 (runs, badges);
- §23 (the policy).

---

## Decisions

| # | Decision |
|---|---|
| D1 | **Watch runs come in automatically** (owner). A Galaxy Watch records a run in Samsung Health, which shares it with Health Connect. FITOS reads it there: running and treadmill exercise sessions from another app, read only. Health Connect's own sheet asks for the permissions once: exercise and distance (needed), heart rate and exercise routes (wanted). A switch in Running settings ("Import runs from Galaxy Watch") asks for them when turned on, and stops imports when turned off. |
| D2 | **Read on the phone, then sent like any run.** The native `runningSessions` reads each session with the other app's own distance and heart rate in the session's time (`dataOriginFilter`), the seconds paused (pause segments), and the route when shared (`ExerciseRouteResult.Data`). `WatchImporter` sends each new one through `POST /running/runs` with `source: watch`, `externalId` (Health Connect's record id), and `hrAvg`/`hrMax` checked to 25–250. It runs whenever Running opens. It looks back 30 days the first time, then from the last import less 2 days. |
| D3 | **Once, and not doubled.** The client id is a UUID v5 of the user and the record id, so it is the same on every phone. The server also keys watch runs by `(user, external_id)`, unique, so a replay from another phone or a reinstall answers the same run. A watch run overlapping a phone-recorded run by more than half its time is left out. |
| D4 | **A watch run without a route** (not shared, or a treadmill) keeps the watch's distance and time. Outdoors without a track is allowed only for `source = watch` (`runs_track_kind`). Its page says "No map: Samsung Health did not share this run's route". With a route it is a run like any other: figures from the track, best efforts, replay. |
| D5 | **More badges** (core `running/badges.ts`): |
| | • **Speed:** the best effort under 30/25/20 min for 5K, 60/50 for 10K, 2 h for the half and 4 h for the marathon. |
| | • **Lifetime:** 50 to 1,000 km, every run added up. |
| | • **Consistency:** a run in 4 ISO weeks in a row, 3 runs in a week, a plan finished (its race run done). |
| | Each is dated by the run that earned it, past runs count, and it is kept in `user_rewards` and stays if that run is deleted. Each badge goes only to the build that knows it (`since`: 20 for the distance firsts, 23 for these). |
| D6 | **Two rewards** (owner): 1,000 km unlocks the **Mileage** theme (dark, deep orange; reward `total-1000k`); a 5K under 20 minutes unlocks the **Bolt** app icon (the lime F with an amber lightning streak; `.IconBolt`). |
| D7 | **Where it shows:** Running → Badges in four groups. Streak & rewards shows each badge with its progress: the longest run for distance, the best time for speed, the total for lifetime. The finish screen says "Badge earned" for distance, speed and lifetime at once; consistency appears after sync. `GET /running/records` gains `totalM`. |
| D8 | **Privacy:** the policy had said Health Connect data never reaches the server. It now names the one exception, only when switched on: watch runs, with their time, distance, route when shared, and average and maximum heart rate, kept like a run (exported, deleted with the account) and never sent to any AI. The version is `2026-10-30.1`, so everyone accepts once. |

## Consequences

- **4.5 is build 23, an APK through Update now:** new Health Connect permissions and a new launcher icon. The API deploys first (`0039`).
- **Honest limits:**
  - some Samsung Health versions do not share routes;
  - a run appears only once Samsung Health has synced it;
  - the import runs when Running is opened, not in the background.
- **Field check:** a run on the Galaxy Watch 4 appears by itself, with heart rate and, if shared, a map; it is not doubled with a phone run; past badges appear; Mileage and Bolt unlock when earned.
