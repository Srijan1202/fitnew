/**
 * Phase 10 — mess recommendations (ADR-015; docs/phase-plans/phase-10-plan.md).
 * Every constant, formula and safety rule the plan fixes is pinned here.
 */
import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { ALLERGENS, allergenStatus, type Allergen } from '../src/mess/allergens.js';
import { classifyDiet } from '../src/mess/classify.js';
import { capMessConfidence, enrichDish } from '../src/mess/nutrition.js';
import { parseMenuString } from '../src/mess/parse.js';
import { VIT_DESCRIPTORS, VIT_ENDPOINTS } from '../src/mess/providers/vit/config.js';
import { buildDay } from '../src/mess/providers/vit/provider.js';
import {
  GOAL_WEIGHTS, SCORING, currentMealSlot, isDietAllowed, scoreTerms,
  type DietPreference, type PlateGoal, type PlateRequest,
} from '../src/mess/recommend.js';
import {
  MEAL_WEIGHTS, NOTHING_EATEN, defaultRecommendationSlot, gapOf, mealShare, mealTarget, recommendMeal,
  type DayTargets, type MealRecommendationInput,
} from '../src/mess/recommendation.js';
import { defaultMealSlot } from '../src/nutrition/log.js';
import type { MacroRange, MealSlot, MessDay, MessItResponse, MessMeal } from '../src/mess/types.js';

/* ----------------------------------------------------------- fixtures -- */

const load = (path: string): MessItResponse =>
  JSON.parse(readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8')) as MessItResponse;
const fresh = (n: string) => load(`./fixtures/messit-2026-09-24/${n}.json`);
const old = (n: string) => load(`./fixtures/${n}.json`);
const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);
const servesNonVeg = (n: string): boolean => {
  const e = VIT_ENDPOINTS.find((x) => `hostel-${x.hostel}-mess-${x.mess}` === n);
  return VIT_DESCRIPTORS.find((d) => d.hostelId === e?.hostelId && d.messId === e?.messId)?.servesNonVeg ?? true;
};

/** A menu as the API serves it: estimates capped at medium, as stored (ADR-014). */
function stored(day: MessDay): MessDay {
  return {
    ...day,
    meals: day.meals.map((m) => ({
      ...m,
      dishes: m.dishes.map((d) =>
        d.nutrition === null ? d : { ...d, nutrition: { ...d.nutrition, confidence: capMessConfidence(d.nutrition.confidence) } },
      ),
    })),
  };
}
const dayOf = (payload: MessItResponse, date: string, nonVeg: boolean): MessDay => stored(buildDay(payload, date, nonVeg));
const mealOf = (day: MessDay, slot: MealSlot): MessMeal => {
  const m = day.meals.find((x) => x.slot === slot);
  if (m === undefined) throw new Error(`no ${slot}`);
  return m;
};

const TARGETS: DayTargets = { kcal: 2400, proteinG: 140, carbG: 290, fatG: 70 };
const THREE_MEALS_EATEN = { kcalLow: 1100, kcalHigh: 1300, proteinLow: 55, proteinHigh: 70, carbLow: 150, carbHigh: 170, fatLow: 30, fatHigh: 40 };

function input(over: Partial<MealRecommendationInput> & Pick<MealRecommendationInput, 'menu' | 'slot'>): MealRecommendationInput {
  return {
    diet: 'non-vegetarian',
    allergies: [],
    excludedDishIds: [],
    goal: 'muscle-gain',
    targets: TARGETS,
    eaten: NOTHING_EATEN,
    loggedSlots: [],
    varietyDays: {},
    postWorkout: false,
    ...over,
  };
}

const WOMENS_NONVEG_DINNER = dayOf(fresh('hostel-2-mess-3'), '2026-09-11', true);
const MENS_VEG_LUNCH_DAY = dayOf(fresh('hostel-1-mess-2'), '2026-09-24', false);

/* ------------------------------------------------ B12: slot boundaries -- */

describe('meal-slot boundaries are 11 / 16 / 19 everywhere (owner D21)', () => {
  it.each([
    [10, 'breakfast'], [11, 'lunch'], [15, 'lunch'], [16, 'snacks'], [18, 'snacks'], [19, 'dinner'], [23, 'dinner'],
  ] as const)('%i:00 → %s', (hour, slot) => {
    expect(currentMealSlot(hour)).toBe(slot);
    expect(defaultMealSlot(hour)).toBe(slot);
  });
});

/* ------------------------------------------------ B6: the meal's share -- */

