# ADR-056 — Beta 5.7: Progress | Recovery halves; the camera closes before the gallery

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

The owner, 2026-11-08: "gallery still have same problem and fix it in 5.7 in that we will divide the progress and recovery in 2 sections same as we did in gym and running we will follow the same ui by default the page will open on progress". The plan was approved the same day ("go").

## The camera's Gallery button

5.6.3 (ADR-055 G1) kept the camera screen open while the gallery was up. It let the camera go and ignored the app leaving and coming back. On the S24 the camera still came back over the gallery. The emulator's picker never showed the fault.

| # | Decision |
|---|---|
| A1 | **The gallery never opens while the camera screen is up.** The camera's Gallery button lets the camera go and closes the camera screen, which returns `kCameraChoseGallery`. Snap a meal then opens the gallery, the same way as its own Gallery button, which has worked on the S24 since 5.5. |
| A2 | **A gallery closed without a photo keeps Snap a meal open**, with Take a photo and Gallery. Closing the camera with ✕ before any photo still closes Snap a meal, as in 5.5. `MealPhotoSource.pick` returns a `MealPhotoPick` that says which happened. |
| A3 | The 5.6.3 guard stays: the camera starts once, even while its permission dialog is up. |

## Progress | Recovery

| # | Decision |
|---|---|
| B1 | **Two halves at the top of the tab**, with Training's switch: the same 52 px track, sliding block, corners and glow. The switch is now one shared widget (`FitModeSwitch`), used by both tabs. Progress uses the `insights` icon and Recovery the `self_improvement` icon; both were already in the release's font. |
| B2 | **It opens on Progress.** The choice holds while the app is open, like Gym \| Running (`progressModeProvider`). |
| B3 | **Progress:** "PROGRESS / Your progress", then 1W · 1M · 3M and the weekly report. Below them come Weight, Strength, Training, Nutrition and Body, then Get started. |
| B4 | **Recovery:** "RECOVERY / Your recovery", then Today (the check-in and readiness). Next is Recovery (what went into readiness, and the phone's sleep and heart rate). Without Health data, a Connect Health data line takes its place. Readiness is a daily figure, so Recovery has no period buttons. |
| B5 | **The ways in open the right half.** Home's Readiness tile, and Home's Sleep tile when the sleep is from the check-in or not logged, open Recovery. The check-in reminder opens Recovery. The weigh-in reminder and the weekly recap open Progress. The notification payload now carries its `kind`. |
| B6 | Only the layout changes. Every section, number and rule (§17) is as before; the sections only moved between the halves. "Progress & Recovery" is no longer the page title. |

## Release

- **App only:** a Shorebird patch to 1.0.0-beta.5.3 (build 33). It is Dart only, with no dependency or icon changes. There is no migration and nothing for the admin panel.
- **Then:** the owner checks the S24 and accepts.
