# ADR-038 — Running (beta 4.0): recording a run on the phone, the record on the server

**Status:** PROPOSED. The owner approved the plan on 2026-10-27 (`docs/phase-plans/beta-4.0-plan.md`). Built on `phase-19`. Becomes ACCEPTED when the owner accepts beta 4.0 after field runs on the S24.
**Date:** 2026-10-27
**Phase:** 19 (beta 4.0)
**Affects:**
- MASTER-SPEC §7.3 (one exception, below);
- MASTER-SPEC §9.2 (`runs`);
- MASTER-SPEC §10.1 (`/running/runs*`);
- MASTER-SPEC §23 (location in the policy, version 2026-10-27.1);
- ADR-006 (a fourth queue, same policy);
- ADR-023 (export and deletion cover runs);
- ADR-033 (a `running` switch);
- `packages/core` (`running/track`, `running/summary`);
- `packages/contracts` (`running.ts`);
- migration `0035_running`;
- the phone database (schema 4).

---

## Context

The owner asked for running as the second half of Training (2026-10-27):

- GPS live tracking on a map, like Strava;
- pace, speed and distance;
- export of the map after a run;
- guidance during the run;
- sprints to marathons;
- badges;
- route replay;
- later, the Galaxy Watch 4.

The owner answered four questions:

| Question | Answer |
|---|---|
| Map | Google Maps first. It did not work for the owner, so **OpenFreeMap through MapLibre**: no key, no account, no billing. |
| Release | **In steps:** 4.0 recording, history, share card, GPX and privacy zone; 4.1 coach and plans; 4.2 records, badges and replay; 4.3 the watch. |
| Where runs are kept | **Synced to the account**, like workouts. |
| Free or premium | **All running is free.** |

These decisions cover 4.0.

## Decisions

