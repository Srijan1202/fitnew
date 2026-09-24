## PHASE 10 — Mess recommendations — ACCEPTED

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
- **Correction pass after the owner's review:**
  - `bfec183` — the ambient check is context-aware (blocker 1)
  - `91ff5c8` — the Home test pins its hour (a pre-existing test fault that surfaced)
  - plus this report update
- plus this report

**Decision record:** the owner approved the audit (D1–D25; D12 clarified, D13 modified, D18 deferred), then the [plan](../phase-plans/phase-10-plan.md) with 29 locked decisions. [ADR-015](../decisions/ADR-015-mess-recommendations.md).

**Status:** **ACCEPTED and FROZEN** by the owner on 2026-09-24, after the S24 manual acceptance passed **20/20** on the corrected APK (below). The §38 Phase 10 boxes are ticked. `phase-10` is **not merged** into `main` (owner instruction); `main` stays at the accepted Phase 9 commit `08a085b`.

History: the first S24 run found the recommender suggesting single dishes as meals (Watermelon Juice for breakfast, White Rice for lunch, Rasam for dinner). The owner stopped acceptance and approved the meal-composition design (C1–C6) and a data correction (Amendment B). After reviewing that implementation, the owner required a correction pass (the ambient check). The corrected build then passed.

### ACCEPTANCE AND CLOSEOUT (2026-09-24)

- **S24 manual acceptance:** **20/20 PASS** (owner, Samsung Galaxy S24), covering checks 1–16 (decision 26) and 17–20 (Amendment A). See the table below.
- **Accepted build:**
  - APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (debug, LAN), built from `91ff5c8` for `http://172.16.205.86:8080`. The host was verified inside the APK (`kernel_blob.bin`, `network_security_config.xml`).
  - API: the LAN container (`docker compose up --build -d api`, development), rebuilt from `91ff5c8`, with migration 0012 applied to the dev database.
- **Code head of the accepted build:** `91ff5c8`. Every commit after it is documentation only (`c292579`, and this closeout commit).
- **Automated results at the accepted code:**
  - suites: core **747**, contracts **66**, API **394** (27 files), Flutter **534**;
  - checks: `tsc`, ESLint, build, `dart analyze --fatal-infos`, custom_lint and format all clean;
  - CI: **green on `91ff5c8`** (ci-core, ci-api, ci-mobile) and on the docs-only `c292579`.
- **Final September sweep** (stored menus, dev database, 180 menus × 4 meals × 6 personas): 4,320 recommendations, 7,516 plates.
  - **Zero** on every check: single-supporting meals, missing staples, soup/juice/fruit as the meal, drinks on plates, desserts or crisps at lunch or dinner, diet or allergy violations, non-meaningful alternatives, nondeterminism.
  - Statuses: `ok` 3,834, `nothing-safe` 342, `no-meal` 144, `nothing-fits` 0.
  - Performance: the slowest single recommendation took 7.3 ms. The CI latency test (every real September meal, median of 3, under 100 ms) passes.
- **What Phase 10 delivered** (details in the sections below and in ADR-015 and ADR-016):
  - mess-only recommendations (`GET /v1/mess/menu/recommend`);
  - fixed, pinned scoring with F1;
  - the meal-composition system: components, structure tiers as a constraint, no drinks on plates, no desserts or crisps at lunch or dinner, meaningful alternatives, `no-meal` / `nothing-fits`, and the meal-grade fallback;
  - the confirmed-free allergy filter;
  - the context-aware ambient classifier;
  - the four Phase 9 estimate corrections (migration 0012, with provenance);
  - the app's "What should I eat?", with Log this plate and the Profile → Food editor.
- **The three-staple-serving constraint was NOT implemented.** It was proposed with evidence in the correction pass and did not receive an implementation decision before acceptance. The accepted build does not contain it. The rules in force are: at most 2 distinct `staple` dishes, and 1 `complete` dish counted separately, within the existing serving caps (rice-type 2, bread-type 3) and 8 servings per plate.
  - Consequence: plates with 4 or more staple servings (up to 6) still occur, but only when a meal's target is at least 1.3× a normal meal (e.g. dinner with nothing logged). They never occur at normal-sized targets.
  - The proposal (count a complete dish as a staple; at most 3 staple servings) is recorded under *Correction pass → 3* and listed as deferred.


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

