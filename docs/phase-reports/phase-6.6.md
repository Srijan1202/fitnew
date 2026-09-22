## PHASE 6.6 — Closed alpha + FITOS AI + product polish — IN PROGRESS

**Status: NOT complete.** Gates 1–4 done and verified; Gates 5–8 pending. Nothing merged to `main`.

**Branch** `phase-6.6` (stacked on `phase-6.5`) · **Plan** owner brief 2026-09-22, decisions B1–B6 · **Records** [ADR-010](../decisions/ADR-010-fitos-ai.md) (FITOS AI), ADR-008/009 (6.5)

| Gate | Scope | Status | Commits |
|---|---|---|---|
| 1 | Audit | reported, approved | — |
| 2 | Summary personalization (display name), branding | **verified** (CI 241 mobile / 168 API) | `3998d0e` `4a281e0` `72cfac3` |
| 3 | Gemini backend foundation | **verified** (CI 199 API) | `ea58b88` |
| 4 | AI context, allowlisted tools, chat, Flutter AI screen | **verified** — see below | see report |
| 5 | AI programme generation through the deterministic generator | pending | |
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

KNOWN ISSUES (Gate 4)
  - **Model name**: `gemini-2.5-flash` is unavailable to this key; set `GEMINI_MODEL=gemini-3.6-flash`
    in `docker/.env` (owner decision — nothing in code assumes a name).
  - Free-tier quota: bursts of more than a few calls a minute return 429; the screen says "busy".
  - Sets logged with no weight are read by the engine as bodyweight (Phase 6 rule 1b); the
    assistant repeats that reason faithfully.
  - Answers arrive in one piece (no streaming); 3–10 s with tools.
