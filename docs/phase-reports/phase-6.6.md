## PHASE 6.6 — Closed alpha + FITOS AI + product polish — IN PROGRESS

**Status: NOT complete.** Gates 1–4 done and verified; Gates 5–8 pending. Nothing merged to `main`.

**Branch** `phase-6.6` (stacked on `phase-6.5`) · **Plan** owner brief 2026-09-22, decisions B1–B6 · **Records** [ADR-010](../decisions/ADR-010-fitos-ai.md) (FITOS AI), ADR-008/009 (6.5)

| Gate | Scope | Status | Commits |
|---|---|---|---|
| 1 | Audit | reported, approved | — |
| 2 | Summary personalization (display name), branding | **verified** (CI 241 mobile / 168 API) | `3998d0e` `4a281e0` `72cfac3` |
| 3 | Gemini backend foundation | **verified** (CI 199 API) | `ea58b88` |
| 4 | AI context, allowlisted tools, chat, Flutter AI screen | **verified** (CI 222 API / 251 mobile) | `71c54c1` `56441a4` `77a623c` |
| 5 | AI programme generation through the deterministic generator | **implemented, awaiting owner verification** — see below | see report |
| 6 | Alpha configuration (LAN backend, flavour, Firebase defines) | pending | |
| 7 | Release-like APK | pending | |
| 8 | Samsung S24 manual alpha checklist | pending | |

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
