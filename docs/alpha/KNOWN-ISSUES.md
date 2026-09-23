# FITOS closed alpha — known issues

Carried forward from Gate 6 into Gate 7 (Phase 6.6). Each entry says what
happens, how bad it is, whether it blocks closed-alpha use, and what is
known about the cause. Nothing here is marked fixed until it has been
verified on the Samsung S24.

| # | Issue | Severity | Blocks alpha? | Status |
|---|---|---|---|---|
| KI-1 | Health Connect **Connect** button crashes FITOS on the S24 | High | No — "Manage permissions" is a working path | **PASS on the S24** (owner, 2026-09-23) — fixed by `d66d54b` |
| KI-2 | The backend address is compiled into the APK; the PC's LAN address changes between networks | Medium | No — rebuild on the current network | Mitigated, by design for LAN alpha |
| KI-3 | Gemini free tier: 20 requests/day/model | Medium | Partly — AI testing is rationed | Open (needs a paid tier) |
| KI-4 | `com.example.fitos` application id and debug-key signing | Low for alpha | No | Accepted for closed alpha |
| KI-5 | The release-mode (R8) APK has not yet been run on a device | Medium | Unknown until B/A1 on the S24 | Open — Gate 7 check |
| KI-6 | Sessions finished "1 not synced" and reached History only after Retry | High | Yes — fixed, **S24 retest pending** | Fixed in code (Gate 7), see below |
| KI-7 | No way to edit personal details collected at onboarding | Medium | No | Implemented (Gate 7), **S24 retest pending** |
| KI-8 | Every new session refused: "A session is already in progress" (409), Retry never helps | High | Yes — fixed, **S24 retest pending** | Fixed in code (Gate 7), see below — the orphan was discarded on the S24 via the notice (01:07:31) |
| KI-9 | Queued sessions refused 404 "That day is not in your active programme" after the programme was replaced | High | Yes — fixed, **S24 retest pending** | Fixed in code (Gate 7), see below |
| KI-10 | After KI-9's fix: each old session one 404, then repeated 409 "A session is already in progress" — the phone's own newer session blocked them, and they blocked its completion | High | Yes — fixed, **S24 retest pending** | Fixed in code (Gate 7), see below |

---

## KI-10 — Old queued sessions and the phone's own newer session wait on each other (fixed in code; S24 retest pending)

**Seen on the S24 (API log 2026-09-23 01:43:51–01:45:46 UTC, APK `d362279`):**
per old session exactly **one** 404 then the ad-hoc resend (KI-9's fix
working) — and that resend, and every retry after it, → **409 "A session is
already in progress"**; five tries, parked; Retry repeats.

**Database:** the session holding the slot was **this phone's own**
`a0932540…` (Bro Split, started and synced normally); it was completed on the
phone at 01:43:23 but its `/complete` reached the server only at 01:45:43.
None of the old sessions was created — they are still on the phone.

**Cause — `SyncEngine._loop` (`sync_engine.dart`), two rules together:**
1. **Global queue order.** An entry was only sent when *no* earlier entry
   was pending, and a failed entry in backoff stopped the whole drain. The
   old starts had lower queue ids than `a0932540`'s completion, so the
   completion waited behind them.
2. **409 was a generic failure.** The old starts were refused because
   `a0932540` was still open on the server — which only that completion
   (queued behind them) could change. Circular wait → 5 attempts → park.

