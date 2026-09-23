## PHASE 6.6 — Closed alpha + FITOS AI + product polish — IN PROGRESS

**Status: NOT complete.** Gates 1–5 verified; Gate 6 verified on the S24 (Health Connect
**Connect** now passes — KI-1); Gate 7 in progress: S24 found a sync bug (KI-6) and a missing
Personal details editor (KI-7), both fixed in code, **S24 retest pending**. Nothing merged to `main`.

**Branch** `phase-6.6` (stacked on `phase-6.5`) · **Plan** owner brief 2026-09-22, decisions B1–B6 · **Records** [ADR-010](../decisions/ADR-010-fitos-ai.md) (FITOS AI), ADR-008/009 (6.5)

| Gate | Scope | Status | Commits |
|---|---|---|---|
| 1 | Audit | reported, approved | — |
| 2 | Summary personalization (display name), branding | **verified** (CI 241 mobile / 168 API) | `3998d0e` `4a281e0` `72cfac3` |
| 3 | Gemini backend foundation | **verified** (CI 199 API) | `ea58b88` |
| 4 | AI context, allowlisted tools, chat, Flutter AI screen | **verified** (CI 222 API / 251 mobile) | `71c54c1` `56441a4` `77a623c` |
| 5 | AI programme generation through the deterministic generator | **verified** (owner 2026-09-22) | `cc8157a` |
| 6 | Alpha configuration (LAN backend, flavour, Firebase defines) | **verified on the S24 — NOT fully accepted**: Health Connect Connect crashes (KI-1) | `a061b89` `fbe053e` `d66d54b` |
| 7 | Alpha APK + S24 acceptance (owner brief 2026-09-23; absorbs the old Gate 8 checklist) | **in progress** — APK built + inspected on the PC; S24 matrix pending | see Gate 7 |

### Gate 4 — FITOS AI (context + tools + chat + screen)

IMPLEMENTED
  - **Context assembler** `apps/api/src/modules/ai/context-assembler.ts` — `UserContextAssembler` →
    `FitosAiContext` from the existing services only: profile (display name, sex, age, height,
    latest weight, level, activity, days/week, session minutes, location, equipment, timezone),
    goal + targets (kcal / protein / carbs / fat / fibre + reason), programme (name, split,
    days/week, mesocycle week, each day's session and exercise names), today (status rest /
    ready / in-progress / completed / no-programme, every exercise with sets, reps, RIR, target
    load, the progression recommendation with its reason, last time's sets, substitution;
    deload state, neglected muscles), the last **3** completed sessions (date, working sets,
    tonnage, records, ≤ 6 sets per exercise), this week's volume with status and landmarks,
    `nutrition.loggingAvailable: false`, `health.availableToServer: false`. ~8.5 k chars for the
    owner's real account.
  - **Tools** `tools.ts` — 13 allowlisted, read-only, strict-Zod tools (see ADR-010 §4) with
    hand-written JSON-schema declarations; the user id is closed over; unknown tool / invalid
    arguments / service 404 → a readable result; `MAX_TOOL_ROUNDS = 4`.
  - **Orchestration** `service.ts` — `AiService.chat`: assemble → system instruction (12 rules +
    context JSON) → model → tool loop → plain-text answer + navigation actions derived from the
    tools used (open-workout / plan / volume / progression / profile / nutrition / history /
    exercise) + `toolsUsed`; stateless (last 12 turns from the client); provider failures →
    envelope; failure kind + upstream status logged for operators (never a body or key).
  - **Route** `POST /v1/ai/chat` (default-deny, 20/min/user), `GET /v1/ai/status`; contracts
    `aiChatRequestSchema {message 1–2000, history ≤ 20}`, `aiChatResponseSchema {text, actions,
    toolsUsed, model}`; openapi regenerated.
  - **Provider** — `AiMessage.toolCalls` + call `id` / `signature` round-trip (Gemini 3 thought
    signatures); default `AI_MAX_OUTPUT_TOKENS` 2048 (thinking shares the budget).
  - **Flutter** — `features/ai`: entities, `DioAiApi` (status, chat; 60 s receive timeout),
    `aiStatusProvider`, `AiChatController` (turns, sending, failure; retry re-sends the
    unanswered turn and drops it from history; new sign-in = new conversation), `AiChatScreen`
    replacing the placeholder on the AI tab: editorial column (YOU / FITOS AI eyebrows,
    hairlines, selectable text), actions as outlined buttons that navigate, six starter prompts
    (none needing Phase 8), "Thinking…", error line with Retry, "Not set up on this server
    yet" when unconfigured, "Could not reach FITOS AI" with Try again; composer above the
    floating bar. `ErrorMapper` keeps the server's 503 message.

