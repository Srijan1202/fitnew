# Phase 10 — Mess recommendations: implementation plan

**Status** APPROVED 2026-09-24 and implemented. After the first S24 run, the owner approved **Amendment A (meal composition, C1–C6)** and **Amendment B (known estimate corrections)**: §20–§22 and ADR-016.
**Date** 2026-09-24 · **Branch** `phase-10`, from `main` = `08a085b` (accepted Phase 9, fast-forwarded)
**Decisions** from the Phase 10 audit:
- **Approved:** D1–D11, D14–D17, D19–D25.
- **Approved with a written, fixed formula required:** D12.
- **Modified by the owner:** D13 (shortfall, below).
- **Deferred:** D18.
- **Done:** D26.
The owner's additional requirements 1–19 are binding. Once approved, this becomes ADR-015 with the MASTER-SPEC amendments listed in §17.

Every number here is fixed before implementation, and tests pin it. **No weight is tuned during implementation.** A change needs the owner.

---

## 1. Scope

**In Phase 10:**
- Mess recommendations only: "what to eat" at one meal of your mess, from the dishes on its menu. They are computed on request, never stored.
- Log this plate.
- Diet and allergy filters, visible and editable.

**Out of Phase 10:**
- general or non-mess recommendations, and `GET /nutrition/recommendations`;
- classifying the 305 Phase 7 foods;
- budget scoring;
- "Don't suggest this" (`excluded_dish_ids` stays as it is: honoured if already set, never written);
- storing recommendations, and event tracking (Phase 11);
- AI rephrasing (Phase 14);
- applying user corrections (Phase 16).

## 2. Inputs (all server-side, the caller's own data only)

| Input | Source |
|---|---|
| Menu for (mess, date) | Phase 9 `resolveDay`: its resolution (exact, inferred or unavailable) and freshness |
| Dish estimates | **Stored `mess_dish_nutrition` rows** (capped at medium; used for both the preview and the log) |
| Diet | `diet_preferences.diet_type` |
| Allergies | `user_allergies.allergen` (severity is read but never used to relax anything) |
| Excluded dishes | `diet_preferences.excluded_dish_ids` (honoured if present, never written) |
| Goal | the active `user_goals.goal_type` (six values) |
| Day target | the `nutrition_targets` row in effect on the date (kcal, protein, carb, fat) |
| Eaten today | the Phase 8 day totals: low and high sums for kcal, protein, carb and fat |
| Meals already logged | the slots with at least one live log on the date |
| Variety | the distinct local days, among the **3 days before the menu date**, on which each `mess_dish_slug` was logged (0–3) |
| Post-workout | a `workout_sessions` row with `completed_at` within the **3 hours before now**, on today's local date; only when the date is today |

## 3. Meal slots and the default meal (D21, D22)

- **Boundaries everywhere are 11, 16 and 19:** breakfast before 11:00, lunch before 16:00, snacks before 19:00, dinner after. Core `currentMealSlot` (currently 10/15/18) is changed to use core `defaultMealSlot`.
- **Default meal:**
  - **today:** the first meal at or after the current hour's meal that has no log. If every such meal is logged, the current hour's meal, with `slotAlreadyLogged: true`;
  - **tomorrow:** breakfast.
- **Dates (review point R3):** only today and tomorrow. Tomorrow is for planning: the target in effect, nothing counted as eaten, no post-workout, and **not loggable**. Any other date → 422.

## 4. The meal's share of the day (D5)

Meal weights:

| Breakfast | Lunch | Snacks | Dinner |
|---|---|---|---|
| 0.25 | 0.35 | 0.10 | 0.30 |

For the chosen meal `m`:
- **Meals still to come:** `m`, plus every later meal that has no log yet.
- **`share = weight(m) ÷ (sum of the weights of the meals still to come)`.**
- **Worked example:** at lunch with nothing eaten, lunch gets 0.35 ÷ (0.35 + 0.10 + 0.30) = 0.4667 of what remains. At dinner it gets 1.0.

Remaining for the day (the Phase 8 definition): `remaining.low = target − eaten.high` and `remaining.high = target − eaten.low`.

The meal target, one number per nutrient, conservative:

| Nutrient | Meal target |
|---|---|
| kcal | `Tk = max(0, remaining.kcal.low) × share` |
| protein | `Tp = max(0, remaining.protein.high) × share` |
| carbs | `Tc = max(0, remaining.carb.low) × share` |
| fat | `Tf = max(0, remaining.fat.low) × share` |

- **No targets yet** → status `no-targets`, no plates.
- **`Tk = 0`** (remaining kcal already at or below zero at its low end) → status `target-reached`, no plates (review point R2).

## 5. Which dishes can go on a plate

A dish goes on a plate only if every step passes. The first step that fails is its exclusion reason.

1. **Diet**, on the primary name (§6).
2. **Diet of each alternative** (§6).
3. **Allergens**, primary: for each of the user's allergens, the status must be `free` (§7).
4. **Allergens, each alternative:** the same rule.
5. **Has a stored estimate**; otherwise `no-estimate`.
6. **Not ambient** (bread, butter, jam, tea, coffee, milk, chocos, sauce, pickle); otherwise `ambient`.
7. **Role allowed on a plate**:
   - currently staple, protein, legume, dairy, vegetable, fruit;
   - **review point R1:** add fried, sweet, beverage and other, at most 1 serving each, which is what §15.1 actually says (it excludes only ambient items and condiments). With the current list, snacks almost never get a plate;
   - condiments are always excluded, reason `not-a-plate-dish`.
8. **Not in `excluded_dish_ids`**; otherwise `disliked`.
9. **Among the top 9 by protein density**; otherwise `not-top-candidate`.
   - Protein density = midpoint protein ÷ midpoint kcal of one serving.
   - Ties are broken by slug, alphabetically.

## 6. Diet rules (D3, D4, the existing §14.5 rules)

- **User diets:**
  - vegetarian → `veg` only;
  - eggetarian → `veg` or `egg`;
  - non-vegetarian → everything, including `unknown`.
  - `unknown` is never given to a vegetarian or an eggetarian (unchanged).
- **Dish diet** (core `resolveDiet`, unchanged except for one step): either the label or a keyword saying non-veg wins; then the positive veg list; then `unknown`, which becomes `veg` in messes that serve no non-veg.
- **New step (D4):** after the meat and egg keyword checks, a name whose **first word is `veg`** (`Veg Puff`, `Veg. Cutlet (2 Nos)`) is `veg`.
  - It never overrides a non-veg label, or a meat or egg keyword anywhere in the name.
  - This also changes the diet marks on the Phase 9 MESS screen for such dishes.
