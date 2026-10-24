# ADR-020 — AI features: meal drafts from words, checked explanations, a usage ledger and a kill switch

**Status** ACCEPTED 2026-10-22 — Phase 14 passed the owner's S24 manual checks. (Was PROPOSED: written from the Phase 14 audit (2026-10-21) and implemented on `phase-14`. Becomes ACCEPTED with Phase 14's acceptance (S24 manual checks pending).)
**Date** 2026-10-21
**Phase** 14
**Affects**
- MASTER-SPEC: §19.3 (provider tier, cost control), §19.2 (estimates), §13.4 (natural language moves to Phase 14), §9.2 (`ai_usage`), §10.1 (`/nutrition/parse`, `/ai/explain`), §31 Phase 14, §38 (on acceptance only).
- ADR-010 (FITOS AI): chat now sits behind the kill switch, the hourly limit and the token budget; `/ai/status` gains `enabled`.
- ADR-013 (food logging): AI drafts are logged through the ordinary search and quick-add logs; nothing new on the log path.
- ADR-017 (TODAY): the why sheet gains "Explain simply". No engine change.

---

## Context

**What §31 asks of Phase 14:**
- the `AiDraft` contract;
- natural-language food parsing (`POST /nutrition/parse`) with a draft confirmation sheet;
- explanation rephrasing with numeric validation;
- a kill switch and a token budget.

**Tests it names:** every AI output requires confirmation · implausible macros rejected · an explanation with a number absent from the input is discarded · the kill switch disables all AI routes · the rate limit is enforced.

**Acceptance:** nothing AI-derived enters the database without user confirmation, and the app is fully functional with `AI_ENABLED=false`.

**What already existed (Phase 6.6, ADR-010):** the `AiProvider` seam with Gemini, fake and not-configured providers; `/ai/status`; `/ai/chat` with a bounded context, read-only tools and a 20/min burst limit; error mapping to the §10 envelope.

## Decisions

1. **D1 — Free Gemini tier for the alpha (owner decision, 2026-10-21).**
   - The owner chose the free tier for now ("use free tier only … in alpha we do not care if Google have our data; later we will change").
   - This **overrides §19.3's hard rule** ("all production AI calls must run on a paid tier") for the alpha only. Google may use free-tier prompts to improve its products.
   - **Before beta, or before anyone outside the alpha group uses FITOS AI, move to a paid tier or Vertex AI.** Tracked as BACKLOG O7.
   - What each call sends, so the exposure is known:
     - **parse:** the meal text only. No profile, history or targets.
     - **explain:** one TODAY action's headline, detail and reason values (these can include the user's own targets and amounts).
     - **chat:** the Phase 6.6 context (profile, goal and targets, programme, today, recent sessions, volume). Health Connect data is still never sent.
   - Free-tier quotas are small; a quota refusal surfaces as "busy" (429), as in Phase 6.6.
   - The free tier also answers 503 ("overloaded") often: 2 of 12 calls in the spaced live smoke. The provider retries a 5xx **once** after 1 s. It never retries a 429, a bad key, a timeout or a malformed answer.
2. **D2 — Natural-language logging is built in Phase 14.** §13.4 listed it as V1.5; §31 puts `POST /nutrition/parse` and the NL input in Phase 14. §31 wins; §13.4 is amended.
3. **D3 — A usage ledger, `ai_usage`, not `audit_logs`.**
   - `audit_logs` (§9.2) is for admin actions and data export/delete, and it does not exist yet (Phase 16).
   - `ai_usage`: `id`, `user_id` (cascade), `route` (`chat` | `parse` | `explain`), `model`, `input_tokens`, `output_tokens` (non-negative, a check), `outcome` (`ok` | `discarded` | `failed`), `created_at`; index `(user_id, created_at)`. Migration 0017 with a hand-written down.
   - One row per model call (chat: one per tool round). Never the prompt or the answer.
4. **D4 — Limits per user, counted from `ai_usage`** (so they survive restarts and hold across instances):

   | Purpose | Per hour | Setting |
   |---|---|---|
   | parse | 20 | `AI_PARSE_PER_HOUR` |
   | explain | 20 | `AI_EXPLAIN_PER_HOUR` |
   | chat | 60 (model calls, including tool rounds) | `AI_CHAT_PER_HOUR` |
   | all purposes | 200,000 tokens in the last 24 h | `AI_DAILY_TOKEN_BUDGET` |

   - Over a limit: 429 `RATE_LIMITED` before any model call, with a plain message.
   - The Phase 6.6 burst limit (20 requests a minute on every AI route) stays.
5. **D5 — "Explain simply": `POST /ai/explain { actionId }`.**
   - The phone sends only the id of a TODAY action it was shown. The server loads that action for that user (404 otherwise), so nothing else can be put in front of the model.
   - The model sees `{ headline, detail, facts }` and may only reword it (at most 3 sentences, no medical advice, plain text).
   - **Numeric validation (§19.2):** every number in the answer must appear in the input. Digits, decimals, thousands separators, fractions and number words ("forty-seven", "a dozen", "half") all count. Otherwise the answer is discarded and the engine's own detail is returned with `source: 'engine'` and `discarded: 'new-number'`. An empty answer or one over 600 characters is discarded the same way.
   - The check is strict on purpose: an ordinary word like "one" that the input does not contain also sends back the engine's words. That costs a plainer sentence, never a wrong number.
   - Nothing is stored except the usage row. It is not a TODAY event.