TESTS
  - API: **54** AI tests — provider mapping incl. thought-signature round trip; registry
    (exact allowlist, read-only names, unknown tool, bad args, `userId` rejected, strict
    schemas); loop (direct answer, tool round with results fed back after the assistant turn,
    unknown/malformed calls as results, cap at 4 rounds, provider failure → envelope, empty →
    fallback, history bound); plain-text pass; **integration on real Postgres**: default-deny,
    the real context of an onboarded user with a programme and a completed session, no
    programme/history stated as absent, **isolation** (user B's tools never see user A; A's
    session id is NOT_FOUND for B), tools answering real data (today, progression, volume,
    library search filtered by equipment), bad enum → result not 422, request validation
    (empty, > 2000, extra field), malformed/rate-limited/blocked → 503/429/422 without the
    upstream body, status, **no rows written by a full tool sweep**. API total **220**.
  - Mobile: 9 AI screen tests (empty + prompts, prompt → turn + answer + action navigates,
    history carried and field cleared, New chat, empty not sent, server words + Retry, rate
    limited / offline / expired, not configured, status unreachable, action routes) + a
    conformance group for status / request / response / enums.
  - Local: typecheck, lint, `dart analyze --fatal-infos`, custom_lint, format, APK — clean.
    The Flutter suite was also run in a Linux container (`ghcr.io/cirruslabs/flutter:stable`,
    251/251) because `flutter_tester` is blocked on the host; CI remains authoritative.
  - Docker: `docker compose up --build -d api` → "ai: configured", `/health` 200,
    `/v1/ai/status` and `/v1/ai/chat` 401 without a token.

