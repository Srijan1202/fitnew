# ADR-026 — The beta app: package `me.tryfitos.app`, Play signing, crash reports on by default, in-app feedback, a minimum-build gate

**Status:** PROPOSED. Owner decisions 2026-10-22; built on `phase-19`. Becomes ACCEPTED with Phase 19's acceptance (PLAY.md step 8).
**Date:** 2026-10-22
**Phase:** 19 (beta)
**Affects:**
- MASTER-SPEC §31 Phase 19 (Play internal testing, Crashlytics, feedback channel), §23 (the privacy policy: version 2026-10-22.2), §9.2 (`feedback`), §10.1 (`/feedback`, `/admin/feedback`, `/meta/config.minimumBuild`);
- BACKLOG E1 (minimum app version: done) and E18 (flags read by the app: the provider exists, nothing switched on them yet).

---

## Context

**§31 Phase 19 asks for:**
- Play Store internal testing;
- Crashlytics;
- a feedback channel;
- for acceptance, an installable build and a crash-free rate above 99% over one week with 20 real users.

**What the app had:**
- It still carried Flutter's placeholder package `com.example.fitos`, which Google Play refuses.
- Release builds were signed with the debug key.
- There was no crash reporting.
- There was no way for testers to send feedback.
- The app never read `/meta/config`.

## Owner decisions (2026-10-22)

1. Package name **`me.tryfitos.app`**, from the owned domain `tryfitos.me`.
2. Crash reports **on by default**, with an off switch in Privacy & data and a policy update.
3. Feedback through an **in-app form, read in the admin panel**.

## Decisions

| # | Decision |
|---|---|
| D1 | **`me.tryfitos.app`** is both the Android namespace and the applicationId. The Kotlin sources move with it; the method channels (`fitos/...`) don't depend on it. iOS gets the same bundle id; iOS is not shipped (ADR-003). The new name has to be registered in Firebase with its SHA-1s (PLAY.md step 2). The old `com.example.fitos` app stays registered until no old build is in use. |
| D2 | **Signing:** `android/key.properties` (gitignored) names the owner's upload keystore, which lives outside the repo. Without it a release build falls back to the debug key, so LAN and hosted APKs keep working. `hosted.ps1 -AppBundle` refuses to build a Play bundle without it. Google holds the app signing key (Play App Signing). |
| D3 | **Crashlytics:** collection is off in the manifest until `main()` applies the user's choice, which is kept on the phone and on unless turned off. Turning it off also deletes unsent reports. Debug builds never report. No user id and no custom keys are set, so a report carries the error, the stack, the version and the device model only. A `CrashReporter` seam keeps tests off the platform. The policy (doc and app text, kept in step by a test) gains a "Crash reports" section; its version becomes `2026-10-22.2`, so everyone re-accepts once. |
| D4 | **Feedback:** migration 0021 `feedback` holds the category, a message of up to 2000 characters, the app version and a status. The user owns it through CASCADE, so it is exported and deleted with the account. `POST /v1/feedback` allows 5 an hour per user. `GET /v1/admin/feedback` and `PATCH /v1/admin/feedback/{id}` are for admins only, checked before validation, and status changes are audited. The admin panel's Feedback page lists them. The sender is shown as an id only; the audited Support lookup finds them. |
| D5 | **Minimum build (E1):** `/meta/config` gains `minimumBuild`, set from `MIN_APP_BUILD` (default 0, which asks nothing). If the app's build number (`package_info_plus`) is below it, the app shows only "Update FITOS". Unknown (offline, loading) never blocks. `flagOn()` reads the same config for E18. |
| D6 | **The policy describes the beta:** AWS hosting in India, HTTPS only, one day of database backups, feedback, crash reports. |

## Consequences

**Good:**
- Play-ready.
- Testers can report problems.
- Crashes are visible, which the §31 crash-free target needs.
- An old build can be stopped without a new app.

**Bad / accepted:**
- **One-time owner work:** a new Firebase app registration and SHA-1s. Until it's done, Google sign-in fails on new builds.
- **A fresh install:** a phone with the old `com.example.fitos` app installs the new one beside it. Its local data does not carry over; the server data does.
- **Re-consent:** everyone re-accepts the policy once.
- **The Crashlytics Gradle plugin is not applied:** Dart stack traces are readable as they are, but release Java/Kotlin traces aren't de-obfuscated. Add the plugin if R8 obfuscation is turned on.

## Not in this decision

- The store listing (screenshots, description; Phase 20).
- A public privacy policy URL (PLAY.md step 4 hosts it on tryfitos.me's existing GitHub Pages site).
- Server push (O9).
