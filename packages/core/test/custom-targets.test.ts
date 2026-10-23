/**
 * Beta 3.2 (ADR-031): the user's own calorie and protein targets — the
 * limits, the split FITOS uses, and the warnings. Hand-calculated.
 */
import { describe, expect, it } from 'vitest';

import { CUSTOM_TARGET_LIMITS, customTargets, proteinRangeG } from '../src/nutrition/custom-targets.js';

const suggestion = { kcal: 2400, proteinG: 140 };
const base = { kcal: 2400, proteinG: 140, weightKg: 70, suggestion };

describe('customTargets', () => {
  it('within FITOS’s range: the §13.1 split, no warnings', () => {
    // fat = max(0.8 × 70 = 56, 2400 × 0.22 / 9 = 58.67) → 59; carbs = (2400 − 560 − 531) / 4 = 327.25 → 327; fibre 33.6 → 34.
    expect(customTargets(base)).toEqual({ ok: true, targets: { kcal: 2400, proteinG: 140, fatG: 59, carbG: 327, fiberG: 34 }, warnings: [] });
  });

  it('calories outside 1200–6000 or not whole are refused on kcal', () => {
    for (const kcal of [1199, 6001, 2000.5]) {
      expect(customTargets({ ...base, kcal })).toMatchObject({ ok: false, field: 'kcal' });
    }
    expect(customTargets({ ...base, kcal: 1200, proteinG: 100 })).toMatchObject({ ok: true });
    expect(customTargets({ ...base, kcal: 6000 })).toMatchObject({ ok: true });
  });

  it('protein outside 0.6–3.3 g/kg (inside 30–400 g) or not whole is refused on protein', () => {
    expect(proteinRangeG(70)).toEqual({ min: 42, max: 231 });
    expect(proteinRangeG(40)).toEqual({ min: 30, max: 132 }); // the absolute floor wins
    expect(proteinRangeG(150)).toEqual({ min: 90, max: 400 }); // the absolute ceiling wins
    for (const proteinG of [41, 232, 140.5]) {
      const r = customTargets({ ...base, proteinG });
      expect(r, String(proteinG)).toMatchObject({ ok: false, field: 'proteinG' });
    }
    expect(customTargets({ ...base, proteinG: 42 })).toMatchObject({ ok: true });
    expect(customTargets({ ...base, proteinG: 231 })).toMatchObject({ ok: true });
  });

  it('protein and the fat floor must fit inside the calories', () => {
    // 1200 kcal, 231 g protein: fat 56 g → 924 + 504 = 1428 > 1200.
    const r = customTargets({ ...base, kcal: 1200, proteinG: 231 });
    expect(r).toEqual({ ok: false, field: 'kcal', problem: '231 g protein and the minimum fat need 1428 kcal: raise the calories or lower the protein.' });
  });

  it('warns beyond ±25 % of FITOS’s calories, and outside 1.2–2.2 g/kg protein', () => {
    const low = customTargets({ ...base, kcal: 1700, proteinG: 70 });
    expect(low).toMatchObject({ ok: true });
    expect(low.ok && low.warnings).toEqual([
      "29 % below FITOS's suggestion of 2400 kcal.",
      '1.0 g protein per kg is below the 1.2–2.2 g that supports training.',
    ]);
    const high = customTargets({ ...base, kcal: 3100, proteinG: 200 });
    expect(high.ok && high.warnings).toEqual([
      "29 % above FITOS's suggestion of 2400 kcal.",
      '2.9 g protein per kg is above the 1.2–2.2 g that most people need.',
    ]);
    // Exactly 25 % away: no warning.
    expect(customTargets({ ...base, kcal: 3000 })).toMatchObject({ ok: true, warnings: [] });
  });

  it('the limits are the ones the plan names', () => {
    expect(CUSTOM_TARGET_LIMITS).toMatchObject({ kcalMin: 1200, kcalMax: 6000, proteinMinPerKg: 0.6, proteinMaxPerKg: 3.3 });
  });
});
