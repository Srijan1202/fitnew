# ADR-050 — Beta 5.0: exercise demos drawn by FITOS, and home-screen widgets

**Status:** PROPOSED. Owner, 2026-10-31: "Exercise demo animations for the ~30 most-used lifts" and "make some widgets for the app", the answers below, then "go" on `docs/phase-plans/beta-5.0-plan.md`. Becomes ACCEPTED with the owner's check on the phone.
**Date:** 2026-10-31
**Phase:** 19 (beta 5.0)

---

## Exercise demos

| # | Decision |
|---|---|
| D1 | **Drawn by FITOS, for everyone.** No licensed or commissioned art, so there is no licence to clear and nothing to download. The figure is a head and capsules, drawn in the theme's ink, with its equipment in a mid-tone. Plates are see-through, so the arms behind them show. |
| D2 | **A rig, posed by data.** Pure Dart (`exercise/domain/demo`). <br>• Each lift is 2–3 key moments of joint angles. <br>• A hand or foot can be sent to a point instead (two-bone reach): the hands hold the bar, the feet stay on the leg-press platform. <br>• One joint is anchored: the ankle standing, the hip seated, the hand on a pull-up bar, the toes in a push-up. <br>• Moves ease in and out. <br>• Side view, or front view for the lateral raise, rear delt fly and cable fly. |
| D3 | **The 30 lifts:** two or three per movement pattern. Each key moment carries the index of the library's own written cue, so its chip is numbered as that step. <br>**12 close variants** share a demo with one line saying what differs (chin-up: "Palms facing you."). They are listed one by one, never guessed. |
| D4 | **Where it shows:** <br>• on the exercise's page, above "How to do it"; <br>• from a play icon beside each exercise's name during a workout, in a sheet with the cues, without leaving the session; <br>• as a play mark in the exercise list. |
| D5 | **How it plays:** three loops, then it rests on the start with Play. That saves battery, keeps it from distracting while the cues are read, and lets the app's tests settle. <br>Tap pauses. Slow plays at half speed. A key moment's chip shows that moment still. <br>With Android's Remove animations on, it never loops: the key moments are still pictures. |
| D6 | **Checked:** <br>• every lift and variant is in the library; <br>• the cues are in order, each used once; <br>• no joint goes below the floor; <br>• bones keep their length; <br>• reached hands and feet arrive within 1 cm; <br>• standing feet stay planted, and the squat's, deadlift's and press's bar travels straight. <br>**Goldens:** a picture of every lift's key moments, generated on Linux Flutter 3.47.8 (CI's pin) and identical on the Windows host. This starts E20. |

## Home-screen widgets

| # | Decision |
|---|---|
| W1 | **Four widgets,** Android `AppWidgetProvider` + `RemoteViews` (Kotlin, no new library): <br>• **Food left** (2×2): a ring of calories eaten against the target, with calories and protein left; <br>• **Today's training** (4×1): today's workout or planned run, or rest, with Start; <br>• **Streak** (3×2): the count and this week, coloured like Streak & rewards; <br>• **Quick actions** (4×1): Log food, Workout, Run, Weight. <br>They follow the phone's light or dark mode; trained is blue and rest green. |
| W2 | **A snapshot, already worded.** The app writes JSON to its shared preferences (`widgets.snapshot`) a second after anything it shows changes, then asks the widgets to redraw. It is written by the pure `WidgetSnapshot` and `homeWidgetsCoordinatorProvider`, on Android only. <br>The snapshot holds: <br>• today's food, as Nutrition words it; <br>• the next 7 days (a run on its date wins, else the programme's weekday, rest, or no plan); <br>• the streak's last 14 days. |
| W3 | **Midnight without the app.** The widgets pick today from the snapshot: the week's entry, and a full "food left" from the targets. The streak says "Log today to keep it". An inexact alarm just past midnight redraws them (no exact-alarm permission). So do clock and time-zone changes, and Android's hourly update. |
| W4 | **Taps open, never start.** `fitos://widget/<target>` to MainActivity (`singleTop`): <br>• the link FITOS opened from is taken once; <br>• later ones are sent while it runs. <br>Each target opens a screen: <br>• food opens Log food for the meal of the hour; <br>• workout and run open Training on that tab; <br>• training picks the tab by today's plan; <br>• weight opens the quick weigh-in; <br>• streak opens Streak & rewards. |
| W5 | **Privacy.** The widgets show only what is already on the phone, to whoever sees the home screen. Signed out, they say so and show nothing. Nothing new is collected or sent, so the policy is unchanged. Privacy & data says what they show and how to hide them. |

## Release

APK 1.0.0-beta.5.0 (build 29): a full release, because the widget code is native. The API is unchanged.
