# ADR-015 — Mess recommendations: fixed scoring, meal share, confirmed-free allergens and an honest shortfall

**Status** ACCEPTED — the owner approved the Phase 10 audit (D1–D25, with D12 clarified, D13 modified and D18 deferred) and then the implementation plan, with 29 locked decisions (2026-09-24). Phase 10 was accepted on 2026-09-24 after the S24 manual acceptance passed 20/20. Amended by ADR-016 (see the Amendment below).
**Date** 2026-09-24
**Phase** 10
**Affects** MASTER-SPEC §10.1 (`/mess/menu/recommend`; `/nutrition/recommendations` deferred), §14.5 (the leading-"Veg" rule, alternatives, confirmed-free allergens), §15.1 (formula, constants, meal share, roles; budget removed), §15.2 (shortfall), §26.2 (the six food personas), §31 Phase 10, §33 and §38 Phase 10. The spec is amended only where it would otherwise contradict what is built. This record holds the reasons.

---

## Context

`packages/core` already had a plate search (`suggestPlates`, §15.1): a diet filter, the top 9 candidates by protein density, a bounded search over whole servings, and a score made of protein, kcal and plate shape. Nothing called it. Phase 9 added the mess mirror, stored per-dish estimates, and mess logging through the Phase 8 snapshot.

§15.1 listed the Phase 10 additions only by name: "carb/fat gap terms, variety penalty against the last 3 days, budget tier, meal-timing bias". It gave no formula and no constants, and it did not say how a day's target becomes one meal's target. The owner asked for all of these to be written down and pinned by tests before any code (D12), with no silent tuning.

## Decisions

### 1. Mess only; nothing stored

- Phase 10 recommends plates from a mess menu and nothing else.
- `GET /nutrition/recommendations` and general (non-mess) food suggestions are **deferred**, together with any classification of the 305 Phase 7 foods.
- A recommendation is computed on each request from the caller's own data and returned. It is never persisted:
  - there are no `recommendations` or `recommendation_events` rows (those arrive in Phase 11);
  - no migration was needed.
- No text comes from a model. The API returns reason **codes** with numbers, and the app turns each code into a fixed sentence.

### 2. The meal target (the meal's share of the day)

- **Meal weights:** breakfast 0.25, lunch 0.35, snacks 0.10, dinner 0.30.
- **Share for the chosen meal:** its weight ÷ the sum of the weights of the meals still to come. The meals still to come are the chosen meal plus every later meal with no log yet. At lunch with nothing logged the share is 0.35 ÷ 0.75 = 0.4667; at dinner it is 1.
- **Remaining for the day** follows the Phase 8 definition, conservatively:
  - kcal, carbs and fat use the **low** end of what remains;
  - protein uses the **high** end, i.e. the most protein the user may still need.
- **The meal target** is the remaining amount × the share.
- **Special cases:**
  - no targets yet → `no-targets`;
  - kcal target 0 → `target-reached`, with no plate, but still stating the protein gap. An over-budget plate is never offered unasked.

### 3. The score (fixed, and pinned by tests)

Plates are ranked by the midpoints of their ranges. Midpoints are used for ranking only and are never shown.

```
score = proteinScore + carbReward − kcalPenalty − carbPenalty − fatPenalty − shapePenalty − varietyPenalty
proteinScore   = 100 × min(p / Tp, 1.25)
kcalPenalty    = W_over(goal) × max(0, k − Tk)/Tk + W_under(goal) × max(0, Tk − k)/Tk
carbPenalty    = (40, or 20 post-workout) × max(0, c − Tc)/Tc
fatPenalty     = 50 × max(0, f − Tf)/Tf
carbReward     = post-workout ? 20 × min(c / Tc, 1) : 0
shapePenalty   = 4 × |dishes − 4| + 6 × max(0, servings − 7)
varietyPenalty = Σ dishes 6 × daysSeen(dish), daysSeen ∈ 0..3 over the 3 days before the menu date
```

Every target is floored at 1 in the denominators.

**Goal weights (W_over / W_under):**

