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
| A9 | Turn Wi-Fi off on the phone → Home → pull to refresh | "Can't reach FITOS — You appear to be offline…" with Retry; Health blocks unaffected; Wi-Fi on → Retry → notice gone | |
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

## B. Gate 8 — full alpha acceptance

Filled in at Gate 8: FITOS AI in depth, Phase 6.5's 27 Health Connect /
Home points (`docs/phase-reports/phase-6.5.md`), branding, crash-free
session, release-like APK behaviour.