- **Alternatives (D3):**
  - each alternative (`Coconut Rice / Tamarind Rice`) gets its own diet class through the same `resolveDiet`, with the segment's label and the mess's non-veg flag;
  - **a dish can be recommended only if the primary and every alternative pass**;
  - the plate item is always the primary, and the log records the primary's slug;
  - failure reason: `diet-alternative`, naming the alternative and its class.

## 7. Allergy rules (D1, D2; requirements 5 and 6)

**Principle:**
- a dish is allowed for an allergy only when it is **confirmed free** of that allergen;
- `contains`, `likely` and `unknown` are all excluded;
- severity (mild, moderate, severe) never changes this;
- every allergen the user has must be `free` for the primary **and** for each alternative.

**Status of (dish, allergen)**, from the name normalised as for slugs (lower case, parentheses dropped, anything but letters and digits becoming a space):
1. **`contains`:** a whole word or phrase from `CONTAINS[a]` appears.
2. **`likely`:** a phrase from `LIKELY[a]` appears.
3. **`free`:**
   - for fish and shellfish, the dish's diet is `veg` or `egg`;
   - for every other allergen, the normalised name is **exactly** one of `FREE[a]`. Exact match, never a word inside a longer name, so "rice" never vouches for "egg fried rice".
4. **`unknown`:** anything else.

`CONTAINS` and `LIKELY` only choose which explanation "Why not" gives. **Safety rests on the exact-name `FREE` lists alone.**

**The cooking-fat rule.** FITOS does not know which oil or fat a mess cooks with: it may be groundnut, gingelly (sesame) or soybean oil, ghee or butter, and tempering usually adds mustard seed. So for **peanut, sesame, soy, mustard and milk**, `FREE` lists only dishes made **without added fat or tempering**.

**`FREE` lists** (exact normalised names):
- **Shared groups:**
  - `PLAIN_RICE` = white rice, steamed rice, plain rice
  - `STEAMED` = idly, idli
  - `FRUIT` = seasonal fruit, fruit, fruits, banana, papaya, watermelon, water melon, musk melon, grapes
  - `EGG_PLAIN` = boiled egg, boiled eggs
  - `DAIRY_PLAIN` = curd, cup curd, loose curd, dahi, milk, cold milk
  - `HOT_DRINKS` = tea, coffee
  - `DRY_BREAD` = phulka, pulka
  - `FLATBREAD` = phulka, pulka, roti, chapathi, chapati
  - `DALS` = dal, dhal, toor dal, toor dhal, dal tadka, dhal tadka, dal fry, dhal fry, yellow dhal, mix dhal, sambar, rasam
  - `NO_FAT` = `PLAIN_RICE` + `STEAMED` + `FRUIT` + `EGG_PLAIN`
- **Per allergen:**

| Allergen | FREE |
|---|---|
| peanut, sesame, soy, mustard | `NO_FAT`, `DAIRY_PLAIN`, `HOT_DRINKS`, `DRY_BREAD` |
| milk | `NO_FAT` only |
| tree-nut | `NO_FAT`, `DAIRY_PLAIN`, `HOT_DRINKS`, `FLATBREAD`, `DALS`, butter milk, dosa, plain dosa, set dosa, poriyal, omelette |
| egg | `PLAIN_RICE`, `STEAMED`, `FRUIT`, `DAIRY_PLAIN`, `HOT_DRINKS`, `FLATBREAD`, `DALS`, butter milk, dosa, plain dosa, set dosa, poriyal, curd rice |
| wheat | `PLAIN_RICE`, `STEAMED`, `FRUIT`, `EGG_PLAIN`, `DAIRY_PLAIN`, `HOT_DRINKS` (sambar, rasam and dal are not free: compounded asafoetida often contains wheat flour) |
| fish, shellfish | the dish's diet is `veg` or `egg` (a vegetarian dish is by definition fish-free), and no `CONTAINS` or `LIKELY` match |

**`CONTAINS` and `LIKELY`** (word or phrase matches; explanations only):

| Allergen | CONTAINS | LIKELY |
|---|---|---|
| peanut | peanut(s), groundnut(s), chikki | chutney, podi, poha, chaat, chat, sundal, fry, fried, vada, vadai, bajji, bonda, pakoda, pakora, samosa, puff(s), cutlet, chips, fryums, appalam, papad, mixture |
| tree-nut | cashew(s), kaju, almond(s), badam, pista, pistachio, walnut, dry fruit | biryani, biriyani, pulao, pulav, ghee rice, kurma, korma, shahi, makhani, makani, butter masala, kofta, payasam, kheer, halwa, laddu, ladoo, kesari, custard, pudding, ice cream, milk shake, milkshake, mysore pak, mysorepaku, badusha, jamun, cake |
| milk | milk, curd, dahi, butter, ghee, paneer, panneer, cheese, cream, lassi, raitha, raita, kheer, payasam, custard, ice cream, milk shake, milkshake, tea, coffee, kadhi, kadi, moore, rasgulla, rasagulla, rasamalai, peda, kova, malai, makhani, makani, butter milk, buttermilk | halwa, laddu, ladoo, mysore pak, mysorepaku, badusha, jamun, jamoon, jalebi, kesari, biryani, biriyani, pulao, pulav, ghee rice, paratha, parota, naan, pongal, kurma, korma, shahi, cake, brownie, pudding, bread |
| egg | egg(s), omelette, omlette, bhurji, burji, french toast, anda | cake, brownie, donut, puff(s), cutlet, pudding, custard, fried rice, noodles |
| wheat | roti, chapathi, chapati, phulka, pulka, paratha, parota, poori, puri, naan, bhatura, bread, pav, paav, bun, samosa, puff(s), pasta, noodles, semiya, vermicelli, upma, rava, suji, sooji, kesari, cake, brownie, donut, biscuit, cutlet, french toast, jalebi, badusha | sambar, rasam, dal, dhal, kurma, korma, gravy, manchurian, chilli, 65, bajji, pakoda, pakora, halwa, jamun |
| soy | soy, soya, meal maker, tofu | manchurian, noodles, fried rice, chilli |
| fish | fish, anchovy, tuna | thai |
| shellfish | prawn(s), shrimp, crab, lobster, squid, clam, mussel, oyster | — |
| sesame | sesame, til, gingelly, ellu | podi, chutney, puliyogare, tamarind rice, kulambu, kuzhambu, kozhambu |
| mustard | mustard, kasundi | sambar, rasam, poriyal, chutney, kootu, kulambu, kuzhambu, kozhambu, lemon rice, tamarind rice, curd rice, upma, pongal, poha, kitchadi, butter milk, pickle, thokku, sundal |