describe('meal share and meal target (ADR-015 §4)', () => {
  it('fixed weights', () => {
    expect(MEAL_WEIGHTS).toEqual({ breakfast: 0.25, lunch: 0.35, snacks: 0.1, dinner: 0.3 });
  });

  it.each([
    ['breakfast', [], 0.25 / 1.0],
    ['lunch', [], 0.35 / 0.75],
    ['snacks', [], 0.1 / 0.4],
    ['dinner', [], 1],
    ['lunch', ['breakfast'], 0.35 / 0.75],
    ['snacks', ['dinner'], 1], // a later meal already logged is not still to come
    ['lunch', ['snacks', 'dinner'], 1],
    ['breakfast', ['lunch'], 0.25 / 0.65],
    ['dinner', ['breakfast', 'lunch', 'snacks', 'dinner'], 1], // the chosen meal always counts
  ] as const)('%s with %j logged → %f', (slot, logged, share) => {
    expect(mealShare(slot, logged)).toBeCloseTo(share, 12);
  });

  it('lunch with nothing eaten gets 0.4667 of the day', () => {
    expect(mealTarget(TARGETS, NOTHING_EATEN, mealShare('lunch', [])).share).toBe(0.4667);
  });

  it('kcal, carbs and fat from the LOW end of what remains; protein from the HIGH end', () => {
    const t = mealTarget(TARGETS, THREE_MEALS_EATEN, 1);
    expect(t).toEqual({ share: 1, kcal: 2400 - 1300, protein: 140 - 55, carb: 290 - 170, fat: 70 - 40 });
    const half = mealTarget(TARGETS, THREE_MEALS_EATEN, 0.5);
    expect(half).toEqual({ share: 0.5, kcal: 550, protein: 42.5, carb: 60, fat: 15 });
  });

  it('never negative', () => {
    const over = { ...THREE_MEALS_EATEN, kcalHigh: 2600, carbHigh: 400, fatHigh: 90, proteinLow: 200 };
    expect(mealTarget(TARGETS, over, 1)).toEqual({ share: 1, kcal: 0, protein: 0, carb: 0, fat: 0 });
  });
});

describe('default meal (owner D22)', () => {
  it('today: the first meal from the current hour with no log', () => {
    expect(defaultRecommendationSlot(true, 13, [])).toEqual({ slot: 'lunch', alreadyLogged: false });
    expect(defaultRecommendationSlot(true, 13, ['lunch'])).toEqual({ slot: 'snacks', alreadyLogged: false });
    expect(defaultRecommendationSlot(true, 13, ['lunch', 'snacks'])).toEqual({ slot: 'dinner', alreadyLogged: false });
  });
  it('every remaining meal logged: the current one, marked logged', () => {
    expect(defaultRecommendationSlot(true, 20, ['dinner'])).toEqual({ slot: 'dinner', alreadyLogged: true });
  });
  it('tomorrow: breakfast', () => {
    expect(defaultRecommendationSlot(false, 22, ['dinner'])).toEqual({ slot: 'breakfast', alreadyLogged: false });
  });
});

/* ------------------------------------------------- B7: scoring pinned -- */

