# Phase 14 — AI features: implementation plan

**Status** Written from the audit on 2026-10-21 and implemented in one pass on `phase-14` from `0dd02ff` (`phase-13-audit-fixes` with `phase-13` merged in). Acceptance pending the S24 manual checks.
**Decision record** [ADR-020](../decisions/ADR-020-ai-features.md).

## 1. What MASTER-SPEC asks for

- **§31 Phase 14:**
  - Tasks: the `AiDraft` contract; natural-language food parsing; explanation rephrasing with numeric validation; a kill switch; a token budget.
  - API `POST /nutrition/parse`. UI: an NL logging input and a draft confirmation sheet.
  - Tests: every AI output requires confirmation · implausible macros rejected · **an explanation containing a number absent from the input is discarded** · the kill switch disables all AI routes · the rate limit is enforced.
  - Acceptance: **nothing AI-derived enters the database without user confirmation** · the app is fully functional with `AI_ENABLED=false`.
  - Manual: parse 10 real meal descriptions; drafts are editable and confirmations accurate.
- **§19.1:** parsing and rephrasing are on the AI side; targets, ranking and every number the engine computes are not.
- **§19.2:** the `AiDraft` shape; foods resolve to a `foods` row or become an explicit estimate; macros outside plausible bounds (> 900 kcal/100 g, protein > 90 g/100 g) are rejected; an explanation with a number not in its input is discarded for the raw engine reason.
- **§19.3:** model names in `MODEL_FOOD_PARSE` / `MODEL_EXPLAIN`; the `AI_ENABLED` kill switch; 20 requests/hour/user; output token caps; every call's tokens logged. The paid-tier rule is overridden for the alpha (D1).
- **§13.4:** "AI-derived logs are always drafts."
- **§38 Phase 14:** paid tier · `AiDraft` · NL parsing · explanation validation · kill switch · token budget · confirmation-required test.

## 2. Decisions (ADR-020)

| # | Decision |
|---|---|
| D1 | **Free Gemini tier for the alpha** (owner, 2026-10-21), overriding §19.3's paid-tier rule; move to paid or Vertex before beta (BACKLOG O7). |
| D2 | NL logging is built now (§31), not V1.5 (§13.4 amended). |
| D3 | `ai_usage` ledger (migration 0017), one row per model call, tokens and outcome, never prompt or answer; not `audit_logs` (admin actions, Phase 16). |
| D4 | Per user: parse 20/h, explain 20/h, chat 60 model calls/h, 200k tokens per rolling 24 h; counted from `ai_usage`; the 20/min burst limit stays. All settings. |
| D5 | `POST /ai/explain { actionId }`: the server loads the user's own TODAY action; numbers checked (digits, fractions, words); discarded → the engine's detail. |
| D6 | Parse: the model reads names and amounts; the food database supplies the numbers at a portion of the food's own rows (exact, alias or prefix hits only — fuzzy counts as not found); unknown foods are bounded estimates logged as named quick adds (a §19.2 amendment); nothing stored; the phone logs what is confirmed through the existing queue. |
| D7 | `MODEL_FOOD_PARSE`, `MODEL_EXPLAIN` optional (→ `GEMINI_MODEL`); per-request model in the provider. |
| D8 | `AI_ENABLED` off → 503 `disabled` on chat, parse and explain; `/ai/status.enabled`; the app hides the AI entry points. |
| D9 | `phase-13` merged into `phase-13-audit-fixes`; `phase-14` branched from it. |

## 3. Build (one pass, dependency order)

1. **Core:**
   - `ai/guard.ts`: `AiDraft`, `draftOf`, `numbersIn` and `checkExplanation`, `checkEstimate` with the §19.2 bounds;
   - `ai/portion.ts`: `choosePortion`;
   - tests.
2. **Contracts:** `ai.ts` — status `enabled`, the parse request/response, the draft item, match and estimate, the explain request/response; OpenAPI.
3. **Database:** migration 0017 (`ai_route`, `ai_outcome`, `ai_usage`) with a hand-written down; migration tests.
4. **API:**
   - env (`AI_ENABLED`, models, limits, budget) and `plugins/ai.ts` `AiConfig`;
   - `modules/ai/usage.ts` (`AiUsageRepository`, `AiBudget`);
   - `parse.ts` (`FoodParseService`), `explain.ts` (`ExplainService`);
   - chat gains the budget;
   - routes `POST /nutrition/parse` and `POST /ai/explain`;
   - integration tests on real Postgres with a scripted model.
5. **Mobile:**
   - `ai_draft.dart` (hand-written DTOs); `parseFood` and `explain`; `aiAvailableProvider`;
   - "Describe your meal" (an entry on Log food → a full-screen draft sheet);
   - `FoodLogger.logDraft`;
   - "Explain simply" in the TODAY why sheet;
   - the AI tab's switched-off state;
   - conformance, widget, layout and Home tests.
6. **Docs:** this plan, ADR-020, the MASTER-SPEC amendments, BACKLOG O7/O8, the report with the S24 checklist.

## 4. API

| Method | Path | Request | Response | Errors |
|---|---|---|---|---|
| POST | `/v1/nutrition/parse` | `{ text }` (2–500 chars) | `{ draft: AiDraft<{ items }>, model }` | 401 · 422 · 429 (hourly / daily) · 503 (off, not set up, provider, malformed) |
| POST | `/v1/ai/explain` | `{ actionId }` | `{ text, source: 'ai' \| 'engine', discarded }` | 401 · 404 (not the user's action) · 422 · 429 · 503 |
| GET | `/v1/ai/status` | — | `+ enabled` | 401 |
| POST | `/v1/ai/chat` | unchanged | unchanged | `+` 429 hourly/daily · 503 off |

A draft item is `{ phrase, quantity, unit, confidence, match | null, estimate | null, problem | null }`.
- `match`: `{ foodId, name, matchKind, basis, servingLabel, servings, row, snapshot }`.
- `estimate`: `{ name, grams | null, kcal, proteinG, carbG, fatG }`.

## 5. Tests that carry the acceptance

- **Nothing stored by a parse:** after a parse, `food_logs` for the user is empty. A log appears only through `POST /nutrition/logs` from what the user confirmed (API and widget tests).
- **Implausible macros:** core bounds tests; the API returns a problem, not an estimate.
- **New number discarded:** core (digits, decimals, fractions, words); API (`47`, `forty-seven` → engine words).
- **Kill switch:** API (503 `disabled` on all three routes, status `enabled: false`, no model call, no usage row, food search still 200); mobile (no Describe, no Explain, chat switched off).
- **Rate limit:** the 3rd parse at a limit of 2 is 429 with no model call; another purpose and another user are unaffected; an hour later it counts no more. Budget: once used up, all three purposes are 429; 24 h later it clears.

## 6. Out of scope

- TODAY and recovery in the chat context (BACKLOG O8, an owner decision).
- Photo logging (V2); barcode (V1.5).
- The food log in the chat context.
- A paid tier (D1, BACKLOG O7).