**What this means on real menus.** On the 2026-09-24 capture (scratch measurement, all six messes, plate-eligible dish occurrences):

| Allergen | Confirmed free |
|---|---|
| peanut, sesame, soy, mustard | 35 of 144 |
| milk | 18 of 144 |
| wheat | 30 of 144 |
| tree-nut, egg | 69 of 144 |

At the men's veg lunch a milk-allergic user can be offered **white rice only**. That is the honest consequence of requirement 5, and the app says why for every other dish.

**Cross-contact.** No list can rule out cross-contact in a shared mess kitchen. Whenever the user has any allergy, the app says so beside the suggestion (review point R5).

## 8. The search (§15.1, unchanged apart from these points)

- **Candidates:** the top 9 from §5, protein density descending, slug ascending on ties.
- **Servings:** whole servings only, per dish up to the role cap: staple 3 (rice 2), protein 2, legume 2, dairy 2, vegetable 1, fruit 1, and fried, sweet, beverage and other 1 if R1 is approved. At most 8 servings in total.
- **Pruning:** stop when the plate's summed low-end kcal exceeds `max(1.5 × Tk, 400)`.
- **Item numbers:** each item's nutrition is core `snapshotNutrition(stored row, servings)`, the same rounding as the Phase 8 log (outward for estimates). A plate's totals are the sum of its item snapshots, so **the preview equals what the log stores** (D20).
- **Results:** sort by score descending, then by plate key (the sorted `slug×servings` list) ascending; drop duplicates; keep the top 3.

## 9. Scoring (§15.1 plus D12, D10, D11, D19; fixed)

For a plate, `k`, `p`, `c` and `f` are the **midpoints** of its kcal, protein, carb and fat totals. Midpoints are used for ranking only; they are never shown (§6.5). `n` is the number of distinct dishes and `s` the total servings.

```
proteinScore  = 100 × min(p / max(Tp, 1), 1.25)
kcalOver      = max(0, k − Tk) / max(Tk, 1)
kcalUnder     = max(0, Tk − k) / max(Tk, 1)
kcalPenalty   = W_over(goal) × kcalOver + W_under(goal) × kcalUnder
carbPenalty   = W_carb × max(0, c − Tc) / max(Tc, 1)
fatPenalty    = W_fat  × max(0, f − Tf) / max(Tf, 1)
carbReward    = postWorkout ? W_carbReward × min(c / max(Tc, 1), 1) : 0
shapePenalty  = 4 × |n − 4| + 6 × max(0, s − 7)
varietyPenalty= Σ over the plate's dishes of 6 × daysSeen(dish)      (daysSeen ∈ 0..3)

score = proteinScore + carbReward − kcalPenalty − carbPenalty − fatPenalty − shapePenalty − varietyPenalty
```

**Constants:**

| Constant | Value |
|---|---|
| `W_carb` | 40, or 20 when post-workout |
| `W_fat` | 50 |
| `W_carbReward` | 20 |
| protein cap | 1.25 |
| variety | 6 per day seen |
| shape | 4 per dish away from 4 dishes; 6 per serving above 7 |

**Goal weights:**

| Goal | W_over | W_under |
|---|---|---|
| muscle-gain | 110 | 55 |
| fat-loss | 180 | 35 |
| recomposition | 180 | 35 |
| strength | 110 | 35 |
| general | 110 | 35 |
| maintenance | 110 | 35 |

**D19 clarification (review point R4).** §15.1 has no goal-dependent protein weight: the protein term is the same for every goal. So "recomposition uses fat-loss kcal weights and muscle-gain protein emphasis" becomes the fat-loss weights. Nothing further is added.

**Checked against real menus** (scratch prototype, 2026-09-24 capture, target 2,400 kcal / 140 g protein / 290 g carbs / 70 g fat):

| Case | Top plate | Totals |
|---|---|---|
| Women's non-veg dinner, 11 Sep, vegetarian (breakfast to snacks logged) | Dhal ×2, Sambar ×2, Rasam, Roti ×2 | 610–965 kcal, 25–40 g protein, against an 85 g target: **a shortfall** |
| Same dinner, non-vegetarian | Tandoori Chicken ×2, Dhal ×2, White Rice, Banana | 900–1,300 kcal, 56–80 g |
| Men's veg lunch, 24 Sep, vegetarian muscle-gain | Curd ×2, Dhal Makhani, Phulka ×3, White Rice | 740–1,045 kcal, 26–39 g |
| Same lunch, post-workout | Same top plate; the 2nd and 3rd plates add rice | — |

## 10. Shortfall (D13 as modified)

Computed for the **top plate** (the one recommended first), for protein and for kcal separately, with `T` the meal target and `[low, high]` the plate's range.

- **A shortfall exists when `high < T`**: even at its optimistic end, the best plate cannot reach the target. There is no percentage threshold.
- **It is reported as `gapLow = T − high` and `gapHigh = T − low`**, both positive. This is the actual remaining gap as a range. It uses the plate's own ends, so it is never inflated.
- **`menuMax`** is the highest optimistic value any searched plate reaches for that nutrient. `menuCanMeet = menuMax ≥ T` says whether the menu could meet the target at all (for example, protein given up to stay within calories).
- **When `low < T ≤ high`**, the plate may or may not reach the target. That is **not** a shortfall. The reason code `protein-may-fall-short` (or the kcal one) carries `T − low`.
- **When `high ≥ T`**, there is nothing to report.
- **Too many calories** is not a shortfall. It is the reason `kcal-over`, with the range.

## 11. Menu states (D6, D7; requirements 9–11)

| Menu | Recommendation |
|---|---|
| exact | plates |
| cycle-inferred | plates; `basis: 'inferred'`; every plate carries the reason `inferred-menu` with `sourceDate`; the app labels them "Based on the inferred menu of {date}" |
| unavailable | status `menu-unavailable`; no plates |
| meal not on the menu | status `meal-not-served`; no plates |
| server's copy stale (24 h without a fetch) | plates, plus `freshness.stale = true`; the app shows the stale notice |
| phone offline | the app does not ask. It shows the saved menu and "Suggestions need a connection". **No stored or earlier suggestion is ever shown** |
| nothing passes the filters | status `nothing-safe`; no plates; every dish listed with its reason |

