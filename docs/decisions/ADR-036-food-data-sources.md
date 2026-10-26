# ADR-036 — Food data sources: IFCT 2017, INDB 2024 and UK CoFID 2021

**Status** PROPOSED — approved in the beta 3.7 plan (owner, 2026-10-25, "yes go"); becomes ACCEPTED with beta 3.7.

## Context

Before 3.7 the food database had 667 foods: USDA records plus FITOS estimates. The estimates were often too wide; the owner gave the example of vada sambar at 200–400 kcal. The owner asked for (2026-10-25):
- narrower, better numbers;
- data from INDB and IFCT 2017 (NIN);
- any other database that has the data;
- plain milk and paneer (backlog E24).

MASTER-SPEC §13 held IFCT and INDB behind an open question: a human must confirm the licensing in writing first.

## Decisions

### The owner's decision on licensing (risk accepted)

1. **IFCT 2017 and INDB are used now, without written permission.** The owner chose this on 2026-10-25 ("Use IFCT/INDB now anyway").
   - NIN's notice permits personal use with acknowledgement. It asks for written permission before the data is stored electronically to build a product.
   - INDB states no licence, and its values derive mainly from IFCT.
   - The owner accepts the risk that NIN or the INDB authors object. If they do, the IFCT and INDB foods come out of the seed in a release; past logs keep their numbers (they are snapshots).
   - Offered, not required: a short email from the owner to NIN and the INDB authors asking for permission, which would close the risk.
2. **UK CoFID 2021** (Public Health England, Crown copyright) is used under the Open Government Licence v3.0. The licence allows commercial reuse with its attribution statement, which the app shows.
3. **Credit everywhere.**
   - Every food names its source with a badge (USDA, IFCT, INDB, CoFID, Estimate).
   - Each food's page gives the source reference: the IFCT code, the INDB recipe code, the CoFID code or the FDC id.
   - Profile → About → **Food data sources** gives each citation and what FITOS changed.

### How each source becomes foods

4. **IFCT 2017** (542 raw foods, 539 kept):
   - per 100 g, as published, verified, high confidence;
   - each value ± the SD IFCT reports across its six regions, kept within 3–10 %;
   - English and Hindi names as aliases only: other languages' names start like common dishes (Telugu *dosakaya*, cucumber, answered "dosa");
   - a name FITOS already uses gets "(IFCT)".
5. **INDB 2024** (1014 recipes, 566 kept):
   - per piece or bowl as INDB serves them, ±10 %, medium confidence, **never verified**;
   - INDB's per 100 g is of the raw ingredients, water included, so it is not used;
   - **left out** (each named, with its reason, in `foods.manifest.json`):
     - every deep-fried recipe: INDB counts the whole pan of oil (a medu vada at ~590 kcal), and a correction for the oil soaked up proved unreliable;
     - whole dishes (a cake, a jar);
     - portions outside 5–900 kcal;
     - a recipe FITOS already has, by name or alias.
6. **CoFID 2021** (13 foods):
   - plain foods ±3 %, dishes ±8 %, verified;
   - new: whole and semi-skimmed milk (aliases toned / double-toned milk) and whole-milk yogurt;
   - 10 FITOS recipe estimates CoFID measures as eaten are **replaced** by its numbers at their FITOS serving. Each keeps its slug, name and aliases, so logs and saved meals still point to it.
