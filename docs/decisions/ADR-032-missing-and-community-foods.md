# ADR-032 — Missing-food reports and community foods

**Status** PROPOSED — approved in the beta 3.2 plan (owner, 2026-10-23); becomes ACCEPTED with beta 3.2.

## Context

The food database has 305 foods; testers search for many that are not there. The owner asked for three things:
- a search that finds nothing is flagged and reported, and the food is added in a later release;
- a food a person adds can be shared, and others see it as a community contribution;
- the database grows.

The owner chose (2026-10-23) to show shared foods **immediately, marked Community**, rather than after an admin's approval.

## Decisions

### Missing foods

1. **Reported quietly.** When the Food library or the log sheet shows "No food matches …", the app reports the text once per text per app session. "Ask us to add …" under it reports it again as asked.
2. **Re-checked and anonymous.**
   - `POST /nutrition/foods/requests` normalises the text as search does (2–60 characters) and re-runs the search. Text that finds a food is not counted.
   - `food_requests` (migration 0026) keeps one row per text: `searches` (distinct person-days), `people` (distinct people), `asked` and a status.
   - Each person counts once a day and once overall through `food_request_marks`: sha256 of a server salt, the user, the text and the day. No user id is stored, and none can be read back.
   - A rate limit of 30 an hour per person.
3. **The admin panel's Missing foods** lists them most-wanted first (people, then asked, then searches). Each is marked **added**, **already there** (a spelling: add an alias under Foods), **ignored** or open again, and the marking is audited.

### Community foods

4. **Shared by choice.** Creating a custom food takes `shareWithCommunity`, off by default; the food's `visibility` becomes `community` (migration 0027; `private` otherwise).
   - Everyone can then find it, see it and log it: search and details apply one rule (FITOS's foods, your own, and shared ones).
   - Someone else's shared food is ordered after FITOS's foods and your own, and is marked `community: true`, which the app shows as **Community · unverified**.
   - It is never verified: the existing rule for user foods holds.
5. **Checks before sharing (a private food needs none):**
   - a name of at least 3 letters;
   - calories within 25 % of 4 × protein + 4 × carbs + 9 × fat (skipped below 20 kcal);
   - not a FITOS food of the same name. That is 409, with the existing food's id so the app can offer it.
   - The physical bounds stay the contract's.
6. **Wrong numbers.** `POST /nutrition/foods/:id/report`, with an optional note of up to 300 characters, is open to anyone who can see someone else's shared food; your own and private foods give 404. Each person reports a food once (`food_reports.mark`, a salted hash, no user id).
7. **The admin panel's Community foods** lists shared foods, most-reported first, with their label numbers and the latest notes, and **never who added them**.
   - **Hide** returns a food to its owner only (`hidden`); **show** shares it again. Both are audited.
   - Making a shared food a FITOS food, or editing its numbers in the panel, is not part of this decision; a correct one can be added to the seed.
8. **Privacy:**
   - The owner's data export includes their shared foods. It never includes other people's reports on them: `food_reports` is excluded from the export walk (`OTHER_PEOPLES`).
   - **Deleting an account deletes the foods it shared**, and their reports, by CASCADE. People who logged one keep their meal's numbers: a log item holds its own copy, and its link to the food is cleared.
   - The plan had said shared foods would stay without their owner. Keeping them would break the rule that a user food always has an owner, and deleting is the more complete erasure, so deletion wins.

## Consequences

- The food database grows in the order people actually need, without asking anyone to file a report by hand.
- A wrong shared food is visible until someone reports it and an admin hides it. The Community · unverified mark and the calorie check limit the damage.
- Nothing in either feature can be traced back to a person.

## Amendment — a bigger food database (beta 3.2, F3)

The owner asked for many more foods in all four groups. They are added through the Phase 7 pipeline unchanged (`food-seed:build`, reproducible with `--check`). No new kind of source is added.

| | Before | Added | Now |
|---|---|---|---|
| USDA records (`usda-picks.json`) | 175 | 151 | 326 |
| FITOS composite estimates (`recipes.json`) | 54 | 211 | 265 |
| Carried core estimates | 76 | 0 | 76 |
| **Total** | **305** | **362** | **667** |

- **Indian dishes** (about 115): breads, rice plates and thalis, dals, paneer and vegetable curries, chicken, mutton, egg and fish dishes, South Indian tiffin, Gujarati snacks and sweets. They are declared recipes from USDA ingredients: `source=estimated`, never verified, confidence medium or low, widened 10–25 %.
- **Drinks and street food** (about 70): shakes, coffees, juices, sharbats; chaat, rolls, momos, Indo-Chinese dishes, instant noodles, sandwiches, burgers and combos (chole bhature, puri bhaji, misal pav…). Mostly recipes; packaged juices, cola, green tea and espresso are USDA records.
- **Gym and protein products** (about 60): generic USDA records (whey-based and soy protein powder, whey isolate, egg white powder, Greek yogurt, low-fat cottage cheese, firm tofu, tempeh, edamame, nut butters, instant oats, granola and bars, rice cakes, grilled chicken breast…), plus recipes for shakes, protein oats, egg-white omelettes, rice bowls and the like.
  - **Change from the plan:** the plan said "generic typical label values". Brand labels are not a permitted source and "typical" values have no record behind them, so these are USDA records and declared recipes instead. Every number still traces to a USDA record.
  - USDA records that carry a brand name (EAS, Red Bull, Ralston…) are left out.
- **Whole foods** (about 70 USDA records): fruit, vegetables, legumes, grains and breads, fish and meat, cheeses, condiments, nuts and seeds.
- **Proxies are named in each recipe's notes,** as Phase 7 did, wherever USDA lacks the ingredient:
  - queso blanco for paneer and chhena;
  - spinach for methi leaves;
  - whole chickpeas for chana dal;
  - besan for sattu;
  - milk powder for khoya;
  - brown sugar for jaggery;
  - pasta for vermicelli and hakka noodles;
  - defatted soy flour for soya chunks;
  - lotus seeds for makhana;
  - orange juice for mosambi juice.
- **Aliases only where the equivalence holds.**
  - "Gooseberries" is not given "amla", because the species differ.
  - King mackerel is not given "surmai".
  - Lotus seeds are not called makhana; makhana is its own estimate, with the proxy named.
- **Missing-food reports first:** none have arrived yet, because the reporting server isn't released. The owner reviews them in the admin panel after the release.
- **Release:** a seed release (`deploy.ps1 -Seed`). The admin edit protection (Phase 7, D5) keeps hand-corrected foods as they are.
