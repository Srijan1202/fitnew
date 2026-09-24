## PHASE 10 — Mess recommendations — AMENDMENT A/B IMPLEMENTED, AWAITING OWNER REVIEW AND A NEW S24 RUN

**Date** 2026-09-24 · **Branch** `phase-10` from `main` at `08a085b` (the accepted Phase 9, fast-forwarded per D26) · not merged (owner instruction)

**Commits**
- `d5b0234` — implementation plan for owner review (no code)
- `33c58f6` — core recommender and contracts
- `0edba9e` — `GET /v1/mess/menu/recommend`
- `cbf7224` — mobile: "What should I eat?", log this plate, Profile → Food
- `18fa3ad` — ADR-015 and the MASTER-SPEC amendments
- `d53126b`, `43b3cb6`, `6159f3f` — this report, and the APK address
- **After the first S24 run (Amendments A and B):**
  - `fb6a610` — the plan amendment and ADR-016, written before any code
  - `56c9443` — core meal composition, F1, the four estimate corrections (mess path), tests, sweep and latency
  - `7addd02` — migration 0012: the four stored estimates corrected, with provenance
  - `38eaca5` — the recommend contract and API (structure, component, `no-meal`, `dayRemainingKcal`, `smallestMealKcal`)
  - `94a5b15` — mobile: structure label, statuses, wording, conformance
  - `f4ca077` — `nothing-fits` exactly as C4 defines it: fall back through meal-grade tiers only
  - plus the docs commit (ADR-015 amendment, MASTER-SPEC) and this report update
- plus this report

**Decision record:** the owner approved the audit (D1–D25; D12 clarified, D13 modified, D18 deferred), then the [plan](../phase-plans/phase-10-plan.md) with 29 locked decisions. [ADR-015](../decisions/ADR-015-mess-recommendations.md).

**Status:** the first S24 run found the recommender suggesting single dishes as meals (Watermelon Juice for breakfast, White Rice for lunch, Rasam for dinner). The owner stopped acceptance, approved the meal-composition design (C1–C6) and a data correction (Amendment B), and both are implemented. Every automated gate passes. **Not accepted:** the owner reviews this report, then a new S24 run follows. The §38 Phase 10 boxes stay unticked.

### AMENDMENT A/B — after the first S24 run (2026-09-24)

**Why it happened** (reproduced exactly from the dev database, read-only):
1. **The fat target collapsed to 0.** Fat eaten was 39.2–67.2 g against a 49 g target, and the conservative rule subtracts the high end. ADR-015's `50 × (f − 1)/1` then cost every real meal 475–950 points, so the lowest-fat single item won.
2. **The search had no notion of a meal.** Any dish could be a plate alone, and global protein-density candidates could drop every staple.

**What changed** ([plan §20–§22](../phase-plans/phase-10-plan.md), [ADR-016](../decisions/ADR-016-meal-composition.md)):
- **A meal-component classifier** (`packages/core/src/mess/components.ts`). It works from term families, not dish lists; Phase 9 `role` is untouched. All 294 September dishes are frozen in a reviewed golden file.
- **Structure tiers are a constraint**, ranked before the score:
  - no drinks on any plate (C5);
  - no desserts or crisps at lunch or dinner (C6);
  - snacks labelled as snacks;
  - per-component candidates, so a staple always survives.
- **Meaningful alternatives (C3):** plates 2 and 3 replace a staple or protein anchor. The menu returns fewer plates rather than fake ones.
- **`no-meal` vs `nothing-fits` (C4)**, each explained in the app.
  - Clarified during implementation to match C4 exactly: a plate must fit within what is left today, and when the best structure doesn't, the recommender falls back through meal-grade tiers only (never into a limited tier because of calories).
  - The stored-menu sweep found 6 dinners that had wrongly returned `nothing-fits`.
- **F1 (C2):** over-penalties are measured against a normal-sized meal. Pinned: 18 g of fat with a fat target of 0 now costs 61.2, where it was 850.
- **Amendment B:** Curd Rice, Rice Papad, Chole Bhatura and Dahi Vada are corrected.
  - In core, only in the mess path. The Phase 7 path is unchanged, because the frozen Phase 7 seed reads it.
  - In stored rows, by migration 0012, only where a row still held the exact wrong values. Each change keeps its previous and new values in `mess_dish_nutrition_revisions`; down restores them.
  - Applied to the dev database: 4 rows corrected, 4 provenance rows.