## 12. API

`GET /v1/mess/menu/recommend?date&mess&slot` (sign-in required; 120/min like other routes).
- `date` = today or tomorrow (default today);
- `mess` = a mess code (default your mess; browsing another mess applies **your** filters);
- `slot` = a meal (default per §3).
- **Errors:** 404 when there is no mess (configured or given); 422 for a bad date or slot.

```ts
{
  status: 'ok' | 'no-targets' | 'target-reached' | 'menu-unavailable' | 'meal-not-served' | 'nothing-safe',
  mess: Mess,                       // Phase 9 shape, with freshness
  date, today, slot,
  slotAlreadyLogged: boolean,
  loggable: boolean,                // date === today
  resolution: MenuResolution,
  basis: 'published' | 'inferred' | null,
  filters: { diet: DietType, allergies: Allergen[] },
  target: { share, kcal, protein, carb, fat } | null,   // the meal target (§4)
  postWorkout: boolean,
  plates: {
    rank: 1 | 2 | 3,
    items: { dishSlug, name, servings, servingLabel, servingGrams, kcalLow, kcalHigh, proteinLow, proteinHigh,
             carbLow, carbHigh, fatLow, fatHigh, fibreLow: null, fibreHigh: null, confidence }[],
    totals: { kcalLow, kcalHigh, proteinLow, proteinHigh, carbLow, carbHigh, fatLow, fatHigh },
    confidence: 'medium' | 'low',   // the worst item
    reasons: Reason[],
  }[],
  shortfall: { protein: Gap | null, kcal: Gap | null } | null,  // for plates[0]
  dishes: { dishSlug, name, diet, onPlate: boolean, reasons: Reason[],
            alternatives: { name, diet, allergens: { allergen, status }[] }[] }[],  // every dish at the meal
}
Gap    = { target, gapLow, gapHigh, menuMax, menuCanMeet }
Reason = { code: ReasonCode, ...values }   // no English; the app words each code
```

- No score is exposed.
- No migration is needed.
- **Unchanged:** the `/mess/menu` and logging contracts.
- The OpenAPI document is regenerated, and the CI smoke check adds a 401 check on the new route.

## 13. Reason codes (D23; requirement 14)

**Plate reasons**, in this order:

