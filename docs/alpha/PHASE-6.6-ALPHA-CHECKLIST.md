# Phase 6.6 — Samsung Galaxy S24 alpha checklist

Owner-run, on the physical S24, against the PC's Docker API over Wi-Fi.
Setup: `docs/alpha/ALPHA-SETUP.md`. Mark each row ✅ / ❌ with a note;
anything ❌ blocks the gate it belongs to.

Before starting: `docker compose up --build -d api` is running; the phone
and the PC are on the same Wi-Fi; `apps/mobile/alpha.env` is filled;
`.\tool\alpha.ps1 -Install` succeeded and printed the `API_BASE_URL`.
Write the host it printed here: `http://__________:8080`.

## A. Gate 6 — integration (stack reachability)

| # | Do (on the S24) | Expect | ✅/❌ |
|---|---|---|---|
| A1 | Phone browser → `http://<host>:8080/health` | `{"status":"ok","uptimeSeconds":…,"database":{"reachable":true,…}}` | |
| A2 | Phone browser → `http://<host>:8080/v1/ai/status` | JSON error `UNAUTHENTICATED` (401) — the API is reachable and default-deny | |
| A3 | Open FITOS (fresh install) | Splash → sign-in screen; no "Firebase not configured" message. The line under the buttons reads `Backend <host>:8080` — **it must match the host in A1** (the address is compiled in; rebuild if it does not) | |
| A4 | Sign in with your **existing** account (Google or email) | Lands on Home (or the name prompt / onboarding step if the account is incomplete); no error | |
| A5 | Profile tab → bottom line | `FITOS 1.0.0-alpha.1 · alpha · <host>` — the same host as above | |
| A6 | Profile | Name, goal, targets shown (from `/user/profile` and `/user/goal` over the LAN) | |
| A7 | If asked for a name on Home: enter one → Save | Greeting shows the name; Profile shows it after a pull-to-refresh | |
| A8 | Home | Greeting + date; "Your next move" with your session; Today grid; no "Can't reach FITOS" notice | |
| A9 | Turn Wi-Fi off on the phone → Home → pull to refresh | No crash; Home keeps today's plan from the phone's cache. (The "Can't reach FITOS" notice appears only when nothing is cached yet — see B-F6.) | |
| A10 | Training tab | The week loads; open a day; exercises with target loads and reasons | |
| A11 | Start today's session → log 2 sets (tap-to-log) → Complete | Summary shows; History lists the session; sync pill shows synced | |
| A12 | Wi-Fi off → start a session → log a set → Wi-Fi on | The set is queued while offline (pill), then drains; History on the PC's DB has it (`docker compose exec postgres psql -U fitos -c "select count(*) from set_logs"` grows) | |
| A13 | AI tab | Empty state with the seven starter prompts (not "Not set up on this server yet") | |
| A14 | AI: "What should I do today?" | An answer from your real programme within ~10 s, with an action button | |
| A15 | AI: "How many steps did I take today?" | It says it cannot see Health Connect data and points to Home — never a number | |
| A16 | AI: "Build me a 3-day programme with more back work, 45 minutes each" | A proposal with structure / days / emphasis / any shortfall, and **Use this programme** — Training tab still shows the OLD programme | |
| A17 | Tap **Use this programme** → "Keep current" | Nothing changes (Training tab unchanged) | |
| A18 | Tap **Use this programme** → confirm | Plan opens with the new 3-day programme; Home's next move updates | |
| A19 | Force-stop FITOS → reopen | Still signed in, Home loads (Firebase session persisted) | |
| A20 | Sign out → sign back in | Works; data intact | |
| A21 | Profile → Health data → Connect → allow | Home shows steps (and sleep / weight if a source exists); AI (A15) still cannot see them | |
| A22 | New account: sign up with a fresh email | Onboarding starts with the name field; completing it generates a programme; Home greets by name | |

Quota note: the Gemini free tier allows **20 requests/day/model**; A14–A16
use about 6. Do not repeat AI rows more than needed.

### Gate 6 result (owner, 2026-09-23) — NOT fully accepted

| Area | Result |
|---|---|
| LAN API reachable from the S24 (`/health` in the phone browser) | ✅ |
| Firebase Google Sign-In | ✅ |
| `/v1/auth/session` bootstrap after sign-in | ✅ after the stale-address fix (`fbe053e`) |
| Corrected alpha APK | ✅ |
| Health Connect → **Manage permissions** → grant | ✅ |
| Health Connect → **Connect** | ❌ **crashes** — KI-1, unresolved after `d66d54b` |

