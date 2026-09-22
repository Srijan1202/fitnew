# ADR-010 — FITOS AI: Gemini through the backend, bounded context, allowlisted tools, deterministic FITOS authority

**Status** ACCEPTED — owner decisions B1–B6 (2026-09-22), Gates 3–4 implemented; Gate 5 (programme generation through the deterministic generator) extends this record
**Date** 2026-09-22
**Phase** 6.6
**Affects** MASTER-SPEC.md §10.1 (`/ai/status`, `/ai/chat`), §19 (AI architecture), §23/§24 (privacy, secrets), §30 (business-logic ownership), §31 (Phase 6.6), ADR-008 (Health Connect stays on the device)

---

## Context

FITOS's numbers — targets, programmes, progression, volume, deload — are
computed by deterministic rules in `packages/core` and served by the API.
Phase 6.6 adds an assistant that can *explain* those numbers in the
user's words and answer questions over the user's own history, without
ever becoming a second, unverifiable source of fitness truth. Health
Connect data lives only on the phone (ADR-008, owner B4). Gemini
credentials must never reach a client (owner B2).

## Decisions

### 1. The model is behind the FITOS API; the key is server-side only (B2)

Flutter → `POST /v1/ai/chat` → `AiService` → `AiProvider` → Gemini. The
phone holds no model credential and calls no model host; `GEMINI_API_KEY`
lives in the backend environment (`docker/.env` / `apps/api/.env`,
gitignored), travels in the `x-goog-api-key` header only, and is never
logged, echoed or returned. Without a key the server boots and
`/ai/status` says `configured: false`; the phone shows "Not set up on
this server yet" instead of a chat.

### 2. A replaceable provider seam (Gate 3)

`AiProvider { name, model, generate(AiRequest) }` is the whole contract:
a system instruction, ordered messages (assistant turns may carry the
tool calls they made, with the provider's opaque call id and thought
signature), tool declarations, tool results, limits. `GeminiProvider`
implements it over REST with Node's `fetch` and a hard timeout;
`FakeAiProvider` scripts it for tests; `NotConfiguredAiProvider` is the
honest default. Every failure is an `AiProviderError` kind
(`not_configured · timeout · unavailable · rate_limited · malformed ·
empty · blocked`) mapped in one place to the §10 envelope (503 / 429 /
422) with user-safe messages.

### 3. Bounded context, assembled from services (Gate 4)

`UserContextAssembler` builds `FitosAiContext` from the existing
services — `UserService`, `TrainingService`, `WorkoutService` — never
from repositories or SQL: profile (name, sex, age, height, latest weight,
level, activity, days, session length, location, equipment, zone), goal
+ targets, the programme's shape, today (status, exercises with sets /
reps / RIR, the recommendation and its reason, last time, substitution;
mesocycle week, deload state, neglected muscles), the **last three**
completed sessions (working sets, tonnage, records, up to six sets per
exercise), the current week's volume with statuses and landmarks. Two
parts are always present and always negative:
`nutrition.loggingAvailable: false` (Phase 8 is not built) and
`health.availableToServer: false` (B4). The whole instruction is ~8–9 k
characters for a real user; tests cap it at 20 k.

### 4. Allowlisted, read-only, Zod-validated tools (Gate 4)

Thirteen tools — `get_user_profile · get_active_goal ·
get_nutrition_targets · get_today · get_current_workout ·
get_recent_workouts · get_workout · get_exercise · search_exercises ·
get_training_volume · get_progression · get_active_program ·
get_deload_state` — each a named call into an existing service with the
**authenticated user's id closed over**. Arguments are strict Zod
schemas; the model never names a user, a table or a query. An unknown
tool or bad arguments become a *result* the model reads (`unknown tool`
/ `invalid arguments`), never an execution; a 404/422/409 from a service
becomes a result too. There is no write tool. Tested: unknown tools, a
`userId` argument, another user's session id, a bad enum, and that a
full sweep of tools changes no row.

### 5. A capped tool loop (Gate 4)

Model → tool calls? → validate → execute for this user → results back →
model, at most `MAX_TOOL_ROUNDS = 4` rounds; the fifth answer is taken as
final or replaced by a readable fallback. Stateless: the client sends the
last 12 turns; nothing is persisted.

### 6. Deterministic FITOS authority and hallucination controls

The system instruction states the rules (Part 5/8): FITOS context and
tool results are the only truth; never invent; food intake is not
logged; Health Connect data is not visible to the server; explain with
FITOS's own `reason` strings; never change data (point to the screen);
no diagnosis; no prompt/schema/credential disclosure; concise, plain
text. The server strips markdown emphasis deterministically. Live
verification on a real user: "What did I bench last time?" → *50 kg × 12
@ 1 RIR, stay at 50 kg and add reps* from `get_progression`; "How many
steps?" → *cannot see it, the Home screen shows it*; "How much protein
have I eaten?" → *target 133 g; intake is not logged*.

### 7. Privacy boundary (B4)

No Health Connect value exists on the server, so none can be assembled;
the integration test asserts the instruction contains no
`steps / sleep / restingHeartRate / bodyFat / activeCalories` keys and
no uid, key or credential. The phone does not serialise health data into
the chat request. AI responses contain only the assistant's text,
navigation actions and tool names.

### 8. Model name is configuration

`GEMINI_MODEL` is env-driven. On 2026-09-22 Google reported
`gemini-2.5-flash` "no longer available to new users" (404) and pointed
to `gemini-3.6-flash`, which works with our request shape and requires
thought signatures to be echoed on tool rounds (done). The owner decides
the pinned name; nothing in code assumes one.

## Consequences

- Two routes beyond §10.1: `GET /v1/ai/status`, `POST /v1/ai/chat` (20/min/user).
- §30: the assistant is explanation over server numbers; no fitness
  arithmetic moves to the model.
- Gate 5 adds a second flow — natural-language programme requests
  extracted by the model, executed and validated by the deterministic
  generator — under the same seam and the same authority rule.
- Free-tier Gemini quotas (per-minute) surface as 429 "busy" to the user;
  a paid tier is required for production (§19.3).
