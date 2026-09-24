## PHASE 10 — Mess recommendations — IMPLEMENTED, AWAITING S24 ACCEPTANCE

**Date** 2026-09-24 · **Branch** `phase-10` from `main` at `08a085b` (the accepted Phase 9, fast-forwarded per D26) · not merged (owner instruction)

**Commits**
- `d5b0234` — implementation plan for owner review (no code)
- `33c58f6` — core recommender and contracts
- `0edba9e` — `GET /v1/mess/menu/recommend`
- `cbf7224` — mobile: "What should I eat?", log this plate, Profile → Food
- `18fa3ad` — ADR-015 and the MASTER-SPEC amendments
- plus this report

**Decision record:** the owner approved the audit (D1–D25; D12 clarified, D13 modified, D18 deferred), then the [plan](../phase-plans/phase-10-plan.md) with 29 locked decisions. [ADR-015](../decisions/ADR-015-mess-recommendations.md).

**Status:** implemented and every automated gate passes. **Not accepted:** Phase 10 is accepted only after the owner's S24 manual acceptance (below). The §38 Phase 10 boxes stay unticked until then.

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
| core | **646 passed** (11 files) | 104: slot boundaries; meal share and target; default meal; every constant and goal weight pinned, plus each score term; **diet safety across every real menu**; allergen status table; **allergy hard filter across real menus** (every plate dish confirmed free, severity irrelevant); alternatives; the "Veg" prefix; snack plates; menu states and zero budget; shortfall (exists only when high < T, never inflated, `menuCanMeet`); deterministic, < 100 ms, coded reasons; variety; post-workout; the six personas snapshotted |
| contracts | **65 passed** (10 files) | 4: query strictness, statuses and codes, reasons carry no text, the response shape |
| API | **391 passed** (27 files) | 18 recommend integration tests (real Postgres, date-shifted capture) |
| Flutter | **531 passed** | 34: 30 in `recommend_test.dart` and 4 conformance tests |

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

- **LAN API container:** `docker compose up --build -d api` (development), rebuilt from `phase-10`. `/health` returns 200 at `http://172.16.205.86:8080`, and `GET /v1/mess/menu/recommend` answers 401 without a session.
- **LAN APK:** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (debug, `.\tool\alpha.ps1`), built from `phase-10` at `18fa3ad`. It targets `http://172.16.205.86:8080`, and `/health` returned 200 at build time. No phone was connected over adb, so the owner installs it by hand.

The PC's LAN address has changed since Phase 9 (from `10.52.198.11` to `172.16.205.86`). The Phase 9 APK on the phone points at the old address, so **install the new APK**.

### S24 MANUAL ACCEPTANCE — PENDING (owner)

Install the new APK. The PC and the phone must be on the same Wi-Fi, with the API container running. Then check (decision 26):

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
