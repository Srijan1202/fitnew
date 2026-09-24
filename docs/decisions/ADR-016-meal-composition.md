# ADR-016 — Meal composition: FITOS recommends a meal, not the nutritionally cheapest dish

**Status** ACCEPTED (design) — owner decisions C1–C6 on the post-S24 audit (2026-09-24). Phase 10 is accepted only after a new S24 run.
**Date** 2026-09-24
**Phase** 10 (Amendments A and B to the [plan](../phase-plans/phase-10-plan.md), §20–§22)
**Affects**
- ADR-015: §3 (F1) and §4 (which dishes may go on a plate).
- MASTER-SPEC: §15.1 (pipeline, caps, candidates), §15.2 (limited menu, `no-meal`) and §10.1 (statuses).
- The Phase 10 contract: plate `structure`, item `component`, reason codes, the `no-meal` status, `target.dayRemainingKcal` and `smallestMealKcal`.
- Phase 9 `mess_dish_nutrition`: four rows corrected, with provenance.

---

## Context

The first S24 acceptance run recommended Watermelon Juice as breakfast, White Rice as lunch and Rasam as dinner, for a fat-loss user with three meals logged. The run was reproduced exactly from the development database, read-only. Two causes were found:

1. **The fat term exploded.** Fat eaten (39.2–67.2 g) exceeded the 49 g target at its high end, so the conservative fat target was 0. ADR-015's `50 × max(0, f − Tf) / max(Tf, 1)` then charged 50 points per gram, 475–950 points for any real meal. The lowest-fat single item won every meal.
2. **There was no notion of a meal.**
   - Every plate-eligible Phase 9 `role` (fruit, beverage, a soup-like "legume", dessert, fried) could make a plate on its own, and the only structural signal was a 4-point shape penalty per dish.
   - Global top-9-by-protein-density selection could drop every staple.
   - Even with sane targets, the September menus gave lunch plates with no staple (Curd ×2 + Dhal ×2 + Sambar ×2 + Rasam) and breakfasts with no main (Chickpea Masala ×2).

The Phase 9 `role` is also wrong for this purpose in places:
- juices are `fruit`;
- rasam shares a role with dal;
- Podi Dosa is a `condiment`;
- Curd Rice is `dairy`.

But `role` drives the Phase 9 estimator and the `/mess/menu` contract, which are accepted.

## Decisions

1. **A separate meal-component classifier (C1).** It uses ordered word-boundary term rules on the dish name and diet class, and assigns one of: staple, complete, protein (strong), pulse-gravy and dairy (weak protein), veg, soup, fruit, snack, dessert, crisp, beverage, condiment, other.
   - There are no per-dish lists and no nutrition thresholds, so it generalises to unseen menus by term family.
   - The Phase 9 `role` is untouched.
2. **Structure is a constraint, not a penalty.**
   - Each meal type has tiers (lunch/dinner: staple + strong + veg › staple + strong › staple + weak › staple only › strong without staple; breakfast: main + strong › main + weak › main only › strong without main).
   - Plates rank by (tier, score, key), and only the best achievable tier is returned.
   - A plate without a staple and without a strong protein is never a meal.
   - There are no dish-specific penalties.
3. **Drinks never go on a plate (C5).** Desserts and crisps never go on lunch or dinner plates (C6); only snacks may use them. All of them stay loggable.
4. **Snacks are their own kind.** A substantive item may stand alone and is labelled a snack. Snack rules never apply to other meals.
5. **Candidates are chosen per component, anchors first** (a staple is always a candidate). The kcal ceiling always admits the smallest valid meal. Serving caps stay realistic and are never inflated.
6. **F1 (C2).** Over-penalties divide by `max(remaining meal target, normal meal)`, where normal meal = day target × meal weight, instead of `max(target, 1)`. The under-term, the constants and the goal weights are unchanged. Tests pin the values (e.g. a fat target of 0 at dinner with 49 g a day: 18 g of fat costs 61.2, not 850).
7. **Meaningful alternatives (C3).** Plates 2 and 3 must *replace* an anchor (a staple, a strong protein or a complete dish): their anchor set may be neither equal to, nor a subset or superset of, an earlier plate's. They come from the same tier, and fewer are returned rather than manufactured.
8. **`no-meal` (C4), distinct from `nothing-fits`.**
   - `no-meal`: the filtered menu cannot form a structurally valid meal.
   - `nothing-fits`: a valid meal exists, but no meal-grade plate fits within everything left today.
   - A plate whose low end is above what is left today is never offered.
   - When the best structure doesn't fit the day, the recommender falls back through meal-grade tiers only (lunch/dinner T1–T3, breakfast T1–T2). Calories never push a plate into a limited tier; those are for menus that lack a component.
   - A meal that only exceeds this meal's share is returned, with its kcal reason and an honest shortfall.
9. **Structured reasons.** A plate carries its structure, its anchors, its components and, when the menu lacks a component, `limited-menu` with what is missing. The app words each code; no model is involved.
10. **Four Phase 9 estimate corrections, mess only.** Curd Rice, Rice Papad, Chole Bhatura and Dahi Vada were wrong through rule order.
    - The correction is an overlay in the mess enrichment path. The frozen Phase 7 food seed keeps reading the unchanged `estimateNutrition`.
    - Migration 0012 corrects rows still holding the exact wrong values and records each change in `mess_dish_nutrition_revisions` (previous and current values, reason, time). Down restores the previous values.
    - Logged snapshots never change.

## Consequences

- Every breakfast, lunch and dinner plate is a recognisable meal whenever the menu allows one. When it doesn't, the plate says it is limited and what is missing, and the protein or kcal shortfall stays honest.
- Protein can come out slightly lower than the old "bag of dishes" plates (e.g. Pongal + Sambar + one egg instead of two eggs + sambar with no main). This is the owner's intended trade: a meal first.
- Juice, tea, desserts and crisps are never suggested for main meals. They remain loggable.
- Persona snapshots change as a reviewed diff. A new persona, `fat-budget-spent`, freezes the S24 case.
- The Phase 7 food "Curd rice" carries the same curd values; it is reported, not changed (Phase 7 is frozen).
- **Found, not fixed (outside the approved scope):** Phase 9's ambient check matches `butter` and `sauce`, so "Paneer Butter Masala", "Butter Chicken Masala" and "Spring Roll With Sauce" are treated as ambient and never reach a plate. This is reported to the owner; the ambient rule belongs to accepted Phase 9.