**The S24 account now** (same data, real service):

| Meal | Before | Now |
|---|---|---|
| Breakfast | Watermelon Juice | Onion Uthappam + Sprouted Moong Dhal (complete meal); alternatives Poha + Moong Dhal, Uthappam + Masala Omelette |
| Lunch | White Rice | Chapathi + Dhal Makhani + Mochai Kara Kulambu (complete meal); alternative with White Rice |
| Snacks | Sweet Corn Chaat | Sweet Corn Chaat, labelled a snack |
| Dinner | Rasam | White Rice + Dhal + Brinjal Fry + Seasonal Fruit (complete meal); alternatives with Phulka and Veg Chow Mein |

**September sweep on the stored menus.** This covers every mess, day and meal in the dev database: 180 menus × 4 meals × 6 personas (vegetarian muscle-gain, vegetarian fat-loss, eggetarian, non-veg muscle-gain, the S24 state, and vegetarian with peanut and milk allergies). That is 4,320 recommendations and 7,449 plates.

| Check | Count |
|---|---|
| a breakfast, lunch or dinner plate that is a single supporting item | **0** |
| a lunch or dinner top plate without a staple when the filtered menu has one | **0** |
| soup, juice or fruit as the top meal | **0** |
| a drink on any plate | **0** |
| a dessert or crisp at lunch or dinner | **0** |
| a diet violation (primary or alternative) | **0** |
| an allergy violation | **0** |
| alternatives that do not differ by an anchor | **0** |
| a different result on repeat | **0** |

- **Statuses:** `ok` 3,812, `nothing-safe` 342 (allergy persona), `no-meal` 166 (snack menus with nothing but drinks and a dish the diet excludes), `nothing-fits` 0.
- **Slowest single recommendation:** 6.0 ms.
- **The same checks run in CI** as a core test over the September capture, plus a latency test on every real meal (each median-of-3 under 100 ms).

**Found and reported, not fixed** (outside the approved scope):
1. **Phase 9's ambient rule** matches `butter` and `sauce`. So "Paneer Butter Masala", "Butter Chicken Masala" and "Spring Roll With Sauce" count as ambient and never reach a plate. On 8 snack menus that leaves a non-vegetarian `no-meal`. Fixing it touches accepted Phase 9 classification, so it needs the owner's decision.
2. **The frozen Phase 7 food "Curd rice"** carries the same curd values as the old mess row (65–105 kcal). It is not changed, because Phase 7 is frozen.
3. **The first persona sweep showed** that with a whole day left (dinner with nothing logged), a plate can hold two staples with five servings (Curd Rice ×2 + Plain Dosa ×3 + Dal ×2 + Bhindi). This is within the caps and scoring; it is noted for review.


No contradiction with the locked decisions or the plan came up during implementation. Three readings were made and are recorded in ADR-015:
- "dinner: 19:00" means dinner from 19:00;
- the "drink" role is the core's `beverage` role;
- the carb, fat and goal reasons got their own codes.

### What was built

**Core** (`packages/core/src/mess`)
- **`allergens.ts` (new):**
  - `allergenStatus` returns contains, likely, free or unknown from the normalised dish name.
  - The exact-name `FREE` lists follow the cooking-fat rule (peanut, sesame, soy, mustard, milk).
  - Fish and shellfish are free only for veg or egg dishes.
  - Only `free` passes.
- **`classify.ts`:** a leading "Veg"/"Veg." is veg, after the meat and egg checks.
- **`parse.ts`:** each `/` alternative gets its own diet class (`alternativeDiets`).
- **`recommend.ts`:**
  - the fixed score (`SCORING`, `GOAL_WEIGHTS`; formula in ADR-015 §3);
  - the §15.1 roles, including fried, sweet, beverage and other at 1 serving;
  - `dishVerdicts` gives the first failing step for every dish;
  - `searchPlates` builds items from `snapshotNutrition`, so the preview equals the log;
  - deterministic tie-breaks;
  - `currentMealSlot` now uses 11/16/19.
- **`recommendation.ts` (new):**
  - meal share (0.25/0.35/0.10/0.30 over the meals still to come);
  - the conservative meal target;
  - the default meal;
  - statuses;
  - the honest shortfall (`[T − high, T − low]`, `menuMax`, `menuCanMeet`);
  - `recommendMeal`.

**Contracts:** `mess-recommend.ts`:
- query `{date?, mess?, slot?}` (strict);
- 7 statuses and 27 reason codes;
- the reason, plate, item, gap and dish-outcome schemas;
- OpenAPI regenerated.

