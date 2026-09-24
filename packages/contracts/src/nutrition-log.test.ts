import { describe, expect, it } from 'vitest';

import {
  ENTRY_METHODS,
  MEAL_SLOTS,
  createLogRequestSchema,
  createSavedMealRequestSchema,
  logFoodItemRequestSchema,
  quickAddSchema,
} from './nutrition-log.js';

const id = '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f';

describe('vocabulary', () => {
  it('meal slots are the mess slots; entry methods are the Phase 8 three (core equality is checked in the API suite)', () => {
    expect([...MEAL_SLOTS]).toEqual(['breakfast', 'lunch', 'snacks', 'dinner']);
    expect([...ENTRY_METHODS]).toEqual(['search', 'quick-add', 'saved-meal']);
  });
});

describe('log a food', () => {
  const item = { foodId: id, basis: 'per_serving' as const, servingLabel: '1 katori', servings: 1.5 };

  it('servings OR grams, never both or neither; bounded', () => {
    expect(logFoodItemRequestSchema.safeParse(item).success).toBe(true);
    expect(logFoodItemRequestSchema.safeParse({ ...item, servings: undefined, grams: 225 }).success).toBe(true);
    expect(logFoodItemRequestSchema.safeParse({ ...item, grams: 225 }).success).toBe(false);
    expect(logFoodItemRequestSchema.safeParse({ ...item, servings: undefined }).success).toBe(false);
    expect(logFoodItemRequestSchema.safeParse({ ...item, servings: 0.09 }).success).toBe(false);
    expect(logFoodItemRequestSchema.safeParse({ ...item, servings: 20.5 }).success).toBe(false);
    expect(logFoodItemRequestSchema.safeParse({ ...item, servings: undefined, grams: 5001 }).success).toBe(false);
    expect(logFoodItemRequestSchema.safeParse({ ...item, kcal: 100 }).success).toBe(false);
  });

  it('a log is one of three methods, each with its own payload and nothing else', () => {
    const base = { clientLogId: id, mealSlot: 'lunch' };
    expect(createLogRequestSchema.safeParse({ ...base, entryMethod: 'search', items: [item] }).success).toBe(true);
    expect(createLogRequestSchema.safeParse({ ...base, entryMethod: 'search', items: [] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, entryMethod: 'quick-add', quickAdd: { kcal: 300, proteinG: 10, carbG: 40, fatG: 9 } }).success).toBe(true);
    expect(createLogRequestSchema.safeParse({ ...base, entryMethod: 'saved-meal', savedMealId: id }).success).toBe(true);
    expect(createLogRequestSchema.safeParse({ ...base, entryMethod: 'saved-meal', savedMealId: id, items: [item] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, entryMethod: 'mess', items: [item] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, mealSlot: 'brunch', entryMethod: 'search', items: [item] }).success).toBe(false);
    expect(createLogRequestSchema.safeParse({ ...base, loggedAt: '2026-09-24T12:00:00+05:30', entryMethod: 'search', items: [item] }).success).toBe(true);
    expect(createLogRequestSchema.safeParse({ ...base, loggedAt: 'yesterday', entryMethod: 'search', items: [item] }).success).toBe(false);
  });

  it('quick add needs kcal and the three macros; fibre may be unknown', () => {
    expect(quickAddSchema.safeParse({ kcal: 300, proteinG: 10, carbG: 40, fatG: 9 }).success).toBe(true);
    expect(quickAddSchema.safeParse({ kcal: 300, proteinG: 10, carbG: 40, fatG: 9, fibreG: null }).success).toBe(true);
    expect(quickAddSchema.safeParse({ kcal: 300, proteinG: 10, carbG: 40 }).success).toBe(false);
    expect(quickAddSchema.safeParse({ kcal: -1, proteinG: 10, carbG: 40, fatG: 9 }).success).toBe(false);
  });
});

describe('saved meals', () => {
  it('are made from logged meals only — there is no item list to compose', () => {
    expect(createSavedMealRequestSchema.safeParse({ clientMealId: id, name: 'Usual breakfast', fromClientLogIds: [id] }).success).toBe(true);
    expect(createSavedMealRequestSchema.safeParse({ clientMealId: id, name: 'X', fromClientLogIds: [] }).success).toBe(false);
    expect(createSavedMealRequestSchema.safeParse({ clientMealId: id, name: 'X', items: [{ foodId: id }] }).success).toBe(false);
  });
});