describe('scoring constants and terms are fixed (ADR-015 §9, owner D12)', () => {
  it('constants', () => {
    expect(SCORING).toMatchObject({
      proteinCap: 1.25, proteinPoints: 100, carbWeight: 40, carbWeightPostWorkout: 20, fatWeight: 50, carbReward: 20,
      shapeTargetItems: 4, shapePerItem: 4, shapeServingsFree: 7, shapePerServing: 6, varietyPerDay: 6, varietyMaxDays: 3,
      maxCandidates: 9, maxServings: 8, kcalCeilingFactor: 1.5, kcalCeilingFloor: 400,
    });
  });

  it('goal weights; recomposition = fat-loss (owner R4)', () => {
    expect(GOAL_WEIGHTS).toEqual({
      'muscle-gain': { over: 110, under: 55 },
      'fat-loss': { over: 180, under: 35 },
      recomposition: { over: 180, under: 35 },
      strength: { over: 110, under: 35 },
      general: { over: 110, under: 35 },
      maintenance: { over: 110, under: 35 },
    });
  });

  const plate = (kcal: [number, number], protein: [number, number], carb: [number, number], fat: [number, number]): MacroRange => ({
    kcalLow: kcal[0], kcalHigh: kcal[1], proteinLow: protein[0], proteinHigh: protein[1],
    carbLow: carb[0], carbHigh: carb[1], fatLow: fat[0], fatHigh: fat[1],
  });
  const req = (over: Partial<PlateRequest> = {}): PlateRequest => ({
    meal: { slot: 'lunch', dishes: [], rawMenu: '' },
    remainingKcal: 800, remainingProtein: 40, remainingCarb: 100, remainingFat: 20,
    diet: 'non-vegetarian', goal: 'general', ...over,
  });

  it('each term, by hand', () => {
    // midpoints: kcal 1000, protein 30, carb 120, fat 30
    const t = scoreTerms({ macros: plate([900, 1100], [25, 35], [110, 130], [25, 35]), itemCount: 5, totalServings: 8, request: req() });
    expect(t.proteinScore).toBeCloseTo(100 * (30 / 40), 10);
    expect(t.kcalPenalty).toBeCloseTo(110 * (200 / 800), 10);
    expect(t.carbPenalty).toBeCloseTo(40 * (20 / 100), 10);
    expect(t.fatPenalty).toBeCloseTo(50 * (10 / 20), 10);
    expect(t.carbReward).toBe(0);
    expect(t.shapePenalty).toBe(4 * 1 + 6 * 1);
    expect(t.varietyPenalty).toBe(0);
    expect(t.score).toBeCloseTo(75 - 27.5 - 8 - 25 - 10, 10);
  });

  it('the protein reward is capped at 1.25 × 100', () => {
    const t = scoreTerms({ macros: plate([800, 800], [90, 110], [0, 0], [0, 0]), itemCount: 4, totalServings: 4, request: req() });
    expect(t.proteinScore).toBe(125);
  });

  it('undershoot weight by goal', () => {
    const m = plate([400, 400], [40, 40], [0, 0], [0, 0]);
    const under = (goal: PlateGoal) => scoreTerms({ macros: m, itemCount: 4, totalServings: 4, request: req({ goal }) }).kcalPenalty;
    expect(under('muscle-gain')).toBeCloseTo(55 * 0.5, 10);
    expect(under('fat-loss')).toBeCloseTo(35 * 0.5, 10);
    expect(under('recomposition')).toBeCloseTo(35 * 0.5, 10);
  });

  it('overshoot weight by goal: recomposition = fat-loss', () => {
    const m = plate([1200, 1200], [40, 40], [0, 0], [0, 0]);
    const over = (goal: PlateGoal) => scoreTerms({ macros: m, itemCount: 4, totalServings: 4, request: req({ goal }) }).kcalPenalty;
    expect(over('fat-loss')).toBeCloseTo(180 * 0.5, 10);
    expect(over('recomposition')).toBe(over('fat-loss'));
    expect(over('muscle-gain')).toBeCloseTo(110 * 0.5, 10);
  });

  it('post-workout: the carb penalty halves (40 → 20) and the carb reward (20 × min(c/Tc, 1)) applies', () => {
    const m = plate([800, 800], [40, 40], [140, 160], [20, 20]); // carb midpoint 150 vs Tc 100
    const off = scoreTerms({ macros: m, itemCount: 4, totalServings: 4, request: req() });
    const on = scoreTerms({ macros: m, itemCount: 4, totalServings: 4, request: req({ postWorkout: true }) });
    expect(off.carbPenalty).toBeCloseTo(40 * 0.5, 10);
    expect(on.carbPenalty).toBeCloseTo(20 * 0.5, 10);
    expect(off.carbReward).toBe(0);
    expect(on.carbReward).toBe(20);
    const half = scoreTerms({ macros: plate([800, 800], [40, 40], [50, 50], [20, 20]), itemCount: 4, totalServings: 4, request: req({ postWorkout: true }) });
    expect(half.carbReward).toBeCloseTo(10, 10);
  });

  it('no carb/fat target → no carb/fat terms (the pre-Phase-10 request still scores as before)', () => {
    const t = scoreTerms({
      macros: plate([800, 800], [40, 40], [500, 500], [90, 90]), itemCount: 4, totalServings: 4,
      request: (({ remainingCarb: _c, remainingFat: _f, ...rest }) => rest)(req()),
    });
    expect(t.carbPenalty).toBe(0);
    expect(t.fatPenalty).toBe(0);
  });

  it('variety: 6 per day seen, 0–3 days, summed over the plate', () => {
    const m = plate([800, 800], [40, 40], [0, 0], [0, 0]);
    const v = (days: Record<string, number>, ids: string[]) =>
      scoreTerms({ macros: m, itemCount: 4, totalServings: 4, request: req({ varietyDays: days }), dishIds: ids }).varietyPenalty;
    expect(v({ dal: 1 }, ['dal'])).toBe(6);
    expect(v({ dal: 3 }, ['dal'])).toBe(18);
    expect(v({ dal: 5 }, ['dal'])).toBe(18); // capped at 3 days
    expect(v({ dal: 2, rice: 1 }, ['dal', 'rice'])).toBe(18);
    expect(v({ dal: 3 }, ['rice'])).toBe(0);
  });
});

/* ------------------------------------------------ B1: diet safety sweep -- */

const DIETS: readonly DietPreference[] = ['vegetarian', 'eggetarian', 'non-vegetarian'];
const SLOTS: readonly MealSlot[] = ['breakfast', 'lunch', 'snacks', 'dinner'];