**Found and reported** (the owner decided afterwards):
1. **Phase 9's ambient rule** matched `butter` and `sauce` anywhere in a name. **Fixed in the correction pass (below).**
2. **The frozen Phase 7 food "Curd rice"** (owner: stays deferred; not a Phase 10 blocker) carries the same curd values as the old mess row (65–105 kcal). It is not changed, because Phase 7 is frozen.
3. **The first persona sweep showed** that with a whole day left (dinner with nothing logged), a plate can hold two staples with five servings (Curd Rice ×2 + Plain Dosa ×3 + Dal ×2 + Bhindi). This is within the caps and scoring; it is noted for review.


No contradiction with the locked decisions or the plan came up during implementation. Three readings were made and are recorded in ADR-015:
- "dinner: 19:00" means dinner from 19:00;
- the "drink" role is the core's `beverage` role;
- the carb, fat and goal reasons got their own codes.

### CORRECTION PASS — after the owner's review of the implementation report (2026-09-24)

**1. Ambient detection is context-aware (blocker, fixed in `bfec183`).**
- **The fault:** Phase 9's `isAmbient` matched `butter`, `sauce`, `bread` or `milk` anywhere in a name, which hid real dishes.
- **The rule now:** an item is ambient only when it **is** the accompaniment. Its name must **end** with an ambient term (the head noun), and a trailing "with …" clause is ignored, because it names what comes alongside.
- **No vocabulary was removed.** The effect is computed on read (menus are parsed on read), so no data changes.

| September dish | Before | Now |
|---|---|---|
| Paneer Butter Masala, Butter Chicken Masala | ambient (never on a plate) | a dish (protein) |
| Spring Roll With Sauce | ambient | a dish (snack) |
| Bread Halwa, Milk Peda | ambient | a dish (dessert) |
| Bread, Butter, Jam, Pickle, Garlic Sauce, Tea, Coffee, Milk, Butter Milk, Rose Milk, Chocos | ambient | ambient (unchanged) |

- **Regression tests:**
  - the classification table: the five dishes above; Butter Naan is not ambient; Garlic Sauce, Pickle, Mango Pickle, Butter, Bread, Jam, Butter Milk, Tea, Masala Tea, Coffee, Milk, Cold Milk, Rose Milk, Chocos and Corn Flakes are;
  - Paneer Butter Masala and Butter Chicken Masala reach plates, while Pickle, Garlic Sauce, Bread, Butter and Jam stay ambient in the same menus;
  - the real men's special snack of 9 Sep (Spring Roll With Sauce) is a snack again, not `no-meal`.

**2. Full September sweep rerun** (stored menus, dev database, after the fix): 4,320 recommendations, 7,516 plates.
- **Every check is still 0:**
  - a single supporting item as a meal;
  - a missing staple when one exists;
  - soup, juice or fruit as the top meal;
  - a drink on a plate;
  - a dessert or crisp at lunch or dinner;
  - diet or allergy violations;
  - look-alike alternatives;
  - different results on repeat.
- **Statuses:** `ok` 3,834, `nothing-safe` 342, `no-meal` 144, `nothing-fits` 0.
  - The 22 former `no-meal` snacks from the ambient fault now get a snack.
  - The 144 left are one menu shape: Brownie Cake (diet unknown in a non-veg mess, so excluded for vegetarian and eggetarian users) with only drinks. That is correct.
- **Slowest single recommendation:** 7.3 ms. The CI latency test (every real September meal, median of 3, under 100 ms) passes.

**3. Staple-heavy plates: analysis and proposal (no rule changed).**

Scope: all 6,760 breakfast, lunch and dinner plates of the sweep (snacks excluded).

| Measure | Result |
|---|---|
| Staple servings per plate (staple + complete dishes) | 1: 2,883 · 2: 1,878 · 3: 755 · 4: 979 · 5: 241 · **6: 24** |
| Total servings per plate | at most 8 (the existing cap); 7 servings on 2,474 plates |
| Plates with ≥ 4 staple servings | **1,244 (18.4%)**, of which 470 are top plates |
| Three staple-type dishes on one plate | **76**. A complete dish (e.g. Egg Fried Rice) is not counted toward "at most 2 distinct staples" |

