## PHASE 14 — AI FEATURES — IMPLEMENTATION COMPLETE, S24 ACCEPTANCE PENDING

**Date** 2026-10-21 · **Branch** `phase-14` from `0dd02ff` (`phase-13-audit-fixes` with `phase-13` merged in) · **not merged**

**Status:** **implemented and tested; NOT accepted, NOT frozen.**
- The S24 manual checks (§8) have not been run.
- §38 Phase 14 is not ticked; ADR-020 is PROPOSED.

**Commits**
- `84c16f7` — core: the `AiDraft` shape, the numeric check for explanations, the §19.2 bounds for estimates, `choosePortion`
- `d1c5ca8` — contracts: status `enabled`, the parse and explain shapes
- `a3dc54b` — API: `POST /nutrition/parse`, `POST /ai/explain`, `ai_usage` (migration 0017), hourly limits and the daily token budget, the kill switch, models per purpose; integration tests; OpenAPI
- `d382b5c` — mobile client: DTOs, `parseFood` / `explain`, `aiAvailableProvider`; conformance
- `d6119df` — mobile UI: Describe your meal, Explain simply, the AI tab's switched-off state; widget, layout and Home tests
- `4109fa8` — fixes from the live Gemini smoke (§6)
- `028a348` — docker compose and env examples carry the Phase 14 settings
- plus the documentation commit: this report, the plan, ADR-020, the MASTER-SPEC and BACKLOG amendments

**Decision record:** [plan](../phase-plans/phase-14-plan.md), [ADR-020](../decisions/ADR-020-ai-features.md) (D1–D9).

### 1. BASELINE

- `phase-13-audit-fixes` with `phase-13` merged in (`0dd02ff`); `phase-14` branched from it.
- `main` untouched.
- At the start: migrations through 0016; Drift schema v3 (unchanged by Phase 14).

### 2. WHAT MASTER-SPEC REQUIRES (and where it is)

| Requirement (§31, §19, §13.4, §38) | Built |
|---|---|
| `AiDraft` contract (`source: 'ai-draft'`, `requiresConfirmation: true`) | core `ai/guard.ts`; contracts `foodDraftSchema` (literal types) |
| NL food parsing, `POST /nutrition/parse` | `modules/ai/parse.ts` |
| Foods resolve to a `foods` row or an explicit estimate | the Phase 7 search (exact/alias/prefix) + core `choosePortion`; estimates labelled |
| Implausible macros rejected (> 900 kcal/100 g, protein > 90 g/100 g) | core `checkEstimate` (also carbs/fat, portion size, energy consistency) |
| Explanation rephrasing, a new number → the engine's reason | `POST /ai/explain` + core `checkExplanation` |
| Kill switch `AI_ENABLED` | `AiBudget.assertEnabled` on chat, parse and explain; `/ai/status.enabled`; the app hides AI |
| Token budget, every call's tokens logged | `ai_usage` (§9.2 amended) + `AiBudget` |
| 20 requests/hour/user | parse 20, explain 20, chat 60 model calls (settings) |
| `MODEL_FOOD_PARSE` / `MODEL_EXPLAIN` | env, falling back to `GEMINI_MODEL` |
| NL logging input + draft confirmation sheet | Log food → "Describe your meal" |
| Paid Gemini tier | **deferred for the alpha by owner decision** (ADR-020 D1, BACKLOG O7) |

### 3. ACCEPTANCE CRITERIA (automated)

