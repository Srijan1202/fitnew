import { describe, expect, it } from 'vitest';

import { estimateNutrition, scaleMacros } from '../src/mess/nutrition.js';
import {
  FOOD_SOURCES,
  addFoodNutrition,
  composeRecipe,
  compareSources,
  exactFoodNutrition,
  foodSourceFromNutritionSource,
  isExactNutrition,
  normaliseAliases,
  normaliseFoodText,
  preferredBySource,
  roundFoodNutrition,
  scaleFoodNutrition,
  sourceRank,
  validateFoodNutrition,
  validateSourceClaims,
  widenFoodNutrition,
  type FoodNutritionRange,
  type FoodSource,
} from '../src/nutrition/food.js';

const rice = exactFoodNutrition({ kcal: 130, protein: 2.7, carb: 28.2, fat: 0.3, fibre: 0.4 });
const noFibre = exactFoodNutrition({ kcal: 60, protein: 3.3, carb: 4.6, fat: 3.2, fibre: null });

describe('source vocabulary (Phase 7, D3)', () => {
  it('is exactly the six approved values', () => {
    expect([...FOOD_SOURCES]).toEqual(['estimated', 'usda', 'ifct', 'indb', 'user', 'user-corrected']);
  });

  it("maps the mess module's NutritionSource without changing it", () => {
    expect(foodSourceFromNutritionSource('estimated-table')).toBe('estimated');
    expect(foodSourceFromNutritionSource('ifct-mapped')).toBe('ifct');
    expect(foodSourceFromNutritionSource('user-corrected')).toBe('user-corrected');
    // The existing core table still labels itself `estimated-table`.
    expect(estimateNutrition('Sambar', 'legume')?.source).toBe('estimated-table');
  });
});

describe('source precedence (§13.3)', () => {
  it('user-corrected → ifct / indb → usda → user → estimated', () => {
    const order: FoodSource[] = ['estimated', 'user', 'usda', 'indb', 'user-corrected'];
    const sorted = [...order].sort(compareSources);
    expect(sorted).toEqual(['user-corrected', 'indb', 'usda', 'user', 'estimated']);
    expect(sourceRank('ifct')).toBe(sourceRank('indb'));
  });

  it('preferredBySource picks the most trusted and keeps order on ties', () => {
    const rows = [
      { id: 'a', source: 'estimated' as const },
      { id: 'b', source: 'usda' as const },
      { id: 'c', source: 'usda' as const },
    ];
    expect(preferredBySource(rows)?.id).toBe('b');
    expect(preferredBySource([])).toBeUndefined();
  });
});

describe('ranges and validation', () => {
  it('a measured value is exact (low == high); an estimate is not', () => {
    expect(isExactNutrition(rice)).toBe(true);
    expect(isExactNutrition(widenFoodNutrition(rice, 0.1))).toBe(false);
  });

  it('accepts a valid range, and unknown fibre', () => {
    expect(validateFoodNutrition(rice, 'per_100g')).toEqual([]);
    expect(validateFoodNutrition(noFibre, 'per_100g')).toEqual([]);
  });

  it('rejects low > high, negatives and non-numbers', () => {
    const bad: FoodNutritionRange = {
      macros: { ...rice.macros, kcalLow: 200, kcalHigh: 100, proteinLow: -1, fatHigh: Number.NaN },
      fibre: { low: 3, high: 1 },
    };
    const fields = validateFoodNutrition(bad, 'per_serving').map((i) => `${i.field}:${i.problem}`);
    expect(fields).toContain('kcal:low is greater than high');
    expect(fields).toContain('protein:negative');
    expect(fields).toContain('fat:not a number');
    expect(fields).toContain('fibre:low is greater than high');
  });

  it('per 100 g: no more than 900 kcal or 100 g of any macro', () => {
    const impossible = exactFoodNutrition({ kcal: 950, protein: 101, carb: 10, fat: 10, fibre: null });
    const problems = validateFoodNutrition(impossible, 'per_100g').map((i) => i.field);
    expect(problems).toEqual(['kcal', 'protein']);
    // The same numbers are fine for a large serving.
    expect(validateFoodNutrition(impossible, 'per_serving')).toEqual([]);
  });

  it('source claims: estimates are never verified or high; user values are never verified', () => {
    expect(validateSourceClaims('estimated', true, 'low')).toHaveLength(1);
    expect(validateSourceClaims('estimated', false, 'high')).toHaveLength(1);
    expect(validateSourceClaims('user', true, 'medium')).toHaveLength(1);
    expect(validateSourceClaims('usda', true, 'high')).toEqual([]);
    expect(validateSourceClaims('user', false, 'medium')).toEqual([]);
  });
});

describe('unknown fibre is never zero', () => {
  it('stays null through scaling', () => {
    expect(scaleFoodNutrition(noFibre, 2).fibre).toBeNull();
  });

  it('adding a food of unknown fibre makes the total unknown, not the known part', () => {
    expect(addFoodNutrition(rice, noFibre).fibre).toBeNull();
    expect(addFoodNutrition(rice, rice).fibre).toEqual({ low: 0.8, high: 0.8 });
  });

  it('exactFoodNutrition keeps null as null', () => {
    expect(exactFoodNutrition({ kcal: 1, protein: 0, carb: 0, fat: 0, fibre: null }).fibre).toBeNull();
    expect(exactFoodNutrition({ kcal: 1, protein: 0, carb: 0, fat: 0, fibre: 0 }).fibre).toEqual({ low: 0, high: 0 });
  });
});