| Code | Values |
|---|---|
| `protein-covers` | `{ target, low }` (the plate's low end reaches the target) |
| `protein-may-fall-short` | `{ target, low, high }` |
| `protein-short` | `{ target, high }` (see `shortfall`) |
| `kcal-within` | `{ target, high }` |
| `kcal-may-exceed` | `{ target, low, high }` |
| `kcal-over` | `{ target, low }` |
| `top-protein-dish` | `{ dishSlug }` (the highest protein-density dish on the plate) |
| `post-workout-carbs` | `{ carbLow, carbHigh, target }` |
| `repeat` | `{ dishSlug, days }` (penalised for variety) |
| `inferred-menu` | `{ sourceDate }` |
| `low-confidence-dish` | `{ dishSlug }` |

**Dish reasons** (why a dish is or isn't on a plate):

| Code | Values |
|---|---|
| `on-plate` | `{ ranks }` |
| `diet` | `{ dietClass }` |
| `diet-alternative` | `{ alternative, dietClass }` |
| `allergen` | `{ allergen, status }` (one per failing allergen) |
| `allergen-alternative` | `{ alternative, allergen, status }` |
| `no-estimate` | — |
| `ambient` | — |
| `not-a-plate-dish` | `{ role }` |
| `disliked` | — |
| `not-top-candidate` | — |
| `not-chosen` | — |

## 14. Logging a plate (D14; requirement 12)

- One `POST /nutrition/logs` with `entryMethod: 'mess'`, the plate's dishes at their servings, the chosen meal, and `menuDate` = the date. **No contract change.**
- **Only when `loggable`** (today).
- A new `clientLogId` per tap, so it is retry-safe. It goes through the Phase 8 queue, so it works offline.
- The server snapshots the stored estimates. Because they are the same numbers the preview used (§8), **the logged values equal the preview**, item by item.
- Corrections stay pending and never alter a plate (D24).

## 15. App (D16, D17; requirement 11)

- **MESS:** a **"What to eat"** section for the chosen meal (default per §3), with:
  - a meal switcher;
  - the **thali**: a plate outline with one compartment per dish (diet dot, servings, name), and ledger rows below it for the kcal and protein ranges and the confidence;
  - reasons worded from the codes;
  - the shortfall line when there is one;
  - **Log this plate**;
  - up to 2 more plates;
  - the filter line "Vegetarian · no peanut, milk", tapping through to Profile;
  - "Why not …?", listing every dish with its reason;
  - the cross-contact note when the user has an allergy.
- **Style:** the existing palette and hairlines. No AI or chat-style cards.
- **States:** loading; offline; no targets; target reached; unavailable; meal not served; nothing safe; inferred (labelled); stale (notice); tomorrow (planning only, no log button).
- **EAT:** the "Today's mess" strip gains "Suggested plate ›", which opens MESS at the suggested meal.
- **Profile:** a **Food** section (diet type, allergies with severity) using the existing `GET/PUT /user/diet-preferences`. Saving refreshes suggestions.
- **No computation on the phone:** the app only draws what the server returns.

## 16. Test matrix

**A. Already in place (must stay green)**
- Core `mess.test.ts` plate tests:
  - vegetarian on the real tandoori-chicken dinner;
  - chicken offered to a non-vegetarian;
  - the fat-loss calorie budget;
  - ranges;
  - excluded dishes honoured;
  - an empty result when nothing qualifies.
- Diet classification, labelled and unlabelled.
- `mess-phase9.test.ts`.
- The API mess suite: the medium cap, dish logging, frozen history, saved-meal ranges, retry safety.
- The Phase 8 logging suite.

**B. To add**

| # | Level | Test |
|---|---|---|
| B1 | core | **Diet safety sweep** over every meal of all six 2026-09-24 captures and the 2026-09-07 captures × 3 diets: vegetarian plates only `veg`; eggetarian only `veg`/`egg`; `unknown` never for either |
| B2 | core | **Allergy sweep**, same menus × each of the 10 allergens × each severity: every plate dish is `free` for the primary and all alternatives; results identical across severities |
| B3 | core | Allergen status table: a fixed set of (name, allergen) → status, including exact-name `free` versus "egg fried rice" (not free), the fish rule by diet, and wheat for sambar = `likely` |
| B4 | core | Alternatives: "Paneer Curry / Chicken Curry" excluded for vegetarians (`diet-alternative`); a peanut alternative excluded for a peanut allergy |
| B5 | core | D4: "Veg Puff" → `veg`; "Veg Egg Fried Rice" → `egg`; "Non Veg : Veg Cutlet" → `nonveg` |
| B6 | core | **Meal share:** fixed cases (lunch with nothing logged = 0.4667; dinner = 1.0; snacks with dinner logged; breakfast, all four) and the low/high end choice for each nutrient |
| B7 | core | **Scoring constants pinned:** `scorePlate` on hand-built plates gives exact values for each term (protein cap, the goal weights for all 6 goals, carb and fat penalties, the post-workout switch, shape, variety) |
| B8 | core | **Shortfall:** exact `gapLow`/`gapHigh`/`menuMax`/`menuCanMeet` on the real vegetarian dinner (top plate 25–40 g against Tp); the "may fall short" case is not a shortfall; kcal shortfall; never below the plate's own ends |
| B9 | core | **Determinism:** the same input twice gives deep-equal output; a menu with dishes in shuffled order gives the same plates (slug tie-break) |
| B10 | core | **Performance:** under 100 ms per call on the largest real meal (the special mess's lunch), median of 20 runs |
| B11 | core | Reason codes: every returned dish has at least one reason; plates carry only codes (no English) |
| B12 | core | Meal-slot boundaries 11/16/19 in `currentMealSlot` and `defaultMealSlot` |
| B13 | core | **Personas (D25)** as frozen JSON snapshots, reviewed on any change (see the list below) |
| B14 | API | 401; 404 with no mess; 422 for a past date or bad slot; tomorrow is not loggable |
| B15 | API | **No cross-user leakage:** A's allergies, diet, logs and variety never affect B; the same mess and date for two users gives outputs that differ only by their own inputs |
| B16 | API | Browsing another mess applies the caller's own filters |
| B17 | API | Stored estimates are used: change a `mess_dish_nutrition` row and the plate changes; log the plate and the snapshot equals the preview item by item; change the row afterwards and the log is unchanged |
| B18 | API | Log a plate: one log with N items, retry-safe (same `clientLogId`, then 200) |
| B19 | API | Statuses: `no-targets`, `target-reached`, `menu-unavailable`, `meal-not-served`, `nothing-safe`, inferred (`basis`), stale (`freshness`) |
| B20 | API | Default meal with logged meals; post-workout within 3 h (a session 2 h ago versus 4 h ago); variety from the last 3 days' `mess_dish_slug` |
| B21 | API | A pending correction never changes a plate; p95 under 200 ms |
| B22 | contracts | Response schema: reason codes as an enum; no score field |
| B23 | app | Conformance; the "What to eat" states; log this plate (one log, the right meal) and offline queueing; no stale suggestion offline; "Why not"; the Profile Food editor round trip; the EAT link |
| B24 | app | Layout: S24 and 360×640, 100% and 200% text, keyboard open and closed (the Food editor), with no overflow |

**Personas (B13)** use real menus from the 2026-09-24 capture unless noted:

| Persona | Menu | User |
|---|---|---|
| `vegetarian-vit` | Women's non-veg dinner, 2026-09-11 (tandoori chicken) | vegetarian, muscle-gain, 2,400 / 140 / 290 / 70; breakfast to snacks logged (1,300 kcal high, 55 g protein low) |
| `eggetarian-vit` | Same dinner | eggetarian |
| `nonveg-vit` | Same dinner | non-vegetarian |
| `allergy-restricted` | Men's veg lunch, 2026-09-24 | vegetarian; peanut (severe) and milk (mild) |
| `stale-mess-endpoint` | The **2026-09-07** men's non-veg capture, date 2026-09-07 | `cycle-inferred` from 08-24; plates labelled inferred |
| `protein-deficit` | Men's veg dinner, 2026-09-24 | vegetarian, muscle-gain, 20 g protein eaten by dinner; `shortfall.protein` present |

**C. S24 manual acceptance** (for after implementation)
1. Three diets on the same real dinner (switch diet in Profile → Food). The results diverge correctly, and no `unknown` dish goes to a vegetarian or eggetarian.
2. A peanut allergy: no chutney, fried or peanut items; "Why not" names peanut.
3. A milk allergy: honest, very small or no plate; the cross-contact note.
4. Every plate: ranges, confidence (medium or low), reasons; a shortfall where it applies.
5. Log this plate: one entry, the right dishes and servings; EAT totals rise by the plate's range; ticks on MESS.
6. Kill and retry: one entry.
7. Offline: the menu shows; "Suggestions need a connection"; no old suggestion.
8. After 30 Sep (inferred): plates labelled inferred. An unavailable date: no plate.
9. Log lunch: the suggestion moves to the next meal.
10. A dish eaten on 3 days drops in the ranking.
11. After a completed workout: a carb tilt, with its reason.
12. Tomorrow: a planning plate, with no log button.
13. The same state twice gives the same plates.
14. The preview equals the logged snapshot, dish by dish.
15. No overflow at normal and large text.

**D. Regression:**
- all Phase 7, 8 and 9 suites;
- the Phase 7 seed test (the core estimate table is untouched);
- the migration up/down suite;
- the Flutter suite, including the known workout-sync flake noted in the Phase 9 report;
- CI on all three jobs.

## 17. MASTER-SPEC amendments on approval (minimal; reasons in ADR-015)

- **§15.1:**
  - the exact scoring formula and constants;
  - the meal-share formula;
  - **budget removed** (no price data; §36 already says V2);
  - if R1: plate roles as §15.1 already states.
- **§15.2:** the shortfall definition (§10 here).
- **§14.5:**
  - the leading-"Veg" rule;
  - alternatives classified separately;
  - the confirmed-free allergen rule and the cooking-fat principle.
- **§10.1:** `/mess/menu/recommend` parameters and states; `/nutrition/recommendations` **deferred**.
- **§31 Phase 10:** general recommendations and budget deferred; tests and acceptance unchanged.
- **§33:** recommendations need the network; no stored suggestion is shown offline.
- **§26.2:** the six food personas land in Phase 10; the rest stay Phase 11.
- **§38 Phase 10:** the `budget` part of "carb/fat/variety/budget/timing scoring" is annotated as deferred.

## 18. Points for your final review

| # | Point | Proposal |
|---|---|---|
| **R1** | Plate roles. The code allows 6 roles; §15.1 excludes only ambient items and condiments, so snacks almost never get a plate today (the prototype gave none at the men's non-veg snack). | Follow §15.1: add fried, sweet, beverage and other, 1 serving each. Checked: the lunch and dinner top plates are unchanged. |
| **R2** | `target-reached` when the meal's kcal target is 0. | No plates, and the remaining protein shown. Alternative: still offer the highest-protein, lowest-kcal plate. |
| **R3** | Dates: today and tomorrow only (tomorrow for planning, not loggable). | As stated. |
| **R4** | Recomposition equals the fat-loss weights, because §15.1 has no goal-specific protein weight. | As stated. |
| **R5** | The cooking-fat principle for peanut, sesame, soy, mustard and milk, the `FREE` lists above, and a cross-contact note. It leaves very few dishes for those allergies. | As stated; the lists become core data with tests, and changing them needs the owner. |
| **R6** | Milk and tea are ambient, so they never go on a plate (§15.1). At breakfast that removes the best vegetarian protein. | Keep (spec). Noted for a later review. |

## 19. Implementation order (after approval)

1. **Core:**
   - `allergens.ts` (§7);
   - the diet changes (§6);
   - the recommender (§§3–5 and 8–10, reason codes, slot boundaries);
   - tests B1–B13 and the personas.
2. **Contracts** and OpenAPI.
3. **API:** the route, its data loading, tests B14–B21, and the smoke check.
4. **App:** entities and conformance; "What to eat" with the thali; log this plate; "Why not"; the EAT link; the Profile Food editor; tests B23–B24.
5. **Docs:** ADR-015 and the §17 amendments; the report.
6. Full suites, CI, an S24 APK, then your S24 acceptance.

---

## 20. Amendment A — meal composition (owner C1–C6, 2026-09-24)

**Why.** The S24 acceptance run (fat-loss, non-vegetarian, women's special mess, three meals logged) produced Watermelon Juice for breakfast, White Rice for lunch and Rasam for dinner. The read-only audit found two causes:
- **(A)** Fat eaten (39.2–67.2 g) exceeded the 49 g target at its high end, so the fat target was 0. The over-penalty `50 × (f − 0) / max(0, 1)` then cost every real meal 475–950 points, and the lowest-fat single item won.
- **(B)** The search has no notion of a meal: any plate-eligible dish can make a plate alone, and global protein-density selection can drop every staple.

**The owner's invariant:** *FITOS recommends a MEAL, not merely the nutritionally cheapest dish.* Structure is a constraint (a tier), never a penalty; no dish-specific penalties.

**Pipeline** (replaces §8's candidate selection and the top of §9):

```
menu → diet + allergy hard filter (unchanged, primary and every alternative)
     → meal component per dish (new classifier; Phase 9 `role` untouched)
     → components allowed at this meal (C5, C6)
     → per-component candidates (anchors first, capped)
     → bounded serving search (whole servings, caps, kcal ceiling that always admits the smallest valid meal)
     → structure tier per plate → keep the best achievable tier
     → existing scoring within that tier (goal, carb/fat with F1, variety, post-workout)
     → up to 3 plates that differ in a meaningful anchor (C3)
```

### 20.1 Meal components (C1)
`packages/core/src/mess/components.ts` holds ordered, word-boundary term rules on the dish name plus its diet class. There are no per-dish lists and no nutrition thresholds, so it generalises by term family; an unrecognised name is `other`.

| Component | Role in a meal | Examples |
|---|---|---|
| `staple` | carbohydrate anchor ("main" at breakfast) | rice dishes, phulka/roti/chapathi, idly, dosa, uthappam, pongal, upma, poha, kitchadi, poori, paratha, pulao, pasta, noodles, pav, Curd Rice, Podi Dosa/Idly/Rice |
| `complete` | a staple and a strong protein in one dish | a staple term with egg or meat (Egg Fried Rice, Chicken Biriyani, Egg Chow Mein), Chole Bhatura, Meal Maker Pulao |
| `protein` | strong protein anchor | any egg, meat or fish dish; paneer, soya, meal maker; dal/dhal family; channa/chana/chenna/chole/rajma/chickpea; sprouts; sundal |
| `pulse-gravy` | weak protein | sambar family, kootu, kadhi/kadi |
| `dairy` | weak protein | curd, dahi, raitha, buttermilk, lassi, Dahi Vada |
| `veg` | vegetable component | poriyal, sabzi, kurma, kulambu, gravy, fry, masala, salad, kofta, stew, baby corn dishes |
| `soup` | supporting only | rasam, every soup |
| `fruit` | supporting / snack | banana, papaya, melons, grapes, "fruit" |
| `snack` | snack item | samosa, puff, cutlet, bonda, bajji, vada, sandwich, pani puri, chaat, fries, spring roll, corn, peanuts |
| `dessert` | snack only | sweets, cakes, ice cream, payasam, kheer, halwa |
| `crisp` | snack only | appalam, papad, fryums, chips |
| `beverage` | never on a plate | juice, tea, coffee, milk, milkshake, sarbat, mint lemon |
| `condiment` | never on a plate | chutney, pickle, sauce, jam, butter, thokku, bare podi |
| `other` | never on a plate | unrecognised names |

A golden test covers every dish in the September capture.

### 20.2 What may go on a plate (C5, C6)

| Meal | Allowed components | Never |
|---|---|---|
| lunch, dinner | staple, complete, protein, pulse-gravy, dairy, veg, soup, fruit | **beverage (C5), dessert and crisp (C6)**, snack, condiment, other |
| breakfast | staple, complete, protein, pulse-gravy, dairy, veg, fruit, snack (a vada as a side) | **beverage (C5)**, soup, dessert, crisp, condiment, other |
| snacks | snack, dessert, fruit, dairy, protein, staple, complete, crisp | **beverage (C5)**, soup, pulse-gravy, veg, condiment, other |

- A dish left out for its component shows under "Why not" with the reason `not-a-meal-component {component}`.
- Drinks, desserts and crisps stay loggable from the menu and search as before.

### 20.3 Structure tiers (C1)
Definitions: *staple* = staple or complete; *strong* = protein or complete; *weak* = pulse-gravy or dairy; *veg* = veg.

| Lunch / dinner | Kind | Breakfast | Kind |
|---|---|---|---|
| T1 staple + strong + veg | `complete-meal` | T1 staple + strong | `complete-meal` |
| T2 staple + strong | `meal` (missing vegetable) | T2 staple + weak | `meal-weak-protein` |
| T3 staple + weak | `meal-weak-protein` | T3 staple only | `limited` (missing protein) |
| T4 staple only | `limited` (missing protein) | T4 strong, no staple | `limited-no-staple` |
| T5 strong, no staple | `limited-no-staple` | | |

- **Never returned:** a plate with no staple and no strong protein. That covers soup-, fruit-, veg- and weak-protein-only plates; drinks, desserts and crisps can't reach a lunch or dinner plate at all.
- **Snacks:** any allowed item forms a plate of kind `snack` (at most 2 dishes). Snack rules never apply to other meals.
- **Ranking:** plates rank by **(tier ascending, score descending, plate key)**, and only the best achievable tier is returned.

### 20.4 Candidates and search
- **Per-component candidates**, each group sorted by protein density (descending) with the slug breaking ties:
  - staple 3, complete 2, protein 3;
  - pulse-gravy 2, veg 2, dairy 1, soup 1, fruit 1;
  - snack 2, dessert 2, crisp 1.
  A staple is always a candidate when one exists.
- **Dishes per plate, by component:**
  - lunch and dinner: staple ≤ 2, complete ≤ 1, protein ≤ 2, pulse-gravy ≤ 1, dairy ≤ 1, veg ≤ 2, soup ≤ 1, fruit ≤ 1; at most **5 dishes**;
  - breakfast: staple ≤ 2, complete ≤ 1, protein ≤ 2, pulse-gravy ≤ 1, dairy ≤ 1, veg ≤ 1, fruit ≤ 1, snack ≤ 1; at most **4 dishes**;
  - snacks: at most **2 dishes**.
  - Every meal: at most 8 servings (unchanged).
- **Serving caps** (no inflation):
  - rice-type and one-pot staples (rice, pulao, biryani, bath, pongal, upma, poha, kitchadi, pasta, noodles, semiya) 2; bread-type staples 3;
  - complete 1; protein and pulse-gravy 2;
  - everything else 1 (dairy drops from 2 to 1).
- **kcal ceiling** = `max(1.5 × Tk, 400, 1.5 × floor)`. `floor` is the smallest single-serving kcal (low end) of a minimal plate of the best tier the filtered menu offers. The smallest valid meal is therefore never cut off; overshoot is reported with the existing `kcal-may-exceed` / `kcal-over` reasons.
- **Performance** (under 100 ms on every real menu; a test on the widest real September menu):
  - running macro sums are kept during the walk, with no allocation at the leaves;
  - only the best plate per *anchor signature* in each tier is retained.

### 20.5 Alternatives (C3)
- **Anchor signature:** the plate's set of staple, complete and strong-protein dishes (servings ignored).
- **Plate 1** is the best plate of the best tier.
- **Plates 2 and 3** are the next best plates of the **same tier** whose signature is neither equal to, nor a subset or superset of, any plate already chosen. So they *replace* an anchor, never just add one.
  - Rice + Dal + Veg, then Phulka + Dal + Veg, then Rice + Paneer + Veg: accepted.
  - Rice + Dal + Rasam, or Rice + Dal + Curd, after Rice + Dal + Veg: rejected.
- If the menu cannot produce three such plates, fewer are returned. None are manufactured.

### 20.6 Statuses (C4)
Status order: `menu-unavailable`, `meal-not-served`, `no-targets`, `target-reached`, `nothing-safe`, **`no-meal`**, **`nothing-fits`**, `ok`.

- **`nothing-safe`** (unchanged): no dish passes diet, allergy and estimate.
- **`no-meal`** (new): dishes pass, but the filtered menu has no structurally valid meal, e.g. only rasam, fruit and papad pass. No plate; "Why not" lists every dish.
- **`nothing-fits`** (redefined): a valid meal exists, but no meal-grade plate fits within **everything left today** (`dayRemainingKcal`, the conservative low end). The app says so with the smallest meal's kcal and what is left.
  - A plate whose low end is above what is left today is never offered.
  - A meal that merely exceeds this meal's share is still returned, with the kcal reason.
  - This refines owner decision 8 (no over-budget plate) together with C4 (never drop the smallest valid meal only because the ceiling is tight).
- **Clarified during implementation (2026-09-24), to match C4 exactly:** when the best structure the menu offers doesn't fit the day, the recommender falls back to the next **meal-grade** tier (lunch and dinner T1–T3, breakfast T1–T2), e.g. Rice + Sambar + Sabji when Chole Bhatura doesn't fit. It **never** drops into a limited tier because of calories: the limited tiers are for menus that lack a component. So a bowl of dal alone is never offered as lunch when the menu has a staple; that case is `nothing-fits`.
  - Found by the stored-menu sweep: 6 dinners (women's veg, 7 Sep, the S24 state) had returned `nothing-fits` although a valid tier-3 meal fitted.
- **`target-reached`** (Tk = 0) is unchanged.

### 20.7 Scoring change F1 (C2) — amends ADR-015 §3
- **Change:** over-terms are divided by `max(remaining meal target, normal meal)`, where `normal meal` = day target × meal weight (0.25 / 0.35 / 0.10 / 0.30). Previously they were divided by `max(target, 1)`.
- **Terms affected:**

```
kcalOver = W_over × max(0, k − Tk) / max(Tk, Nk)
carbPen  = W_carb × max(0, c − Tc) / max(Tc, Nc)
fatPen   = W_fat  × max(0, f − Tf) / max(Tf, Nf)
```

- **Unchanged:** the under-term (`/ max(Tk, 1)`), every constant and every goal weight.
- **Pinned example:** with a day fat target of 49 g at dinner (Nf = 14.7) and Tf = 0, a meal with 18 g fat at its midpoint costs 50 × 18 / 14.7 = **61.2** (it was 850 under ADR-015's floor of 1 g: 50 × (18 − 1) / 1). Tests pin this and the equivalent carb case.
- The excess is measured over the real target, so a target of 0 gives an excess of the full amount; a request without a normal meal keeps ADR-015's exact terms.

### 20.8 Reasons, contract and app
- **New plate reasons:**
  - `meal-structure {kind}`
  - `staple-anchor {dishSlug}`
  - `protein-anchor {dishSlug, strength: strong|weak}`
  - `vegetable-component {dishSlug}`
  - `supporting-side {dishSlug}`
  - `limited-menu {missing: (staple|protein|strong-protein|vegetable)[]}`, emitted when the best tier lacks something the menu (after your filters) doesn't offer
- **Dish reasons:** `not-a-meal-component {component}` replaces `not-a-plate-dish {role}`.
- **Contract:**
  - each plate gains `structure {kind, missing[]}`;
  - each item gains `component`;
  - the status list adds `no-meal`;
  - `target` gains `dayRemainingKcal`;
  - the response gains `smallestMealKcal` (set only for `nothing-fits`).
- **App:**
  - the plate shows its structure ("Complete meal", "Meal · no vegetable dish on this menu", "Limited menu — no protein dish fits your filters", "Snack");
  - `no-meal` and `nothing-fits` each get their own message;
  - "Why not" explains the component exclusions.

### 20.9 Tests (owner list 1–18) and the September sweep
- **Core — safety and structure:**
  - Watermelon Juice is never a breakfast plate;
  - White Rice alone is `limited`;
  - Rasam alone is never dinner;
  - T1 beats any single supporting dish;
  - vegetarian and allergy safety across every real menu;
  - corn stays a valid `snack`;
  - no drink on any plate;
  - no dessert or crisp at lunch or dinner.
- **Core — alternatives and statuses:**
  - alternatives differ by an anchor (subset and superset rules);
  - `no-meal` vs `nothing-fits`;
  - `limited-menu` missing lists.
- **Core — scoring, determinism and speed:**
  - F1 with fat target 0 and carb target 0, pinned;
  - determinism;
  - under 100 ms on the widest real September menu;
  - a new persona `fat-budget-spent` (the S24 state), and the six personas re-snapshotted as a reviewed diff.
- **September sweep (core test over the 2026-09-24 capture, every mess, date and meal, several personas):**
  - no breakfast, lunch or dinner top plate is a single supporting item;
  - no lunch or dinner top plate lacks a staple when the filtered menu has one;
  - no soup, juice or fruit is a top meal;
  - diet and allergy safety holds;
  - results are deterministic.
- **API, contract and app:** the new fields and statuses, conformance, the new wording, and the corrected estimates (§21).

## 21. Amendment B — known Phase 9 estimate corrections (owner, 2026-09-24)

**The errors.** Four dishes carry wrong stored estimates, all caused by rule order in core `mess/nutrition.ts` (the first matching term wins):

| Dish (slug) | Stored now | Cause | Corrected to |
|---|---|---|---|
| Curd Rice (`curd-rice`) | 1 cup curd: 65–105 kcal, 4–7 g P | `curd` matches before the existing `curd rice` entry | the table's own `curd rice` entry: 1 katori (180 g), 180–260 kcal, P 5–8, C 30–40, F 4–8, medium |
| Rice Papad (`rice-papad`) | 1 katori rice: 175–215 kcal | `rice` matches before `rice papad` | the table's own crisp entry: 1 small portion (25 g), 95–155 kcal, P 1–2.5, C 11–17, F 5–10, low |
| Chole Bhatura (`chole-bhatura`) | 1 katori chole: 150–230 kcal | `chole` matches first; the bhatura is lost | a sum of the table's own entries, chole (1 katori) + bhatura × 2: 1 plate (330 g), 590–870 kcal, P 17–27, C 80–112, F 20–41, low |
| Dahi Vada (`dahi-vada`) | 1 cup curd: 65–105 kcal | `dahi` matches before `vada` | a sum of the table's own entries, vada × 2 + curd (1 cup): 2 pieces in curd (230 g), 305–485 kcal, P 10–18, C 31–48, F 15–29.5, low |

No new nutrition numbers are invented: each correction is an existing table entry or a sum of existing entries, and is capped at medium confidence.

**Scope:**
- **Mess only.** The corrections apply in `enrichDish` (the mess path) through a `MESS_ESTIMATE_CORRECTIONS` overlay consulted before the table.
- **`estimateNutrition` is unchanged**, because the frozen Phase 7 food seed reads it. The Phase 7 food "Curd rice" carries the same curd values; that is reported to the owner and not changed here.
- Nothing else in Phase 9 data changes.

**Why a migration is required.** Stored estimates are write-once (`insertNutritionIfAbsent` → `ON CONFLICT DO NOTHING`, ADR-014 D6), and nothing ever updates them. Phase 9 corrections are pending-only, and `mess_dish_nutrition` isn't seeded (the mirror writes it). Fixing core alone corrects only databases that have never seen these dishes. The dev database (and any later hosted one) would keep the wrong numbers forever, and recommendations and logs read the stored row.

**The migration (`0012`):**
1. Creates **`mess_dish_nutrition_revisions`** `(id, dish_slug → mess_dish_nutrition ON DELETE CASCADE, reason, previous jsonb, current jsonb, revised_at)` so every correction keeps its provenance. This stores data corrections, not recommendations (nothing about recommendations is persisted).
2. For each of the four slugs, only where the row **still holds the exact wrong Phase 9 values**, records a revision (reason `phase-10-estimate-correction`) and updates the row. A row that is absent or already different is left alone.
3. **Down** restores each row's `previous` values from its revision and drops the table.

**What this doesn't touch:** logs already made keep their snapshot (Phase 8 immutability); new logs and recommendations read the corrected rows.

**Tests:**
- **core:** each correction equals its source entries; `estimateNutrition` is unchanged for every Phase 7 carried term; `enrichDish` returns the corrections;
- **API migration test:** up and down with the wrong rows present (revision written, values corrected; down restores them), and no-ops for absent or edited rows;
- **API integration test:** the recommendation plate and a new log use the corrected Curd Rice values;
- **mirror:** a fresh database gets the corrected values.

## 22. Implementation order (Amendment A and B)
1. This amendment and ADR-016 (committed before code).
2. Core: components, the composition search, F1, statuses, reasons and alternatives; the estimate overlay; tests, sweep and performance.
3. Contracts and OpenAPI.
4. Migration 0012 and the API (new fields, `dayRemainingKcal`, `smallestMealKcal`); tests.
5. App: structure label, statuses, wording, DTOs, conformance and widget tests.
6. Docs: the ADR-015 F1 amendment, MASTER-SPEC §15.1/§15.2/§10.1, and the phase report. §38 stays unticked.
7. All suites, the sweep, the performance test, CI and the APK, then a report. **No acceptance claim**; the S24 run happens after the owner's review.