**By meal-target size.** Tk is the meal's kcal target; a normal meal is the day target × the meal weight.

| Tk vs a normal meal | Plates | Staple servings seen | Three staple-type dishes |
|---|---|---|---|
| < 1.3× | 2,546 | max **3** (1: 2,166 · 2: 360 · 3: 20) | 0 |
| 1.3–2× | 2,178 | max 5 (≥ 4 on 167) | 14 |
| ≥ 2× | 2,036 | max 6 (≥ 4 on 1,077) | 62 |

- **Worst examples:** men's non-veg dinner, 1, 8, 15 and 22 Sep, with a target of 2,400 kcal against a normal dinner of 720. The plate is Methi Chapathi ×3 + White Rice ×2 + Egg Fried Rice + Gobi Manchurian, about 1,210 kcal and six staple servings.
- **The optimizer is buying score with staples.** On the 470 heavy top plates, cutting each staple back to one serving would lose 16.2 points on average: 8.7 from staple protein and 10.3 of kcal under-penalty avoided. The shape and carb terms barely push back.
- **The cause** is an oversized meal target. When earlier meals are unlogged or past (e.g. dinner with nothing logged), one meal is asked to carry most of the day (ADR-015 meal share), and staples are the cheapest way to fill it. At normal-sized targets it never happens.

**Proposed constraint (smallest found; not implemented, awaiting the owner):**
1. **Count a complete dish as a staple for "at most 2 distinct staples".** The dish already contains a staple.
2. **Allow at most 3 staple servings per plate**, with a complete dish counting as 1 serving.
   - The bound is taken from the data: no plate at a normal-sized target ever used more than 3.
   - Still allowed: Rice ×1 + Chapathi ×2 + protein + vegetable; Chapathi ×3 + protein + vegetable; Rice ×2 + Phulka ×1 + protein + vegetable.

**Simulated on the same sweep** (scratch copy of core; nothing committed):

| | Now | (1) only | (1) + ≤ 4 | **(1) + ≤ 3** |
|---|---|---|---|---|
| plates with ≥ 4 staple servings | 1,244 | 1,206 | 1,199 | **0** |
| max staple servings | 6 | 5 | 4 | **3** |
| recommendations changed at normal-sized targets (1,440) | — | — | — | **0** |
| top plates changed (1.3–2× / ≥ 2×) | — | — | — | 58 / 412 |
| avg top-plate protein, ≥ 2× targets | 35.1 g | 35.0 g | 34.5 g | 34.3 g |
| protein shortfalls; complete-meal tops; single-supporting; no-staple tops | unchanged | unchanged | unchanged | **unchanged** |

A bound of 4 barely helps, because heavy plates cluster at exactly 4. **A bound of 3 removes every heavy plate, changes nothing at normal targets, and costs under 1 g of protein on average where it applies.**

- **Example,** men's veg dinner, 1 Sep:
  - now: Veg Fried Rice ×2 + White Rice ×2 + Mix Dhal ×2 + Gobi Manchurian;
  - with the proposal: Veg Fried Rice ×2 + Mix Dhal ×2 + Sambar ×2 + Gobi Manchurian.
- **An alternative that treats the cause** would cap the meal target itself (e.g. at 2× a normal meal). That changes the locked meal share (ADR-015 D5), so it is noted, not proposed.

**4. A pre-existing test fault surfaced (fixed in `91ff5c8`, test only).**
- The Home engine deliberately stops "eat protein" from 22:00.
- A Phase 8 Home test (J16) never pinned the hour, so it failed on a real clock between 22:00 and midnight (seen at 22:23).
- The test harness now pins the hour to 12. No app code changed.

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
| core | **747 passed** (12 files; 724 before the correction pass, 646 before Amendment A) | 104: slot boundaries; meal share and target; default meal; every constant and goal weight pinned, plus each score term; **diet safety across every real menu**; allergen status table; **allergy hard filter across real menus** (every plate dish confirmed free, severity irrelevant); alternatives; the "Veg" prefix; snack plates; menu states and zero budget; shortfall (exists only when high < T, never inflated, `menuCanMeet`); deterministic, < 100 ms, coded reasons; variety; post-workout; the six personas snapshotted |
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

