# ADR-040 — App updates (beta 4.1): Shorebird code push, and FITOS installing its own APK

**Status:** PROPOSED. The owner asked for "a mixture of both" and answered the plan's questions (`docs/phase-plans/beta-4.1-updates-plan.md`) on 2026-10-28. Built on `phase-19`. Becomes ACCEPTED after the field check on the S24 (below) and the owner's acceptance of beta 4.1.
**Date:** 2026-10-28
**Phase:** 19 (beta 4.1)
**Affects:**
- ADR-026 (the update check: version.json now names the APK);
- MASTER-SPEC §23 (the policy names Shorebird, version `2026-10-28.1`);
- the Android manifest (`REQUEST_INSTALL_PACKAGES`, a FileProvider);
- `tool/hosted.ps1`, `tool/patch.ps1`, `tool/shorebird.sh`, `scripts/update-kind.mjs`.

---

## Context

Each beta so far meant: download the APK from the website, open it and install it. A one-line Dart fix (4.0.1's Start button) cost every tester that round trip.

## Decisions

| # | Decision |
|---|---|
| D1 | **Dart-only fixes are Shorebird patches.** FITOS is built as a Shorebird release. On each start the app asks Shorebird for a patch, downloads it in the background, and runs it on the next start, so code never changes mid-run or mid-workout. A patch keeps the version and build number, so the patch number appears next to the version in Profile and in every feedback report ("1.0.0-beta.4.1+18 patch 2"). Shorebird signs patches with a key it manages for the account (its default), and the app installs only patches signed with it. |
| D2 | **What a patch cannot carry gets a full APK**, per Shorebird: native code, a plugin, permissions, Gradle, assets, or a new Flutter version. `scripts/update-kind.mjs <release tag>` decides from git: anything under `android/`, `pubspec.yaml`/`.lock`, `assets/` or `shorebird.yaml`, or a changed CI Flutter pin, needs an APK. Dart under `lib/` alone is a patch, and anything else needs neither. It is tested on sample diffs in ci-core. `tool/patch.ps1` refuses when it says APK, and Shorebird itself refuses a patch with native or asset changes. |
| D3 | **Shorebird builds run in WSL** (Windows Smart App Control blocks the CLI). `tool/hosted.ps1 -Shorebird` and `tool/patch.ps1` run `tool/shorebird.sh`. It builds a **committed** SHA only, never the working tree, in a clean clone on WSL's own disk, with CI's Flutter pin, so a release and its patches build from the code they claim. The dart-defines go in the environment (WSLENV), never in a file. The secret scan still runs on the release APK. |
| D4 | **The same signing key.** Every hosted APK so far is signed with this PC's debug key (no `key.properties` yet). Android installs an update only with the same signature, so the WSL build uses that keystore, copied into WSL's own `~/.android`. With an upload key (`key.properties`) the Shorebird build refuses, until its signing is set up there too. |
| D5 | **Everything else: "Update now" installs FITOS's own APK.** version.json gains `apkUrl`, `sha256` and `sizeBytes`. The app downloads only from `https://tryfitos.me/…apk` into its cache's `updates/`, with progress and Cancel. It checks the SHA-256 against version.json's, throws away a file that does not match, and hands the file to Android's installer through FITOS's own FileProvider (its own class, so it never clashes with a plugin's). The tester taps Update once; Android requires that. The first time, FITOS says why it needs "Install unknown apps", opens that settings page, and carries on when the tester comes back. Any failure offers the download page. An older version.json, or a phone that is not Android, keeps the page. |
| D6 | **Privacy.** On each start Shorebird is sent the app id, the release version, the patch number, the phone type and a random id for the install; nothing about the user. Shorebird keeps the network address in its logs for a limited time. The policy names Shorebird and the in-app download from tryfitos.me; its version becomes `2026-10-28.1`, so everyone accepts once. |

## Consequences

- 4.1 itself is installed the old way, once; it is the first build with both paths.
- Shorebird's free plan allows 5,000 patch installs a month; six testers taking ten patches a month use 60.
- **Field check on the S24 before acceptance:**
  1. install 4.1 from the download page;
  2. a harmless patch (a label) arrives on the second start;
  3. a 4.1.1 APK installs over 4.1 through **Update now**, keeping all data.
