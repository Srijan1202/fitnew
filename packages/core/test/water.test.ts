import { describe, expect, it } from 'vitest';

import { WATER_DEFAULT_TARGET_ML, waterTargetMl } from '../src/nutrition/water.js';

describe('beta 6.0: the water target', () => {
  it('is 35 ml a kg, to the nearest 250 ml glass', () => {
    expect(waterTargetMl(70)).toBe(2500); // 2,450 → 2,500
    expect(waterTargetMl(80)).toBe(2750); // 2,800 → 2,750
    expect(waterTargetMl(64.3)).toBe(2250); // 2,250.5 → 2,250
  });

  it('stays between 1.5 L and 4 L', () => {
    expect(waterTargetMl(30)).toBe(1500);
    expect(waterTargetMl(150)).toBe(4000);
  });

  it('is 2.5 L without a usable weight', () => {
    expect(waterTargetMl(null)).toBe(WATER_DEFAULT_TARGET_ML);
    expect(waterTargetMl(0)).toBe(2500);
    expect(waterTargetMl(-5)).toBe(2500);
    expect(waterTargetMl(Number.NaN)).toBe(2500);
  });
});
