# ADR-035 — Progress photos, on the phone only

**Status** Accepted by the owner on 2026-10-24 (beta 3.4 plan, F8) · **Date** 2026-10-24

## Context

Backlog F8. The owner chose: **free** for everyone, and kept **inside FITOS only**.

## Decisions

| # | Decision |
|---|---|
| D1 | **Never uploaded.** No server, no AI, no analytics, and not in the data export, which is the server's data. There is no API change. |
| D2 | **Where:** the app's private files, `getFilesDir()/progress_photos/<account>/`, as `<id>.jpg` plus an `index.json` (id, date, pose, file, the trend weight that day). It is **one folder per account**, so signing out, which wipes the local database, keeps the photos, and another account on the phone never sees them. **Deleting the account** deletes the folder. |
| D3 | **Out of Android's backup:** `fullBackupContent` (Android ≤ 11) and `dataExtractionRules` (Android 12+: cloud backup and device transfer) exclude `progress_photos/`. Until now the app had no backup rules. The workout and food databases are still backed up as Android's default; that is unchanged and is a separate decision if wanted. |
| D4 | **Taking a photo:** `image_picker` 1.2.4, from the camera or the gallery, resized to at most 1600 px at JPEG quality 85 (about 300–500 KB). Then a pose (Front, Side, Back, Other) and the day (today by default, up to 3 years back). The trend weight on that day, or the latest within the week before it, is recorded from what Progress has loaded; it is never typed. |
| D5 | **Seeing them:** <br>• Progress → **Photos** shows the newest, **Add photo**, and **See all · Compare**; <br>• the grid filters by pose; <br>• a photo opens full screen with **Save or share** (the phone's share sheet) and **Delete**; <br>• **Compare** puts two photos side by side (by default the oldest and newest of the most-photographed pose, and either can be swapped), with "N days apart · ±x kg". A **slider** overlays one on the other. |
| D6 | **The screen says it plainly:** "Photos stay on this phone. Uninstalling FITOS or changing phones loses them; save any photo to keep it." |
| D7 | **Behind the `progress-photos` switch** (ADR-033): the section hides when it is off. Photos already taken stay on the phone. |
| D8 | **Privacy policy:** progress photos stay on your phone, are never uploaded (not even to a backup), and are deleted with your account. |

## Consequences

- No storage cost and no new personal data on the server.
- Losing the phone loses the photos. That is accepted and stated on the screen.