| Goal | W_over | W_under |
|---|---|---|
| muscle-gain | 110 | 55 |
| fat-loss | 180 | 35 |
| recomposition | 180 | 35 |
| strength, general, maintenance | 110 | 35 |

**Search:**
- candidates: 9;
- at most 8 servings;
- pruning when a plate's low-end kcal exceeds max(1.5 × Tk, 400);
- ties broken by plate key.

**Why these values:**
- **Protein leads**, as in §15.1.
- **Carbs and fat are penalised only when over.** Being under is already covered by the kcal term, and adding a penalty for it would double-count.
- **After a workout**, the carb penalty is halved and a small reward added, so carbs are favoured without overriding the kcal term.
- **Variety** is a penalty, never an exclusion. It is capped at 18 per dish (6 × 3 days), well below the up to 125 points of protein, so a dish eaten every day can still top a plate when it is the best choice.
- **Recomposition** takes the fat-loss weights because §15.1 has no goal-dependent protein weight (D19/R4).

**Validation:** the weights were run on the real 2026-09-24 capture before they were fixed. The lunch and dinner top plates stayed sensible, and a post-workout lunch kept its top plate while the 2nd and 3rd plates added rice. The core suite asserts each constant and each goal weight, so any change is a reviewed diff.

**Post-workout:** a workout session completed within the last 3 hours, on today's local date. Tomorrow is never post-workout.

### 4. Which dishes may go on a plate

A dish is kept only if every step passes. The first step that fails is the reason shown under "Why not":

1. diet (primary);
2. diet (each alternative);
3. allergens (primary);
4. allergens (each alternative);
5. it has a stored estimate;
6. it is not ambient;
7. its role may go on a plate;
8. it is among the top 9.

- **Roles (R1):** §15.1 excludes only ambient items and condiments, so fried, sweet, beverage and other dishes are allowed at 1 serving each, and snacks get plates. The lunch and dinner top plates were checked and are unchanged.
- **Ambient items and condiments:** milk and tea stay ambient (R6), even though that removes the best vegetarian protein at breakfast; the shortfall says so honestly. Ambient items remain loggable from the menu as before.

### 5. Diet (§14.5 extended)

- **Leading "Veg":** a name whose first word is "Veg" ("Veg Puff", "Veg. Cutlet") is veg. This check runs **after** the meat and egg keyword checks, so it never overrides a non-veg label or keyword.
- **Alternatives:** a `/` alternative ("Coconut Rice / Tamarind Rice") gets its own diet class. A dish is offered only if the primary **and every alternative** pass. The plate and the log carry the primary.
- **Unchanged:** `unknown` is never offered to a vegetarian or an eggetarian.

### 6. Allergies: confirmed free, or excluded

- **The rule:**
  - a dish passes an allergy only when its normalised name is **exactly** on that allergen's `FREE` list;
  - `contains`, `likely` and `unknown` are all excluded;
  - severity never relaxes this;
  - every allergen must pass for the primary and for every alternative.
