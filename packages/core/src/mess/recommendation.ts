/**
 * A mess meal recommendation, end to end (Phase 10, ADR-015): the meal's
 * share of what the day still needs, the menu's state, the plates, the
 * honest shortfall, and why every dish is or is not on a plate.
 *
 * Pure and deterministic. The API gathers the inputs (the caller's own data
 * only) and returns this as it is; nothing here is stored.
 */
import { defaultMealSlot } from '../nutrition/log.js';
import type { Allergen } from './allergens.js';
import { searchPlates, dishVerdicts, type DietPreference, type DishReason, type PlateGoal, type PlateReason, type PlateSuggestion } from './recommend.js';
import type { MealSlot, MessDay, MessDish } from './types.js';

export const MEAL_ORDER: readonly MealSlot[] = ['breakfast', 'lunch', 'snacks', 'dinner'];

/** ADR-015 §4 — fixed. */
export const MEAL_WEIGHTS: Readonly<Record<MealSlot, number>> = {
  breakfast: 0.25,
  lunch: 0.35,
  snacks: 0.1,
  dinner: 0.3,
};

/**
 * The meal's share of what the day still needs: its weight over the weights
 * of the meals still to come (this one, and every later one with no log).
 */
export function mealShare(slot: MealSlot, loggedSlots: readonly MealSlot[]): number {
  const logged = new Set(loggedSlots);
  const from = MEAL_ORDER.indexOf(slot);
  let total = 0;
  MEAL_ORDER.forEach((s, i) => {
    if (i < from) return;
    if (s === slot || !logged.has(s)) total += MEAL_WEIGHTS[s];
  });
  return MEAL_WEIGHTS[slot] / total;
}

export interface DayTargets {
  readonly kcal: number;
  readonly proteinG: number;
  readonly carbG: number;
  readonly fatG: number;
}

/** What has been eaten on the day, as ranges (the Phase 8 day totals). */
export interface EatenRanges {
  readonly kcalLow: number;
  readonly kcalHigh: number;
  readonly proteinLow: number;
  readonly proteinHigh: number;
  readonly carbLow: number;
  readonly carbHigh: number;
  readonly fatLow: number;
  readonly fatHigh: number;
}

export const NOTHING_EATEN: EatenRanges = {
  kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0, carbLow: 0, carbHigh: 0, fatLow: 0, fatHigh: 0,
};

export interface MealTarget {
  readonly share: number;
  readonly kcal: number;
  readonly protein: number;
  readonly carb: number;
  readonly fat: number;
}

const round1 = (v: number): number => Math.round(v * 10) / 10;

/**
 * ADR-015 §4, conservative: kcal, carbs and fat from the LOW end of what
 * remains (as if the most was eaten), protein from the HIGH end.
 * kcal to a whole number, grams to one decimal.
 */
export function mealTarget(targets: DayTargets, eaten: EatenRanges, share: number): MealTarget {
  return {
    share: Math.round(share * 10_000) / 10_000,
    kcal: Math.round(Math.max(0, targets.kcal - eaten.kcalHigh) * share),
    protein: round1(Math.max(0, targets.proteinG - eaten.proteinLow) * share),
    carb: round1(Math.max(0, targets.carbG - eaten.carbHigh) * share),
    fat: round1(Math.max(0, targets.fatG - eaten.fatHigh) * share),
  };
}

/**
 * The meal to recommend when none is asked for (owner D22): today, the first
 * meal at or after the current hour's with no log — else the current hour's
 * meal, marked already logged; tomorrow, breakfast.
 */
export function defaultRecommendationSlot(
  isToday: boolean,
  hour: number,
  loggedSlots: readonly MealSlot[],
): { slot: MealSlot; alreadyLogged: boolean } {
  if (!isToday) return { slot: 'breakfast', alreadyLogged: false };
  const logged = new Set(loggedSlots);
  const current = defaultMealSlot(hour);
  for (const s of MEAL_ORDER.slice(MEAL_ORDER.indexOf(current))) {
    if (!logged.has(s)) return { slot: s, alreadyLogged: false };
  }
  return { slot: current, alreadyLogged: true };
}

export type RecommendationStatus =
  | 'ok'
  | 'no-targets'
  | 'target-reached'
  | 'menu-unavailable'
  | 'meal-not-served'
  | 'nothing-safe'
  | 'nothing-fits';

export interface Gap {
  readonly target: number;
  /** target − the plate's HIGH end: the least the plate falls short by. */
  readonly gapLow: number;
  /** target − the plate's LOW end: the most. */
  readonly gapHigh: number;
  /** The highest optimistic value any searched plate reaches. */
  readonly menuMax: number;
  readonly menuCanMeet: boolean;
}

export interface MealRecommendationInput {
  readonly menu: MessDay;
  readonly slot: MealSlot;
  readonly diet: DietPreference;
  readonly allergies: readonly Allergen[];
  readonly excludedDishIds: readonly string[];
  readonly goal: PlateGoal;
  readonly targets: DayTargets | null;
  readonly eaten: EatenRanges;
  readonly loggedSlots: readonly MealSlot[];
  readonly varietyDays: Readonly<Record<string, number>>;
  readonly postWorkout: boolean;
}

