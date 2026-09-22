# FITOS closed alpha — known issues

Carried forward from Gate 6 into Gate 7 (Phase 6.6). Each entry says what
happens, how bad it is, whether it blocks closed-alpha use, and what is
known about the cause. Nothing here is marked fixed until it has been
verified on the Samsung S24.

| # | Issue | Severity | Blocks alpha? | Status |
|---|---|---|---|---|
| KI-1 | Health Connect **Connect** button crashes FITOS on the S24 | High | No — "Manage permissions" is a working path | **UNRESOLVED** |
| KI-2 | The backend address is compiled into the APK; the PC's LAN address changes between networks | Medium | No — rebuild on the current network | Mitigated, by design for LAN alpha |
| KI-3 | Gemini free tier: 20 requests/day/model | Medium | Partly — AI testing is rationed | Open (needs a paid tier) |
| KI-4 | `com.example.fitos` application id and debug-key signing | Low for alpha | No | Accepted for closed alpha |
| KI-5 | The release-mode (R8) APK has not yet been run on a device | Medium | Unknown until B/A1 on the S24 | Open — Gate 7 check |

---

## KI-1 — Health Connect "Connect" crashes on the S24 (UNRESOLVED)

**Action:** FITOS → Profile → Health data → **Connect**.
**Expected:** the Android health-permission sheet opens; granting or
declining returns to FITOS, which shows Connected / Not connected.
**Actual:** FITOS closes immediately; Android shows its generic crash
dialog. **Reproducible:** yes, every time, on the S24 (Android 17 / API 37).
**Evidence:** no logcat captured yet.
**Workaround:** Health data → **Manage permissions** opens Health Connect,
where FITOS can be granted every permission; FITOS then reads the data.

**What was done.** Gate 6 (`d66d54b`) diagnosed a definite crash in this
path from the library bytecode: on API 34+,
`PermissionController.createRequestPermissionResultContract()` delegates
to `ActivityResultContracts.RequestMultiplePermissions`, whose intent
carries the sentinel action
`androidx.activity.result.contract.action.REQUEST_PERMISSIONS`; the channel
started that intent directly, which throws `ActivityNotFoundException`.
The fix moved `MainActivity` to `FlutterFragmentActivity` and launches
the contract through a registered `ActivityResultLauncher` in a
`try/catch`. That change compiles, is in the APK (verified in the dex),
and passes 16 regression tests — **but the owner reports the S24 still
crashes**, so either that was not the (only) cause, or a different
failure now occurs in the same flow. It must not be assumed fixed.

**Next step (needs the S24 on USB):**

```powershell
adb logcat -c
adb logcat -v time AndroidRuntime:E ActivityManager:W HealthConnectChannel:D flutter:E *:S
# reproduce: FITOS → Profile → Health data → Connect
```

The `FATAL EXCEPTION` block (exception class, message and the first
`at com.example.fitos…` / `at androidx.health…` frames) identifies the
cause. Also note whether the Health Connect sheet flashes before the
crash (after-return failure) or not at all (launch failure). No code
change is made to Health Connect in Gate 7 without that trace.

## KI-2 — The backend address is baked into the APK

The alpha build compiles `API_BASE_URL` (Dart) and the matching
cleartext exception (Android network-security config) from the PC's LAN
address **at build time**. This PC alternates between two networks
(`172.16.205.86` and `10.160.235.11` were both observed on 2026-09-22/23);
an APK built on one does not reach the PC on the other and every request
times out. Mitigations in place: `tool/alpha.ps1` refuses to build when
`/health` does not answer at the resolved address; the sign-in screen and
Profile show the compiled-in address; a failed request names the address
it could not reach. **Rule:** build on the network you will test on;
rebuild after switching.

## KI-3 — Gemini free-tier quota

`gemini-3.6-flash` on the free tier allows 20 requests per day per
project per model. A single chat turn can use 2–3 requests (tool rounds).
When exhausted, FITOS AI answers "busy right now" (429 mapped cleanly).
A paid tier is required before real alpha users (MASTER-SPEC §19.3).

## KI-4 — Application id and signing

`applicationId` is Flutter's placeholder `com.example.fitos`, and the
release-mode APK is signed with the debug keystore. Both are acceptable
for a closed alpha installed by hand; both must change before any store
distribution (Phase 19). Changing either now would require re-registering
the Android app and SHA-1 in Firebase (Google Sign-In) and would reset
Health Connect grants, so it is deliberately left as is.

## KI-5 — Release-mode APK untested on a device

Gate 7's APK is built with `-Release` (AOT, R8 shrinking, not
debuggable). It has been inspected (identity, version, permissions,
network config, compiled address, no secrets) but not yet run on the S24.
R8 renames classes; the Health Connect channel's wire name survives (it is
a string constant) but any reflection-dependent plugin could behave
differently from the debug build. Section B of the checklist is the
check; the debug APK remains the fallback.