The remaining A-rows are re-covered by section B below.

## B. Gate 7 — alpha APK + S24 acceptance

**The APK:** the release-like build (AOT, R8, not debuggable), built on the
network you test on:

```powershell
cd "D:\dev\fit new\apps\mobile"
.\tool\alpha.ps1 -Release -Install
```

(`adb install -r` replaces the debug build in place: same package, same
signing key, sign-in survives.) If a row fails only in the release APK,
re-run it with the debug APK (`.\tool\alpha.ps1 -Install`) and note both.

Result column: ✅ pass · ❌ fail (log it in section C) · ⚠ pass with a
note · — not run. **PC** means verified on the build PC, not the phone.

### B-A. APK / build

| # | Do | Expect | Result |
|---|---|---|---|
| A1 | `.\tool\alpha.ps1 -Release` | Prints `API_BASE_URL` and `/health 200 OK`, then builds `app-release.apk` | ✅ PC 2026-09-23 (`http://10.160.235.11:8080`, 64 MB) |
| A2 | Build with an unreachable host | Refuses before building (`/health did NOT answer…`), exit 1 | ✅ PC (`-ApiHostOverride 192.0.2.1`) |
| A3 | Build with a Firebase value missing / `API_HOST=10.0.2.2` | Refuses, naming the missing key / the unreachable alias | ✅ PC |
| A4 | Inspect the APK | `com.example.fitos` · `1.0.0-alpha.1` (2) · label FITOS · not debuggable · INTERNET + exactly 10 health READ permissions · base-config HTTPS-only, cleartext for the one host · Dart compiled to that host · no Gemini key / service account / private key inside | ✅ PC (aapt + byte scan) |
| A5 | Install on the S24 | Installs; launcher shows the FITOS icon and name; splash shows the FITOS mark | |
| A6 | Sign-in screen | Bottom line `Backend 10.160.235.11:8080 · FITOS 1.0.0-alpha.1` (= the host that works in the phone browser) | |
| A7 | Anywhere | No debug banner, no "local"/emulator text, no stack traces | |

### B-B. Authentication

| # | Do | Expect | Result |
|---|---|---|---|
| B1 | Continue with Google (existing account) | Home loads, greeting uses your name | |
| B2 | Continue with Google (a second account), if available | Onboarding starts at the name step; finishing generates a programme | |
| B3 | Force-stop FITOS → reopen | Still signed in, Home loads | |
| B4 | Profile → Sign out | Back to sign-in | |
| B5 | Sign in again | Home loads; data intact (same programme, same history) | |
| B6 | PC: `docker compose logs api \| Select-String "auth/session"` | A `POST /v1/auth/session` 200 for each sign-in | |

### B-C. Core app

| # | Do | Expect | Result |
|---|---|---|---|
| C1 | Home | Greeting + date, "Your next move", Today grid, This week; no "Can't reach FITOS" | |
| C2 | Profile | Name, goal, targets (kcal / protein / carbs / fat / fibre), build line `FITOS 1.0.0-alpha.1 · alpha · 10.160.235.11` | |
| C3 | Training tab | The week loads; a day shows exercises with sets, reps, RIR, target load and reason | |
| C4 | Exercise library → search "bench" → open one | Results filter; detail shows muscles, equipment, alternatives | |
| C5 | Start today's (or any) session | Session screen with prescribed sets | |
| C6 | Log 2–3 sets: weight, reps, RIR | Each set saves; rest timer runs; sync pill settles | |
| C7 | Complete the session | Summary: sets, tonnage, any PRs | |
| C8 | History | The session is listed; opening it shows the logged sets | |
| C9 | Open the lift you just logged (progression) | A recommendation with its reason | |
| C10 | Home → Training volume | This week's sets per muscle with On track / High / Very high | |
| C11 | Wi-Fi off → start a session → log a set → Wi-Fi on | The set is queued offline, then drains; History shows it | |

### B-D. FITOS AI (≈ 8 of the day's 20 requests)