export interface RankedPlate extends PlateSuggestion {
  readonly rank: number;
}

export interface DishOutcome {
  readonly dish: MessDish;
  readonly onPlate: boolean;
  readonly reasons: readonly DishReason[];
}

export interface MealRecommendation {
  readonly status: RecommendationStatus;
  readonly basis: 'published' | 'inferred' | null;
  readonly target: MealTarget | null;
  readonly plates: readonly RankedPlate[];
  readonly shortfall: { readonly protein: Gap | null; readonly kcal: Gap | null } | null;
  readonly dishes: readonly DishOutcome[];
}

/**
 * ADR-015 §10 (owner D13 as modified): a nutrient falls short when even the
 * top plate's optimistic (high) end is below the meal target. The gap is the
 * plate's own range below the target — never inflated.
 */
export function gapOf(target: number, low: number, high: number, menuMax: number): Gap | null {
  if (high >= target) return null;
  return {
    target,
    gapLow: round1(target - high),
    gapHigh: round1(target - low),
    menuMax,
    menuCanMeet: menuMax >= target,
  };
}

export function recommendMeal(input: MealRecommendationInput): MealRecommendation {
  const r = input.menu.resolution;
  const basis = r.kind === 'exact' ? 'published' : r.kind === 'cycle-inferred' ? 'inferred' : null;
  const empty = (status: RecommendationStatus, target: MealTarget | null, dishes: readonly DishOutcome[] = []): MealRecommendation => ({
    status,
    basis,
    target,
    plates: [],
    shortfall: null,
    dishes,
  });

  if (r.kind === 'unavailable') return empty('menu-unavailable', null);
  const meal = input.menu.meals.find((m) => m.slot === input.slot);
  if (meal === undefined || meal.dishes.length === 0) return empty('meal-not-served', null);

  const target = input.targets === null ? null : mealTarget(input.targets, input.eaten, mealShare(input.slot, input.loggedSlots));

  const request = {
    meal,
    remainingKcal: target?.kcal ?? 0,
    remainingProtein: target?.protein ?? 0,
    remainingCarb: target?.carb ?? 0,
    remainingFat: target?.fat ?? 0,
    diet: input.diet,
    goal: input.goal,
    excludedDishIds: input.excludedDishIds,
    allergies: input.allergies,
    postWorkout: input.postWorkout,
    varietyDays: input.varietyDays,
  };
  const verdicts = dishVerdicts(request);
  const filtered = (onPlateRanks: Map<string, number[]>, candidates: ReadonlySet<string>): DishOutcome[] =>
    verdicts.map((v) => {
      if (!v.eligible) return { dish: v.dish, onPlate: false, reasons: v.reasons };
      const ranks = onPlateRanks.get(v.dish.id);
      if (ranks !== undefined) return { dish: v.dish, onPlate: true, reasons: [{ code: 'on-plate', ranks }] };
      return {
        dish: v.dish,
        onPlate: false,
        reasons: [candidates.has(v.dish.id) ? { code: 'not-chosen' } : { code: 'not-top-candidate' }],
      };
    });

  if (target === null) return empty('no-targets', null, filtered(new Map(), new Set()));
  // Owner decision 8: no plate when the meal's calorie budget is already zero;
  // the protein still needed is reported in `target`.
  if (target.kcal <= 0) return empty('target-reached', target, filtered(new Map(), new Set()));

  const search = searchPlates(request);
  const candidateIds = new Set(search.candidates.map((d) => d.id));
  if (search.candidates.length === 0) return empty('nothing-safe', target, filtered(new Map(), candidateIds));
  if (search.plates.length === 0) return empty('nothing-fits', target, filtered(new Map(), candidateIds));

  const inferred: PlateReason[] = r.kind === 'cycle-inferred' ? [{ code: 'inferred-menu', sourceDate: r.sourceDate }] : [];
  const plates: RankedPlate[] = search.plates.map((p, i) => ({ ...p, reasons: [...p.reasons, ...inferred], rank: i + 1 }));

  const ranks = new Map<string, number[]>();
  for (const plate of plates) {
    for (const item of plate.items) ranks.set(item.dishId, [...(ranks.get(item.dishId) ?? []), plate.rank]);
  }

  const top = plates[0];
  let shortfall: MealRecommendation['shortfall'] = null;
  if (top !== undefined) {
    const protein = gapOf(target.protein, top.macros.proteinLow, top.macros.proteinHigh, search.menuMax.proteinHigh);
    const kcal = gapOf(target.kcal, top.macros.kcalLow, top.macros.kcalHigh, search.menuMax.kcalHigh);
    if (protein !== null || kcal !== null) shortfall = { protein, kcal };
  }

  return { status: 'ok', basis, target, plates, shortfall, dishes: filtered(ranks, candidateIds) };
}
