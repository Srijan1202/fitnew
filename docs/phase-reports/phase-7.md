## PHASE 7 — Food database — IMPLEMENTED, AWAITING OWNER AUDIT

**Date** 2026-09-24 · **Branch** `phase-7` from the Phase 6.7 line at `3255b8f` · not merged
**Commits** `b4a2e36` (core + contracts) · `ed09310` (seed builder, seed, manifest, CI seed checks) ·
`b8a307c` (migration 0009, food seeding, nutrition API) · `6a349f0` (mobile Food Library) · plus this report
**Decision record** Gate 7-0 (owner, 2026-09-24): D1–D12 + N1–N5, and the reproducibility requirement.
The owner then asked for all of Phase 7 in one go, with no gate stops; this report is the audit.
**CI on `6a349f0`:** ci-core ✓ · ci-api ✓ (tests on PG 18, image migrates, seeds, boots, and `/v1/nutrition/foods/search` answers 401) · ci-mobile ✓ (analyze, custom_lint, format, tests, APK)
**MASTER-SPEC:** unchanged. §38 "licensing confirmed" and "500 foods seeded" stay **unticked**.

### The honest numbers

| | Foods | Source | Verified | Confidence |
|---|---:|---|---|---|
| USDA FoodData Central records | **175** | `usda` | yes | high, `low == high` |
| &nbsp;&nbsp;of which Foundation Foods (2026-04-30) | 25 | | | |
| &nbsp;&nbsp;of which SR Legacy (2018-04) | 150 | | | |
| Carried over unchanged from the core estimate table | **76** | `estimated` | no | 31 medium · 45 low |
| Indian dishes composed from USDA ingredients | **54** | `estimated` | no | 43 medium · 11 low |
| **Total seeded** | **305** | | | |
| Target in MASTER-SPEC (~500) | 500 | | | |
| **Gap to target** | **195** | not padded | | |

- 580 nutrition rows (per 100 g plus up to two USDA household portions for USDA foods; one
  serving row for estimates) · 339 aliases · 0 USDA picks dropped · 93 foods with fibre
  **unknown** (stored as NULL, shown as "Not known", never 0).
- **IFCT 2017 / INDB:** still excluded. No written redistribution terms have arrived; the
  sources exist in the vocabulary (`ifct`, `indb`) but no row uses them.
- Six carried core entries are labelled `high` in core (boiled eggs, chapati, curd, curd rice,
  idli, cooked white rice). Their **numbers are unchanged**. Gate 7-0 says an estimate is never
  high confidence, so they are seeded as `medium`. The manifest records both values
  (`coreConfidence` / `confidence`).

### IMPLEMENTED

- **Core** (`packages/core/src/nutrition/food.ts`)
  - The six food sources and §13.3 precedence: user-corrected > IFCT/INDB > USDA > user >
    estimate.
  - Range arithmetic. Unknown fibre propagates as null.
  - Per-100 g plausibility: ≤ 900 kcal, ≤ 100 g per macro.
  - Source claims: an estimate is never verified or high confidence; a user food is never
    verified.
  - One text normalisation for names, aliases and queries.
  - Deterministic recipe composition: sum the ingredients, span the oil allowance, widen by
    the recipe's factor, round outward.
- **Contracts** (`packages/contracts/src/food.ts`, `openapi.json` regenerated): food and
  nutrition row, search query and response, the custom-food request, and seed rows.
  - The seed-row rules: USDA foods are verified, exact and high; estimates are ranges and
    never verified or high.
- **Seed builder** (`apps/api/src/db/food-seed/`, `src/scripts/build-food-seed.ts`)
  - Reads the pinned USDA downloads. They are not committed; the raw zips' SHA-256 values are
    in the manifest.
  - Energy uses nutrient 208, else Atwater 958, else 957.
  - USDA values are rounded to nearest: kcal to 0 decimals, grams to 1.
  - Keeps up to two USDA household portions, in USDA's order. RACC portions, labels over 60
    characters and portions over 1 kg are skipped ("1 waxgourd" is 5.7 kg, not a serving).
  - The inputs are `usda-picks.json` (175 FDC IDs plus aliases), `carried.json` (76 core terms)
    and `recipes.json` (54 recipes, each with its version, ingredients by FDC ID, oil
    allowance, widening and proxy notes).
  - Output is ordered by slug, LF line endings, no timestamps.
  - `--check` proves the committed files are exactly what the builder produces.
  - The manifest holds:
    - dataset, release and SHA-256 for each input;
    - the builder version and the rules;
    - every USDA food's FDC ID and dataset;
    - every composite's recipe version and ingredients;
    - the exact per-100 g USDA values every composite was computed from, so CI can recompute
      the composites without the raw data.
