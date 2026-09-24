import { describe, expect, it } from 'vitest';

import {
  createLogRequestSchema,
  foodLogItemSchema,
  logMessDishRequestSchema,
  savedMealItemSchema,
} from './nutrition-log.js';
import {
  dishSlugSchema,
  menuResolutionSchema,
  messCodeSchema,
  messCorrectionRequestSchema,
  messDishNutritionSchema,
  messMenuQuerySchema,
} from './mess.js';
import { patchProfileRequestSchema } from './profile.js';

const id = '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f';
const estimate = {
  servingLabel: '1 katori', servingGrams: 150,
  kcalLow: 120, kcalHigh: 185, proteinLow: 6, proteinHigh: 9, carbLow: 16, carbHigh: 23, fatLow: 3, fatHigh: 7,
  fibreLow: null, fibreHigh: null, confidence: 'medium', source: 'estimated',
};

describe('mess ids', () => {
  it('codes and slugs are lower-case kebab', () => {
    expect(messCodeSchema.safeParse('mens-veg').success).toBe(true);
    expect(messCodeSchema.safeParse('Mens Veg').success).toBe(false);
    expect(dishSlugSchema.safeParse('veg-cutlet').success).toBe(true);
    expect(dishSlugSchema.safeParse('-veg').success).toBe(false);
    expect(dishSlugSchema.safeParse('').success).toBe(false);
  });

  it('the menu query is optional on both fields and strict', () => {
    expect(messMenuQuerySchema.safeParse({}).success).toBe(true);
    expect(messMenuQuerySchema.safeParse({ date: '2026-09-24', mess: 'womens-special' }).success).toBe(true);
    expect(messMenuQuerySchema.safeParse({ date: '24/09/2026' }).success).toBe(false);
    expect(messMenuQuerySchema.safeParse({ hostel: 1 }).success).toBe(false);
  });
});

describe('mess nutrition is never high confidence, always an estimate', () => {
  it('accepts medium and low only', () => {
    expect(messDishNutritionSchema.safeParse(estimate).success).toBe(true);
    expect(messDishNutritionSchema.safeParse({ ...estimate, confidence: 'low', servingGrams: null }).success).toBe(true);
    expect(messDishNutritionSchema.safeParse({ ...estimate, confidence: 'high' }).success).toBe(false);
    expect(messDishNutritionSchema.safeParse({ ...estimate, source: 'usda' }).success).toBe(false);
  });
});

describe('menu resolution', () => {
  it('names how the menu was found', () => {
    expect(menuResolutionSchema.safeParse({ kind: 'exact', date: '2026-09-24' }).success).toBe(true);
    expect(
      menuResolutionSchema.safeParse({ kind: 'cycle-inferred', date: '2026-10-02', sourceDate: '2026-09-18', cycleLengthDays: 14 }).success,
    ).toBe(true);
    expect(menuResolutionSchema.safeParse({ kind: 'cycle-inferred', date: '2026-10-02' }).success).toBe(false);
    expect(menuResolutionSchema.safeParse({ kind: 'unavailable', date: '2026-10-02', latestAvailable: null }).success).toBe(true);
  });
});