| # | Decision |
|---|---|
| D1 | **Training is Gym \| Running.** A switch at the top of the Training tab. It opens on Gym; the choice holds while the app is open. Running is built the first time it is chosen. With the admin's `running` switch off, Training is the gym alone. |
| D2 | **The phone's database is the run's source of truth while it happens** (ADR-006 D1). The `local_runs` row holds the state and the timer: `activeMs`, plus `resumedAt` while running. Every stored point is written to `local_run_points` as it comes. If FITOS is closed mid-run, the next start finds the run paused at its last point, with its time counted to that point; nothing is lost. A finished run waits for Save or Discard and survives a restart too. |
| D3 | **GPS and the screen off.** `geolocator` (Fused Location) at about one fix a second. Its foreground service, type `location`, keeps a run recording with the screen off or another app open. It needs only "while using the app" location, never "all the time". FITOS writes the live time (Android's chronometer) and distance into that same notification (same id and channel); tapping it returns to the run. Samsung's battery saver can stop background apps, so before the first outdoor run FITOS asks once to set Battery → Unrestricted, with a button to the app's settings page. |
| D4 | **Cleaning GPS is the phone's job; what it stores is the track.** Fixes worse than 20 m are dropped. A jump faster than 12.5 m/s is dropped, until eight in a row mean the phone really moved, as when leaving a tunnel. A small Kalman filter smooths the positions. A point is stored only 3 m or more from the last one, so standing at a crossing adds no distance. Elevation is smoothed. Stored points are rounded the way the encoding keeps them (6 decimals, 0.1 m, 0.1 s). |
| D5 | **Auto-pause** (owner default on; a setting): slower than 0.6 m/s for 8 s pauses; faster than 1.2 m/s on two fixes in a row resumes. Every pause, by the runner or automatic, starts a new segment, so the gap adds no distance or time. |
| D6 | **The track on the wire and in the database: encoding v1.** Each point is lat·1e6, lon·1e6, elevation·10 and t·10, written as differences in Google's polyline scheme. `breaks` marks where each segment after the first begins. The server keeps it in one column per run (`runs.track_points`, plus `track_breaks` and `track_elevation`), not a row per point. A marathon at one fix a second is about 200 KB; a run holds at most 50,000 points, and the upload route accepts 2 MB. |
| D7 | **The record is the server's** (`packages/core running/summary`), computed when the run arrives. **Distance:** great-circle between the points of each segment. **Time:** the phone's timer as the runner saw it, with pauses excluded; pace is that time over the distance. **Splits per km and per mile:** interpolated at each boundary from the track's own times. **Chart:** 50 m buckets, at most 100. **Elevation gain:** 5 m hysteresis. **Calories:** ACSM gross, walking below 6 km/h and running above, capped at 24 km/h, with the weight on the run's day. **Outline:** up to 64 points for the history list. The distance, pace, gain, calories and outline are kept on the row (rebuildable from the track; calories also need that day's weight). Splits and the chart are computed on read. |
| D8 | **The exception to §7.3.** A run's numbers must show every second, with no signal, and a finished run must show its summary before it uploads. So the phone has a Dart port of D7 (`features/running/domain/run_math.dart`, `live_stats.dart`). The server's figures replace the phone's as soon as it has the run; until then the phone's are marked "not synced yet". **Shared fixtures** (`packages/core/test/fixtures/running`, made by `make-fixtures.ts`) hold the two together: core checks its summary of each fixture is unchanged, and the app checks its own equals it, to 0.05 per figure and exactly for calories and counts. The rounding is JavaScript's (half up) on both sides. |
| D9 | **The queue** (ADR-006 policy, its own `run_sync_queue`, like Phase 8's). **Save** queues one upload with everything the server needs; there is no partial upload. **An edit** while the upload waits rides in it; after the upload it is its own PATCH. **Deleting** a run the server never had removes it at once; otherwise a DELETE follows, and a 404 also counts as done. 422 and 403 park with the server's words; offline or 401 charge nothing; anything else backs off 300 ms · 2ⁿ, five times, then parks. A confirmed upload caches the server's run and removes the phone's copy (row and points) in one transaction. |
| D10 | **The API:** `POST /running/runs` (201, or 200 with the same run on a replay; another user's id is 409); `GET /running/runs` (newest first, 20 a page, `before` = a `startedAt`, with this week (Monday on) and this month in the user's timezone); `GET`/`PATCH`/`DELETE /running/runs/{id}`, all addressed by the phone's id. A track that does not decode is 422 with its reason. The admin's `running` switch refuses new runs and edits (403 `feature-off`); the history, a run and deleting one always work. |
| D11 | **Location is personal.** A deleted run is deleted (no soft delete). Runs go with the account (CASCADE) and are in the data export as stored; the export notes the track encoding, and the app exports any run as GPX. **The privacy zone** (owner default 200 m) leaves the first and last 200 m out of a shared picture and a GPX file, unless the runner turns it off for that share. The policy (doc and app, in step by test) names runs, their route, and OpenFreeMap as the map provider. Its version becomes `2026-10-27.1`, so everyone accepts once. |
| D12 | **The map.** MapLibre draws OpenFreeMap's tiles: Dark on dark themes, Positron on light. OpenStreetMap is credited on the map. With no network, and in tests (a platform view cannot run there), FITOS draws the route itself on a grid. The style address is one constant, so a move to self-hosted tiles (a Protomaps extract on AWS) is a small release. **The share picture:** the map is a platform view, so it is frozen as a snapshot (MapLibre's offscreen renderer), then the card (map, name, distance, time, pace, the FITOS mark) is captured whole. |
| D13 | **Treadmill runs** have no GPS. The timer runs, and the distance is typed from the treadmill at the end (up to 200 km); the pace is even and there are no splits. |
| D14 | **Units:** km by default, miles in Running settings. Only the display changes; everything is stored in metres and seconds. |

## Consequences

- **Not in 4.0:** the voice coach, intervals and plans (4.1); best efforts, badges and route replay (4.2); the watch (4.3). Running does not yet count in Today, Recovery's training load or the streak (4.1).
- **Field check:** acceptance needs the owner's runs on the S24 (an easy run; one with the screen off and music on; one with stops). GPS, the foreground service, the battery setting and the map cannot be proved on a PC.
- **APK size** grows by MapLibre's native library: 39.1 MB for arm64, up from 29.4 MB. Its AAR carries every ABI, so a build for named platforms excludes the others at packaging (`android/app/build.gradle.kts`); Flutter's plugin resets `abiFilters`.
- **OpenFreeMap** runs on donations with no service guarantee. If it stops, the map falls back to the drawn route until the style address moves.