7. **Energy must match the macros.** A measured food whose energy is more than 25 % (at least 10 kcal) from 4/4/9 of its own protein, carbohydrate and fat is left out, not guessed.
   - This removed 27 INDB recipes (mostly soups listing ~13 g protein and fat per 100 g at 27 kcal) and 3 IFCT foods (a skinless chicken leg at twice the thigh's energy, a crab, lemon juice).
   - IFCT lists 0 kJ for its 14 oils and fats, a gap rather than a value. Their energy is computed with IFCT's own factors (17/37/17/8 kJ per g).
   - USDA keeps its food-specific energy factors and is not checked this way.

### Ranges

8. **No range is wider than ±20 % around its middle** (above 20 kcal). A seed test checks every row.
   - This amends §13.3's "verified foods set `low == high`". USDA's verified foods stay exact; verified IFCT and CoFID foods carry their source's small variation (items 4 and 6).
   - FITOS recipe estimates: oil ranges tightened, widening at most 10 %.
   - The VIT mess table (`packages/core` `mess/nutrition.ts`):
     - every estimate is capped at ±20 %;
     - dishes CoFID measures are calibrated to it at ±8 % (biryani, butter chicken, dal tadka, sambar, curd, raita, rice, puri…).
   - Stored mess estimates are rebased once with `db:rebase-mess-nutrition`. Dishes an admin has revised are left alone, and every change is recorded as a revision.
9. **One number, the range on tap** (owner, 2026-10-25).
   - The app shows an estimate as its middle: "about 330 kcal". An exact value shows as itself.
   - A food's page, and a tapped logged item, show the range and the source.
   - Targets and plate checks still compare ranges, as before; only the wording changed.

### Precedence and search

10. **Source precedence** on an equal search match is unchanged from Phase 7 (D3, `SOURCE_RANK` in core):
    - a person's correction first;
    - then the measured sources (IFCT, INDB, CoFID);
    - then USDA, then a person's own foods, then FITOS estimates.

    Search tiers (exact, alias, prefix, word, fuzzy) come before source.
11. **Search** puts the plain food first among prefix matches: "Milk, whole, Cow" before Milk cake, "Bananas, raw" before Banana cake. That is the comma or bracket form USDA, IFCT and CoFID use for a plain food.
12. **The food guide's common items** include milk (CoFID whole milk, a glass) and paneer (IFCT) again.

## Consequences

- 1,775 foods instead of 667.
- Migration 0034 adds `cofid` to `food_source`; its down file turns CoFID foods back into unverified estimates.
- The seed is deterministic and rebuilt from the committed converted files (`database/seeds/food-sources/{ifct2017,indb,cofid}.json`, from `tools/convert_sources.py`); the raw downloads are not in the repository, and their checksums are recorded.
- MASTER-SPEC §13's open question is decided by the owner, with the risk accepted.

## Not in 3.7

- INDB's deep-fried recipes, until a reliable oil-uptake rule exists.
- Rebasing the mess table on INDB recipes (the plan's D3). CoFID calibration and the ±20 % cap were used instead, because INDB's portions and frying made it the less reliable reference.

## Amendment — beta 3.9: INDB's deep-fried recipes (owner, 2026-10-26)

The owner chose to bring the deep-fried recipes in, checked against CoFID within **±15 %** (BACKLOG E25).

1. **The pan comes out.** INDB lists the whole pan of oil as an ingredient, so a poori comes to ~920 kcal.
   - The converter records the pan: the heaviest fat line "for frying" (or 100 ml of oil or more), when it is at least 100 g. That is 129 recipes.
   - A few tablespoons "for frying" is a sauté, and all of it is eaten.
2. **The fat kept is what CoFID measured in the same kind of fried food.**
   - It is measured as grams of fat per gram of protein + carbohydrate. That ratio does not depend on water or portion size, so INDB's own per-piece protein and carbohydrate give the fat.
   - The fat is never less than the recipe's fat without the pan (a gravy's own oil). The energy moves with the fat.
   - Each kind has one share (`FRIED_KINDS` in `apps/api/src/db/food-seed/sources.ts`). Its CoFID references are listed in `cofid-picks.json` `oilReferences`; they are converted into `cofid.json` and are never foods themselves.
3. **The owner's check.** A kind is used only when its one share puts **every** reference's energy within ±15 % (`food-seed.test.ts`). A fried food's range is ±15 %.

   | Kind | Share | CoFID references |
   |---|---|---|
   | Poori, bhatura, kachori, mathri | 0.51 | puri |
   | Cauliflower pakora, gobi 65 | 0.88 | aubergine and cauliflower bhajia, restaurant pakora |
   | Potato, onion or leafy pakora, potato bonda | 0.47 | onion, potato, potato-carrot-pea and spinach bhajia, retail bhajia |
   | Fried fish | 0.47 | cod in batter, fish fingers |
   | Sev, namak para, murukku, papdi | 0.48 | sev, chevda |
   | Kofta | 0.53 | dudhi kofta curry, lamb kofta |
   | Spring roll / scotch egg | 0.66 / 0.64 | spring rolls / scotch eggs |

   Pakoras are split by what is fried: cauliflower and aubergine soak up nearly twice the oil (0.87–0.90 against 0.41–0.55). One share for all of them misses by up to 30 %.
4. **Left out, not guessed:**
   - **Samosa:** CoFID's own samosas range from 0.26 to 1.26, a 42 % miss even at the best share.
   - **Vada, cutlet and tikki:** 0.25 to 0.95, a 24–34 % miss even split into pulse and other kinds.
   - **Pakoras of paneer, egg, bread, chicken, fish or chilli:** no reference.
   - **Gulab jamun:** INDB also counts the whole pan of syrup.
   - **Curries, chaat, pickles, cakes and the rest:** no kind of their own.
5. **Names.** INDB's slashes also hid spellings.
   - "Potato pakora/pakoda" made the alias "pakoda", which is another FITOS food, so every pakora was skipped as one FITOS already had. A one-word spelling of the last word now gives "Potato pakoda".
   - "Ghiya/Lauki Kofta Curry" was named "Ghiya". One word before a whole dish now names the dish: "Lauki Kofta Curry".
   - A seeded food's slug never changes (the seed is upserted by slug). So "Saunth" keeps its slug and is now named "Sonth chutney with ginger".
   - Spellings never make a recipe "one FITOS already has". The same fix lets in 19 ordinary INDB dishes that a lone "omlet", "paratha" or "khichri" had kept out: omelettes, paranthas, khichdis and cheelas.

**Result:** 1,839 foods (+64). That is 45 deep-fried INDB recipes and 19 ordinary ones. No existing food is removed and no food's nutrition changes. Release needs a `-Seed` deploy and no migration.

**Search:** "panee" now matches more than 20 foods. Measured sources rank before FITOS estimates, so Paneer butter masala falls past the first 20 until the next word is typed. The ranking is unchanged.
