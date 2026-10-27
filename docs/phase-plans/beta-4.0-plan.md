# Beta 4 — plan: running

**Date** 2026-10-27 · **Branch** `phase-19` · **Status: the owner answered all four questions and said go on 2026-10-27. 4.0 is built on `phase-19` (ADR-038). It is released only on the owner's word, after field runs on the S24.**

The owner's brief (2026-10-27):

- The Training page gets two choices at the top, **Gym** and **Running**. Gym is the default.
- A full running guide, like Samsung Health:
  - live GPS tracking on a map, like Strava;
  - pace, speed, distance and everything else;
  - export the map after a run.
- Guidance during the run, for example to speed up or slow down at the start.
- For every distance, from sprints to marathons.
- Badges, for example the fastest 10 km.
- Route replay, like Strava.
- Later: connect a watch (the owner has a Galaxy Watch 4).
- "And more."

Nothing is released until the owner says beta 4 is ready.

---

## What the runner gets

### R1 — Record a run

- **Gym | Running** switch at the top of Training. It opens on Gym every time. Running shows this week's runs, a **Start run** button, history and records.
- **Before the start:**
  - choose the kind: outdoor or treadmill (treadmill runs have no GPS; you type the distance at the end);
  - choose a goal: free run, distance, time or a target pace;
  - a GPS signal indicator. Start is allowed before a good fix; the first points then wait for one.
- **During the run:**
  - large numbers: time, distance, current pace, average pace;
  - a swipe shows speed, the last split, elevation gain and calories;
  - a map with your line drawn live;
  - pause and resume, plus **auto-pause** when you stop at a crossing (can be switched off);
  - a screen lock against pocket taps.
- **The run carries on with the screen off or in another app.** Android shows a FITOS notification with the time and distance while you run. Every point is saved on the phone as it arrives, so a crash or a flat battery loses nothing already recorded.
- **After the run:** a summary with:
  - the map;
  - splits per km;
  - pace and elevation charts;
  - calories (from your weight and pace, using the standard ACSM running equation);
  - a name, a note and how hard it felt (1–10).
  - You can save or discard it.
- **Units:** km and min/km by default; miles in settings.
- **Offline:** recording never needs the internet. Map tiles need a connection; without one, your line still shows on a blank grid. The run uploads when you're back online, the same way workouts do (ADR-006).

### R2 — Guidance and plans

- **Voice coach** through the phone's own text-to-speech, so it works offline and over music:
  - every km (or every 0.5 km): the split, your average and the time;
  - with a target pace: "you're 20 seconds fast, ease off" or "pick it up a little", with a tolerance so it doesn't nag;
  - **start guidance:** most runners go out too fast. For the first km FITOS tells you to hold back if you're well under target, and late in the run it says when an even or faster finish is on;
  - halfway and the last km on distance goals.
- **Interval workouts:** warm-up, repeats (for example 6 × 400 m at 5K pace with 90 s jog), recoveries and cool-down. The coach calls each step and the phone vibrates.
- **Plans:** beginner 5K (run/walk), 10K, half marathon and marathon.
  - You enter a recent race or a time trial, or your goal time. FITOS works out your pace zones (easy, tempo, interval, long) with the published Daniels running formula.
  - Plan runs show in the training week next to gym days. Today shows a planned run as today's session. The run reminder works like the workout reminder.
- **Sprints:** short-distance timing (100–400 m) with a countdown start and a summary of the reps.

### R3 — Records and badges

- **Best efforts,** found anywhere inside any run, the way Strava does it: 400 m, 1 km, 1 mile, 5 km, 10 km, half marathon and marathon. "Fastest 10 km" is your best 10 km stretch in any run, not only in runs of exactly 10 km.
- **Badges:**
  - a first run;
  - each best effort (gold for your best, silver and bronze for the next two);
  - longest run;
  - biggest climb;
  - monthly distance (25, 50, 100 and 200 km);
  - weekly streaks;
  - completing a plan.
  - New records get a celebration on the summary screen.
- **History:** a list and a calendar, with week, month and year totals.
- **Progress page:** a new Running section with distance per week, pace trend and records.

### R4 — Export and replay

- **Share card:** an image of your route map with distance, time, pace and the FITOS mark in your theme. It goes out through Android's share sheet (Instagram, WhatsApp, Gallery).
- **GPX export:** the standard file Strava, Garmin and others import. You can also move FITOS runs into Strava.
- **Route replay:** a marker runs your route with the time, distance and pace at that moment. Speeds are 10×, 30× and 60×; drag to scrub.
- **Privacy zone:** the first and last 200 m are hidden on share cards and in GPX by default, so a shared map doesn't show your home. It can be changed per run.

### R5 — Watch (later, beta 4.x)

The Galaxy Watch 4 records runs into Samsung Health, and Samsung Health writes them to Health Connect, which FITOS already reads (ADR-008). FITOS would import those runs with:

- distance;
- time;
- heart rate (a new Health Connect permission);
- the route (a new Health Connect permission; Android asks per run).