| # | Do | Expect | Result |
|---|---|---|---|
| D1 | AI tab | Empty state with starter prompts (not "Not set up on this server yet") | |
| D2 | "What should I do today?" | An answer from your real programme within ~10 s | |
| D3 | "What did I bench last time?" | Your real last bench sets (or "no bench logged yet" — never invented) | |
| D4 | "How many steps did I take today?" | Says it cannot see Health Connect data; points to Home. Never a number | |
| D5 | "Build me a 3-day programme with more back work, 45 minutes each" | A proposal + **Use this programme**; Training still shows the old programme | |
| D6 | **Use this programme** → Keep current | Nothing changes | |
| D7 | **Use this programme** → confirm | Plan opens with the new programme; Home's next move updates | |
| D8 | Any AI error you meet (quota "busy", server stopped) | One plain FITOS line with Retry; no stack trace, no key, no provider name | |

### B-E. Health Connect (KI-1 is known and NOT a Gate 7 blocker)

| # | Do | Expect | Result |
|---|---|---|---|
| E1 | Profile → Health data → **Manage permissions** | Health Connect opens on FITOS's permissions | ✅ owner, Gate 6 |
| E2 | Grant permissions there → back to FITOS | Health data shows Connected with the granted categories | ✅ owner (grant), confirm the FITOS screen |
| E3 | Home | Steps (and sleep / weight / resting HR if a source exists) with their source and freshness; a missing metric says why — never a fake 0 | |
| E4 | Health Connect → revoke one category → back to FITOS | That category reads "Not allowed"; no stale number | |
| E5 | AI D4 after granting | Still cannot see steps | |
| E6 | Health data → **Connect** | **Known crash (KI-1).** Record ❌ and, if the phone is on USB, capture the logcat in KI-1. Do not mark ✅ unless it really works | ❌ expected |

### B-F. Network resilience

| # | Do | Expect | Result |
|---|---|---|---|
| F1 | Backend reachable | Core rows above work | |
| F2 | PC: `docker compose stop api` → FITOS Home → pull to refresh | No crash. Home keeps today's plan from the phone's cache (`/today` is network-first, cached — local-first by design); Health blocks unaffected | |
| F3 | With the API still stopped: AI → send "hi" | "Could not reach FITOS at 10.160.235.11:8080. Check your Wi-Fi and that the server is running." with Retry; no crash | |
| F4 | PC: `docker compose start api` → Retry | The answer arrives | |
| F5 | Phone Wi-Fi off → AI → send; then Home → pull to refresh | AI shows the same named line; Home keeps cached data; no crash. Wi-Fi on → Retry works | |
| F6 | Fresh install (or Android Settings → FITOS → Clear storage) with the API stopped → sign in | After ~30 s (three connection attempts) sign-in stops with the named "Could not reach FITOS at 10.160.235.11:8080…" line — not a bare "offline", no crash | |
| F7 | Compare the sign-in / Profile address with the PC's `ipconfig` | They match | |

### Gate 7 — owner results so far (2026-09-23, S24)

| Area | Result |
|---|---|
| Google sign-in; sign-out → sign-in | ✅ |
| AI chat; AI programme generation | ✅ |
| Exercise add / remove; custom programme | ✅ |
| Health Connect **Connect** (E6) | ✅ now passes (KI-1) |
| Workout sync | ❌ needed Retry — KI-6, fixed in code, retest below |
| Profile personal-data editing | ❌ missing — KI-7, implemented, retest below |

### B-G. Retest after the Gate 7 fixes (new APK)

| # | Do | Expect | Result |
|---|---|---|---|
| G1 | Online: start a session, log 3 sets (include one removed and re-logged, and one quick double tap), Complete | Summary; within a few seconds no "to sync"/"not synced" pill — **no Retry** | |
| G2 | History right after G1 | The session is listed, with the sets as you left them (the removed set gone, the double tap = one set) | |
| G3 | Home right after G1 | This week / next move reflect the finished session | |
| G4 | Wi-Fi off → a session → log a set → Complete | "n to sync" pill; nothing parked; the session is on the phone | |
| G5 | Wi-Fi on (do nothing else) | Within ~15 s it syncs by itself; History shows it | |
| G6 | Wi-Fi off → two sessions completed → Wi-Fi on | Both sync with no Retry | |
| G7 | PC: `docker compose stop api` → complete a session → `docker compose start api` (Wi-Fi stays on) | It syncs by itself within ~2 min of the API returning | |
| G8 | Profile → **Edit personal details** → change name, height, weight, sex, activity → Save | "Saved. FITOS recalculated your targets."; Profile shows the new values and new targets with "· weight-change" or "· profile-change" | |
| G9 | PC: `docker compose exec postgres psql -U fitos -c "select measured_on, weight_kg, source from body_metrics order by measured_on desc limit 3"` | Today's row = your weight, `manual`; earlier days untouched | ✅ PC 2026-09-23: today `manual`, 21–22 Sep `onboarding` rows untouched |
| G10 | Personal details with Health Connect weight granted | A line "Health Connect on this phone: … kg · date"; the FITOS field keeps your value until you type another | |
| G11 | Health Connect still works (Home steps) and AI still answers (one question) | ✅ both | |
| G12 | Sign out → sign in | No 422 in `docker compose logs api` for `DELETE /v1/auth/session` | |