| Criterion | Evidence |
|---|---|
| **Nothing AI-derived enters the database without confirmation** | API: after a parse, `food_logs` for the user is empty; logs appear only through `POST /nutrition/logs`. Mobile: nothing is queued before Add. |
| **Fully functional with `AI_ENABLED=false`** | API: 503 `disabled` on all three AI routes, no model call, no usage row, food search 200. Mobile: no Describe, no Explain, the AI tab says "Switched off for now", the log sheet as before. |
| Every AI output requires confirmation | contracts: `requiresConfirmation` is `z.literal(true)`; the draft sheet logs only on Add |
| Implausible macros rejected | core bounds tests; API: the 5,000 kcal shake becomes a problem, not an estimate |
| A number absent from the input is discarded | core: digits, decimals, fractions, words; API: "47" and "forty-seven" → the engine's words, outcome `discarded` |
| Rate limit enforced | API: the 3rd parse at a limit of 2 is 429 before any model call; per purpose and per user; an hour later it clears. Budget: all three purposes 429; 24 h later it clears |

### 4. TESTS

| Suite | Count | New for Phase 14 |
|---|---|---|
| core | 890 | `test/ai-phase14.test.ts` (16) |
| contracts | 82 | the Phase 14 drafts block in `ai.test.ts` |
| API | 473 (33 files) | `phase14.integration.test.ts` (11), migration 0017, the 5xx retry, status `enabled` |
| Flutter | 657 | conformance (3), Describe your meal (5), its layout at 2 sizes × 2 text scales (4), Explain simply (4), chat switched off (1) |

- `flutter analyze --fatal-infos`: clean. TypeScript typecheck and lint: clean. OpenAPI: exported, no drift.

### 5. HOW IT WORKS (short)

- **Describe your meal:**
  1. The user types what they ate. Only that text goes to the model.
  2. The model names the foods and amounts; FITOS finds each in its database and picks a portion of that food's own rows.
  3. A food FITOS lacks is the model's estimate, labelled ESTIMATE, kept only within §19.2's bounds. Outside them it is NOT FOUND, to be entered by hand.
  4. The user steps portions, leaves items out, and taps Add. The FITOS foods go as one search log and each estimate as a named quick add, through the ordinary offline queue.
- **Explain simply:** in the TODAY why sheet. The server rewords the action's own words. If the rewording brings in any number the engine did not give, the engine's words come back instead, labelled "FITOS's own words".
- **Limits:** per user, from `ai_usage`. The kill switch is one setting and a container restart.

### 6. LIVE GEMINI SMOKE (free tier, `gemini-3.6-flash`, 2026-10-21)

Run in-process on the isolated `_test` database with the real key. The script was temporary and not committed.
- **Run 1 (back to back):**
  - 3 of 12 calls got Gemini 503s and 6 got 429s (the free-tier per-minute quota).
  - Two matching faults: "brown bread" → "Sugars, brown" (fuzzy), and "2 boiled eggs" → 0.91 × "2 eggs".
  - All four were fixed in `4109fa8`.
- **Run 2 (spaced 7 s):**

| Meal | Draft |
|---|---|
| 2 chapati and a katori of dal tadka | Chapati 2 × 1 piece · Dal tadka 1 × 1 katori |
| poha and a cup of chai | Poha 0.83 × 1 katori (guessed portion, flagged) · Tea 1 × 1 cup |
| 3 idli with sambar and coconut chutney | Idli 1.5 × 2 pieces · Sambar 1 katori · coconut chutney ESTIMATE 70 kcal |
| a plate of veg biryani and raita | Veg biryani 1 plate · Raita 1 katori |
| 2 boiled eggs and 2 slices of brown bread | Boiled eggs 1 × 2 eggs · brown bread ESTIMATE 150 kcal |
| masala dosa and filter coffee | Gemini 503 (before the retry existed) |
| one banana and a glass of milk | Gemini 503 (before the retry existed) |
| paneer butter masala with 2 butter naan | Paneer butter masala 1.67 katori (guessed) · butter naan ESTIMATE 520 kcal |
| 100 g chicken breast and a bowl of rice | chicken breast ESTIMATE 165 kcal · White rice (cooked) 1 katori |
| a protein bar and black coffee | both ESTIMATE (210, 2 kcal) |
| Explain "No session today" | AI: "You have no workout scheduled today. Set up a programme so FITOS can plan your sessions. A walk is a good start." |

