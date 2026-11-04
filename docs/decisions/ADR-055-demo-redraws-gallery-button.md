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

## Release

- **API:** migration 0045. The owner runs `deploy.ps1`.
- **Admin:** the new previews. The owner runs `admin.ps1`.
- **App:** a Shorebird patch to 1.0.0-beta.5.3 (build 33). It is Dart only, and every icon is already in the release's font.
- **Then:** the owner re-checks the 62 in Admin → Content → Exercise demos. The app shows each one once it is approved.
