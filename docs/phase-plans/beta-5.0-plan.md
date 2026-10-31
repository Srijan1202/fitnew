# Beta 5.0 plan: exercise demo animations and home-screen widgets

**Owner, 2026-10-31.** "Exercise demo animations for the ~30 most-used lifts" and "make some widgets for the app". Decisions taken with the owner:
- **Animations:** drawn by FITOS in code, no licensed or commissioned art.
- **Who gets them:** everyone.
- **Widgets:** Android home-screen widgets, all four proposed — Today: food left; Today's training; Streak; Quick actions.

**Status:** built 2026-10-31 after the owner's "go" (ADR-050); release awaits the owner.

**Shape:**
- APK 1.0.0-beta.5.0 (build 29), a full release: new native widget code.
- No API change and no migration expected.
- Website and blog.

---

## A. Exercise demo animations

### What you see

- **On an exercise's page,** above the cues: a looping animation of the lift.
  - A plain figure in the app's colours, seen from the side (from the front where that shows the lift better, such as a lateral raise).
  - It has the equipment: bar, dumbbells, bench, cable, pull-up bar, machine seat.
- **The tempo:** about 2 s down and 1 s up, with a short hold at the bottom of lifts where the cue asks for one.
- **Controls:**
  - Tap pauses it. "Slow" plays it at half speed.
  - A row of 2–4 numbered key moments (start, bottom, top), each tied to the matching written cue.
- **During a workout:** each exercise card gets a **How** button, which opens the animation and cues in a sheet without leaving the session.
- **In the exercise list:** a small play mark shows which lifts have a demo.
- **Reduce motion** (Android's "Remove animations"): shows the key moments as still pictures you step through, never a loop.

### Which 30

Two or three from every movement pattern, chosen for what the programme generator and beginners use most, across barbell, dumbbell, machine, cable and bodyweight.

| Pattern | Lifts |
|---|---|
| Squat | Barbell back squat · Goblet squat · Leg press |
| Hinge | Conventional deadlift · Romanian deadlift · Hip thrust |
| Lunge | Walking lunge · Bulgarian split squat |
| Horizontal push | Barbell bench press · Dumbbell bench press · Push-up |
| Vertical push | Overhead press · Seated dumbbell shoulder press |
| Horizontal pull | Barbell row · Dumbbell row · Seated cable row |
| Vertical pull | Pull-up · Lat pulldown |
| Arms | Dumbbell curl · Hammer curl · Triceps pushdown · Overhead triceps extension |
| Shoulders | Dumbbell lateral raise · Rear delt fly |
| Chest | Cable fly |
| Legs | Leg extension · Seated leg curl · Standing calf raise |
| Core | Plank · Hanging leg raise |

- **Close variants share a demo,** but only where the movement is the same and a short line says what differs. For example, kettlebell goblet squat uses the goblet squat ("hold a kettlebell by the horns"), and chin-up uses the pull-up ("palms facing you").
- **Variants are listed explicitly,** never guessed from the pattern. A lift without a demo shows its cues as today.

### How it is built

- **Pure Dart, no assets, no licences.**
  - A small rig: a head and capsules for the torso, upper and lower arms and legs.
  - It is posed by joint angles: hip, knee, ankle, shoulder, elbow and trunk lean.
  - Each lift is a list of keyframes plus its equipment, eased between frames.
  - It is drawn with a `CustomPainter` in the theme's ink and accent, so it follows Dark, Light, Cobalt and the rest.
- **The lifts are data** (`exercise_demos.dart`), keyed by the exercise slug. The cue each key moment belongs to is the instruction's index.
- **Checks:**
  - **Every demo is physically consistent:** bones keep their length, feet stay on the floor where they should, and the bar path is vertical for squats, deadlifts and presses within a tolerance.
  - **A golden image of each lift's key moments,** so a change to the rig is seen. This starts the deferred E20 goldens.
  - **Every slug in the table exists in `exercises.json`,** and every listed variant points at a demo.
- The animation is the app's own drawing, so it needs no licence and adds no download.

## B. Home-screen widgets

Four Android widgets, added from the phone's widget picker. They follow the phone's dark or light mode, and their accent is FITOS's.

| Widget | Size | Shows | Tap |
|---|---|---|---|
| **Food left** | 2×2, resizable | A ring of calories eaten against the target; calories and protein left today. "Logged at 1:20 pm" when it is stale | Opens Log food |
| **Today's training** | 4×1 / 4×2 | Today's workout (name, exercise count) or planned run (kind, distance), or "Rest day" | Starts that workout or run (the app opens on its start screen; nothing begins without a tap there) |
| **Streak** | 2×2 | The streak in days, the flame, and this week's seven days in the calendar's colours: blue trained, green rest, grey skipped, outline missed | Opens Streak & rewards |
| **Quick actions** | 4×1 | Four buttons: Log food · Start workout · Start run · Log weight | Each opens that screen |

### How it is built

- **The app writes a snapshot** whenever what a widget shows changes, then asks the widgets to redraw. Changes include a meal logged, a workout or run finished, the plan changed, the streak or the targets.
  - The snapshot is small JSON in the app's own storage: the date, targets, eaten, protein, the next 7 days of the plan, the streak and this week's days.
  - Native widgets (`AppWidgetProvider` with `RemoteViews`, Kotlin) draw from it. No new library is needed for the drawing.
- **The day rolls over without the app.** The snapshot holds the targets and the week's plan, so after midnight the widgets show the new day's training and a full "food left", worked out on the phone. An alarm at midnight redraws them.
- **Signed out:** the widgets say "Open FITOS to sign in" and show no data.
- **Taps go through a `fitos://` link** to the screen. They follow the same route as a notification tap (the app may be closed), and only the app's own widgets send them.
- **Privacy:** the widgets show on your home screen only what you add there. Nothing new is collected or sent, and nothing reaches the server, so the policy is unchanged. The settings page says the widgets show your figures on the home screen.

## C. Tests and checks

- Dart unit tests:
  - the demo rig (bone lengths, contact points, bar path);
  - the variant map;
  - the snapshot (day rollover, signed out, rest day, run day).
- Goldens: each demo's key moments, and the widget preview layouts.
- Widget tests: the exercise page and the How sheet, reduce motion, the play marks.
- The full app suite, `analyze --fatal-infos`, and CI.

## D. Release

1. **APK 1.0.0-beta.5.0 (29):** a Shorebird release with the native widget code and new keep rules if needed.
2. **The API is unchanged,** so no deploy.
3. **Website:** the download, a blog post with screenshots of the demos and widgets, and the features page.

**Field check:**
- the 30 demos play, and the variants say what differs;
- How works mid-workout;
- each widget shows the right figures and opens the right screen;
- the widgets turn over at midnight without opening FITOS.

## Not in 5.0

- Demos for the other ~140 lifts. The rig makes each one a few keyframes, so they can come in later betas, a pattern at a time.
- Lock-screen widgets, and a widget for the Galaxy Watch.
- Real-person video.