LIVE GEMINI SMOKE (owner's key in `docker/.env`, never printed)
  - `gemini-2.5-flash` (as configured): Google answers **404 "no longer available to new
    users → use gemini-3.6-flash"**. The path still behaves: 503 envelope, no key, no health data.
  - `gemini-3.6-flash` (runtime override, env file untouched): status configured ✓; "Explain my
    current workout." → Pull, 4 exercises with sets/reps/RIR, each FITOS recommendation and
    reason, deload none, a next action ✓; "What did I bench last time, and should I increase
    it?" → *50 kg × 12 @ 1 RIR on 2026-09-21; not yet, stay at 50 kg* via `search_exercises` +
    `get_progression` ✓; "How many steps did I take today?" → *cannot see it; Home shows it* ✓;
    "What is my protein target and how much have I eaten?" → *133 g; intake not logged* ✓.
    Health Connect values sent: none; key in requests/logs: none; first context 8 487 chars.
    Free-tier per-minute quota surfaced as 429 "busy" when calls were sent back to back.

### Gate 5 — AI programme generation through the deterministic generator

IMPLEMENTED
  - **Core** `GeneratorInput.emphasis?: MuscleGroup[]` → `emphasisedTarget` (goal target × 1.25,
    floored at MAV-low, capped at MAV-high); rationale line with the raised targets, or "cannot
    apply: no session in this split trains it directly". Everything else in the engine unchanged.
  - **Contracts** `generateProgramRequestSchema.emphasis` (≤ 3 muscles); `programRequestSchema`
    (+ `template` slug); `programPreviewSchema`; `AI_ACTION_TYPES` + `apply-program` with
    `programRequest`.
  - **API** `TrainingService.preview(userId, request)` — same engine, nothing stored; `generate` /
    `applyTemplate` accept `emphasis`. Tools `list_program_templates` and `propose_program`
    (strict Zod = the contract; a rejection returns `error` + `alternatives` + `note`); rule 12 in
    the system instruction; `AiService.actionFromProposal` → `apply-program` carrying the same
    request. Total tools: 15.
  - **Flutter** `AiActionType.applyProgram`, `AiProgramRequest`, `GenerateProgramRequest.emphasis`;
    the AI screen confirms ("Replace your programme?" / Keep current / Use this programme) and
    then calls `ProgramController.applyTemplate` or `.generate` with that request, invalidates
    today + volume, opens the plan; a failure is a snackbar. Starter prompt "Build me a new
    program" added.

TESTS
  - Core **461** (+5: emphasis bands for every muscle/goal/week, a chest+shoulders programme plans
    more and stays under MAV-high, deterministic + duplicate-safe, no line without emphasis,
    push/pull declines an abs emphasis honestly). Contracts **35**. API **230** (+8: proposal →
    action with the same request; exercises/sets/userId cannot be smuggled and the generator is
    not called; rejection with alternatives and no action; template list; instruction wording;
    integration: real proposal for a real user with raised targets, active programme unchanged,
    then applied through the ordinary route; rejection is a tool result not a 422; emphasis on the
    generate route incl. 422 for 4 muscles / a fake muscle; the write-sweep now includes both
    tools). Mobile **254** (+3 screen: cancel changes nothing; confirm sends the same request via
    the template route and opens the plan; generate path + failure snackbar; conformance for the
    enum, `programRequest` and `emphasis`).

LIVE SMOKE (real account, key never printed; programme count 8 → 8, active unchanged)
  - `gemini-3.6-flash`: "I want a 5-day bodybuilding split focused on chest and shoulders, 60
    minutes per session." → `list_program_templates`, `propose_program {bodybuilding-5, 60,
    emphasis [chest, shoulders]}` → summary with the raised targets (12 / 12 under a strength
    goal), no shortfall, "not applied yet — tap Use this programme"; action carries that request.
  - The free tier for `gemini-3.6-flash` is **20 requests per day per project**
    (`GenerateRequestsPerDayPerProjectPerModel-FreeTier`); the day's quota ran out after this.
    The remaining two paths were exercised on sibling models (config untouched):
    `gemini-3.5-flash`: "3-day programme with more back work, 45 minutes" → generate path, back
    target 12, the engine's two shortfalls (biceps, calves: session time) repeated, action with
    `{3, 45, [back]}`. `gemini-3.5-flash-lite`: "the 5-day bodybuilding split on 3 days" →
    rejected by the engine ("5-day structure; cannot run on 3 days"), the two valid 3-day
    structures named, nothing offered.

### Gate 6 — Alpha configuration + integration

IMPLEMENTED (`a061b89`, CI green)
  - **LAN endpoint** — `API_BASE_URL` is the single source: `lib/core/config/env.dart` reads it;
    `android/app/build.gradle.kts` reads the same `--dart-define` (Flutter forwards defines to
    Gradle as `-Pdart-defines`) and *generates* `res/xml/network_security_config.xml` with
    `base-config cleartextTrafficPermitted="false"` plus one `domain-config` for that host. An
    `https://` URL produces no cleartext entry. Verified by building with a test host (the entry
    appears in the APK's `res/xml/`) and with an https URL (no entry). No IP is committed.
  - **Manifest** — `INTERNET` in the main manifest (Flutter grants it in debug/profile only);
    `android:networkSecurityConfig` wired.
  - **Alpha build script** — `apps/mobile/tool/alpha.ps1` (+ `alpha.sh`): reads the gitignored
    `apps/mobile/alpha.env` (Firebase five, `API_HOST=auto|<ip>`, `API_PORT`), resolves the PC's
    Wi-Fi IPv4 (`Get-NetIPAddress`, virtual adapters excluded; refuses 10.0.2.2/localhost),
    passes `FLAVOR=alpha`, `APP_VERSION`, `API_BASE_URL` and the Firebase defines; `-Install`,
    `-Run`, `-Release`, `-ApiHostOverride`. Prints values masked. Dry-run with a throwaway env:
    resolved `172.16.205.86` (the Wi-Fi adapter), APK built, config generated for that host.
  - **Build identity** — `Env.isAlpha / apiHost / appVersion`; Profile shows
    `FITOS 1.0.0-alpha.1 · <flavour> · <host>`; pubspec `1.0.0-alpha.1+2`.
  - **Friendly failure** — Home shows "Can't reach FITOS — <failure's words>" with Retry when
    `/today` fails and nothing is cached; Health blocks stay (device data). Other screens already
    had Retry states (week, browser, history, AI, profile); the AI screen's not-configured /
    unreachable / busy lines exist from Gate 4.
  - **Docs** — `docs/alpha/ALPHA-SETUP.md`, `docs/alpha/PHASE-6.6-ALPHA-CHECKLIST.md` §A (22 S24
    checks), README pointer.