- **Fish and shellfish** are free for veg or egg dishes that match no fish or shellfish word.
- **The `CONTAINS` and `LIKELY` lists** only choose the "Why not" wording. Safety rests on the exact `FREE` lists alone (`packages/core/src/mess/allergens.ts`).
- **The cooking-fat rule:** the oil or fat a mess cooks with is unknown (groundnut, gingelly, soybean, ghee, butter, mustard-seed tempering). So for **peanut, sesame, soy, mustard and milk**, `FREE` holds only dishes made without added fat or tempering.
- **Consequence:** very few dishes pass (at the men's veg lunch, a milk allergy leaves white rice only). That is the intended, honest outcome, and every other dish says why.
- **What the app claims:** "no known peanut ingredient" and "ingredient status confirmed by FITOS rules". Whenever the user has any allergy, the app also shows a cross-contact note. It never claims medical certainty.
- **Changing the lists** needs the owner.

### 7. The shortfall (D13 as modified)

- **Scope:** computed for the top plate, separately for protein and for kcal.
- **When it exists:** only when the plate's **high** end is below the target; there is no percentage threshold.
- **How it is reported:**
  - the gap range `[T − high, T − low]`, never inflated;
  - `menuMax`: the most any searched plate reaches;
  - `menuCanMeet`: whether any searched plate reaches the target.
- **What is not a shortfall:**
  - a plate that *may* reach the target (`low < T ≤ high`) gets the reason `protein-may-fall-short` instead;
  - going over on kcal is the reason `kcal-over`.

### 8. Dates, meals and menus

- **Dates:** today or tomorrow only. Tomorrow is planning: nothing counts as eaten, and it cannot be logged. Any other date returns 422.
- **Meal boundaries:** 11, 16 and 19 hours (breakfast, lunch, snacks, dinner).
- **Default meal:**
  - today: the first unlogged meal from the current one onward (a logged meal can still be opened explicitly);
  - tomorrow: breakfast.
- **Menu states:**
  - an inferred menu gives plates labelled with their source date;
  - an unavailable menu or a meal not served gives no plates;
  - a stale mirror gives plates plus the stale notice;
  - nothing passing the filters → `nothing-safe`;
  - nothing within the kcal limits → `nothing-fits`.
- **Offline:** the app shows "Suggestions need a connection" and never a stored or earlier suggestion. The cached menu still shows.

### 9. Estimates and logging

- **Numbers:** stored Phase 9 estimates are authoritative. Each plate item is `snapshotNutrition(stored row, servings)`, the same rounding as the Phase 8 log, so **the preview equals what is logged**.
- **Log this plate:** one `POST /nutrition/logs` with `entryMethod: 'mess'` and one item per dish, at whole servings.
  - It goes through the Phase 8 queue with a new `clientLogId` per tap, so it is retry-safe and works offline.
  - Today only.
  - There is no contract change.
- **Corrections:** Phase 9 corrections stay pending and never change a plate.

## Deferred

- **Budget scoring and filtering:** there is no price data, and none is invented; §36 already places budget in V2.
- **General recommendations** and `/nutrition/recommendations`.
- **"Don't suggest this" / `excluded_dish_ids` UI (D18):** there is no way to set the list in the app. The core and API honour whatever is stored (reason `disliked`), which is empty unless set through the existing diet-preferences API. The Profile → Food editor never sends it, so saving leaves it untouched.
- **Persistence and events:** Phase 11.
- **AI wording:** out of scope.
- **Cloud Scheduler for the mirror:** unchanged from ADR-014, still deferred while GCP is paused.

## Consequences

- Recommendations are reproducible: the same input gives the same ranked output, snapshotted for the six personas (`vegetarian-vit`, `eggetarian-vit`, `nonveg-vit`, `allergy-restricted`, `stale-mess-endpoint`, `protein-deficit`).
- Users with allergies to peanut, sesame, soy, mustard or milk will often see `nothing-safe` or very small plates. This is by design; a wider `FREE` list needs ingredient data FITOS does not have.
- Tuning any weight is a visible change to a pinned test and to this record.

## Amendment — 2026-09-24, after the first S24 run ([ADR-016](ADR-016-meal-composition.md))

The owner stopped acceptance after the S24 run produced Watermelon Juice as breakfast, White Rice as lunch and Rasam as dinner. The owner then approved C1–C6.

- **§3, F1 (C2):** over-penalties now divide by `max(target, a normal-sized meal)` (the day target × the meal weight) instead of `max(target, 1)`, and measure the excess over the real target. The under-term, every constant and every goal weight are unchanged. Pinned: a fat target of 0 at dinner, 49 g a day, and 18 g of fat now costs 61.2 (it was 850).
- **§4 is replaced by ADR-016's meal composition:** a component classifier, structure tiers ranked before the score, no drinks on plates, no desserts or crisps at lunch or dinner, per-component candidates and meaningful alternatives.
- **§3's "9 candidates" is replaced** by per-component candidates.
- **§7 and §8 add** `no-meal`, the refined `nothing-fits`, and `limited-menu`.
- **Amendment B:** four stored Phase 9 estimates are corrected (migration 0012, with provenance).
- The six personas were re-snapshotted as a reviewed diff; `fat-budget-spent` freezes the S24 case.
