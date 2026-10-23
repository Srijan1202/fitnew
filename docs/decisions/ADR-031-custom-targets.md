# ADR-031 — Your own calorie and protein targets

**Status** PROPOSED — approved in the beta 3.2 plan (owner, 2026-10-23); becomes ACCEPTED with beta 3.2.

## Context

FITOS computes calorie and macro targets from the profile and goal (§13.1, packages/core `computeTargets`), and adjusts calories from the weight trend (§13.2, Phase 12). The owner asked that a person can set their own calories and protein, "not just as the app suggests".

The owner chose (2026-10-23) **calories + protein**: FITOS splits the rest into carbs and fat.

## Decisions

1. **What the user sets.** Calories and protein, as whole numbers. Fat and carbs follow FITOS's own split (`adjustTargets`): fat at max(0.8 g/kg, 22 % of kcal), carbs the remainder, fibre at 14 g per 1,000 kcal. The split uses the latest weight.
2. **Hard limits (422 with the field)** — core `customTargets`:
   - kcal 1,200–6,000;
   - protein 0.6–3.3 g per kg of the latest weight, inside 30–400 g;
   - the protein and the fat floor must fit inside the calories (carbs never below 0).
3. **Warnings, not limits:** more than 25 % from FITOS's suggested calories, or protein outside 1.2–2.2 g/kg. Returned with the save and shown in the app.
4. **Storage.** `nutrition_targets.source` (`fitos` | `custom`, migration 0025 with its down migration). A custom target is a new history row (reason `custom`); its rationale states the user's numbers and FITOS's suggestion. Past rows never change. The user's data export carries the column.
5. **What keeps it:**
   - weight and profile changes no longer recompute a custom target;
   - the calorie-adjust policy (§13.2) is not offered while the target is custom, and an older offer accepted afterwards is refused (409, `target-custom`).
6. **What ends it:**
   - **Use FITOS's suggestion** (`DELETE /user/targets/custom`, reason `reset-to-fitos`; a no-op when already FITOS's);
   - **a goal change**, which always recomputes. The goal editor says so before saving.
7. **API:**
   - `GET /user/targets`: the targets in effect, FITOS's suggestion and the limits for the editor;
   - `PUT /user/targets/custom` with `{kcal, proteinG}`, answering the targets and warnings;
   - `DELETE /user/targets/custom`;
   - every targets response carries `source`.
8. **FITOS AI** sees `setByUser` on the targets, so it explains them as the user's own and does not argue with them.

## Consequences

- People who know what they want are not overruled, and FITOS's suggestion stays one tap away.
- The weekly calorie adjustment pauses for custom targets. A user who wants it back resets to FITOS's suggestion.
- The limits keep a typo (12,000 kcal, 20 g protein) from becoming a target.