### B-H. Retest — the stuck "session already in progress" (KI-8)

Do these **first**, before new sessions, on the new APK:

| # | Do | Expect | Result |
|---|---|---|---|
| H1 | Open FITOS → Home | "UNFINISHED SESSION ON FITOS" — the session from 2026-09-23 ~02:12 with 5 sets. (Also above Start session on the Training tab) | |
| H2 | Tap **Finish it** → confirm (or **Discard it** if you would rather not keep it) | The notice disappears; any "not synced" pill clears within a few seconds | |
| H3 | History | The finished session is listed (if you chose Finish); your newer sessions are listed too | |
| H4 | PC: `docker compose exec postgres psql -U fitos -d fitos -c "select status, count(*) from workout_sessions group by 1"` | At most one `active` | ✅ PC 2026-09-23: at most one `active` per user |
| H5 | Start a session, log 2 sets, Complete | Syncs by itself — no Retry, no 409 in `docker compose logs api` | |
| H6 | Start a session, log a set, **force-stop** FITOS, reopen | The session is still there (Resume); completing it syncs | |
| H7 | Wi-Fi off → start + log + Complete → Profile → Sign out | "Unsynced workout changes" dialog. **Stay signed in** → Wi-Fi on → it syncs; then Sign out works without the dialog | |
| H8 | Today after H5 | Home's next move / week reflect the finished session | |

### B-I. Retest — queued sessions from a replaced programme (KI-9)

| # | Do | Expect | Result |
|---|---|---|---|
| I1 | Install the new APK; if a "n not synced · Retry" pill shows, tap **Retry** once | Within seconds the pill clears; `docker compose logs api` shows each old session as one 404 then a 201 — no burst of 404s | |
| I2 | History | The old sessions appear (as "Session", ad-hoc — their programme no longer exists); your Bro Split sessions as before | |
| I3 | Training → today (Wednesday = Shoulders) → Start → log 2 sets → Complete | 201 once, syncs by itself, History + Home update | |
| I4 | Offline: start a session → Training → apply another programme (AI or template) online later → Complete → Wi-Fi on | The session syncs as ad-hoc (one 404 then 201), not parked | |

### B-J. Retest — old sessions waiting behind a newer one (KI-10)

Do these on the new APK, **before** I1–I4 if those have not been done yet:

| # | Do | Expect | Result |
|---|---|---|---|
| J1 | Install; open FITOS. If "n not synced · Retry" shows, tap **Retry** once | Pill clears within seconds. `docker compose logs api`: per old session **one 404 then one 201**, then its sets and `/complete` — **no 409** | ⚠ PC log ✅ 02:14:06–02:14:20 UTC: 8 old sessions → 201 ad-hoc + sets + complete, zero 404 / 409 (their ad-hoc payload was stored by `d362279`); phone pill: owner |
| J2 | History | The old sessions appear as ad-hoc "Session" entries with their sets; the Bro Split sessions unchanged | |
| J3 | PC: `docker compose exec postgres psql -U fitos -d fitos -c "select status, count(*) from workout_sessions group by 1"` | At most one `active` | ✅ PC 2026-09-23: at most one `active` per user (the one active row belongs to the second account, since 21 Sep) |
| J4 | Wi-Fi off → Start today's session → log 2 sets → Complete → Wi-Fi on | Syncs by itself: one 201, sets, complete — no Retry, no 409 | |
| J5 | Start a session (online), log a set; leave it **in progress**; tap Retry if the pill shows | Nothing old is sent while it is open (no 409 in the log); Complete it → any queued old work follows by itself | |

### B-K. Phase 6.5 manual acceptance (Part K, 27 points) — folded in