VERIFIED ON THE PC
  - Docker: `fitos-api` listens on every interface; host publishes `0.0.0.0:8080` (`netstat`);
    `GET http://172.16.205.86:8080/health` from the PC → 200 `{"status":"ok","database":
    {"reachable":true}}`; `ai: configured`, model `gemini-3.6-flash`; `/v1/ai/status` 401 without
    a token. Windows Firewall: Docker Desktop's inbound allow rules for `com.docker.backend.exe`
    (TCP/UDP any port, Public profile); the Wi-Fi network is Public → applies.
  - CORS: not applicable (native app, no browser origin); the phone's browser check of `/health`
    is a plain GET.
  - Mobile tests 255; API 230; core 461; contracts 35.

NOT YET VERIFIED — needs the S24 (owner): A1–A22 in the checklist. The alpha APK itself has
not been built with real Firebase values (`alpha.env` does not exist on this machine's checkout;
the script refuses without it).

#### Gate 6 on the S24 (owner, 2026-09-23)

  - ✅ LAN API from the phone; ✅ Google Sign-In; ✅ `/v1/auth/session` bootstrap — after
    `fbe053e`. Root cause of the earlier hang: the APK carried the PC's build-time LAN address
    (`172.16.205.86`) while the PC had moved to `10.160.235.11`; every request timed out and
    the only feedback was "offline". Fix: failures name the address; the sign-in screen shows the
    compiled-in backend; the build script refuses to build when `/health` does not answer.
  - ✅ Health Connect via **Manage permissions**.
  - ❌ Health Connect **Connect** still crashes on the S24 after `d66d54b` (which fixed a real,
    bytecode-evidenced `ActivityNotFoundException` in that path). No logcat yet. Carried forward
    as **KI-1** in `docs/alpha/KNOWN-ISSUES.md`; not a Gate 7 blocker (owner).

### Gate 7 — Alpha APK + S24 acceptance (in progress)

AUDIT (2026-09-23, before any change)
  - Branch `phase-6.6` at `d66d54b`, working tree clean, 24 commits ahead of `main`.
  - **Secrets:** a scan that loads the real values from the gitignored env files and reports only
    presence found the Gemini key, the three Firebase client values and the service-account key id
    **absent** from every tracked file, from the entire Git history (all branches), and from both
    APKs; no PEM key in any tracked file. `alpha.env`, `docker/.env`, `apps/api/.env`,
    `apps/api/.secrets/` are all gitignored (`git check-ignore`).
  - **Alpha config:** `alpha.env` has the five Firebase keys + `API_HOST=auto` + `API_PORT=8080`;
    `API_BASE_URL` → Dart `Env.apiBaseUrl` and the generated network-security config from the same
    define; version `1.0.0-alpha.1+2`; release signed with the debug key (KI-4).
  - **Backend:** `fitos-api` + `fitos-postgres` up; `/health` 200 over the LAN address; `/v1/ai/status`
    401 without a token; `ai: configured`, `gemini-3.6-flash`; no API/contracts/core change since the
    image was built (`cc8157a`). The LAN architecture remains appropriate for a one-phone closed
    alpha; its one sharp edge is KI-2 (address changes between networks).
  - Health Connect implementation not touched.

BUILD + INSPECTION (PC)
  - `.\tool\alpha.ps1 -Release` → `http://10.160.235.11:8080`, `/health 200 OK`, `app-release.apk`
    64.0 MB (AOT, R8), 936 s cold.
  - Refusals exercised: unreachable host (`192.0.2.1`) → exit 1 before building; missing
    `GOOGLE_WEB_CLIENT_ID` → refused; `10.0.2.2` → refused.
  - `aapt`: `com.example.fitos` · versionName `1.0.0-alpha.1` · versionCode 2 · label FITOS ·
    not debuggable · minSdk 26 / targetSdk 36 · INTERNET + exactly the ten health READ permissions.
  - Network config (shrunk to `res/8G.xml`): base-config cleartext **false**; one domain-config,
    cleartext true, `10.160.235.11` only. Dart AOT (`libapp.so`, arm64) carries exactly
    `http://10.160.235.11:8080`, flavour `alpha`, version `1.0.0-alpha.1`.
  - Dex: `FlutterFragmentActivity` present (the `d66d54b` change is in the build); the channel's
    wire name `fitos/health_connect` survives R8 in both dex and Dart AOT.
  - No Gemini key, service-account material or private key in the release APK.