**CI on `91ff5c8` (correction-pass head; all green):** ci-core ✓, ci-api ✓, ci-mobile ✓.

**CI on `92164ee` (Amendment A/B head; all green):** ci-core ✓, ci-api ✓ (including migration 0012 up and down), ci-mobile ✓. Before the amendment, CI was also all green on `18fa3ad`:
- **ci-core ✓**
- **ci-api ✓:** typecheck, lint, tests, build, the image migrates, seeds and boots, and the smoke check including the new route's 401.
- **ci-mobile ✓:** analyze `--fatal-infos`, custom_lint, format, the full Flutter suite, APK.

### BUILDS

- **LAN API container:** `docker compose up --build -d api` (development), rebuilt from `phase-10` at `91ff5c8` (earlier at `92164ee`). Migration 0012 was applied to the dev database with `pnpm --filter @fitos/api db:migrate`, because the container does not migrate itself. `GET /v1/mess/menu/recommend` answers 401 without a session.
- **LAN APK (correction pass):** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, built from `91ff5c8` with `.\tool\alpha.ps1 -ApiHostOverride 172.16.205.86 -SkipHealthCheck` (owner: the PC's LAN address is 172.16.205.86).
  - **Host verified inside the APK:** `http://172.16.205.86:8080` is in `kernel_blob.bin` (the Dart API base URL) and in `res/xml/network_security_config.xml` (the cleartext allowlist). The old address 10.52.198.11 appears in no file.
  - **Not verified at that address:** when this was built (22:29 IST) the PC was on the S24 hotspot at 10.52.198.11, so `/health` at 172.16.205.86 could not be reached. The script's health check was skipped for that reason.
  - **Verified on the running container** (rebuilt from `91ff5c8`): `/health` returns 200 on localhost and on 10.52.198.11; `GET /v1/mess/menu/recommend` returns 401 without a session.
  - Before installing, put the PC on the network where it is 172.16.205.86 and check `http://172.16.205.86:8080/health` returns 200.
- Superseded: the APK built from `92164ee` targeted 10.52.198.11.

The PC's address depends on the network it joins. A first build targeted `172.16.205.86` (another Wi-Fi) and was replaced when the PC moved back to the hotspot. **Rebuild with `.\tool\alpha.ps1` whenever the address changes.**

### S24 MANUAL ACCEPTANCE — PASSED 20/20 (owner, Samsung Galaxy S24, 2026-09-24)

The corrected APK (from `91ff5c8`, for `http://172.16.205.86:8080`) against the LAN API container. Checks 1–16 are decision 26; 17–20 are Amendment A:

| # | Check | How | Result |
|---|---|---|---|
| 1 | Vegetarian dinner | Profile → Food: Vegetarian, no allergies. MESS → Dinner. Every plate dish and every alternative is veg; "Why not" lists meat/egg dishes as "not vegetarian". | **PASS** |
| 2 | Eggetarian dinner | Switch to Eggetarian. Egg dishes may appear; meat never. | **PASS** |
| 3 | Non-veg dinner | Switch to Non-vegetarian (non-veg mess). Plates may include meat; compare with 1–2 on the same dinner. | **PASS** |
| 4 | Allergy-restricted | Add milk (any severity). Plates contain only confirmed-free dishes (often white rice only, or "nothing safe"); the filter line says "no known milk ingredient"; the cross-contact note shows; changing severity changes nothing. | **PASS** |
| 5 | Protein-deficit | With a high protein target remaining, the top plate leads with protein and states its protein range against the target. | **PASS** |
| 6 | Snack | MESS → Snacks: a plate appears (fried, sweet or drink allowed at 1 serving). | **PASS** |
| 7 | Zero-calorie | Log enough to reach today's kcal target; the meal shows "target reached", no plate, and the protein still needed. | **PASS** |
| 8 | Shortfall | A meal whose best plate cannot reach the protein target (e.g. vegetarian dinner late in the day) shows "X–Y g protein below this meal's T g", with the menu's maximum. | **PASS** |
| 9 | Post-workout | Finish a workout, then open the next meal within 3 h: "After your workout: … carbs" appears among the reasons. | **PASS** |
| 10 | Variety | A dish logged from the mess yesterday or earlier shows "you had it on N of the last 3 days" and is not excluded. | **PASS** |
| 11 | Tomorrow planning | Next day on MESS: breakfast by default, a planning note, no log button. | **PASS** |
| 12 | Log this plate | Today: tap Log this plate. EAT shows one mess log with each dish at its servings and numbers equal to the plate; the meal's dishes show as logged on the menu. | **PASS** |
| 13 | Profile editing | Profile → Food: change diet and allergies, save; the suggestion refetches with the new filter line. | **PASS** |
| 14 | Offline | Airplane mode: MESS shows the saved menu and "Suggestions need a connection", with no plate. | **PASS** |
| 15 | No non-veg for vegetarian | Across meals and messes browsed while vegetarian, no non-veg or unknown dish appears on a plate. | **PASS** |
| 16 | No allergic dish | With allergies set, no plate dish contains, likely contains, or is unconfirmed for an allergen (check "Why not"). | **PASS** |
| 17 | A meal, not a dish (the first run's cases) | Same account, same day. Breakfast, lunch and dinner each show a staple with a protein, and a "Complete meal" (or "Meal · …") label. Never Watermelon Juice, White Rice alone, or Rasam alone. | **PASS** |
| 18 | Drinks, desserts, crisps | Juice and tea never appear on a plate; papad, appalam and desserts never appear at lunch or dinner. "Why not" says why, and they can still be logged from the menu. | **PASS** |
| 19 | Meaningful alternatives | Other plates change the staple or the protein (e.g. Phulka instead of Rice), never just add rasam or curd. | **PASS** |
| 20 | Limited menu, no-meal, nothing-fits | With a milk allergy at lunch: "Limited menu · no protein dish" plus the shortfall. A snack of only drinks says no meal can be made. With almost no calories left: "even the smallest (about X kcal) is more than you have left today (Y kcal)". | **PASS** |

### MASTER-SPEC AMENDMENTS (minimal; reasons in ADR-015)

- **§5 table:** budget deferred.
- **§10.1:** `/mess/menu/recommend` parameters and statuses; `/nutrition/recommendations` deferred.
- **§14.5:** the leading "Veg", alternatives, confirmed-free allergens, the cooking-fat rule, and what the app says.
- **§15.1:** roles, the meal target, the exact score and constants; budget tier removed.
- **§15.2:** the shortfall definition.
- **§26.2:** the six food personas land in Phase 10.
- **§31 Phase 10:** mess-only; general recommendations and budget deferred.
- **§33:** recommendations are never stored or shown offline.
- **§38 Phase 10:** budget annotated as deferred; **all boxes ticked at acceptance (2026-09-24).**
- **Amendment A (ADR-016):** §15.1 (meal composition, F1, candidates, ceiling), §15.2 (limited menu, `no-meal`, `nothing-fits`) and §10.1 (statuses and structure).

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
- **Staple-heavy plates at oversized meal targets:** see Acceptance → the three-staple-serving constraint was not implemented; the evidence-backed proposal is deferred to the owner.
- **Phase 7 food "Curd rice"** still carries curd values. The owner deferred it: the mess path is corrected by migration 0012, and Phase 7 stays frozen.
- **Pre-existing:** the `automatic_sync_test.dart` teardown flake (since Phase 6.6); `apps/admin` lint needs an interactive setup.

### INTENTIONALLY NOT DONE

- No merge into `main`, and no Phase 11 or Phase 14 work.
- No GCP, billing, Cloud Run, Artifact Registry, Secret Manager, WIF or DNS changes.
- No classification of the 305 Phase 7 foods.
- No user-corrected precedence.
- No recommendation persistence and no migration for it. The only migration, 0012, corrects four stored estimates, with provenance.
- No general (non-mess) recommendations and no budget.
- No staple-serving bound (proposed, not approved before acceptance).