describe('diet safety across every real menu (B1)', () => {
  it('vegetarian → only veg; eggetarian → veg or egg; unknown never for either — primary and alternatives', { timeout: 120_000 }, () => {
    let plates = 0;
    const sources: [string, MessItResponse][] = [
      ...NAMES.map((n) => [n, fresh(n)] as [string, MessItResponse]),
      ...NAMES.map((n) => [n, old(n)] as [string, MessItResponse]),
    ];
    for (const [name, payload] of sources) {
      for (const d of payload.menu) {
        const day = dayOf(payload, d.date, servesNonVeg(name));
        for (const slot of SLOTS) {
          if (!day.meals.some((m) => m.slot === slot)) continue;
          for (const diet of DIETS.slice(0, 2)) {
            const rec = recommendMeal(input({ menu: day, slot, diet }));
            for (const plate of rec.plates) {
              plates += 1;
              for (const item of plate.items) {
                const dish = mealOf(day, slot).dishes.find((x) => x.id === item.dishId);
                expect(dish).toBeDefined();
                expect(isDietAllowed(dish!.diet, diet), `${name} ${d.date} ${slot} ${diet} ${dish!.name}`).toBe(true);
                expect(dish!.diet).not.toBe('unknown');
                for (const a of dish!.alternativeDiets) expect(isDietAllowed(a, diet)).toBe(true);
              }
            }
          }
        }
      }
    }
    expect(plates).toBeGreaterThan(500);
  });
});

/* ------------------------------------------- B2/B3: allergy hard filter -- */

describe('allergen status (B3)', () => {
  it.each([
    ['White Rice', 'peanut', 'free'],
    ['White Rice', 'milk', 'free'],
    ['Egg Fried Rice', 'egg', 'contains'],
    ['Egg Fried Rice', 'peanut', 'likely'], // "fried"
    ['Veg Fried Rice', 'peanut', 'likely'],
    ['Jeera Rice', 'peanut', 'unknown'], // cooked with an unknown fat
    ['Curd', 'milk', 'contains'],
    ['Curd', 'peanut', 'free'],
    ['Curd Rice', 'mustard', 'likely'],
    ['Groundnut Chutney', 'peanut', 'contains'],
    ['Coconut Chutney', 'peanut', 'likely'],
    ['Sambar', 'wheat', 'likely'], // compounded asafoetida
    ['Sambar', 'tree-nut', 'free'],
    ['Dhal Makhani', 'tree-nut', 'likely'],
    ['Dhal Makhani', 'milk', 'contains'],
    ['Phulka', 'wheat', 'contains'],
    ['Phulka', 'peanut', 'free'],
    ['Phulka', 'milk', 'unknown'], // may be brushed with ghee
    ['Idly', 'wheat', 'free'],
    ['Tea', 'milk', 'contains'],
    ['Meal Maker Curry', 'soy', 'contains'],
    ['Kara Kulambu', 'sesame', 'likely'],
    ['Veg. Cutlet (2 Nos)', 'wheat', 'contains'],
    ['Paneer Butter Masala', 'milk', 'contains'],
    ['Paneer Butter Masala', 'tree-nut', 'likely'],
    ['Cashew Pulao', 'tree-nut', 'contains'],
    ['Seasonal Fruit', 'mustard', 'free'],
    ['Urapadai', 'egg', 'unknown'],
  ] as const)('%s × %s → %s', (name, allergen, status) => {
    expect(allergenStatus(name, allergen, 'veg')).toBe(status);
  });

  it('fish and shellfish: free only for a veg or egg dish', () => {
    expect(allergenStatus('Dal Tadka', 'fish', 'veg')).toBe('free');
    expect(allergenStatus('Scrambled Egg', 'shellfish', 'egg')).toBe('free');
    expect(allergenStatus('Salna', 'fish', 'unknown')).toBe('unknown');
    expect(allergenStatus('Chicken Gravy', 'fish', 'nonveg')).toBe('unknown');
    expect(allergenStatus('Fish Fry', 'fish', 'nonveg')).toBe('contains');
    expect(allergenStatus('Prawn Masala', 'shellfish', 'nonveg')).toBe('contains');
  });

  it('exact names only: a free word inside a longer name vouches for nothing', () => {
    expect(allergenStatus('Rice', 'peanut', 'veg')).toBe('unknown');
    expect(allergenStatus('Special White Rice', 'peanut', 'veg')).toBe('unknown');
  });
});

