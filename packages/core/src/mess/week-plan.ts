/**
 * Beta 6.1 (premium): a week of mess meals, planned by FITOS's own
 * recommender (owner: not the AI). Each served meal of each day gets the
 * plate `recommendMeal` would suggest for it, in meal order, as if the
 * earlier plates of that day were eaten — so a day's plates share the day's
 * targets the way the recommender splits them. A dish planned (or eaten) in
 * the three days before loses ties, through the recommender's own variety
 * term, so the week does not repeat itself.
 *
 * The day's menu keeps its basis: an inferred menu is planned, and says so.
 */
import type { Allergen } from './allergens.js';
import { addMacros, ZERO_MACROS } from './nutrition.js';
import type { DietPreference, PlateGoal } from './recommend.js';
import { MEAL_ORDER, recommendMeal, type DayTargets, type RankedPlate, type RecommendationStatus } from './recommendation.js';
import type { MacroRange, MealSlot, MessDay } from './types.js';

/** How far back a planned dish counts for variety (the recommender's own window). */
export const WEEK_PLAN_VARIETY_DAYS = 3;

export interface WeekPlanInput {
  /** The days to plan, in order. */
  readonly days: readonly MessDay[];
  readonly diet: DietPreference;
  readonly allergies: readonly Allergen[];
  readonly excludedDishIds: readonly string[];
  readonly goal: PlateGoal;
  readonly targets: DayTargets | null;
  /** Dish id → days it was eaten in the three days before the first one. */
  readonly history: Readonly<Record<string, number>>;
}

export interface WeekPlanMeal {
  readonly slot: MealSlot;
  readonly status: RecommendationStatus;
  /** The recommender's first plate; null when it has none. */
  readonly plate: RankedPlate | null;
}

export interface WeekPlanDay {
  readonly date: string;
  readonly basis: 'published' | 'inferred' | null;
  readonly meals: readonly WeekPlanMeal[];
  /** The planned plates added up. */
  readonly totals: MacroRange;
}

export function planWeek(input: WeekPlanInput): WeekPlanDay[] {
  const chosen: Set<string>[] = [];
  return input.days.map((menu, i): WeekPlanDay => {
    // Variety: days the dish is planned in the 3 days before; the history only while it is inside that window.
    const variety: Record<string, number> = {};
    if (i < WEEK_PLAN_VARIETY_DAYS) for (const [id, n] of Object.entries(input.history)) variety[id] = n;
    for (let j = Math.max(0, i - WEEK_PLAN_VARIETY_DAYS); j < i; j += 1) {
      for (const id of chosen[j]!) variety[id] = (variety[id] ?? 0) + 1;
    }
    const today = new Set<string>();
    const meals: WeekPlanMeal[] = [];
    let eaten: MacroRange = ZERO_MACROS;
    const logged: MealSlot[] = [];
    const basis = menu.resolution.kind === 'exact' ? 'published' : menu.resolution.kind === 'cycle-inferred' ? 'inferred' : null;
    // No menu for the day: nothing to plan (the screen says the menu is not out).
    for (const slot of basis === null ? [] : MEAL_ORDER) {
      const served = menu.meals.find((m) => m.slot === slot);
      if (served === undefined || served.dishes.length === 0) continue;
      const r = recommendMeal({
        menu,
        slot,
        diet: input.diet,
        allergies: input.allergies,
        excludedDishIds: input.excludedDishIds,
        goal: input.goal,
        targets: input.targets,
        eaten,
        loggedSlots: logged,
        varietyDays: variety,
        postWorkout: false,
      });
      const plate = r.plates[0] ?? null;
      meals.push({ slot, status: r.status, plate });
      if (plate === null) continue;
      eaten = addMacros(eaten, plate.macros);
      logged.push(slot);
      for (const item of plate.items) today.add(item.dishId);
    }
    chosen.push(today);
    return { date: menu.date, basis, meals, totals: eaten };
  });
}