**API:** `GET /v1/mess/menu/recommend` (`recommend-service.ts`, `recommend-repository.ts`)
- **Data:** the caller's own diet, allergies (severity ignored), goal, targets, today's totals and logged meals, variety (mess dishes logged in the 3 days before the menu date), and post-workout (a session completed within 3 h, today).
- **Menu:** the Phase 9 stored menu and stored estimates.
- **Errors:** 422 for a date other than today or tomorrow; 404 without a mess.
- **Unchanged:** no migration; nothing stored; the `/mess/menu` and logging contracts.
- **CI:** the smoke check adds a 401 check for the route.

**App**
- **MESS:** "WHAT SHOULD I EAT?" sits above "THE MENU", with:
  - a meal bar;
  - a thali drawing;
  - per-dish servings with kcal and protein ranges;
  - estimate confidence;
  - reasons worded from the codes (`recommend_words.dart`, the only place a code becomes text);
  - the shortfall line;
  - up to two other plates;
  - "Why not" for every dish, with its alternatives and their classes;
  - the filter line ("Vegetarian · no known peanut or milk ingredient", tap → Profile → Food) and the cross-contact note when allergies are set.
- **Today:** **Log this plate** makes one mess log with one item per dish, through the Phase 8 queue (retry-safe, works offline).
- **Tomorrow:** a planning plate, with no log button.
- **Other states:**
  - a past date or a date beyond tomorrow: a rule line and no request;
  - offline: "Suggestions need a connection", never an earlier plate.
- **EAT:** "Suggested plate ›" under today's mess strip.
- **Profile → Food:** diet type and allergies with severity, saved with `PUT /user/diet-preferences`; saving refetches the suggestion. There is no excluded-dish UI (D18 deferred).

### Found and fixed during implementation

- **Severity chips overflowed:** the shared allergy row's chips overflowed a 360 dp screen by 60–270 px once an allergy was ticked. This bug was already in onboarding. The chips now wrap.
- **Scrolling reset the section:** the MESS list is lazy, so scrolling to the end disposed "What should I eat?". That lost the chosen meal and plate, and scrolling back refetched. The section is now kept alive, and a regression test fails without the fix.
- **Existing MESS tests:** two needed narrower finders, because "Phulka" now also appears on the plate and the menu sits lower.

### TESTS

| Suite | Result | New in Phase 10 |
|---|---|---|
| core | **724 passed** (12 files; 646 before Amendment A) | 104: slot boundaries; meal share and target; default meal; every constant and goal weight pinned, plus each score term; **diet safety across every real menu**; allergen status table; **allergy hard filter across real menus** (every plate dish confirmed free, severity irrelevant); alternatives; the "Veg" prefix; snack plates; menu states and zero budget; shortfall (exists only when high < T, never inflated, `menuCanMeet`); deterministic, < 100 ms, coded reasons; variety; post-workout; the six personas snapshotted |
| contracts | **66 passed** (10 files) | 4: query strictness, statuses and codes, reasons carry no text, the response shape |
| API | **394 passed** (27 files; incl. migration 0012 up/down, meals-not-dishes on every mess and meal, the corrected estimates) | 18 recommend integration tests (real Postgres, date-shifted capture) |
| Flutter | **534 passed** (structure label, `no-meal`, `nothing-fits` numbers, drink under "Why not", conformance for the new shapes) | 34: 30 in `recommend_test.dart` and 4 conformance tests |

**Persona snapshots** (`packages/core/test/fixtures/personas/`): `vegetarian-vit`, `eggetarian-vit`, `nonveg-vit`, `allergy-restricted`, `stale-mess-endpoint`, `protein-deficit`. Each file holds the frozen input and the ranked output, so any ranking change shows as a diff.

**API integration tests:**
- **Errors:** 401, 404 and 422 (past day, the day after tomorrow, bad meal).
- **Plates:** core and contract allergen lists agree; a vegetarian lunch gets ranges, confidence, coded reasons, filters and only veg dishes; a snack gets a plate.
- **Estimates and logging:**
  - plate items equal the Phase 8 snapshot of the stored estimate;
  - logging the plate stores exactly those numbers, once;
  - a changed estimate changes the next plate, but not the logged snapshot.
- **Safety and privacy:**
  - allergies are a hard filter, and severity changes nothing;
  - no data crosses users;
  - browsing another mess applies the caller's own filters.
