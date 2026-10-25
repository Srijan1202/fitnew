# Beta 3.7 — plan: better food data

**Date** 2026-10-25 · **Branch** `phase-19` · **Status: awaiting the owner's approval.**

The owner chose 3.7 on 2026-10-25: better food data.

- **The problem:** ranges are far too wide. Vada sambar shows 270–561 kcal a plate; the owner's own reading is 200–400, and that is still too wide.
- **The sources:** use INDB and IFCT 2017 (NIN), and look for more databases.
- **The gaps:** plain milk and paneer are missing (backlog E24).

The owner answered two questions:

| Question | Owner's answer |
|---|---|
| IFCT 2017 and INDB need written permission (NIN's notice; MASTER-SPEC §13 open question since Phase 7) | **Use them now** without waiting for permission. The owner accepts the risk. |
| How calories show | **One number everywhere** ("about 330 kcal"); the range shows when you tap the item |

Nothing is released until the owner says 3.7 is ready.

---

## Why the ranges are wide today

Most of the 265 composite dishes are FITOS estimates built from USDA ingredients (`recipes.json`). Each recipe:
- gives frying oil as a range (vada sambar: 14–24 g);
- then widens both ends by a blanket **±25 %** for "recipe variation";
- then rounds outward.

The ±25 % roughly doubles the spread. There is no measured Indian data anywhere in the seed (Phase 7 left IFCT and INDB out over licensing).

## The sources

| Source | What it adds | Terms |
|---|---|---|
| **IFCT 2017** (NIN, ICMR) | 528 raw Indian foods, measured across six regions (mean ± SD): cereals, pulses, milk, **paneer**, vegetables, fruit, meat, fish | NIN's notice asks for written permission for electronic product use. **The owner decided to use it** (risk accepted, recorded in ADR-036). Cited in full as NIN asks. |
| **INDB 2024** (Jaacks et al., Current Developments in Nutrition) | 1,014 Indian recipes: idli, dosa, sambar, vada, dal, sabzi, biryani…, per 100 g and per standard serving, built from IFCT with USDA nutrient-retention factors | No licence stated; values derive from IFCT. **Used by owner decision**, cited in full. |
| **UK CoFID 2021** (gov.uk) | ~2,900 foods, including dairy and some South Asian dishes, to fill gaps | Open Government Licence v3.0. Attribution required. Only the gov.uk copy; the Quadram copy is non-commercial. |
| **USDA FoodData Central** | already in use | Public domain |

Considered and not used in 3.7:
- **Bangladesh FCT 2013 (FAO):** licence not stated.
- **Open Food Facts:** ODbL (share-alike); packaged products are a separate decision.
- **Kaggle uploads:** unknown licences and provenance.

**Downloads needed (owner to approve with this plan):**
1. `INDB.xlsx`, `recipes_servingsize.xlsx` and `recipes_names.xlsx` from github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB- (well under 5 MB in all).
2. The IFCT 2017 composition data, from the `ifct2017` data package on GitHub (CSV). It is checked against NIN's own PDF (nin.res.in/ebooks/IFCT2017.pdf) on a sample of foods.
3. CoFID 2021 from gov.uk (Excel, 4.4 MB).

Each source goes into `database/seeds/food-sources/` as its own file, with its source, version, licence or terms, and citation.

---

## What changes

### D1 — Measured foods first (§13.3 precedence: user-corrected > IFCT/INDB > USDA > estimated)

- **IFCT 2017 raw foods are added**, with the energy calculated from their measured composition.
  - The range is the mean ± 1 SD where IFCT gives one, capped at ±10 %.
  - Confidence: high. The badge says *IFCT*.
- **INDB recipes are added as dishes**, per standard serving (INDB's serving sizes, in katori, piece, plate and so on) and per 100 g.
  - The range is ±10 % for kitchen-to-kitchen variation (documented); confidence medium; the badge says *INDB*.
- **Where FITOS already has the dish** (vada sambar, idli, dosa, dal…), its numbers are replaced by INDB's.
  - The food keeps its id, slug and aliases, so past logs and favourites still point at it.
  - Past logs keep the numbers they were logged with (as now).
  - The match is by name and alias, and the list of replacements is reviewed by hand and kept in the source file.
- **Duplicates are merged, not added:** "Idli" from INDB and FITOS's "Idli" are one food.
- **Plain staples arrive:** cow and buffalo milk, toned milk, curd, **paneer**, ghee, and so on from IFCT (CoFID where IFCT lacks one).
  - **Milk and Paneer** go back into the food guide's common items (`GUIDE_STAPLES`, backlog E24 closed).

### D2 — Tighter ranges for what stays a FITOS estimate

- The blanket widening drops from 0.25 to **0.10**.
- Frying oil stays a range (that is a real difference between kitchens), using INDB's absorption figures where they exist.
- **The result:** a typical plate's range is about ±10–15 % of its middle, instead of about ±35 %.
- **A check:** a test fails if any non-custom food's kcal range is wider than ±20 % of its middle, unless it is on a reviewed list with a reason (e.g. "thali, contents vary").

### D3 — Mess dishes

The VIT mess estimate table (`mess/nutrition.ts`, ~300 dishes) is re-based on INDB recipes where the dish matches (sambar, rasam, poriyal, chapati…). Dishes without a match follow D2. The mess menu, plates and the food guide all pick this up.

### D4 — One number, range on tap

- **Everywhere a calorie or protein figure shows**, it reads *"about 330 kcal"* / *"about 14 g protein"* (the middle of the range): Eat totals, meals, logged items, search results, the mess menu and plates, Home, TODAY, the weekly report, the food guide.
  - About six formatters, mostly `FoodFormat.range`.
  - An exact value (a label you typed) still shows as itself.
- **The range shows on tap:** food details and a logged item's details show *"Range 300–360 kcal · INDB recipe"*, with the source.
- **Targets still compare honestly:** "on target" logic keeps using the ranges, as now. Only the wording changes.

### D5 — Credit and the record

- **Profile → About → Food data sources:** what each source is, its citation (IFCT 2017: Longvah et al., NIN-ICMR; INDB: Jaacks et al. 2024; CoFID: Crown copyright, Open Government Licence v3.0; USDA FoodData Central) and what FITOS changed (serving sizes, ranges).
- **The badge on each food** names its source.
- **ADR-036 (food data sources):**
  - the owner's decision to use IFCT/INDB without written permission, and the risk accepted;
  - the range policy;
  - the precedence and the merge rules.
- **MASTER-SPEC:** the §13 open question is marked *decided by the owner 2026-10-25*.
- **Offered, not required:** a short email for the owner to send to NIN and the INDB authors asking for permission, so the risk can be closed later.

### D6 — The database and the seed

- **A new food source, `cofid`:** migration 0034 adds the enum value, with its down file. The contracts and the app learn it.
- **The seed builder** gains IFCT, INDB and CoFID readers next to the USDA one.
  - Every row keeps its source reference (IFCT code, INDB recipe code, CoFID code, FDC id).
  - The food count rises from 667 to an estimated 2,000+.
- **The production seed** runs with the release (`deploy.ps1 -Seed`).
  - It updates existing foods in place by slug.
  - The loader is checked to never delete a food that logs point to.
- **Search:** more foods mean more near-matches. A plain food ranks above a dish that starts with its name ("Milk, cow" before "Milkshake"). AI parsing and the food guide get the right food.

---

## Tests

- **Every source file:** the row count, its licence/citation field, no duplicate slugs, and energy within ±10 % of 4/4/9 from the macros.
- **Precedence:** a dish in both INDB and FITOS keeps its id with INDB's numbers. Past logs are unchanged.
- **Ranges:** the ±20 % check (D2), with the reviewed exceptions listed. Vada sambar lands within a sane band (about 300–400 kcal a plate).
- **Staples:** milk and paneer are found by exact name; the food guide pins them.
- **Search ranking:** a plain food first.
- **The app:** "about N" everywhere, the range on tap, the sources page, 200 % text.
- **The migration test for 0034, the seed loader on real Postgres, and contract checks.**

## Order of work

1. Downloads and source files (with the owner's approval of this plan).
2. The seed builder: IFCT, then INDB with the merge list, then CoFID gaps, then the range policy.
3. The mess table re-based.
4. Search ranking.
5. The app's one-number display, the range on tap, and the sources page.
6. ADR-036, the MASTER-SPEC note, docs.

**Release:** API (migration 0034 + `-Seed`), APK **1.0.0-beta.3.7 (13)**, website post, then Announce update.