describe('allergy hard filter across real menus (B2)', () => {
  it('every plate dish, primary and alternatives, is confirmed free of every allergy', { timeout: 120_000 }, () => {
    let plates = 0;
    for (const n of NAMES) {
      const payload = fresh(n);
      for (const d of payload.menu.slice(0, 7)) {
        const day = dayOf(payload, d.date, servesNonVeg(n));
        for (const slot of SLOTS) {
          if (!day.meals.some((m) => m.slot === slot)) continue;
          for (const allergen of ALLERGENS) {
            const rec = recommendMeal(input({ menu: day, slot, allergies: [allergen] }));
            for (const plate of rec.plates) {
              plates += 1;
              for (const item of plate.items) {
                const dish = mealOf(day, slot).dishes.find((x) => x.id === item.dishId)!;
                expect(allergenStatus(dish.name, allergen, dish.diet), `${n} ${d.date} ${slot} ${allergen} ${dish.name}`).toBe('free');
                dish.alternatives.forEach((a, i) => expect(allergenStatus(a, allergen, dish.alternativeDiets[i]!)).toBe('free'));
              }
            }
            // Every excluded dish says which allergen.
            for (const o of rec.dishes) {
              if (!o.onPlate && o.reasons.some((r) => r.code === 'allergen')) {
                expect(o.reasons.every((r) => r.code !== 'allergen' || r.allergen === allergen)).toBe(true);
              }
            }
          }
        }
      }
    }
    expect(plates).toBeGreaterThan(50);
  });

  it('several allergies: a dish must be free of all of them', () => {
    const day = MENS_VEG_LUNCH_DAY;
    const rec = recommendMeal(input({ menu: day, slot: 'lunch', diet: 'vegetarian', allergies: ['peanut', 'milk'] }));
    for (const plate of rec.plates) {
      for (const item of plate.items) expect(item.dishId).toBe('white-rice');
    }
    const curd = rec.dishes.find((o) => o.dish.id === 'curd')!;
    expect(curd.reasons).toEqual([{ code: 'allergen', allergen: 'milk', status: 'contains' }]);
    const phulka = rec.dishes.find((o) => o.dish.id === 'phulka')!;
    expect(phulka.reasons).toEqual([{ code: 'allergen', allergen: 'milk', status: 'unknown' }]);
  });
});

/* ----------------------------------------- B4/B5: alternatives and "Veg" -- */

describe('alternatives are classified separately (owner D3, B4)', () => {
  const meal = (raw: string, nonVeg = true): MessMeal => ({
    slot: 'lunch',
    rawMenu: raw,
    dishes: parseMenuString(raw, { messServesNonVeg: nonVeg }).map(enrichDish),
  });

  it('a veg primary with a chicken alternative is excluded for a vegetarian', () => {
    const m = meal('Paneer Butter Masala / Chicken Butter Masala, White Rice, Dal Tadka');
    const paneer = m.dishes[0]!;
    expect(paneer.diet).toBe('veg');
    expect(paneer.alternativeDiets).toEqual(['nonveg']);
    const rec = recommendMeal(input({ menu: { date: '2026-09-24', meals: [m], resolution: { kind: 'exact', date: '2026-09-24' } }, slot: 'lunch', diet: 'vegetarian' }));
    const o = rec.dishes.find((x) => x.dish.id === paneer.id)!;
    expect(o.onPlate).toBe(false);
    expect(o.reasons).toEqual([{ code: 'diet-alternative', alternative: 'Chicken Butter Masala', dietClass: 'nonveg' }]);
    // A non-vegetarian may still get it (the primary is what the plate names).
    const nv = recommendMeal(input({ menu: { date: '2026-09-24', meals: [m], resolution: { kind: 'exact', date: '2026-09-24' } }, slot: 'lunch' }));
    expect(nv.dishes.find((x) => x.dish.id === paneer.id)!.reasons[0]!.code).not.toBe('diet-alternative');
  });

  it('an alternative carrying the allergen excludes the dish', () => {
    const m = meal('White Rice / Peanut Rice, Dal Tadka', false);
    const rec = recommendMeal(input({ menu: { date: '2026-09-24', meals: [m], resolution: { kind: 'exact', date: '2026-09-24' } }, slot: 'lunch', allergies: ['peanut'] }));
    const rice = rec.dishes.find((x) => x.dish.id === 'white-rice')!;
    expect(rice.onPlate).toBe(false);
    expect(rice.reasons).toEqual([{ code: 'allergen-alternative', alternative: 'Peanut Rice', allergen: 'peanut', status: 'contains' }]);
  });
});

describe('a leading "Veg" / "Veg." is vegetarian, after the meat and egg checks (owner D4, B5)', () => {
  it.each([
    ['Veg Puff', 'veg'],
    ['Veg. Cutlet (2 Nos)', 'veg'],
    ['Veg Egg Fried Rice', 'egg'],
    ['Veg Chicken Mix', 'nonveg'],
    ['Vegetable Kurma', 'veg'], // the positive list, not the prefix
    ['Vegan Delight', 'unknown'], // "Vegan" is not the word "Veg"
  ] as const)('%s → %s', (name, diet) => {
    expect(classifyDiet(name)).toBe(diet);
  });

  it('a "Non Veg" label still wins', () => {
    const [dish] = parseMenuString('Non Veg : Veg Cutlet', { messServesNonVeg: true });
    expect(dish?.diet).toBe('nonveg');
  });

  it('in the special messes, Veg Puff and Veg. Cutlet now reach a vegetarian', () => {
    const day = dayOf(fresh('hostel-1-mess-1'), '2026-09-01', true);
    const snacks = mealOf(day, 'snacks');
    expect(snacks.dishes.find((d) => d.name.startsWith('Veg. Cutlet'))?.diet).toBe('veg');
  });
});