- No `food_logs` were written by any parse.
- Tokens: about 390 per parse and about 200 per explanation.
- The 5xx retry (1 s, once) was added after run 2.

### 7. KNOWN LIMITS AND OPEN ITEMS

- **The free tier is small and flaky:** a few calls a minute, and occasional 503s (one retry now). Users will see "FITOS AI is busy" when several people use it at once. Fixed by the paid tier (O7).
- **Privacy (D1):** the alpha's prompts may be used by Google. Parse sends only the meal text. Explain sends one action's words and values, which can include the user's targets.
- **Estimates have no fibre.** They are logged as the user's own quick add (Eat shows them as such).
- **Online only:** Describe your meal needs the network to read the text; the confirmed logs then queue as usual. Explain simply needs the network and is not offered for a plan shown from the offline cache. If the AI status cannot be fetched (offline at launch), both are hidden.
- **Not built (owner decisions):** O7 (paid tier before beta) and O8 (TODAY and recovery in the chat context). Still open from before: O2 (§18 cap), O3 (merges), O6.

### 8. S24 MANUAL CHECKLIST

**Setup**
- **APK:** `Downloads\fitos-phase14-028a348-lan-172.16.205.231.apk` (`phase-14` @ `028a348`, API host baked in: `http://172.16.205.231:8080`).
- **API:** container `fitos-api` rebuilt from `phase-14`, migration 0017 applied (18 migrations), `/health` 200, AI enabled.
- **Backup** taken before the migration: `C:\Users\Jirans\FitOS-backups\fitos-20261021-160648.dump`.

**A. Describe your meal (§31 manual: 10 real meals)**
1. Eat → Log food: a "Describe your meal" box sits above Recent · Search · Saved meals · Quick add.
2. Open it: the field, the line "Only this text is sent to FITOS AI", and Read it.
3. For each of **10 real meals** (mess food, outside food, snacks), check:
   - every food you named appears, once;
   - FITOS foods show the FITOS tag and a sensible portion (e.g. "2 × 1 piece", "1 × 1 katori");
   - foods FITOS lacks show ESTIMATE with a believable kcal;
   - nothing you did not eat appears.
4. Use + / − on a portion: the kcal line and the total change.
5. Untick an item: the Add button's count drops.
6. Add: you return to Eat, and the meal shows the foods with the portions you chose. The estimates appear as quick adds with their names.
7. Read a meal, then go back **without** Add: nothing new on Eat.
8. Airplane mode → Read it: an offline message; nothing logged.
9. A nonsense text ("asdf"): "No food found in that"; Add stays off.

**B. Explain simply**
1. Home → tap a TODAY card → the why sheet shows "Explain simply".
2. Tap it: a box headed "IN PLAIN WORDS · FITOS AI". Its words agree with the detail above, and every number in it is one the card already shows.
3. Try it on 3–4 different cards. A box headed "FITOS'S OWN WORDS" is fine: it means the rewording was thrown away.

**C. Kill switch** (on the PC)
1. In `docker\.env` add `AI_ENABLED=false`, then run `docker compose up -d api` in `docker\`.
2. Reopen the app (or wait for it to refetch):
   - no Describe box on Log food;
   - no Explain simply in the why sheet;
   - the AI tab says "Switched off for now".
3. Search, quick add, a workout set and Home all work as usual.
4. Remove the line, and run `docker compose up -d api` again: the AI features come back.

**D. Regression**
- The AI tab still answers a question.
- Search, recent and quick add still log.
- TODAY cards, Progress and Recovery as in build 3.

**E. Large text**
- Android font size at maximum → Describe your meal with a draft: nothing cut off or overflowing, and Add reachable by scrolling.

**Accept Phase 14 when** A–E pass. Then:
- ADR-020 → ACCEPTED;
- §38 Phase 14 ticked, the paid tier marked deferred (O7);
- this report's status updated.

No merge without your approval.