The runs would get the same splits, records and badges. Live heart rate *during* a phone run, or a FITOS app on the watch, needs its own Wear OS app: a separate project for after beta 4.

### Linked to the rest of FITOS

- Runs count as training:
  - in Recovery's training load;
  - in the weekly training count and the streak;
  - a run day isn't a "missed session".
- **Calories:** a run's calories join the day's active energy without double-counting Health Connect's. When both have a run at the same time, the one with the higher-quality source counts.
- **FITOS AI (premium):** recent runs join the chat context later. Not in beta 4.
- **Privacy:** runs are in the data export (with GPX) and in delete-account. The privacy policy names location (ADR-023).

---

## How it's built

- **Phone:** a new `features/running`.
  - **GPS:** `geolocator` with an Android foreground service of type location. It records while the screen is off and needs only "while using the app" location, not "all the time".
  - **Accuracy:** points with an accuracy worse than 20 m are dropped, and the track is smoothed (a small Kalman filter) so a standing runner doesn't drift.
  - **Storage:** points go into drift every second.
  - **Voice:** `flutter_tts`.
  - **Map:** MapLibre (`maplibre_gl`) showing OpenFreeMap's tiles: the Dark style for FITOS Dark and Positron for the light themes. A small map-provider setting keeps a later switch to self-hosted tiles a one-line change.
- **Samsung's battery saver** can kill background apps. The first run asks once to set FITOS to *Unrestricted*, with a button to the right settings page.
- **Server:**
  - a `runs` table: summary, the kind, the goal and the plan step;
  - the track as one compact encoded column per run, not one row per point;
  - `badges` and `run_best_efforts` tables.
  - `packages/core` recomputes distance, splits, best efforts and badges from the uploaded track. Those are the numbers kept for the record.
- **The exception to MASTER-SPEC §7.3 / §5** (no business logic in Dart): the live numbers and the voice coach have to work offline and in real time, so the phone computes them as a live view.
  - **Recorded in:** ADR-038.
  - **What the server keeps:** the server's figures replace the phone's after upload.
  - **Expected gap:** the two should agree within 1 %. A test checks it on recorded tracks.
- **Tests:**
  - real recorded tracks (GPX fixtures: a park loop, a track session, a run with tunnels and stops) are replayed through the phone engine and through core;
  - core keeps its 100 % branch gate;
  - widget tests cover every screen at 200 % text.
- **Acceptance needs real runs on the S24.** GPS can't be fully proved on a PC, so the owner's field runs are part of the check: one easy run, one interval session and one run with the screen off and music on.
- **APK size** grows by about 3–6 MB with a map library.

---

## The owner's answers (2026-10-27)

| Question | Owner's answer |
|---|---|
| Map provider | ~~Google Maps~~. Google Maps didn't work for the owner (2026-10-27), so it's replaced by **OpenFreeMap through MapLibre** (proposed 2026-10-27, owner to confirm). It needs no key, no account and no billing; app and commercial use are allowed and there's no view limit |
| Release shape | **In steps:** 4.0, 4.1, 4.2, 4.3 |
| Where runs are kept | **Synced to the account**, like workouts. Shares hide the first and last 200 m |
| Free or premium | **All running is free.** FITOS AI stays premium |

Decided by default, which the owner can change:
- km by default, with miles in settings;
- auto-pause on;
- voice every 1 km;
- a 200 m privacy zone.

## The steps

| Release | What's in it |
|---|---|
| **4.0** | **R1** in full: the Gym/Running switch, outdoor and treadmill runs, goals, live map, auto-pause, lock, screen-off recording, the summary with splits and charts, sync. Also a history list with week and month totals, plus the **share card**, the **GPX export** and the **privacy zone** from R4. |
| **4.1** | **R2:** the voice coach, start guidance, intervals, sprints, the 5K/10K/half/marathon plans in the training week, and runs counting in Today, the reminders, Recovery's load and the streak. |
| **4.2** | **R3** and the rest of **R4:** best efforts, badges, the calendar, the Progress section and route replay. |
| **4.3** | **R5:** Galaxy Watch runs from Samsung Health through Health Connect. |

Each step gets its own plan check, its own tests and the owner's field runs before release.

## The map: OpenFreeMap (replaces Google Maps, 2026-10-27)

Google Maps didn't work for the owner, so 4.0 uses **OpenFreeMap**. Its terms, as published on openfreemap.org:
- free, with no registration, no API keys and no cookies;
- commercial use allowed;
- no limit on map views or requests;
- styles include Dark, Positron, Bright and Liberty;
- MapLibre adds the OpenStreetMap credit on the map automatically;
- offline downloads are allowed up to 3,000 tiles or 50 MB per download, with a distinct User-Agent.

**The owner sets up nothing.**

- **The risk:** OpenFreeMap runs on donations, with no service guarantee.
- **The fallback:** host our own tiles. That means a Protomaps extract of India as a single file on our AWS server, read by the same MapLibre with a different style. The app reads the map address from one setting, so switching is a small release.
- **Before 4.0 ships**, the phone check covers the map in Dark and light themes and with no signal.
