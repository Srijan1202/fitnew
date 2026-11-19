# Upkeep plan — Flutter packages (A7) and old database snapshots

**Status:** Accepted 2026-11-19. The owner took both recommendations (see the end).

## 1. Flutter package updates (A7)

The rule: a version is used only once it is two weeks old. 6.4 skipped A7 because of it. Three updates are already two weeks old, but they must move together with Riverpod, so the work starts on 30 November.

### Round 1, from 2026-11-30: minor updates, no breaking changes

| Packages | Out | Two weeks old |
|---|---|---|
| freezed 4.0.3, build_runner 2.17.1, geolocator 14.1.2 | 14–19 Oct | already |
| riverpod / flutter_riverpod 3.5.0, riverpod_annotation 4.0.8, riverpod_generator 4.0.10, riverpod_lint 3.2.0 | 6 Nov | 20 Nov |
| drift 2.35.4, drift_dev 2.35.3, sqlite3 3.9.1 | 8 Nov | 22 Nov |
| go_router 18.1.4, synchronized 3.6.1+1 | 9 Nov | 23 Nov |
| archive 4.7.1, image 4.13.1 | 13–14 Nov | 28 Nov |
| firebase_auth 7.1.0, firebase_core 5.2.0, firebase_crashlytics 6.1.0, firebase_messaging 17.1.0, material_ui 1.11.1 | 16 Nov | **30 Nov** |

### Round 2, from 2026-12-02: two updates with breaking changes

- **flutter_local_notifications 22.3.3 → 23.0.3** (23.0.3 is out 18 Nov, so two weeks old on 2 Dec).
  - 23.0.0 needs the Android Gradle Plugin 9.1.1 (FITOS is on 9.1.0) and compileSdk 37 (FITOS uses Flutter's default, 36). Install Android 37 in the Windows SDK and the WSL SDK (`~/sdk/android`).
  - This package runs the rest timer on the lock screen, the reminders and snooze. Those get an S24 check.
- **maplibre_gl 0.27.1 → 0.28.0** (out 3 Nov, already two weeks old).
  - The engine moves to MapLibre Android 13.7. Error codes change, some calls that did nothing now throw, and `setLayerFilter` now throws instead of returning false.
  - Check the run map's error handling against the migration guide.

### Not moving

Major updates that other packages do not allow yet stay where they are: qr 4, built_collection 6, package_config 3, cli_util 0.6, cross_file 0.4. All of them are pulled in by other packages, so nothing needs doing.

### Checks for each round

1. `build_runner` regenerates the generated code.
2. `flutter analyze --fatal-infos`, `dart format`, and every app test.
3. Compile the Kotlin in WSL (`:app:compileReleaseKotlin`).
4. CI green.
5. One commit and push per group of packages.

### How it ships

Firebase, sqlite3, MapLibre and the notifications package all carry Android code. Shorebird patches only replace Dart code, so these updates need a **full APK**, not a patch.

## 2. Old database snapshots

The privacy policy (2026-11-11) promises that a snapshot is deleted within 30 days:

| Snapshot | Taken | Delete by |
|---|---|---|
| `fitos-beta-pre-6-2-20261111` (baseline) | 2026-11-11 | 2026-12-11 |
| `fitos-beta-pre-0a6a355-…` (6.2 release) | 2026-11-11 | 2026-12-11 |
| `fitos-beta-pre-3c557c9-…` (6.3 release) | 2026-11-14 | 2026-12-14 |

`scripts/aws/deploy.ps1` keeps the newest 3 snapshots and deletes any older than 30 days, but only when it runs, which is during a server deploy. 6.4 had no server deploy. If none happens before these dates, the snapshots would stay longer than the policy allows.

**Proposal:** `scripts/aws/snapshots.ps1` applies the same rule without deploying anything.
- It lists what it would delete, then deletes only after a yes. Deleting a snapshot cannot be undone.
- Run it on about **2026-12-08**, after the owner signs in with `aws login`.
- The snapshot list could not be checked on 2026-11-18 because the AWS sign-in had expired. Confirm the list before deleting anything.

## Owner's answers (2026-11-19)

1. **The package updates ship inside 6.5's full APK.** Each update is committed on `phase-19` as soon as it is two weeks old. Two of them already were on 2026-11-19, so they go first:
   - geolocator 14.1.2, out of round 1;
   - maplibre_gl 0.28.0, out of round 2.
2. **`snapshots.ps1` added** (93697c6). The rule lives in `common.ps1` as `Get-OldSnapshots`, shared with `deploy.ps1`. Run it on about 2026-12-08: on its own it lists the snapshots and marks the ones to delete, and `-Delete` deletes them after the owner's yes.
