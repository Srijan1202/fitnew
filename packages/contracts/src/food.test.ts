import { describe, expect, it } from 'vitest';

import {
  FOOD_SOURCES,
  createFoodRequestSchema,
  foodNutritionSchema,
  foodSearchQuerySchema,
  foodSeedSchema,
} from './food.js';

const row = {
  basis: 'per_100g' as const,
  servingLabel: '100 g',
  servingGrams: 100,
  kcalLow: 130,
  kcalHigh: 130,
  proteinLow: 2.7,
  proteinHigh: 2.7,
  carbLow: 28.2,
  carbHigh: 28.2,
  fatLow: 0.3,
  fatHigh: 0.3,
  fibreLow: 0.4,
  fibreHigh: 0.4,
  confidence: 'high' as const,
};

describe('source vocabulary', () => {
  it('is the six approved values (D3)', () => {
    expect([...FOOD_SOURCES]).toEqual(['estimated', 'usda', 'ifct', 'indb', 'user', 'user-corrected']);
  });
});

describe('foodNutritionSchema', () => {
  it('accepts a range and unknown fibre', () => {
    expect(foodNutritionSchema.safeParse(row).success).toBe(true);
    expect(foodNutritionSchema.safeParse({ ...row, fibreLow: null, fibreHigh: null }).success).toBe(true);
  });

  it('rejects low > high, half-known fibre and negatives', () => {
    expect(foodNutritionSchema.safeParse({ ...row, kcalLow: 200 }).success).toBe(false);
    expect(foodNutritionSchema.safeParse({ ...row, fibreLow: null }).success).toBe(false);
    expect(foodNutritionSchema.safeParse({ ...row, fibreLow: 2, fibreHigh: 1 }).success).toBe(false);
    expect(foodNutritionSchema.safeParse({ ...row, fatLow: -1 }).success).toBe(false);
  });
});

describe('search query', () => {
  it('trims, requires text and bounds the limit', () => {
    expect(foodSearchQuerySchema.parse({ q: '  dal ' })).toEqual({ q: 'dal', limit: 20 });
    expect(foodSearchQuerySchema.safeParse({ q: '   ' }).success).toBe(false);
    expect(foodSearchQuerySchema.safeParse({ q: 'dal', limit: '51' }).success).toBe(false);
  });
});

describe('create custom food', () => {
  const base = {
    clientFoodId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
    name: 'Protein bar',
    basis: 'per_serving' as const,
    servingLabel: '1 bar',
    servingGrams: 60,
    kcal: 220,
    proteinG: 20,
    carbG: 22,
    fatG: 7,
  };

  it('accepts a label with or without fibre', () => {
    expect(createFoodRequestSchema.safeParse(base).success).toBe(true);
    expect(createFoodRequestSchema.safeParse({ ...base, fibreG: null }).success).toBe(true);
    expect(createFoodRequestSchema.safeParse({ ...base, fibreG: 3 }).success).toBe(true);
  });

  it('counts fibre inside carbohydrate, not on top of it (wheat bran per 100 g)', () => {
    const bran = { ...base, basis: 'per_100g' as const, servingLabel: undefined, servingGrams: null, kcal: 216, proteinG: 15.6, carbG: 64.5, fatG: 4.3, fibreG: 42.8 };
    expect(createFoodRequestSchema.safeParse(bran).success).toBe(true);
    expect(createFoodRequestSchema.safeParse({ ...bran, fibreG: 101 }).success).toBe(false);
  });

  it('rejects impossible labels and unknown keys', () => {
    expect(createFoodRequestSchema.safeParse({ ...base, basis: 'per_100g', kcal: 950 }).success).toBe(false);
    expect(createFoodRequestSchema.safeParse({ ...base, basis: 'per_100g', proteinG: 60, carbG: 60 }).success).toBe(false);
    expect(createFoodRequestSchema.safeParse({ ...base, servingGrams: 30 }).success).toBe(false); // 49 g of macros in 30 g
    expect(createFoodRequestSchema.safeParse({ ...base, servingLabel: undefined }).success).toBe(false);
    expect(createFoodRequestSchema.safeParse({ ...base, source: 'usda' }).success).toBe(false);
  });
});

describe('seed rows', () => {
  const usda = {
    slug: 'rice-white-long-grain-cooked',
    name: 'Rice, white, long-grain, regular, unenriched, cooked without salt',
    brand: null,
    barcode: null,
    source: 'usda' as const,
    sourceRef: 'FDC 169757 · SR Legacy (April 2018)',
    isVerified: true,
    aliases: [],
    nutrition: [row],
  };

  it('a direct USDA record is verified, exact and high confidence', () => {
    expect(foodSeedSchema.safeParse(usda).success).toBe(true);
    expect(foodSeedSchema.safeParse({ ...usda, isVerified: false }).success).toBe(false);
    expect(foodSeedSchema.safeParse({ ...usda, nutrition: [{ ...row, kcalHigh: 140 }] }).success).toBe(false);
  });

  it('an estimate is never verified and never high confidence', () => {
    const est = { ...usda, source: 'estimated' as const, isVerified: false, nutrition: [{ ...row, confidence: 'medium' as const }] };
    expect(foodSeedSchema.safeParse(est).success).toBe(true);
    expect(foodSeedSchema.safeParse({ ...est, isVerified: true }).success).toBe(false);
    expect(foodSeedSchema.safeParse({ ...est, nutrition: [row] }).success).toBe(false);
  });
});