TESTS
  - Core 461 · contracts 35 · API **230** · mobile **275**; API typecheck + lint, mobile analyze
    `--fatal-infos`, custom_lint, format — clean.
  - One API test fixed: `ai.integration.test.ts` asserted that `get_today` always returns a
    session name. On 2026-09-23 (a Wednesday, a rest day in the generated 4-day programme) the tool
    correctly returned `status: rest, sessionName: null`, so the test failed deterministically on
    rest days. It now checks the tool against the programme's own plan for the day. Product
    unchanged. (Two other API failures in the first run were timeouts under a parallel release
    build; they pass alone and in the full run.)

S24 RESULTS (owner, 2026-09-23): sign-in, sign-out/in, AI chat, AI programme generation, exercise
add/remove, custom programme, Health Connect **Connect** — ✅. Workout sync — ❌ (needed Retry).
Profile personal-data editing — ❌ (missing).

KI-6 — WORKOUT SYNC (fixed in code; retest G1–G7, G12)
  - Evidence: the API logs of the S24 session — every `DELETE /sets/<id>` (and sign-out's
    `DELETE /auth/session`) → 422 "Body cannot be empty when content-type is set to
    'application/json'"; then `POST /sets` → 409 "A set already exists at that position", five
    attempts in a backoff pattern, parked; retried later → 409 "This session is completed".
  - Root cause, one chain: (1) Dio's `BaseOptions.contentType` stamped `application/json` on
    body-less requests, which Fastify rejects — no DELETE ever succeeded, so a removed set stayed
    on the server; (2) re-logging that slot, or a quick double tap (the log handler mints a new id
    per tap), created a second live set at a position the server's `set_logs_live_position` rule
    forbids → 409 → parked, "1 not synced"; (3) after a backoff the engine waited for "the next
    kick" — the next tap, which never comes after a session's last request; (4) `historyProvider`
    did not follow drains, so History / Home's week stayed stale even when a drain did succeed.
    Found while testing: an edit or removal while a batch was on the wire could be lost (the batch
    was sealed after its payload had been read) — and my first engine change opened a lost-kick
    window after the new scheduling await; both closed.
  - Fix: `NoBodyNoContentType` interceptor; the engine schedules its own wake after a backoff (at
    the entry's due time) or an unreachable server (15 s doubling to 2 min; signed-out stays
    asleep), re-checks kicks after scheduling, and seals a set batch in the same transaction that
    picks it; `logSet` at an occupied live slot corrects that set; `historyProvider` watches
    `serverRefreshProvider`; `syncWakesItselfProvider` (off only in widget tests, which drive the
    queue on a fake clock). Local-first behaviour unchanged.
  - Tests: `automatic_sync_test.dart` (11, real timers; the fake server now enforces the
    position rule): A online completion syncs with no `sync()` call; B offline → pending, nothing
    parked, retry scheduled; C server back with Wi-Fi never dropping → drains alone; D two
    sessions → both; E a rejected request retries itself, parks, never drops, later work still
    syncs; F Retry recovers; H double tap → one set, removed + re-logged → delete first, no 409,
    removed or edited while on the wire → server correct, lost answer re-sent → one set.
    G `server_refresh_test.dart`: a background sync refreshes History. `dio_client_test.dart`:
    no content type without a body; JSON with one; auth header kept. Ran 5× green.

KI-7 — PROFILE → PERSONAL DETAILS (implemented; retest G8–G10)
  - API: `patchProfileRequestSchema` + `sex`, + `weightKg` (today's `body_metrics` reading,
    `source = manual`, one per day, earlier days kept); both are target inputs; recompute through
    the existing `TargetsService` path with `reason = weight-change` (weight only) or
    `profile-change`; targets remain server-only (a `kcal` / `targets` key is 422). Goal changes
    use the existing `PUT /user/goal`. 6 integration tests (history kept, same-day replace, bounds,
    one recompute per save, goal-change reason); the suite's client address is now per user (the
    extra onboardings tripped the per-IP rate limit).
  - App: `PersonalDetailsScreen` at `/profile/details` (name, sex, height, weight, activity;
    goal links to the existing editor; birth date shown, not editable), onboarding's validators and
    choice widgets; one PATCH with only what changed; Profile re-reads the goal so the server's new
    targets show. `ProfileController.savePersonalDetails`, `PersonalDetailsChange`. 9 widget tests +
    a conformance test (body keys and enum values ⊂ the PATCH schema; no target keys).
  - Weight vs Health Connect: **ADR-011** — the FITOS weight is the user's; Health Connect's is
    shown beside the field as the phone's reading, never sent, never auto-copied (B4).