- **Dates and meals:** tomorrow is planning only; the default is the next unlogged meal.
- **Statuses:** zero budget (no plate, protein reported); no targets; inferred menus are labelled, unavailable menus get no plate, and a stale copy says so.
- **Scoring inputs:**
  - post-workout counts within 3 h, not 4 h;
  - variety penalises and never excludes;
  - the shortfall is the top plate's own gap.
- **Determinism and speed:** identical twice; p95 < 200 ms.

**Flutter tests:**
- **The plate:** thali, servings, ranges, confidence and worded reasons; the filter line; "no known … ingredient" with the cross-contact note.
- **Logging:**
  - one mess log with one item per dish at whole servings, for today;
  - offline, the queued log carries no numbers and syncs once.
- **Dates and meals:** tomorrow shows a planning plate with no log button; a past day sends no request; choosing a meal requests that meal.
- **States:** offline shows the connection state and never the earlier plate; each of the 6 non-ok statuses gets its own message and no plate; zero budget names the protein; inferred and already-logged are both said.
- **Why not and shortfall:** other plates; "Why not" with alternatives; the shortfall range.
- **Navigation and editing:** the keep-alive regression test; the EAT link; Profile → Food saves one PUT (severity kept), a failed save keeps the form, and the summary line.
- **Wording:** every plate and dish code has words.
- **Layout:** no overflow at 411×891 and 360×640, with 100 % and 200 % text.
- **Conformance** against `openapi.json`: response, filters, target, plate, item, totals, shortfall, gap, dish and alternative keys; the status enum; every server reason code has wording; the query parameters; a JSON round trip.

**Checks** (run locally on the final code):
- `tsc`: `pnpm typecheck` clean.
- ESLint: `@fitos/contracts` and `@fitos/api` clean. `@fitos/core` has no lint script. `apps/admin`'s `next lint` stops at an interactive setup prompt; admin is untouched since Phase 0 and not linted in CI.
- `pnpm build`: clean.
- Flutter:
  - `dart analyze --fatal-infos`: no issues;
  - `dart run custom_lint`: no issues;
  - `dart format --set-exit-if-changed`: 0 changed;
  - the full suite also ran locally this phase.

**CI on `18fa3ad` (all green):**
- **ci-core ✓**
- **ci-api ✓:** typecheck, lint, tests, build, the image migrates, seeds and boots, and the smoke check including the new route's 401.
- **ci-mobile ✓:** analyze `--fatal-infos`, custom_lint, format, the full Flutter suite, APK.

### BUILDS

- **LAN API container:** `docker compose up --build -d api` (development), rebuilt from `phase-10`. `GET /v1/mess/menu/recommend` answers 401 without a session.
- **LAN APK:** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (debug, `.\tool\alpha.ps1`), built from `phase-10` at `18fa3ad`. It targets `http://10.52.198.11:8080` (the PC on the S24 hotspot), and `/health` returned 200 at build time. The owner installs it by hand; no phone was connected over adb.

The PC's address depends on the network it joins. A first build targeted `172.16.205.86` (another Wi-Fi) and was replaced when the PC moved back to the hotspot. **Rebuild with `.\tool\alpha.ps1` whenever the address changes.**

### S24 MANUAL ACCEPTANCE — PENDING (owner)

Install the new APK. The PC and the phone must be on the same Wi-Fi, with the API container running. Then check (decision 26, plus 17–20 for Amendment A):