/* ------------------------------------------------------ snacks (R1) -- */

describe('snacks get a plate (owner R1: §15.1 roles)', () => {
  it('the men\'s non-veg snack (Sweet Corn Chaat) is recommended, one serving', () => {
    const day = dayOf(fresh('hostel-1-mess-3'), '2026-09-24', true);
    const rec = recommendMeal(input({ menu: day, slot: 'snacks', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch'] }));
    expect(rec.status).toBe('ok');
    expect(rec.plates[0]!.items.map((i) => [i.dishId, i.servings])).toEqual([['sweet-corn-chaat', 1]]);
  });

  it('ambient items (tea, coffee, milk) and condiments never go on a plate — and are still listed', () => {
    const day = dayOf(fresh('hostel-1-mess-3'), '2026-09-24', true);
    const rec = recommendMeal(input({ menu: day, slot: 'snacks', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch'] }));
    for (const id of ['tea', 'coffee', 'milk']) {
      expect(rec.dishes.find((o) => o.dish.id === id)?.reasons).toEqual([{ code: 'ambient' }]);
    }
  });
});

/* ------------------------------------------------- statuses and menus -- */

describe('menu states and zero budget', () => {
  it('unavailable menu → no recommendation', () => {
    const rec = recommendMeal(input({ menu: { date: '2026-09-24', meals: [], resolution: { kind: 'unavailable', date: '2026-09-24', latestAvailable: '2026-08-31' } }, slot: 'lunch' }));
    expect(rec).toMatchObject({ status: 'menu-unavailable', plates: [], basis: null });
  });

  it('inferred menu → plates, each labelled with the source date', () => {
    const day = dayOf(fresh('hostel-1-mess-2'), '2026-10-02', false);
    expect(day.resolution.kind).toBe('cycle-inferred');
    const rec = recommendMeal(input({ menu: day, slot: 'lunch', diet: 'vegetarian' }));
    expect(rec.basis).toBe('inferred');
    expect(rec.plates.length).toBeGreaterThan(0);
    for (const p of rec.plates) expect(p.reasons).toContainEqual({ code: 'inferred-menu', sourceDate: '2026-09-18' });
  });

  it('a meal the menu does not serve', () => {
    const day = { ...MENS_VEG_LUNCH_DAY, meals: MENS_VEG_LUNCH_DAY.meals.filter((m) => m.slot !== 'snacks') };
    expect(recommendMeal(input({ menu: day, slot: 'snacks' })).status).toBe('meal-not-served');
  });

  it('no targets yet', () => {
    expect(recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', targets: null })).status).toBe('no-targets');
  });

  it('zero calorie budget: no plate, the remaining protein still reported (owner decision 8)', () => {
    const eaten = { ...THREE_MEALS_EATEN, kcalHigh: 2450, proteinLow: 100 };
    const rec = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'dinner', eaten, loggedSlots: ['breakfast', 'lunch', 'snacks'] }));
    expect(rec.status).toBe('target-reached');
    expect(rec.plates).toEqual([]);
    expect(rec.target).toEqual({ share: 1, kcal: 0, protein: 40, carb: 120, fat: 30 });
    expect(rec.shortfall).toBeNull();
  });

  it('nothing safe: a milk and wheat allergy at a lunch with no plain rice', () => {
    const lunch = mealOf(MENS_VEG_LUNCH_DAY, 'lunch');
    const noRice = { ...MENS_VEG_LUNCH_DAY, meals: [{ ...lunch, dishes: lunch.dishes.filter((d) => d.id !== 'white-rice') }] };
    const rec = recommendMeal(input({ menu: noRice, slot: 'lunch', diet: 'vegetarian', allergies: ['milk', 'wheat'] }));
    expect(rec.status).toBe('nothing-safe');
    expect(rec.plates).toEqual([]);
    for (const o of rec.dishes) expect(o.reasons.length).toBeGreaterThan(0);
  });
});

/* ------------------------------------------------------- B8: shortfall -- */

describe('shortfall (owner D13 as modified)', () => {
  it('gapOf: a shortfall only when even the high end is below the target; the gap is the plate\'s own range', () => {
    expect(gapOf(85, 25, 40, 46)).toEqual({ target: 85, gapLow: 45, gapHigh: 60, menuMax: 46, menuCanMeet: false });
    expect(gapOf(40, 30, 45, 50)).toBeNull(); // may fall short — not a shortfall
    expect(gapOf(40, 40, 50, 50)).toBeNull();
    expect(gapOf(60, 30, 50, 70)).toEqual({ target: 60, gapLow: 10, gapHigh: 30, menuMax: 70, menuCanMeet: true });
  });

  it('the real vegetarian dinner: protein falls short and is reported from the plate, never inflated', () => {
    const rec = recommendMeal(input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', diet: 'vegetarian', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }));
    const top = rec.plates[0]!;
    const gap = rec.shortfall?.protein;
    expect(gap).toBeTruthy();
    expect(gap!.target).toBe(85);
    expect(gap!.gapLow).toBeCloseTo(85 - top.macros.proteinHigh, 5);
    expect(gap!.gapHigh).toBeCloseTo(85 - top.macros.proteinLow, 5);
    expect(gap!.menuMax).toBeLessThan(85);
    expect(gap!.menuCanMeet).toBe(false);
    expect(top.reasons[0]).toEqual({ code: 'protein-short', target: 85, high: top.macros.proteinHigh });
  });

  it('a non-vegetarian at the same dinner: covered or honestly "may fall short", with no shortfall invented', () => {
    const rec = recommendMeal(input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }));
    const top = rec.plates[0]!;
    if (top.macros.proteinHigh >= 85) expect(rec.shortfall?.protein ?? null).toBeNull();
  });

  it('a kcal shortfall is reported the same way', () => {
    const rec = recommendMeal(input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', diet: 'vegetarian', eaten: NOTHING_EATEN, loggedSlots: [] }));
    // Dinner is the last meal: earlier meals have passed, so it carries the whole
    // remaining day (share 1) — 2,400 kcal no single plate can reach.
    expect(rec.target?.kcal).toBe(2400);
    const top = rec.plates[0]!;
    const kcal = rec.shortfall?.kcal;
    expect(kcal).toBeTruthy();
    expect(kcal!.gapLow).toBe(2400 - top.macros.kcalHigh);
    expect(kcal!.gapHigh).toBe(2400 - top.macros.kcalLow);
    expect(kcal!.menuCanMeet).toBe(false);
  });
});

/* ------------------------------------------------ B9/B10/B11: the rest -- */

describe('deterministic, fast, coded', () => {
  it('the same input twice gives the same output', () => {
    const a = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian' }));
    const b = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian' }));
    expect(b).toEqual(a);
  });

  it('dish order on the menu does not change the plates', () => {
    const lunch = mealOf(MENS_VEG_LUNCH_DAY, 'lunch');
    const reversed = { ...MENS_VEG_LUNCH_DAY, meals: [{ ...lunch, dishes: [...lunch.dishes].reverse() }] };
    const a = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian' })).plates.map((p) => p.items.map((i) => `${i.dishId}x${i.servings}`).sort());
    const b = recommendMeal(input({ menu: reversed, slot: 'lunch', diet: 'vegetarian' })).plates.map((p) => p.items.map((i) => `${i.dishId}x${i.servings}`).sort());
    expect(b).toEqual(a);
  });

  it('under 100 ms on the largest real meal (median of 20)', () => {
    let biggest: { day: MessDay; slot: MealSlot; size: number } | null = null;
    for (const n of NAMES) {
      const payload = fresh(n);
      for (const d of payload.menu) {
        const day = dayOf(payload, d.date, servesNonVeg(n));
        for (const m of day.meals) if (biggest === null || m.dishes.length > biggest.size) biggest = { day, slot: m.slot, size: m.dishes.length };
      }
    }
    const times: number[] = [];
    for (let i = 0; i < 20; i += 1) {
      const t = performance.now();
      recommendMeal(input({ menu: biggest!.day, slot: biggest!.slot }));
      times.push(performance.now() - t);
    }
    times.sort((a, b) => a - b);
    expect(times[10]).toBeLessThan(100);
  });

  it('every dish carries a reason; reasons are codes with values, never prose', () => {
    const rec = recommendMeal(input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', diet: 'vegetarian', allergies: ['peanut'], eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }));
    for (const o of rec.dishes) expect(o.reasons.length).toBeGreaterThan(0);
    const all = [...rec.plates.flatMap((p) => p.reasons), ...rec.dishes.flatMap((o) => o.reasons)];
    for (const r of all) {
      expect(r.code).toMatch(/^[a-z-]+$/);
      for (const v of Object.values(r)) {
        if (typeof v === 'string') expect(v.split(' ').length).toBeLessThanOrEqual(4); // slugs, codes, dates, dish names
      }
    }
    // The fit reasons are always present and in order.
    expect(rec.plates[0]!.reasons.slice(0, 5).map((r) => r.code)).toEqual([
      'protein-short', expect.stringMatching(/^kcal-/), expect.stringMatching(/^carb-/), expect.stringMatching(/^fat-/), 'goal-weighting',
    ]);
  });

  it('item numbers are the Phase 8 snapshot of the stored estimate × servings; totals are their sum', () => {
    const rec = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian' }));
    const plate = rec.plates[0]!;
    const sum = plate.items.reduce((s, i) => s + i.macros.kcalHigh, 0);
    expect(plate.macros.kcalHigh).toBe(sum);
    for (const i of plate.items) {
      expect(Number.isInteger(i.servings)).toBe(true);
      expect(i.confidence).not.toBe('high');
    }
  });

  it('variety lowers a repeated dish but never excludes it (owner decision 14)', () => {
    const base = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian' }));
    const topDish = base.plates[0]!.items[0]!.dishId;
    const varied = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian', varietyDays: { [topDish]: 3 } }));
    const verdict = varied.dishes.find((o) => o.dish.id === topDish)!;
    expect(verdict.reasons[0]!.code).not.toMatch(/diet|allergen|disliked/);
    for (const p of varied.plates) {
      if (p.items.some((i) => i.dishId === topDish)) expect(p.reasons).toContainEqual({ code: 'repeat', dishSlug: topDish, days: 3 });
    }
  });

  it('post-workout adds its reason', () => {
    const rec = recommendMeal(input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian', postWorkout: true }));
    expect(rec.plates[0]!.reasons.some((r) => r.code === 'post-workout-carbs')).toBe(true);
  });
});

/* ----------------------------------------------- B13: the six personas -- */

describe('personas (owner D25): frozen outputs, reviewed on any change', () => {
  const personas: Record<string, MealRecommendationInput> = {
    'vegetarian-vit': input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', diet: 'vegetarian', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }),
    'eggetarian-vit': input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', diet: 'eggetarian', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }),
    'nonveg-vit': input({ menu: WOMENS_NONVEG_DINNER, slot: 'dinner', diet: 'non-vegetarian', eaten: THREE_MEALS_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }),
    'allergy-restricted': input({ menu: MENS_VEG_LUNCH_DAY, slot: 'lunch', diet: 'vegetarian', allergies: ['peanut', 'milk'] }),
    'stale-mess-endpoint': input({ menu: dayOf(old('hostel-1-mess-3'), '2026-09-07', true), slot: 'dinner', diet: 'non-vegetarian' }),
    'protein-deficit': input({
      menu: MENS_VEG_LUNCH_DAY, slot: 'dinner', diet: 'vegetarian',
      eaten: { kcalLow: 1300, kcalHigh: 1500, proteinLow: 20, proteinHigh: 26, carbLow: 200, carbHigh: 230, fatLow: 40, fatHigh: 48 },
      loggedSlots: ['breakfast', 'lunch', 'snacks'],
    }),
  };

  /** The frozen shape: what a user would see, without the full dish objects. */
  const frozen = (i: MealRecommendationInput) => {
    const r = recommendMeal(i);
    return {
      status: r.status,
      basis: r.basis,
      target: r.target,
      plates: r.plates.map((p) => ({
        rank: p.rank,
        items: p.items.map((it) => `${it.dishId} x${it.servings}`),
        macros: p.macros,
        confidence: p.confidence,
        reasons: p.reasons,
      })),
      shortfall: r.shortfall,
      dishes: r.dishes.map((o) => ({ dish: o.dish.id, diet: o.dish.diet, reasons: o.reasons })),
    };
  };

  for (const [name, i] of Object.entries(personas)) {
    it(name, async () => {
      await expect(JSON.stringify(frozen(i), null, 2) + '\n').toMatchFileSnapshot(`./fixtures/personas/${name}.json`);
    });
  }

  it('the three diets diverge correctly on the same real dinner', () => {
    const ids = (i: MealRecommendationInput) => new Set(recommendMeal(i).plates.flatMap((p) => p.items.map((it) => it.dishId)));
    const veg = ids(personas['vegetarian-vit']!);
    const nonveg = ids(personas['nonveg-vit']!);
    const dishes = mealOf(WOMENS_NONVEG_DINNER, 'dinner').dishes;
    for (const id of veg) expect(dishes.find((d) => d.id === id)!.diet).toBe('veg');
    expect([...nonveg].some((id) => dishes.find((d) => d.id === id)!.diet === 'nonveg')).toBe(true);
  });

  it('the stale endpoint persona is inferred and labelled', () => {
    const r = recommendMeal(personas['stale-mess-endpoint']!);
    expect(r.basis).toBe('inferred');
    for (const p of r.plates) expect(p.reasons.some((x) => x.code === 'inferred-menu')).toBe(true);
  });

  it('the protein-deficit persona reports a shortfall', () => {
    expect(recommendMeal(personas['protein-deficit']!).shortfall?.protein).toBeTruthy();
  });
});

// Keep the allergen list in step with the contract's (the API suite checks equality too).
describe('allergen vocabulary', () => {
  it('ten allergens', () => {
    expect([...ALLERGENS]).toEqual(['peanut', 'tree-nut', 'milk', 'egg', 'soy', 'wheat', 'fish', 'shellfish', 'sesame', 'mustard'] satisfies Allergen[]);
  });
});