describe('logging a mess dish', () => {
  const base = { clientLogId: id, mealSlot: 'lunch', entryMethod: 'mess', mess: 'mens-veg', menuDate: '2026-09-24' };
  const dish = { dishSlug: 'dal-tadka', servings: 1 };

  it('servings OR grams, bounded like any portion', () => {
    expect(logMessDishRequestSchema.safeParse({ dishSlug: 'dal-tadka', servings: 1.5 }).success).toBe(true);
    expect(logMessDishRequestSchema.safeParse({ dishSlug: 'dal-tadka', grams: 225 }).success).toBe(true);
    expect(logMessDishRequestSchema.safeParse({ dishSlug: 'dal-tadka' }).success).toBe(false);
    expect(logMessDishRequestSchema.safeParse({ dishSlug: 'dal-tadka', servings: 1, grams: 150 }).success).toBe(false);
    expect(logMessDishRequestSchema.safeParse({ dishSlug: 'dal-tadka', servings: 21 }).success).toBe(false);
  });

  it('a mess log names the mess, the menu date and the dishes, and carries no numbers', () => {
    expect(createLogRequestSchema.safeParse({ ...base, items: [dish] }).success).toBe(true);
    expect(createLogRequestSchema.safeParse({ ...base, items: [] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, menuDate: undefined, items: [dish] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, items: [{ ...dish, kcalLow: 100 }] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, kcal: 300, items: [dish] }).success).toBe(false);
  });

  it('a logged item carries the dish slug as provenance', () => {
    const item = {
      id, position: 0, foodId: null, messDishSlug: 'dal-tadka', foodName: 'Dal Tadka', foodSource: 'estimated',
      basis: 'per_serving', servingLabel: '1 katori', servingGrams: 150, servings: 1, grams: 150,
      kcalLow: 120, kcalHigh: 185, proteinLow: 6, proteinHigh: 9, carbLow: 16, carbHigh: 23, fatLow: 3, fatHigh: 7,
      fibreLow: null, fibreHigh: null, confidence: 'medium',
    };
    expect(foodLogItemSchema.safeParse(item).success).toBe(true);
  });

  it('a saved meal keeps a mess dish as a mess dish (owner D11), with its current estimate as a preview', () => {
    const saved = { kind: 'mess', dishSlug: 'dal-tadka', name: 'Dal Tadka', servings: 1.5, row: estimate };
    expect(savedMealItemSchema.safeParse(saved).success).toBe(true);
    expect(savedMealItemSchema.safeParse({ ...saved, row: null }).success).toBe(true);
    expect(savedMealItemSchema.safeParse({ ...saved, dishSlug: undefined }).success).toBe(false);
  });
});

describe('corrections (owner D17: stored as pending)', () => {
  const base = { clientCorrectionId: id };

  it('a macro correction gives a range', () => {
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'kcal', low: 150, high: 220 }).success).toBe(true);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'kcal', low: 220, high: 150 }).success).toBe(false);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'protein' }).success).toBe(false);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'fat', low: 1, high: 2, diet: 'veg' }).success).toBe(false);
  });

  it('a diet correction names the class; "other" needs a note', () => {
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'diet', diet: 'egg' }).success).toBe(true);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'diet' }).success).toBe(false);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'diet', diet: 'unknown' }).success).toBe(false);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'other', note: 'Two pieces, not one' }).success).toBe(true);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'other' }).success).toBe(false);
    expect(messCorrectionRequestSchema.safeParse({ ...base, field: 'other', note: 'x', low: 1, high: 2 }).success).toBe(false);
  });
});

describe('profile PATCH: the mess can be changed after onboarding (owner D13)', () => {
  const mess = { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' };

  it('accepts a mess, a change of answer, or nothing', () => {
    expect(patchProfileRequestSchema.safeParse({ isVitStudent: true, mess }).success).toBe(true);
    expect(patchProfileRequestSchema.safeParse({ mess }).success).toBe(true);
    expect(patchProfileRequestSchema.safeParse({ isVitStudent: false, mess: null }).success).toBe(true);
    expect(patchProfileRequestSchema.safeParse({ isVitStudent: false }).success).toBe(true);
    expect(patchProfileRequestSchema.safeParse({}).success).toBe(true);
  });

  it('refuses a VIT student with no mess, and a mess for a non-VIT answer', () => {
    expect(patchProfileRequestSchema.safeParse({ isVitStudent: true, mess: null }).success).toBe(false);
    expect(patchProfileRequestSchema.safeParse({ isVitStudent: false, mess }).success).toBe(false);
    expect(patchProfileRequestSchema.safeParse({ mess: { providerId: '', hostelId: 'mens', messId: 'veg' } }).success).toBe(false);
  });
});
