import { describe, expect, it } from 'vitest';

import { ESTIMATE_SPREAD, MEASURED_SPREAD, capSpread, estimateNutrition, measurementOf } from '../src/mess/nutrition.js';
import { FOOD_SOURCES, compareSources } from '../src/nutrition/food.js';

/** Beta 3.7 (owner 2026-10-25, ADR-036): narrower, measured mess estimates. */
describe('the mess table, beta 3.7', () => {
  it('a calibrated dish is the CoFID measurement at the mess serving, +-8 %, rounded outward', () => {
    expect(measurementOf('sambar')).toEqual({ code: '12-467', name: 'Sambar, homemade', per100g: [49, 3.1, 7.7, 0.9] });
    const sambar = estimateNutrition('Sambar', 'other')!;
    // 49 kcal / 100 g x 150 g = 73.5 kcal.
    expect(sambar.macros.kcalLow).toBe(Math.floor(73.5 * (1 - MEASURED_SPREAD)));
    expect(sambar.macros.kcalHigh).toBe(Math.ceil(73.5 * (1 + MEASURED_SPREAD)));
    expect(sambar.source).toBe('estimated-table');
    expect(measurementOf('Sweet Lassi')?.code).toBe('12-373');
  });

  it('buttermilk and sweet lassi are no longer one estimate', () => {
    const lassi = estimateNutrition('Sweet Lassi', 'other')!.macros;
    const chaas = estimateNutrition('Butter Milk', 'other')!.macros;
    expect(lassi.kcalLow).toBeGreaterThan(chaas.kcalHigh);
    expect(measurementOf('butter milk')).toBeNull();
  });

  it('an estimate is at most +-20 % around its middle; a narrower one is left alone', () => {
    expect(capSpread([100, 200], 0)).toEqual([120, 180]);
    expect(capSpread([0.3, 1.2], 1)).toEqual([0.6, 0.9]);
    expect(capSpread([90, 110], 0)).toEqual([90, 110]);
    expect(capSpread([0, 0], 1)).toEqual([0, 0]);
    const kootu = estimateNutrition('Kootu', 'other')!.macros;
    const mid = (kootu.kcalLow + kootu.kcalHigh) / 2;
    expect((kootu.kcalHigh - kootu.kcalLow) / 2).toBeLessThanOrEqual(mid * ESTIMATE_SPREAD + 0.5);
  });

  it('an unrecognised dish keeps the wide role fallback (nothing is known about it)', () => {
    const m = estimateNutrition('Zqxv special', 'staple')!.macros;
    expect([m.kcalLow, m.kcalHigh]).toEqual([150, 300]);
  });
});

describe('food sources, beta 3.7', () => {
  it('CoFID is measured composition data: ranked with IFCT and INDB, above USDA', () => {
    expect(FOOD_SOURCES).toContain('cofid');
    expect(compareSources('cofid', 'usda')).toBeLessThan(0);
    expect(compareSources('cofid', 'ifct')).toBe(0);
  });
});