describe('arithmetic reuses the mess helpers', () => {
  it('scaled macros are exactly scaleMacros', () => {
    expect(scaleFoodNutrition(rice, 1.5).macros).toEqual(scaleMacros(rice.macros, 1.5));
  });
});

describe('rounding', () => {
  it('nearest keeps an exact value exact', () => {
    const r = roundFoodNutrition(exactFoodNutrition({ kcal: 130.4, protein: 2.69, carb: 28.24, fat: 0.28, fibre: 0.44 }), 'nearest');
    expect(r.macros).toMatchObject({ kcalLow: 130, kcalHigh: 130, proteinLow: 2.7, proteinHigh: 2.7, fatLow: 0.3 });
    expect(isExactNutrition(r)).toBe(true);
  });

  it('outward never narrows a range', () => {
    const r = roundFoodNutrition(widenFoodNutrition(exactFoodNutrition({ kcal: 101, protein: 3.33, carb: 10, fat: 1, fibre: 1 }), 0.15), 'outward');
    expect(r.macros.kcalLow).toBe(85); // 85.85 → 85
    expect(r.macros.kcalHigh).toBe(117); // 116.15 → 117
    expect(r.macros.proteinLow).toBe(2.8); // 2.8305 → 2.8
    expect(r.macros.proteinHigh).toBe(3.9); // 3.8295 → 3.9
  });
});

describe('search normalisation and aliases', () => {
  it('one key for case, punctuation, accents and spacing', () => {
    expect(normaliseFoodText('  Dal (Tadka)! ')).toBe('dal tadka');
    expect(normaliseFoodText('Crème  Brûlée')).toBe('creme brulee');
    expect(normaliseFoodText("Lady's finger")).toBe('lady s finger');
  });

  it('aliases are normalised, de-duplicated, sorted and never the name itself', () => {
    expect(normaliseAliases('Dal tadka', ['Dhal', 'dhal', 'DAAL', 'Dal Tadka', ' dal fry '])).toEqual(['daal', 'dal fry', 'dhal']);
  });
});

describe('composeRecipe — deterministic FITOS estimates', () => {
  const inputs = new Map<number, FoodNutritionRange>([
    [1, exactFoodNutrition({ kcal: 340, protein: 13.2, carb: 72, fat: 2.5, fibre: 10.7 })], // flour
    [2, exactFoodNutrition({ kcal: 86, protein: 1.7, carb: 20, fat: 0.1, fibre: 1.8 })], // potato
    [3, exactFoodNutrition({ kcal: 884, protein: 0, carb: 0, fat: 100, fibre: 0 })], // oil
    [4, exactFoodNutrition({ kcal: 60, protein: 3.3, carb: 4.6, fat: 3.2, fibre: null })], // milk, no fibre
  ]);
  const per100g = (id: number): FoodNutritionRange => {
    const v = inputs.get(id);
    if (v === undefined) throw new Error(`no input ${id}`);
    return v;
  };

  it('sums the ingredients, spans the oil, widens and rounds outward', () => {
    const r = composeRecipe(
      { ingredients: [{ fdcId: 1, grams: 50 }, { fdcId: 2, grams: 60 }], oil: { fdcId: 3, gramsLow: 5, gramsHigh: 10 }, widening: 0.15 },
      per100g,
    );
    // kcal: 170 + 51.6 = 221.6; +44.2 oil (low) = 265.8 → ×0.85 = 225.93 → 225
    //                          +88.4 oil (high) = 310.0 → ×1.15 = 356.5 → 357
    expect(r.macros.kcalLow).toBe(225);
    expect(r.macros.kcalHigh).toBe(357);
    expect(r.macros.fatLow).toBe(5.3); // (1.25 + 0.06 + 5) × 0.85 = 5.3635 → rounded down → 5.3
    expect(r.fibre).not.toBeNull();
    expect(validateFoodNutrition(r, 'per_serving')).toEqual([]);
  });

  it('is deterministic', () => {
    const recipe = { ingredients: [{ fdcId: 1, grams: 40 }], oil: null, widening: 0.2 };
    expect(composeRecipe(recipe, per100g)).toEqual(composeRecipe(recipe, per100g));
  });

  it('fibre is unknown if any ingredient does not report it', () => {
    const r = composeRecipe({ ingredients: [{ fdcId: 1, grams: 40 }, { fdcId: 4, grams: 100 }], oil: null, widening: 0.1 }, per100g);
    expect(r.fibre).toBeNull();
  });

  it('rejects empty recipes, zero grams and inverted oil', () => {
    expect(() => composeRecipe({ ingredients: [], oil: null, widening: 0.1 }, per100g)).toThrow();
    expect(() => composeRecipe({ ingredients: [{ fdcId: 1, grams: 0 }], oil: null, widening: 0.1 }, per100g)).toThrow();
    expect(() =>
      composeRecipe({ ingredients: [{ fdcId: 1, grams: 10 }], oil: { fdcId: 3, gramsLow: 5, gramsHigh: 2 }, widening: 0.1 }, per100g),
    ).toThrow();
  });
});
