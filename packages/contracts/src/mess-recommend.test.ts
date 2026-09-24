import { describe, expect, it } from 'vitest';

import {
  MEAL_COMPONENTS,
  REASON_CODES,
  RECOMMENDATION_STATUSES,
  messRecommendQuerySchema,
  plateSchema,
  plateItemSchema,
  recommendationGapSchema,
  recommendationReasonSchema,
} from './mess-recommend.js';

const item = {
  dishSlug: 'dal-tadka', name: 'Dal Tadka', servings: 2, servingLabel: '1 katori', servingGrams: 150,
  kcalLow: 240, kcalHigh: 370, proteinLow: 12, proteinHigh: 18, carbLow: 32, carbHigh: 46, fatLow: 6, fatHigh: 14,
  confidence: 'medium', component: 'protein',
};

describe('mess recommendation contracts (Phase 10)', () => {
  it('the query: date, mess and slot, all optional, nothing else', () => {
    expect(messRecommendQuerySchema.safeParse({}).success).toBe(true);
    expect(messRecommendQuerySchema.safeParse({ date: '2026-09-25', mess: 'mens-veg', slot: 'dinner' }).success).toBe(true);
    expect(messRecommendQuerySchema.safeParse({ slot: 'brunch' }).success).toBe(false);
    expect(messRecommendQuerySchema.safeParse({ source: 'general' }).success).toBe(false); // no general recommendations
  });

  it('reasons are codes with values; unknown codes and prose are refused', () => {
    expect(recommendationReasonSchema.safeParse({ code: 'protein-short', target: 85, high: 39.7 }).success).toBe(true);
    expect(recommendationReasonSchema.safeParse({ code: 'allergen', allergen: 'peanut', status: 'likely' }).success).toBe(true);
    expect(recommendationReasonSchema.safeParse({ code: 'allergen', allergen: 'peanut', status: 'free' }).success).toBe(false);
    expect(recommendationReasonSchema.safeParse({ code: 'looks-tasty' }).success).toBe(false);
    expect(recommendationReasonSchema.safeParse({ code: 'kcal-within', target: 900, high: 800, text: 'Fits!' }).success).toBe(false);
    expect(REASON_CODES).toContain('carb-over');
    expect(REASON_CODES).toContain('fat-within');
    expect(REASON_CODES).toContain('goal-weighting');
  });

  it('a plate item: whole servings (1–3), never high confidence', () => {
    expect(plateItemSchema.safeParse(item).success).toBe(true);
    expect(plateItemSchema.safeParse({ ...item, servings: 1.5 }).success).toBe(false);
    expect(plateItemSchema.safeParse({ ...item, servings: 4 }).success).toBe(false);
    expect(plateItemSchema.safeParse({ ...item, confidence: 'high' }).success).toBe(false);
  });

  it('ADR-016: a plate names its structure; items their component; no-meal is its own status', () => {
    const plate = { rank: 1, items: [item], totals: { kcalLow: 240, kcalHigh: 370, proteinLow: 12, proteinHigh: 18, carbLow: 32, carbHigh: 46, fatLow: 6, fatHigh: 14 }, confidence: 'medium', reasons: [] };
    expect(plateSchema.safeParse({ ...plate, structure: { kind: 'limited', missing: ['protein', 'vegetable'] } }).success).toBe(true);
    expect(plateSchema.safeParse(plate).success).toBe(false);
    expect(plateSchema.safeParse({ ...plate, structure: { kind: 'bag-of-dishes', missing: [] } }).success).toBe(false);
    expect(plateItemSchema.safeParse({ ...item, component: 'garnish' }).success).toBe(false);
    expect(recommendationReasonSchema.safeParse({ code: 'meal-structure', kind: 'complete-meal' }).success).toBe(true);
    expect(recommendationReasonSchema.safeParse({ code: 'protein-anchor', dishSlug: 'dal-tadka', strength: 'weak' }).success).toBe(true);
    expect(recommendationReasonSchema.safeParse({ code: 'limited-menu', missing: ['strong-protein'] }).success).toBe(true);
    expect(recommendationReasonSchema.safeParse({ code: 'limited-menu', missing: [] }).success).toBe(false);
    expect(recommendationReasonSchema.safeParse({ code: 'not-a-meal-component', component: 'beverage' }).success).toBe(true);
    expect(REASON_CODES).not.toContain('not-a-plate-dish');
    expect(RECOMMENDATION_STATUSES).toContain('no-meal');
    expect(RECOMMENDATION_STATUSES).toContain('nothing-fits');
    expect(MEAL_COMPONENTS).toContain('beverage');
  });

  it('a gap is non-negative with the menu maximum', () => {
    expect(recommendationGapSchema.safeParse({ target: 85, gapLow: 45.3, gapHigh: 60, menuMax: 46, menuCanMeet: false }).success).toBe(true);
    expect(recommendationGapSchema.safeParse({ target: 85, gapLow: -1, gapHigh: 60, menuMax: 46, menuCanMeet: false }).success).toBe(false);
  });
});