| # | Check | How | Result |
|---|---|---|---|
| 1 | Vegetarian dinner | Profile → Food: Vegetarian, no allergies. MESS → Dinner. Every plate dish and every alternative is veg; "Why not" lists meat/egg dishes as "not vegetarian". | pending |
| 2 | Eggetarian dinner | Switch to Eggetarian. Egg dishes may appear; meat never. | pending |
| 3 | Non-veg dinner | Switch to Non-vegetarian (non-veg mess). Plates may include meat; compare with 1–2 on the same dinner. | pending |
| 4 | Allergy-restricted | Add milk (any severity). Plates contain only confirmed-free dishes (often white rice only, or "nothing safe"); the filter line says "no known milk ingredient"; the cross-contact note shows; changing severity changes nothing. | pending |
| 5 | Protein-deficit | With a high protein target remaining, the top plate leads with protein and states its protein range against the target. | pending |
| 6 | Snack | MESS → Snacks: a plate appears (fried, sweet or drink allowed at 1 serving). | pending |
| 7 | Zero-calorie | Log enough to reach today's kcal target; the meal shows "target reached", no plate, and the protein still needed. | pending |
| 8 | Shortfall | A meal whose best plate cannot reach the protein target (e.g. vegetarian dinner late in the day) shows "X–Y g protein below this meal's T g", with the menu's maximum. | pending |
| 9 | Post-workout | Finish a workout, then open the next meal within 3 h: "After your workout: … carbs" appears among the reasons. | pending |
| 10 | Variety | A dish logged from the mess yesterday or earlier shows "you had it on N of the last 3 days" and is not excluded. | pending |
| 11 | Tomorrow planning | Next day on MESS: breakfast by default, a planning note, no log button. | pending |
| 12 | Log this plate | Today: tap Log this plate. EAT shows one mess log with each dish at its servings and numbers equal to the plate; the meal's dishes show as logged on the menu. | pending |
| 13 | Profile editing | Profile → Food: change diet and allergies, save; the suggestion refetches with the new filter line. | pending |
| 14 | Offline | Airplane mode: MESS shows the saved menu and "Suggestions need a connection", with no plate. | pending |
| 15 | No non-veg for vegetarian | Across meals and messes browsed while vegetarian, no non-veg or unknown dish appears on a plate. | pending |
| 16 | No allergic dish | With allergies set, no plate dish contains, likely contains, or is unconfirmed for an allergen (check "Why not"). | pending |
| 17 | A meal, not a dish (the first run's cases) | Same account, same day. Breakfast, lunch and dinner each show a staple with a protein, and a "Complete meal" (or "Meal · …") label. Never Watermelon Juice, White Rice alone, or Rasam alone. | pending |
| 18 | Drinks, desserts, crisps | Juice and tea never appear on a plate; papad, appalam and desserts never appear at lunch or dinner. "Why not" says why, and they can still be logged from the menu. | pending |
| 19 | Meaningful alternatives | Other plates change the staple or the protein (e.g. Phulka instead of Rice), never just add rasam or curd. | pending |
| 20 | Limited menu, no-meal, nothing-fits | With a milk allergy at lunch: "Limited menu · no protein dish" plus the shortfall. A snack of only drinks says no meal can be made. With almost no calories left: "even the smallest (about X kcal) is more than you have left today (Y kcal)". | pending |

### MASTER-SPEC AMENDMENTS (minimal; reasons in ADR-015)

- **§5 table:** budget deferred.
- **§10.1:** `/mess/menu/recommend` parameters and statuses; `/nutrition/recommendations` deferred.
- **§14.5:** the leading "Veg", alternatives, confirmed-free allergens, the cooking-fat rule, and what the app says.
- **§15.1:** roles, the meal target, the exact score and constants; budget tier removed.
- **§15.2:** the shortfall definition.
- **§26.2:** the six food personas land in Phase 10.
- **§31 Phase 10:** mess-only; general recommendations and budget deferred.
- **§33:** recommendations are never stored or shown offline.
- **§38 Phase 10:** budget annotated as deferred; **boxes unticked** pending acceptance.

### KNOWN LIMITATIONS

- **Allergies:** the lists are conservative by design. Peanut, sesame, soy, mustard and milk leave very few dishes. A milk allergy at the men's veg lunch gets white rice only, and a plate may be "nothing safe". A wider list needs ingredient data FITOS does not have.
- **Milk and tea are ambient** (§15.1), so breakfast protein is often short for vegetarians. The shortfall says so.
- **Estimates:** they are medium or low confidence (Phase 9 cap), and fibre is not known. Corrections stay pending and never change a plate.
- **Variety** counts only mess dishes logged from the mess.
- **Post-workout** needs a workout completed in FITOS within 3 h today.
- **Deferred:**
  - budget (no price data);
  - general recommendations and `/nutrition/recommendations`;
  - "don't suggest this" (D18);
  - persistence and events (Phase 11);
  - AI wording;
  - Cloud Scheduler for the mirror (GCP paused; the local development timer still runs).
- **Pre-existing:** the `automatic_sync_test.dart` teardown flake (since Phase 6.6); `apps/admin` lint needs an interactive setup.

### INTENTIONALLY NOT DONE

- No merge into `main`, and no Phase 11 or Phase 14 work.
- No GCP, billing, Cloud Run, Artifact Registry, Secret Manager, WIF or DNS changes.
- No classification of the 305 Phase 7 foods.
- No user-corrected precedence.
- No migration.