6. **D6 — Parsing: the model reads, FITOS supplies the numbers.**
   - The model returns JSON only: per food, the phrase, a common name, the quantity and unit as said, its own grams and macro estimate, and a confidence. It is Zod-checked (at most 8 foods); anything else is a malformed answer (503).
   - Each name goes through the Phase 7 food search (trigram + alias, top hit). **Only an exact, alias or prefix hit counts as a FITOS food.** A fuzzy-only hit is treated as not found: in the live smoke "brown bread" fuzzy-matched "Sugars, brown", and a wrong food with confident numbers is worse than a labelled estimate.
   - A portion of **that food's own rows** is chosen in core (`choosePortion`):
     1. grams or ml → the weighed row;
     2. a unit word in a serving label → quantity ÷ the label's count (two pieces of idli are one "2 pieces" serving);
     3. a count ("2 pieces") and a serving that counts the food ("2 eggs", not "1 katori") → by count;
     4. the model's gram guess → a weighed row;
     5. otherwise the first serving row.

     Servings are clamped to 0.1–20 in hundredths. The draft carries the row, so the phone can preview a changed portion.
   - Confidence is never above the model's. A prefix match caps it at medium, and so does a guessed portion.
   - **A food FITOS does not have** becomes the model's estimate, kept only within §19.2's bounds:
     - per 100 g: ≤ 900 kcal, ≤ 90 g protein, ≤ 100 g carbohydrate or fat;
     - per portion: ≤ 3,000 kcal and ≤ 2,000 g;
     - energy consistent with the macros (within half to one and a half of 4/4/9, ±30 kcal).

     An estimate is always low confidence. One outside the bounds becomes a *problem* ("enter it yourself").
   - **Amendment to §19.2:** an estimate is logged as a **named quick add**, not an "estimated custom food". Quick add already means "the user's own numbers" in FITOS (ADR-013 J6). Creating `foods` rows from model output would put model numbers into the shared food table, which §19.1 rules out.
   - **Nothing is stored.** The draft is returned (`source: 'ai-draft'`, `requiresConfirmation: true`, literal types). The phone logs what the user confirms: one search log for the FITOS foods (ids, rows, servings — no numbers; the server snapshots) and one quick add per estimate, through the ordinary offline queue. The API test asserts that a parse writes no `food_logs`.
7. **D7 — Model per purpose.** `MODEL_FOOD_PARSE` and `MODEL_EXPLAIN` (optional); unset → `GEMINI_MODEL`. The provider takes a per-request model. No model name is in code.
8. **D8 — Kill switch `AI_ENABLED`** (default on; `false`, `0`, `off` or `no` turn it off).
   - Off: `/ai/chat`, `/nutrition/parse` and `/ai/explain` answer 503 `UPSTREAM_UNAVAILABLE` (issue `disabled`) without calling the model. `/ai/status` says `enabled: false`.
   - The app hides "Describe your meal" and "Explain simply", and the AI tab says "Switched off for now". Everything else works.
   - Unknown status (offline, an error) also hides the entry points.
9. **D9 — Branching.** `phase-13` was merged into `phase-13-audit-fixes` (`0dd02ff`) and `phase-14` branched from it. Not merged anywhere else.

## Not in Phase 14

- **TODAY and recovery in the chat context.** §31 Phase 11 and 13 point here, but the Phase 14 task list does not include them, and with D1 they would send more health-adjacent data to a free-tier model. Left for an owner decision (BACKLOG O8).
- Photo logging (V2) and barcode (V1.5) are unchanged.
- The food log stays out of the chat context (`foodLogShared: false`).

## Consequences

- A meal can be logged from one sentence. The numbers are the food database's wherever FITOS knows the food, and the user sees and edits everything before anything is stored.
- Free-tier quotas limit how much the alpha can use AI. The ledger shows real token use for sizing the paid tier.
- Adding a purpose means a new `ai_route` enum value (a migration) and a limit setting.

## Amendment — the AI food guide (beta 3.6, owner 2026-10-24, F15)

**`POST /nutrition/guide`, "What should I eat?":** up to 3 plates for one meal of today. Eat → *Ask FITOS AI what to eat*.

1. **What it picks from:**
   - **What the person has**, ticked or typed. Each item is matched to the food database (exact, alias or prefix; never fuzzy).
     - Unknown ones are listed as *not in FITOS yet*, never guessed.
     - One whose name breaks their diet, or contains or likely contains one of their allergens, is left out and said so (core `haveAllowed`).
     - An allergen the name cannot rule out becomes *"Check the label for: …"* on the plate.
   - **Their mess's menu**, through Phase 10's hard rules (`isDietAllowed`, allergens confirmed free, excluded dishes), with the stored estimates.
2. **What the model does:** it answers with candidate ids and servings in quarters (0.25–4) only. Core `readGuideAnswer` drops unknown ids and repeats, and caps the answer at 3 plates of 5 items.
3. **The numbers:** every one is the database's (`snapshotNutrition`) or the mess table's (stored macros × servings). Each plate shows how it fits what is left of today's calories and protein.
4. **What the model sees:** the meal, the candidates' names, servings and rough numbers, what is left of today, and what they feel like. Never their name, weight or history.
5. **Logging:** nothing is stored by the call. **Log this** logs the plate as one search log (foods) and one mess log (dishes), through the queue.
6. **Limits:** premium, the FITOS AI consent, its own purpose in `ai_usage` (`guide`, migration 0033), `AI_GUIDE_PER_HOUR` (default 10) and `MODEL_FOOD_GUIDE`, and the `food-guide` switch (ADR-033). The privacy policy says what is sent.