**Fix (Flutter only; the server's one-active-session rule unchanged):**
- Order is kept **within a session** (start → exercises → sets → completion),
  not across sessions: another session's pending entry no longer holds one
  back, and one session's backoff no longer stops the others.
- A queued **start is not sent while another of this phone's sessions is
  open on the server** (it has a server id and is in progress here, or its
  completion / discard is still queued). It waits — no attempt counted,
  never parked — and goes as soon as that session's close is acknowledged.
- A start refused (409) naming **one of this phone's own sessions** (its
  local view was behind) is the same wait, one request per sync pass at
  most. A 409 naming a session this phone does **not** know (KI-8's orphan)
  still fails, parks and shows the "Unfinished session on FITOS" notice.
- Nothing is marked synced unless the server accepted it; old sessions are
  never mapped onto a day of the new programme (they go ad-hoc, KI-9).

**Test:** `automatic_sync_test.dart` group "Gate 7 (S24, … 01:43–01:45 UTC)"
replays the S24 queue — on the previous engine it ends with all six old
entries parked after repeated refused starts; now: Y's completion, then per old
session one 404 → one 201 → sets → completion, zero 409s, nothing parked.

**On the S24 now:** install the new APK; if the "not synced · Retry" pill
shows, tap **Retry** once — the old sessions sync as ad-hoc sessions.

## KI-9 — A queued session names a day of a programme that was replaced (fixed in code; S24 retest pending)

**Seen on the S24 (API log 2026-09-23 01:07:32–01:11:09 UTC):** 70×
`POST /v1/training/sessions` → 404 "That day is not in your active
programme."; the newer sessions got 201 only at 01:11:32.

**Not a weekday mismatch.** ISO 1 = Monday … 7 = Sunday everywhere (DB
check 1–7, contract, API `isoDayOfWeek`, Dart `DateTime.weekday`); the
active programme (Bro Split `a72047b0`, since 00:37:46) has Wednesday = 3 =
Shoulders `3f85b5cb`, and starts with that day succeeded. The start body
names the day by **`programDayId`**, not a weekday.

**Cause:** sessions started 00:29–00:36 while **Upper / Lower** was the
active programme carry its day ids; they waited behind the orphan (409).
At 00:37:46 `from-template/bro-split` replaced the programme; when the
orphan was discarded (01:07:31) those starts reached the day check (which
runs before the active-session guard) → 404. The engine treated 404 as a
generic failure: 5 attempts, park, Retry repeats — delaying later sessions
and never delivering these workouts.

**Fix (Flutter only; server validation unchanged):** 404 maps to a
`NotFound` failure; a queued `start` refused as NotFound is resent **once
without `programDayId`** — an ad-hoc session (owner 8.6) keeping the phone's
own exercises, so its sets and completion replay; the rewritten payload is
stored. Never mapped onto another programme's day. History lists these as
ad-hoc "Session" entries.

**On the S24 now:** the stuck entries are still parked on the phone; after
installing the new APK tap **Retry** once — they sync as ad-hoc sessions.

## KI-8 — A session FITOS holds that the phone lost blocks every new one (fixed in code; S24 retest pending)

**Seen on the S24 (API log, 2026-09-23 00:33–00:36 UTC):** `POST /v1/training/sessions`
→ 409 "A session is already in progress" in bursts of five, again after
each Retry; `GET /v1/training/sessions/34dd254f…` 200 alongside.

**Database:** `34dd254f…` is **completed** (the phone fetches it because
`/today` names it as today's finished session). The session holding the
slot is **`a7ce5a4a-5908-4dca-ac40-eb50b28fd320`** (client id
`d5f83926…`), `status = active` since 2026-09-22 20:42 UTC, 5 live sets —
never completed or abandoned. The guard is the partial unique index
`one_active_session (user_id) WHERE status = 'active' AND deleted_at IS NULL`.

**How it was orphaned (API log, 2026-09-22 UTC):** 20:43:41 `a7ce5a4a` created
from the phone, its sets and 8 exercise edits synced; 20:43:46 a leftover
batch for the previous session failed (409) and the old APK waited for a
tap; **20:46:15 sign-out** — which wipes the phone's workout data *and its
sync queue*. No `/complete` or `/abandon` for `a7ce5a4a` was ever sent. The
server still has it active; the phone has no record of it.

**Why Retry cannot help:** each new session's `start` (its own client id)
meets the one-active-session rule → 409 → five attempts → parked; Retry
resets and repeats. The retry path is correct — it is not re-creating
`a7ce5a4a` — but the phone never looked at the server's `activeSession`
(Home and Start read only the phone's own), so it never learned what was
blocking it. The server guard is correct and unchanged.

**Fix:** (1) Home — and the Start button — show **"Unfinished session on
FITOS"** when `/today` names an active session this phone does not have:
name, start time, sets; **Finish it** (completed at its last set, into
History) or **Discard it** (abandoned), each confirmed — the user decides
(owner 8.5, sessions never end by themselves). Then the parked work is
re-sent and today / history / volume refresh. (2) **Sign-out** first tries
to sync; if anything is still unsynced it asks ("Stay signed in" / "Sign
out anyway") instead of silently deleting it.

**On your S24 now:** after installing the new APK, Home will show the
notice for `a7ce5a4a` (Pull · 5 sets, started 2026-09-23 02:12 IST). Choose
Finish or Discard; your newer sessions then sync by themselves.

## KI-6 — Workout sync needed Retry (fixed in code; S24 retest pending)

**Seen on the S24:** complete a session → summary → "1 not synced · Retry";
only after Retry did it reach History / Home; two sessions finished before
syncing both waited for Retry.

**Evidence (API logs, 2026-09-23):** every `DELETE /sets/<id>` → **422**
"Body cannot be empty when content-type is set to 'application/json'"
(sign-out's `DELETE /auth/session` too); then `POST /sets` → **409** "A set
already exists at that position" (5 attempts in a backoff pattern, then
parked); `POST /sets` → 409 "This session is completed" when the parked
batch was retried. Sessions with no removed or double-tapped sets synced
on their own.

**Root cause (four defects, one chain):**
1. Dio stamped `Content-Type: application/json` on body-less requests;
   Fastify rejects that, so **no DELETE ever succeeded**. A removed set
   stayed on the server.
2. Re-logging the freed slot (or a quick double tap) created a second live
   set at the same position → the server's `set_logs_live_position` rule
   → 409, retried then **parked** ("1 not synced").
3. After a backoff the engine waited for "the next kick" — a tap. After a
   session's last request there is none, so the queue sat until Retry.
4. `historyProvider` did not follow drains (today/volume did), so a
   session that did sync in the background still did not show in History
   or Home's week until a manual refresh.

A batch edited or removed *while on the wire* could also be lost / leave a
set on the server (a seal applied too late); fixed together.

**Fix:** body-less requests declare no content type; the engine wakes
itself after a backoff or an unreachable server (15 s doubling to 2 min);
one live set per slot on the phone (a double tap corrects the set); a
batch on the wire is sealed atomically, so edits/removals during flight
are queued behind it; History refreshes on every successful drain. Local
first is unchanged: offline, everything stays queued and syncs by itself.

**After installing the new APK:** tap Retry once if any old "not synced"
entries remain from the previous APK — they will now go through (their
DELETEs are sent correctly).

## KI-1 — Health Connect "Connect" crashes on the S24 (PASS on the S24 since `d66d54b`)

> **Update 2026-09-23:** the owner reports Connect now works on the S24.
> The entry below is kept as the record of the diagnosis.

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