MASTER-SPEC Phase 6.6 requires this checklist to carry Phase 6.5's 27
points (`docs/phase-reports/phase-6.5.md`, "Manual acceptance (Part K)"),
never run until now. Use the **alpha APK** above — not the old debug build
with `10.0.2.2`. Needs a step source; 5–6 need a sleep and a weight source.
Rows already covered elsewhere are marked; do them once.

| # | Do | Expect | Result |
|---|---|---|---|
| K1 | Open FITOS signed in, Health Connect untouched | Home loads: greeting + date, "Your next move" (your session), Today grid with Steps "Connect Health data", Food "Not logged yet · Target …", Recovery "Connect Health data to see recovery metrics." | |
| K2 | Home → More for you → "Connect Health data" (or tap Steps) | Health Data screen: Not connected, three categories "Not allowed", Connect / Manage / Refresh | |
| K3 | Connect → in the Health Connect sheet allow **Steps only** | Screen: Connected, Activity "Partly allowed"; back on Home: Steps shows a number and "n% of 8,000"; Active calories "Not allowed"; recovery still asks | |
| K4 | Allow activity (Health Data → "Allow activity") | Steps / Active calories (+ "n kcal in total") / distance populate where the source has them; "No data yet" where it does not | |
| K5 | Allow recovery | Recovery grid: Sleep "6h 12m" (last night), Resting HR "62 bpm · Today/Yesterday/Last recorded …" | |
| K6 | Allow body | Body section appears: Weight "60.5 kg · Last recorded 18 Sep", Body fat, BMR (or "No data yet") | |
| K7 | In Health Connect settings revoke Steps → return to FITOS | Home refreshes on resume: Steps "Not allowed", the old number is gone; Health Data shows Activity "Partly allowed" (= E4) | |
| K8 | A category allowed, no data in the source | "No data yet", never 0 | |
| K9 | Two step sources (phone + watch / two apps) | Steps equals Health Connect's own total, not the sum | |
| K10 | Change a permission in Health Connect, come back | Data changes without restarting (resume refresh) | |
| K11 | Start a workout from the carousel | Card becomes "<day> is in progress · n sets logged" with Resume; Workout block "In progress" | |
| K12 | Complete it | "<day> done · n sets · kg moved" card → See the summary; Workout "Completed"; PR card if a record | |
| K13–14 | Food | "Not logged yet" with the target (Phase 8 not built) — never "0 kcal" | |
| K15 | Steps well below goal after 15:00 / 19:00 | MOVE card "You're n steps from your goal · An easy m-minute walk gets you there" | |
| K16 | Protein remaining | Cannot appear until Phase 8 (documented) — mark ✅ if absent | |
| K17 | Sleep < 6 h last night | RECOVER card "Sleep was 5h 45m · Keep today's session controlled" | |
| K18 | Deload offered (Phase 6 checklist step 8) | DELOAD card first; "Open your plan"; nothing applied until Accept on the plan | |
| K19 | "Training volume →" | Opens the Phase 6 volume screen (= C10) | |
| K20 | Body freshness | "Today" / "Yesterday" / "Last recorded d Mon" matches the reading's date | |
| K21 | Kill and reopen | Health values return at once (cache), then refresh; footer "Health data read just now" | |
| K22 | Airplane mode | Home renders from cached today; health blocks unaffected or "Unavailable right now"; no crash (≈ F5) | |
| K23 | Bottom bar | Floats, translucent over content on all five tabs; each tab switches; content not hidden behind it | |
| K24 | Back | Deeper screen pops; non-home tab root → Home; Home root → leaves | |
| K25 | ~360 px device | No overflow (carousel titles ellipsise at two lines) — S24 is ~393 dp; use Settings → Display → larger font / zoom if you want to approximate | |
| K26 | Wide phone | Spacing intact | |
| K27 | Accessibility | Every block has a label + text; status never colour-only; targets ≥ 48 px | |

Rows that need a source you do not have (K9 two step sources, K17 a short
night, K18 a deload): mark "— not run" with the reason; they are covered by
the Phase 6.5 automated tests and do not block the alpha on their own.

## C. Failure log

One entry per ❌ or ⚠:

```
Row:            (e.g. C6)
Action:         exactly what was tapped / typed
Expected:       from the table
Actual:         what happened (text on screen, crash dialog, hang for N s)
Reproducible:   yes / no / N of M tries
Evidence:       screenshot / logcat (adb logcat -v time AndroidRuntime:E flutter:E *:S)
APK:            release / debug
Severity:       blocker / high / medium / low
Blocks alpha?:  yes / no — why
```
