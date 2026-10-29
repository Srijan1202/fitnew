# ADR-043 — Beta 4.3: a release signing key (by rotation), and one page for every reward

**Status:** PROPOSED. Owner, 2026-10-29: do the signing key first (option 2, of Play closed testing or a release key, sideloaded), plus a page for every reward, "together in 4.3". Built on `phase-19`. Becomes ACCEPTED with the owner's acceptance of beta 4.3.
**Date:** 2026-10-29
**Phase:** 19 (beta 4.3)
**Affects:**
- ADR-040 D4 (every hosted APK signed with this PC's debug key);
- `tool/hosted.ps1`; a new `tool/signing.ps1`;
- the rewards (beta 3.4, ADR-042).

---

## Context

Google Play Protect scans every FITOS update, and it trusts an APK signed with an Android debug key least. A new key normally means every tester uninstalls and reinstalls, which loses what is only on the phone (progress photos, their own sessions, anything not synced).

## Decisions

| # | Decision |
|---|---|
| D1 | **A release key by rotation, not by reinstall.** `tool/signing.ps1 -Create` made FITOS's release key (PKCS12, RSA 4096, alias `fitos`, 30 years). It also made a signed proof of rotation (`lineage.bin`) from the debug key to it. Both, and the random password, live outside the repository in `%USERPROFILE%\.fitos\signing`, never in git, the APK or a log. |
| D2 | **Every hosted APK is signed with both** (`tool/hosted.ps1`, after the build, before the secret scan). v2 and v3 (Android 7–12) stay with the debug key. v3.1 (Android 13+) uses the release key with the lineage: apksigner's default rotation level, Google's recommended one. So an update installs over every earlier FITOS, keeps the phone's data, and Update now works as before. The build stops if the APK does not verify with the release key in v3. |
| D3 | **Backups are the owner's.** The signing folder and `~\.android\debug.keystore` must be kept safe together (a password manager or an encrypted drive): without them no update can be installed over FITOS again. The debug key is still needed, for older Android and the lineage. |
| D4 | **Shorebird patches are unaffected.** They are signed by Shorebird's own patch key and are not installs. Moving to Google Play later can enrol this release key in Play App Signing. |
| D5 | **One page for every reward** (Profile → Rewards), replacing the streak-rewards sheet: |
| | • **Streak:** each reward, earned, or the streak that unlocks it and how many days past the best streak, with a bar. |
| | • **Running:** each distance badge and what it unlocks, earned with its date, or the distance and how far past the longest run, with a bar. The longest run is a new field of `GET /running/records` (`longestM`). |
| | • **Premium:** the icons, themes, pictures and the AI coach, "Yours with Premium" or "With Premium" and the Premium sheet. |
| | • **Above:** "x of y earned". Nothing ever says "lost". |

## Consequences

- **4.3 is build 21, an APK.** The API deploys first, for `longestM`; 4.2 phones ignore the field. The first 4.3 is published without the announcement, until the S24 confirms Update now installs it over 4.2 and keeps the data. Then it is announced.
- **Play Protect** may still ask about a sideloaded app, but no longer about a debug-signed one on Android 13+. Ending the scans needs Google Play (the owner's option 1: a one-time US$25).