- **Database — migration `0009_food_library`** (+ down)
  - **`foods`**:
    - columns: slug (unique), name, generated `search_name`, brand, barcode, source,
      source_ref, is_verified, owner_user_id, client_food_id;
    - a trigram index on `search_name`;
    - checks: ownership matches the source; estimated, user and user-corrected rows are never
      verified; client_food_id is set only on custom foods;
    - a unique (owner, client_food_id).
  - **`food_nutrition`**: numeric(8,2) ranges with low ≤ high, non-negative values, fibre
    both-or-neither, unique (food, position) and (food, basis, serving).
  - **`food_aliases`**: normalised text, with a trigram index.
- **Seeding:** `db:seed` (and the image's `node dist/db/seed.js`) also upserts foods by slug
  in one transaction, replacing each seeded food's rows and aliases. A re-run changes nothing
  and never touches custom foods.
- **API** (`apps/api/src/modules/nutrition/`), default-deny:
  - `GET /v1/nutrition/foods/search?q=&limit=`
    - Ranking: exact name > exact alias > prefix > word prefix > fuzzy (`word_similarity`
      ≥ 0.4). Ties break on similarity, then source precedence, then the shorter name.
    - Shows global foods plus the caller's own custom foods.
    - A query that normalises to empty returns `[]`.
  - `POST /v1/nutrition/foods`
    - Creates a private custom food from a label: `source=user`, not verified, confidence
      medium, exact values.
    - Retry-safe by `clientFoodId`: 201 the first time, then 200 with the same food, even
      under concurrency.
- **Mobile — the Nutrition tab is the Food Library** (it replaces the placeholder)
  - **Search:** results show name, "brand · kcal · serving" and a source badge (USDA in pine /
    ESTIMATE in amber / YOURS).
  - **Detail:**
    - every nutrition row, ranges kept as ranges, "Not known" for unknown fibre;
    - "Verified · High confidence" or the estimate's confidence;
    - a plain-language line on what the source means, the aliases and the source reference;
    - the USDA attribution on USDA foods and on composites built from USDA data.
  - **Add a food from its label:**
    - per serving or per 100 g;
    - fibre may be left empty, which sends null;
    - checks mirror the server's;
    - one `clientFoodId` per form, reused on retry.
  - The USDA attribution also appears on the library's start screen.
  - **No** logging controls, **no** offline food cache.

### Fixed during the phase (found by the new tests)

- **`food_nutrition_fibre_range`**: the first version passed a half-known fibre, `(2, NULL)`,
  because a comparison with NULL is NULL and CHECK accepts NULL. The constraint now requires
  both-null or both-set. 0009 was corrected in place in the schema, SQL and snapshot.
  drizzle-kit reports no drift. The migration had not been applied anywhere except the test
  database.
- **Custom-food contract** counted fibre on top of carbohydrate in the "≤ 100 g per 100 g" and
  "≤ serving weight" checks, which would reject real high-fibre labels such as wheat bran.
  Fibre is now counted inside carbohydrate, and a fibre-only check was added.
- **A USDA portion over the contract's 5000 g** ("1 waxgourd"): portions over 1 kg are no
  longer kept.

### TESTS (all executed locally; CI below)

| Suite | Result | New in Phase 7 |
|---|---|---|
| `pnpm --filter @fitos/core test` | **482 passed** | +21 (`food.test.ts`) |
| `pnpm --filter @fitos/contracts test` | **44 passed** | +9 (`food.test.ts`) |
| `pnpm --filter @fitos/api test` (Postgres 18, `fitos_test`) | **322 passed** (23 files) | +38: seed checks 14, nutrition API 23, migration 0009 1 |
| `flutter test` (host, Flutter 3.47.2) | **396 passed** | +22: food screens 18, contract conformance 4 |

- **API coverage:**
  - seed applied and idempotent (same ids, same counts);
  - 401s;
  - exact name, case and punctuation insensitive;
  - all 12 approved spelling aliases;
  - an alias beats a prefix ("rice" → cooked white rice);
  - prefix and word prefix; fuzzy ("chapatii", "sambaar"); nonsense finds nothing;
  - limit bounds and 422s;
  - USDA provenance; estimates are unverified ranges; USDA-unreported fibre is null;
  - custom create is 201 and exact; retry is 200 with the same id and one row;
  - three concurrent duplicates produce one food;
  - a custom food is private, and two users may share a clientFoodId;
  - an equal-match tie goes USDA "Honey" before a custom "Honey";
  - per-100 g storage, and a stated fibre of 0 is kept;
  - nine impossible or unknown-field bodies each get a 422 and store nothing;
  - re-seeding keeps custom foods.
- **Search latency** (60 requests over 12 mixed queries after warm-up, local Postgres 18):
  **p50 ≈ 14 ms, p95 ≈ 20 ms** against the 200 ms budget, asserted in the test.
- **Static checks:**
  - `pnpm typecheck` (api, core, contracts): clean.
  - `eslint` (api, contracts): clean.
  - `dart analyze --fatal-infos`: clean. `dart run custom_lint`: clean.
  - `dart format --set-exit-if-changed`: clean. build_runner output is committed.
- **Not run:** `next lint` in `apps/admin` stops at an interactive ESLint setup prompt. That
  predates Phase 7, and CI doesn't run it.

### DATABASE AND SEED, RUN FOR REAL

- **Dev database** (`fitos`, Docker):
  - `db:migrate` twice: the second run applies nothing, and 10 migrations are recorded.
  - `db:seed` twice: both runs report "seeded 305 foods, 580 nutrition rows, 339 aliases".
  - Counts in the database: 305 / 580 / 339.
- **Local API container:** rebuilt from this branch. Its compiled `dist/db/migrate.js up` and
  `dist/db/seed.js` ran inside the image and gave the same counts, so the seed path resolves
  from `dist`.
- **Migration suite:** up, idempotent up, the 0009 constraints, and a step-by-step down that
  removes 0009 first (tables and enums gone, 9 remain), then back up.

### BUILDS

- LAN alpha debug APK: `apps/mobile/tool/alpha.ps1` → `build/app/outputs/flutter-apk/app-debug.apk`
  (API `http://10.52.198.11:8080`, `/health` 200 at build time).

### MANUAL CHECKS ON THE S24 (owner; not yet done)

1. Install the LAN APK (`.\tool\alpha.ps1 -Install`), sign in, and open **Nutrition**. You
   should see "Food library", the search field, the intro and the USDA attribution, with no
   "Coming soon".
2. Search `dhal` → **Dal tadka** first, with an ESTIMATE badge. Open it:
   - the row is "Per 1 katori (150 g)", Energy "120–185 kcal", Protein "6–9 g": ranges;
   - Fibre says "Not known";
   - the amber estimate line is shown;
   - "Also called" lists the aliases.
3. Search `roti`, `idly`, `sambhar`, `poori`, `panneer 65`, `biriyani`. Each lands on the
   intended dish.
4. Search `honey` → **Honey**, USDA badge. The detail shows:
   - "Verified · High confidence";
   - Per 100 g (304 kcal), Per 1 cup (339 g) and Per 1 tbsp (21 g, 64 kcal) rows, all
     exact numbers in USDA's portion order;
   - "FDC 169640";
   - the attribution.
5. Search `chapatii` (misspelt) → Chapati still appears. Search `xqzv` → "No food matches"
   with **Add from a label**.
6. **Add a food:**
   - Enter a real label per serving, leave fibre empty, and save. It opens as YOURS, "From
     the label you entered", with Fibre "Not known".
   - Search its name: it appears.
7. With Wi-Fi off, save a food. You should get the offline message and the form stays. Turn
   Wi-Fi on and save again: **one** food is created, the same one.
8. Per 100 g with 950 kcal is refused before sending.
9. No screen offers to log, track or add to a meal.
10. Scroll the results to the end: the last row clears the floating bar.

### INTENTIONALLY NOT DONE / OPEN

- **Not done:**
  - no food logging, meals, daily totals or target progress (Phase 8);
  - no offline food cache;
  - no barcode lookup (the column exists, nullable);
  - no diet or allergen tags;
  - no AI `search_foods` tool (D8–D10).
- **Count:** 305 is short of ~500 by 195. Closing the gap honestly needs licensed Indian data
  (IFCT/INDB) or more composites with declared recipes. Padding is not an option.
- **No single-food endpoint:** the detail screen receives the food with the navigation. A
  restored route shows "Open this food from the library" rather than guessing.
- **Custom foods can't be edited or deleted** in Phase 7; `user-corrected` exists in the
  vocabulary only.
- **Known pre-existing flake** (Phase 6.6 teardown race in two sync tests, documented in the
  6.7 report): not touched.
- **Phase 6.7 hosting:** untouched. No GCP, billing, Cloud Run, Artifact Registry, Secret
  Manager, WIF or DNS changes. The only CI edit adds one line to the image smoke test so it
  also checks that `/v1/nutrition/foods/search` exists (401).
