# Beta 4.1 — plan, part 1: updates without the download page

**Date** 2026-10-28 · **Branch** `phase-19` · **Status:** the owner answered on 2026-10-28 (the table below). It ships **with beta 4.1**; no code before the owner's go on 4.1.

**The owner's brief (2026-10-28):** "a mixture of both". Shorebird code push for what it can do, and FITOS installing its own APK for what it can't.

## The owner's answers (2026-10-28)

| Question | Answer |
|---|---|
| When | **Together with 4.1.** 4.1 itself installs the old way, once. |
| A downloaded patch | **Applied quietly the next time FITOS is opened.** Never mid-workout or mid-run: Shorebird only swaps code on a fresh start. |
| The Shorebird CLI | **I install it.** Done 2026-10-28 without changing the PowerShell execution policy or the PATH: Shorebird's official repo is cloned to `%USERPROFILE%\.shorebird`, and the build scripts call `shorebird.bat` by its full path. |

## Today

FITOS reads `tryfitos.me/version.json`. When a newer build is out, it shows "Beta N is out → Download" and opens the download page in the browser. The tester then downloads the APK, opens it and installs it.

## What changes

### U1 — Code push (Shorebird) for Dart-only changes

- **What it is:** FITOS is built as a Shorebird *release*. A fix that only touches Dart code (screens, logic, text) then goes out as a *patch*. The app downloads it in the background on start and runs it the next time it is opened. There is no APK and no install prompt. 4.0.1's Start-button fix would have been a patch.
- **What a patch cannot carry** (Shorebird's own FAQ):
  - native code (Kotlin, for example MainActivity);
  - new plugins with native code, such as 4.0's GPS and map;
  - Android permissions and Gradle settings;
  - a new Flutter version;
  - assets (fonts, images).

  Those go out as a full APK through U2.
- **Builds:**
  - `tool/hosted.ps1` builds through `shorebird release android --artifact apk --target-platform android-arm64 --flutter-version 3.47.2 -- <the same dart-defines>`. A new `tool/patch.ps1` runs `shorebird patch android` against that release.
  - The hosted-URL rules, the secret scan and the APK name stay as they are.
  - `shorebird.yaml` holds the app id. It is not a secret; it is committed like `firebase_options.dart`.
- **Which way each fix goes:** I decide at release. If anything under `android/`, `pubspec.yaml`, assets or the Flutter version changed since the Shorebird release, it is a full APK; otherwise a patch. The release message says which.
- **A patch never changes the version number.** It is "4.1 patch 1, 2…". The app's About line shows the patch number, so a bug report says what the tester runs.
- **Privacy:** on each start the app asks Shorebird's servers whether a patch exists. Shorebird says it sends the app id, the release version, the patch number, the phone type (arm64, Android) and a random id per install. It sends no account, health or device ids, and its own logs keep the network address for a limited time. The policy names Shorebird, and its version becomes `2026-10-28.1` (everyone accepts once).
- **The free plan** allows 5,000 patch installs a month (shorebird.dev/pricing). Six testers taking ten patches a month is 60.

### U2 — FITOS installs its own APK for everything else

- **The update dialog** gets **Update now**. The download page stays as a fallback when anything fails.
- **The download:**
  - FITOS downloads the APK from tryfitos.me inside the app, with a progress bar and Cancel.
  - It checks the SHA-256 against the one `version.json` now also carries (with the file and size), and throws away a file that doesn't match.
  - Then it opens Android's installer, where the tester taps **Update** once.
  - The first time, Android asks to allow FITOS to install apps. FITOS explains why first and opens the right settings page.
- **Android rules:** an update always needs that one tap, and only a store can skip it. It must be signed with the same key, which every FITOS build already is.
- **Pieces:**
  - the `REQUEST_INSTALL_PACKAGES` permission (fine outside Play);
  - a FileProvider for the downloaded file in the app's cache;
  - a small channel method in MainActivity that hands the file to the installer;
  - the website's `version.json` gains `apkUrl`, `sha256` and `sizeBytes`.

### Together

4.1 is the first build with both, so it is installed the old way, once. After that:
- a Dart fix arrives by itself;
- anything native comes as an in-app **Update now**, followed by Android's one tap.

## Tests and checks

- The update flow is unit- and widget-tested:
  - a matching and a non-matching SHA-256;
  - a cancelled download;
  - permission not yet granted;
  - falling back to the page.
- The script deciding patch or APK is tested on sample diffs.
- **Field check on the S24:**
    1. install 4.1 from the page;
  2. I push a harmless patch (a version label) and it arrives on the second start;
  3. I publish a 4.1.1 APK and **Update now** installs it over 4.1, keeping all data.

## What the owner does

1. **Create a Shorebird account** (free) at shorebird.dev with your email. FITOS never creates accounts.
2. ~~Install the Shorebird CLI~~: done (see the answers above).
3. **Run `& "$HOME\.shorebird\bin\shorebird.bat" login`** in your own PowerShell. It opens the browser. The login stays on this PC and never goes into chat or git.
4. Then I run `shorebird init` (it writes `shorebird.yaml`) and build.

