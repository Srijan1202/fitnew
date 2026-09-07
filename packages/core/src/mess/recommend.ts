/**
 * "What should I eat at this meal?"
 *
 * Deterministic bounded search over serving combinations of the dishes actually
 * on today's menu. No LLM is involved in choosing the plate or computing any
 * number here — an LLM may later be handed the returned `PlateSuggestion` to
 * phrase it, but it cannot alter the arithmetic.
 */

import type { DietClass, MacroRange, MealSlot, MessDish, MessMeal } from './types.js';
import { ZERO_MACROS, addMacros, midpoint, scaleMacros } from './nutrition.js';

/** What the user will and won't eat. */
export type DietPreference = 'vegetarian' | 'eggetarian' | 'non-vegetarian';

export interface PlateItem {
  readonly dishId: string;
  readonly name: string;
  readonly servings: number;
  readonly servingLabel: string;
  readonly macros: MacroRange;
}

export interface PlateSuggestion {
  readonly items: readonly PlateItem[];
  readonly macros: MacroRange;
  /** Machine-readable reasons. The UI renders these; an LLM may rephrase them. */
  readonly reasons: readonly string[];
  /** Lowest confidence among constituent dishes — the plate is only as good as its worst estimate. */
  readonly confidence: 'high' | 'medium' | 'low';
  readonly score: number;
}

export interface PlateRequest {
  readonly meal: MessMeal;
  readonly remainingKcal: number;
  readonly remainingProtein: number;
  readonly diet: DietPreference;
  readonly goal: 'muscle-gain' | 'fat-loss' | 'strength' | 'general';
  /** Dish ids the user has told us they dislike. Hard exclusion. */
  readonly excludedDishIds?: readonly string[];
}

/**
 * Diet gate. `unknown` is excluded for vegetarians by design: in a mess that
 * serves meat, an unrecognised dish name is not proof of vegetarianism, and the
 * cost of being wrong is asymmetric.
 */
export function isDietAllowed(diet: DietClass, preference: DietPreference): boolean {
  switch (preference) {
    case 'non-vegetarian':
      return true;
    case 'eggetarian':
      return diet === 'veg' || diet === 'egg';
    case 'vegetarian':
      return diet === 'veg';
  }
}

/** Max servings we'll ever suggest of one dish, by role. Keeps plates realistic. */
function maxServings(dish: MessDish): number {
  switch (dish.role) {
    case 'staple':
      return dish.name.toLowerCase().includes('rice') ? 2 : 3; // 3 rotis is normal, 3 plates of rice is not
    case 'protein':
      return 2;
    case 'legume':
      return 2;
    case 'dairy':
      return 2;
    case 'vegetable':
      return 1;
    case 'fruit':
      return 1;
    default:
      return 1;
  }
}

/** Roles that can appear on a suggested plate at all. */
const PLATE_ROLES = new Set(['staple', 'protein', 'legume', 'dairy', 'vegetable', 'fruit']);

function proteinDensity(dish: MessDish): number {
  const n = dish.nutrition;
  if (n === null) return 0;
  const kcal = midpoint(n.macros.kcalLow, n.macros.kcalHigh);
  if (kcal <= 0) return 0;
  return midpoint(n.macros.proteinLow, n.macros.proteinHigh) / kcal;
}

export function selectCandidates(request: PlateRequest, limit = 9): MessDish[] {
  const excluded = new Set(request.excludedDishIds ?? []);
  return request.meal.dishes
    .filter((d) => !d.isAmbient)
    .filter((d) => PLATE_ROLES.has(d.role))
    .filter((d) => d.nutrition !== null)
    .filter((d) => !excluded.has(d.id))
    .filter((d) => isDietAllowed(d.diet, request.diet))
    .sort((a, b) => proteinDensity(b) - proteinDensity(a))
    .slice(0, limit);
}

interface ScoreInput {
  readonly macros: MacroRange;
  readonly itemCount: number;
  readonly totalServings: number;
  readonly request: PlateRequest;
}

/**
 * Scoring is intentionally simple and inspectable. Higher is better.
 *
 *  - Protein toward the remaining target is the primary reward, since protein
 *    is the macro students most reliably under-eat on mess food.
 *  - Overshooting calories is penalised much harder than undershooting.
 *  - Fat-loss weights the calorie penalty up; muscle-gain tolerates a small
 *    surplus rather than leaving the user short.
 */
export function scorePlate(input: ScoreInput): number {
  const { macros, itemCount, totalServings, request } = input;
  const kcal = midpoint(macros.kcalLow, macros.kcalHigh);
  const protein = midpoint(macros.proteinLow, macros.proteinHigh);

  const proteinTarget = Math.max(request.remainingProtein, 1);
  const proteinRatio = Math.min(protein / proteinTarget, 1.25);
  const proteinScore = proteinRatio * 100;

  const kcalTarget = Math.max(request.remainingKcal, 1);
  const overshoot = Math.max(0, kcal - kcalTarget) / kcalTarget;
  const undershoot = Math.max(0, kcalTarget - kcal) / kcalTarget;

  const overshootWeight = request.goal === 'fat-loss' ? 180 : 110;
  const undershootWeight = request.goal === 'muscle-gain' ? 55 : 35;

  const kcalPenalty = overshoot * overshootWeight + undershoot * undershootWeight;

  // Prefer a realistic 3–5 item plate over a single giant portion or a pile of ten.
  const shapePenalty = Math.abs(itemCount - 4) * 4 + Math.max(0, totalServings - 7) * 6;

  return proteinScore - kcalPenalty - shapePenalty;
}

