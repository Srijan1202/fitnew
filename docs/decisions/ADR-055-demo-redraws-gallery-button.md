# ADR-055 — Beta 5.6: 62 demos redrawn from the owner's notes; Gallery inside the Snap a meal camera

**Status:** PROPOSED. Owner, 2026-11-04: "next 5.6 is correcting the demos exercises i just checked", the 62 notes from the admin panel, "check and correct all then add them to waiting i will check again and approve", and the Snap a meal note below. Becomes ACCEPTED when the owner has re-checked the demos in the panel and checked the camera on the phone.
**Date:** 2026-11-04
**Phase:** 19 (beta 5.6)
**Builds on:** ADR-050 (the rig), ADR-051 (approvals), ADR-054 (Snap a meal).

---

## Snap a meal

| # | Decision |
|---|---|
| G1 | Owner: "if someone wants to add from the gallery from the start there will be one useless API call". The in-app camera opened by Snap a meal has a **Gallery** button left of the shutter. A gallery photo returns straight to Snap a meal, so no camera photo is taken or read first. If nothing is chosen there, the camera stays open. |
| G2 | The camera is unchanged for the progress photo and feedback screenshots: the button appears only when the caller passes a gallery. |

## The demos

| # | Decision |
|---|---|
| D1 | **Every noted demo is redrawn**: 62 slugs, each with a `Beta 5.6 (owner: …)` comment quoting the note it answers. Approved demos are untouched; their goldens did not change. |
| D2 | **Additions to the rig:** <br>• `Lever`: a machine arm from its pivot to the joint moving it. Chest press, shoulder press, row, preacher curl, triceps extension, lateral raise, pec deck, reverse pec deck, hip abduction, crunch. <br>• `Sled`: a back pad riding with the body (the hack squat). <br>• `Hang`: a plate on a chain from the hips (the belt squat). <br>• `Link.plate`: the landmine's loaded sleeve. <br>• `Link.over`: a band drawn in front of the body (pull-apart, Pallof press). <br>• `AngleMark`: a labelled angle (the floor press's 45°). <br>• `Platform.atToe`: the leg press calf raise's platform keeps its angle and slides. <br>• `Dumbbells.across`: the Arnold press's dumbbells from the front. <br>• `Demo.floor: false`: views from above. <br>• `Pose.twist`: the shoulders turning (Russian twist, woodchopper). <br>• `Pose.thighScaleFar`: one knee stepping toward you (suitcase carry). <br>• Front-view feet can stay planted while the thighs shorten (sumo squat, sumo deadlift, belt squat). <br>• A turned figure is framed as it is (the side plank fills the box). |
| D3 | **Views changed as the owner asked:** <br>• the dumbbell fly, incline fly and floor press are seen from above, on a visible bench (the floor press on the floor, with "45°" between the body and the upper arm); <br>• the Arnold press and the belt squat are seen from the front. |
| D4 | **Pace:** where the note asked for slower and controlled reps, the lowering takes about twice as long as the lift (about 2 s, against 1.2 s). The loop's return to the start is no longer a 0.3 s snap. |
| D5 | **Back to Waiting:** migration **0045** deletes the rejection of each of the 62 slugs, so each shows under Waiting again. An approved row, or any other slug, is not touched. The notes stay in the audit log (`demo.unapprove`). Down changes nothing. |
| D6 | The admin panel's previews (`apps/admin/public/demos`) are exported again from the app's own painter, with the app's font for the 45° label. |

## Beta 5.6.1: the second round

Owner, 2026-11-05: 43 of the 62 approved; 19 rejected again with new notes.