TESTS (after the fixes): mobile **301**; API **235 / 236** locally — the mesocycle-week test
passes alone in 5.5 s, over vitest's 5 s default, because the local Postgres was slow (290 ms per
`/health` DB ping); CI authoritative. Core 461, contracts 35; typecheck, lint, analyze
`--fatal-infos`, custom_lint, format clean.

KI-8 — "A SESSION IS ALREADY IN PROGRESS" ON EVERY START (fixed in code; retest H1–H8)
  - Database: `34dd254f…` is completed; the slot is held by `a7ce5a4a…` (active since 2026-09-22
    20:42 UTC, 5 sets). API log: created 20:43:41, synced, then sign-out 20:46:15 wiped the phone and
    its queue before any `/complete` or `/abandon` was sent — an orphan on the server. Each new
    session's start meets `one_active_session` → 409 → parked; the phone never read the server's
    `activeSession`, so it could not resolve it.
  - Fix (server guard unchanged): `orphanedSessionProvider` (the server's active session when this
    phone does not have it) → `OrphanSessionNotice` on Home and above Start: Finish (completed at its
    last set) / Discard (abandoned), each confirmed (owner 8.5), then `retryParked()` and refresh.
    Sign-out first syncs; if work is still unsynced it asks before deleting it.
  - Tests: API integration — the orphan scenario end to end (409 naming it on repeated starts, never a
    second session, `/today` names it with sets, finishing frees the slot, the blocked start then 201
    once and replays 200, History has it, one active). App — the blocked session is kept and parked,
    repeated Retry never creates a second session; after the orphan ends one Retry sends start, sets
    and completion exactly once; restart with a queued completion drains; the notice's Finish /
    Discard / Not now / failure / not-for-own-session; the sign-out guard. Mobile 311, API 237.

S24 ACCEPTANCE — pending (owner): `docs/alpha/PHASE-6.6-ALPHA-CHECKLIST.md` §B (A–F, 45 rows),
§B-G (G1–G12, KI-6 / KI-7) and §B-H (H1–H8, KI-8 — do these first)
with the failure log in §C. PC-verified rows are pre-marked. Health Connect E6 (Connect) is expected
❌ and is recorded, not waived.

KNOWN ISSUES → `docs/alpha/KNOWN-ISSUES.md` (KI-1 Health Connect Connect — **PASS on the S24**;
KI-6 sync, KI-7 personal details — fixed, retest pending;
KI-2 compiled-in LAN address; KI-3 Gemini free-tier quota; KI-4 application id + debug signing;
KI-5 release-mode APK not yet run on a device).

KNOWN ISSUES (Gate 5)
  - The free tier is unusable for an alpha with real users (20 requests/day/model); a paid tier
    is required before the S24 checklist that covers AI (§19.3 already requires it for production).
  - A generated 3-day programme is named "Full / Body · 3 days" (`splitName` of `full-body`,
    Phase 4 behaviour) — cosmetic, unchanged here.
  - Emphasis is not yet offered in the app's own Generate options screen; only the assistant
    sends it. (Deliberate: Gate 5 scope.)

KNOWN ISSUES (Gate 4)
  - **Model name**: `gemini-2.5-flash` is unavailable to this key. Owner decision: the alpha model is
    `gemini-3.6-flash` — now the env default and the documented example (`apps/api/.env.example`,
    `docker/.env.example`, compose fallback); still env-configurable, nothing in code assumes a name.
  - Free-tier quota: bursts of more than a few calls a minute return 429; the screen says "busy".
  - Sets logged with no weight are read by the engine as bodyweight (Phase 6 rule 1b); the
    assistant repeats that reason faithfully.
  - Answers arrive in one piece (no streaming); 3–10 s with tools.
