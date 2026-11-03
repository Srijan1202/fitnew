# ADR-051 — Beta 5.2: a demo for every lift, shown only once an admin approves it

**Status:** ACCEPTED 2026-11-03 (owner's check on the phone and in the panel). The owner approves the new demos in the panel as time allows. Proposed as: Owner, 2026-10-31: "Cable fly still not right rest are correct. Now make demo for all the rest. Make a section on admin website where i can approve each demo and after my approval only it will show on app", then: the 29 checked demos start approved, every new demo ships at once, preview and approval happen in the admin site, and the version is 5.2. Becomes ACCEPTED with the owner's check.
**Date:** 2026-10-31
**Phase:** 19 (beta 5.2)
**Builds on:** ADR-050 (the rig, the 30 demos, the checks).

---

## Approval

| # | Decision |
|---|---|
| A1 | **Nothing shows until approved.** `exercise_demo_approvals` (migration 0042) holds one row per demo slug: approved or withdrawn, by whom, when. No row means waiting. The 29 demos the owner passed on 5.1.1 are seeded approved; the cable fly is not, since it was redrawn. |
| A2 | **The app asks the server.** `GET /v1/exercises/demo-approvals` returns the approved slugs. The app keeps the last answer on the phone, so demos still show offline. It asks again when FITOS opens or comes back to the front. If it has never had an answer, it shows no demos. |
| A3 | **A variant follows its demo.** Approving the pull-up shows it for the chin-up too. Variants are not approved one by one. |
| A4 | **Where it applies:** the exercise's page, How during a workout, the play mark in the exercise list, and the Exercise demos page. Each shows approved demos only. |
| A5 | **The admin page.** Admin → Content → Exercise demos. Each demo plays as the app draws it (animated WebPs exported from the app's own painter by `tool/demo_frames/export_admin.py`), with its written steps and its variants. It has Approve and Withdraw buttons and Waiting, Approved and All tabs. `GET` and `PUT /v1/admin/exercise-demos[/:slug]`; each decision is audited as `demo.approve` or `demo.unapprove`. |

## Every lift

| # | Decision |
|---|---|
| L1 | **130 new demos** (`exercise_demos_more.dart`): every lift in the library now has its own demo or is one of the 12 variants. That makes 160 demos and 172 exercises. They are grouped by movement family and reuse the approved lifts' numbers where the movement is the same. |
| L2 | **The rig, extended** (no change to how the 29 approved demos look): <br>• the front view poses each side on its own (both feet and both hands can have their own targets), with angles or reach for the legs; <br>• foreshortening: a limb seen pointing toward you is drawn shorter (arms in the side and front views, thighs in the front view). This is how the cable fly, pec deck, Pallof press and flies show; <br>• `tilt` turns the whole figure (the side plank); <br>• new equipment: fixed lines (racks, machine frames, benches at an angle), bands, chains and cables to any joint, kettlebells and handles. <br>From the front, one dumbbell held in both hands is drawn once, and a one-hand weight in one hand. |
| L3 | **The cable fly, redrawn.** Seen from the front, the arms stay long and swing toward you and across, instead of folding at the elbow. |
| L4 | **Checked the same way as the first 30** (ADR-050 D6), for all 160: <br>• cues in order, each used once; <br>• nothing below the floor; <br>• bones keep their length; <br>• hands and feet reach their targets within 1 cm; <br>• a golden of each demo's key moments, generated on Linux and identical on Windows. <br>`tool/demo_frames/reach_test.dart` lists every moment that breaks a check, for tuning. |
| L5 | **Known weak spots,** left for the owner's call in the admin page: the curtsy lunge (the crossing leg reads as crossed legs), the Russian twist (seated from the front, the knees cover the body), and the Pallof press (the press toward you is foreshortened). A demo that does not read well can simply stay unapproved. |

## Release

- **API:** migration 0042 and the new routes. The owner runs `deploy.ps1`.
- **Admin:** the Exercise demos page and its WebPs. The owner runs `admin.ps1`.
- **APK:** 1.0.0-beta.5.2 (build 32), a new Shorebird release, as the owner chose.
- **Website:** release notes.
- **Order:** API first. Until the API is live, the new app shows no demos, because it has no approved list.