| # | Decision |
|---|---|
| E1 | **The 19 are redrawn again**, each with a `Beta 5.6.1 (owner: …)` comment quoting the new note. The 141 other demos are untouched; their goldens did not change. |
| E2 | **Machines look like machines:** <br>• a `WeightStack` (guide rods, plates, pulley); <br>• upholstery drawn lighter than the frame (`Line.pad`); <br>• a base along the floor and frames up to the pivots. <br>Shoulder press, row, crunch, preacher curl, triceps extension, lateral raise, pec deck and reverse pec deck use them. |
| E3 | **Machine arms beside the limb** (`Lever.side`): the preacher curl's and triceps extension's arm turns on a cam at the elbow and runs beside the forearm to the handle. The lateral raise presses a roller pad (`Lever.roller`) on the outside of each elbow, with the forearms pointing toward you. |
| E4 | **Views changed as the owner asked:** <br>• the suitcase carry is a walk seen from the side; <br>• the curtsy lunge is seen from the side, the only view where the back knee's 90° shows; the cue says "across"; <br>• the reverse pec deck faces the machine, with the chest pad and levers drawn in front of the body, so it no longer looks like the pec deck played backwards. |
| E5 | **Hands:** <br>• the sumo deadlift's arms hang straight; <br>• the Russian twist's hands stay together at chest height (front-view arm IK now uses the arms' foreshortened lengths); <br>• the woodchopper's arms stay straight, shorter as they come toward you (`Pose.straightArms`); <br>• the band pulldown's elbows drive down with the forearms upright. |
| E6 | **The rest:** <br>• the Arnold press's dumbbells turn end-on and back with the palms (`Pose.turn`); <br>• the pullover stops just past the head; <br>• the concentration curl stops before the knee; <br>• the upright row has a long bar with plates and a wider grip; <br>• the side plank keeps the elbow and feet on the floor, the hips lowering and lifting (`Pose.tilt`). |
| E7 | **Back to Waiting:** migration **0046** clears the rejection of each of the 19 only, as 0045 did. |
| E8 | **A text label is excluded from the goldens.** Beta 5.6's floor press golden failed on CI: the test font rasterizes differently on Linux than on Windows, where the goldens are made. The painter's `labels` is turned off in the golden test, and a separate test checks that the 45° label is painted. |

## Beta 5.6.2: the third round

Owner, 2026-11-05: 12 of the 19 approved; 7 rejected with new notes.

| # | Decision |
|---|---|
| F1 | **Band lat pulldown:** "do it in one movement". One smooth pull with no stop halfway. |
| F2 | **Cable woodchopper:** "going too much up". The chop starts with the hands by the head. |
| F3 | **Curtsy lunge:** "give front view". Back to the front view, now with the back knee bent to 90°: the thigh drops almost straight to a knee by the floor, and the shin points back and out (`Pose.shinScaleFar`). The back leg is drawn behind the body (`Demo.farLegBehind`). |
| F4 | **Dumbbell pullover:** "from head level to behind the head". It starts over the face, not the chest, and goes back until the arms are in line with the body. |
| F5 | **Machine crunch:** "the machine circle should be at the chest". The pad sits on the chest, and the machine arm runs from the hip axle to it. |
| F6 | **Machine row:** "connected to bottom; elbow should go back". The levers rise from a pivot at the foot of the machine and swing down and back to the waist, with the elbows well behind the body. |
| F7 | **Russian twist:** "the second hand is going weird". The arms turn with the shoulders as one piece, drawn where the turn puts them: the far elbow comes to the middle and the hands stay together (`Pose.elbows`). |
| F8 | **Back to Waiting:** migration **0047** clears only the rejections of these 7. |

## Release

- **API:** migration 0045. The owner runs `deploy.ps1`.
- **Admin:** the new previews. The owner runs `admin.ps1`.
- **App:** a Shorebird patch to 1.0.0-beta.5.3 (build 33). It is Dart only, and every icon is already in the release's font. 5.6.1 is a further patch on the same release.
- **5.6.1:** migration 0046 (`deploy.ps1`), the 19 previews (`admin.ps1`), the patch. Released 2026-11-05: API ec430d1, 5.3 patch 5.
- **5.6.2:** migration 0047, the 7 previews, the patch.
- **Then:** the owner re-checks the 62 in Admin → Content → Exercise demos. The app shows each one once it is approved.