function worstConfidence(items: readonly MessDish[]): 'high' | 'medium' | 'low' {
  let worst: 'high' | 'medium' | 'low' = 'high';
  for (const dish of items) {
    const c = dish.nutrition?.confidence ?? 'low';
    if (c === 'low') return 'low';
    if (c === 'medium') worst = 'medium';
  }
  return worst;
}

function buildReasons(
  macros: MacroRange,
  chosen: readonly MessDish[],
  request: PlateRequest,
): string[] {
  const reasons: string[] = [];
  const protein = midpoint(macros.proteinLow, macros.proteinHigh);
  const kcal = midpoint(macros.kcalLow, macros.kcalHigh);

  const proteinCover = request.remainingProtein > 0 ? protein / request.remainingProtein : 1;
  if (proteinCover >= 0.85) {
    reasons.push('Covers essentially all of your remaining protein.');
  } else if (proteinCover >= 0.6) {
    reasons.push('Covers most of your remaining protein.');
  } else {
    reasons.push('Best protein available on tonight\u2019s menu, though it falls short of your target.');
  }

  if (kcal <= request.remainingKcal) {
    reasons.push('Fits inside your remaining calories.');
  } else {
    reasons.push('Slightly over your remaining calories \u2014 drop a serving of rice or roti to fit.');
  }

  const proteinDish = chosen.find((d) => d.role === 'protein');
  if (proteinDish !== undefined) {
    reasons.push(`${proteinDish.name} is the highest-protein item served at this meal.`);
  }
  return reasons;
}

/**
 * Bounded depth-first enumeration. The candidate list is capped at 9 dishes and
 * total servings at 8, so the search space stays small and the result is
 * deterministic for a given menu and request.
 */
export function suggestPlates(request: PlateRequest, maxResults = 3): PlateSuggestion[] {
  const candidates = selectCandidates(request);
  if (candidates.length === 0) return [];

  const results: PlateSuggestion[] = [];

  const chosenCounts = new Array<number>(candidates.length).fill(0);

  // Precomputed lower-bound calories per candidate, for pruning.
  const kcalLow = candidates.map((d) => d.nutrition?.macros.kcalLow ?? 0);
  const kcalCeiling = Math.max(request.remainingKcal * 1.5, 400);

  const walk = (index: number, totalServings: number, accKcalLow: number): void => {
    // Prune: once the optimistic (low-end) calorie total is far past budget,
    // no deeper combination can score well. Keeps the search fast on-device.
    if (accKcalLow > kcalCeiling) return;
    if (index === candidates.length) {
      if (totalServings === 0) return;
      const chosen: MessDish[] = [];
      const items: PlateItem[] = [];
      let macros: MacroRange = ZERO_MACROS;

      for (let i = 0; i < candidates.length; i += 1) {
        const servings = chosenCounts[i] ?? 0;
        if (servings === 0) continue;
        const dish = candidates[i];
        if (dish === undefined || dish.nutrition === null) continue;
        const scaled = scaleMacros(dish.nutrition.macros, servings);
        macros = addMacros(macros, scaled);
        chosen.push(dish);
        items.push({
          dishId: dish.id,
          name: dish.name,
          servings,
          servingLabel: dish.nutrition.servingLabel,
          macros: scaled,
        });
      }
      if (items.length === 0) return;

      const score = scorePlate({
        macros,
        itemCount: items.length,
        totalServings,
        request,
      });
      results.push({
        items,
        macros,
        reasons: buildReasons(macros, chosen, request),
        confidence: worstConfidence(chosen),
        score,
      });
      return;
    }

    const dish = candidates[index];
    if (dish === undefined) return;
    const cap = maxServings(dish);
    const unit = kcalLow[index] ?? 0;
    for (let servings = 0; servings <= cap; servings += 1) {
      if (totalServings + servings > 8) break;
      const nextKcal = accKcalLow + unit * servings;
      if (nextKcal > kcalCeiling) break;
      chosenCounts[index] = servings;
      walk(index + 1, totalServings + servings, nextKcal);
    }
    chosenCounts[index] = 0;
  };

  walk(0, 0, 0);

  return results
    .sort((a, b) => b.score - a.score)
    .filter((plate, i, all) => {
      // Drop near-duplicates so the three shown options are actually different.
      const key = (p: PlateSuggestion): string =>
        p.items.map((it) => `${it.dishId}x${it.servings}`).sort().join('|');
      return all.findIndex((other) => key(other) === key(plate)) === i;
    })
    .slice(0, maxResults);
}

/** Convenience: pick the meal a user is about to eat, given local time. */
export function currentMealSlot(hour: number): MealSlot {
  if (hour < 10) return 'breakfast';
  if (hour < 15) return 'lunch';
  if (hour < 18) return 'snacks';
  return 'dinner';
}
