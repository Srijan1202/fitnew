import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { exactFoodNutrition, type FoodNutritionRange } from '../src/nutrition/food.js';
import {
  EMPTY_DAY,
  addDays,
  addToDay,
  checkLogDate,
  defaultMealSlot,
  localDateOf,
  remainingForDay,
  removeFromDay,
  resolvePortion,
  rollupDay,
  snapshotNutrition,
} from '../src/nutrition/log.js';

/** Dal tadka, 1 katori (150 g): a FITOS estimate, fibre unknown. */
const dal: FoodNutritionRange = {
  macros: { kcalLow: 120, kcalHigh: 185, proteinLow: 6, proteinHigh: 9, carbLow: 16, carbHigh: 23, fatLow: 3, fatHigh: 7.5 },
  fibre: null,
};
/** Honey per 100 g: a USDA record, exact. */
const honey = exactFoodNutrition({ kcal: 304, protein: 0.3, carb: 82.4, fat: 0, fibre: 0.2 });

describe('portions', () => {
  it('servings are bounded 0.1–20 in hundredths; grams follow the row weight', () => {
    const katori = { basis: 'per_serving' as const, servingGrams: 150 };
    expect(resolvePortion(katori, { servings: 1.5 })).toEqual({ ok: true, portion: { servings: 1.5, grams: 225 } });
    expect(resolvePortion(katori, { servings: 0.1 })).toMatchObject({ ok: true });
    expect(resolvePortion(katori, { servings: 20 })).toMatchObject({ ok: true });
    expect(resolvePortion(katori, { servings: 1.15 })).toMatchObject({ ok: true, portion: { servings: 1.15 } });
    expect(resolvePortion(katori, { servings: 0.09 })).toMatchObject({ ok: false });
    expect(resolvePortion(katori, { servings: 20.01 })).toMatchObject({ ok: false });
    expect(resolvePortion(katori, { servings: 1.005 })).toEqual({ ok: false, problem: 'servings are in steps of 0.01' });
    expect(resolvePortion(katori, { servings: Number.NaN })).toMatchObject({ ok: false });
  });

  it('grams convert exactly: per 100 g ÷ 100, a weighed serving ÷ its weight', () => {
    expect(resolvePortion({ basis: 'per_100g', servingGrams: 100 }, { grams: 55 })).toEqual({
      ok: true,
      portion: { servings: 0.55, grams: 55 },
    });
    const r = resolvePortion({ basis: 'per_serving', servingGrams: 150 }, { grams: 57 });
    expect(r).toMatchObject({ ok: true, portion: { grams: 57 } });
    expect(r.ok && r.portion.servings).toBeCloseTo(0.38, 10);
    // 5000 g is the cap; the servings it implies may exceed 20 — the bound is on what was entered.
    expect(resolvePortion({ basis: 'per_100g', servingGrams: 100 }, { grams: 5000 })).toMatchObject({ ok: true, portion: { servings: 50 } });
    expect(resolvePortion({ basis: 'per_100g', servingGrams: 100 }, { grams: 5000.1 })).toMatchObject({ ok: false });
    expect(resolvePortion({ basis: 'per_100g', servingGrams: 100 }, { grams: 0 })).toMatchObject({ ok: false });
  });

  it('a serving with no known weight takes servings only, and reports no grams', () => {
    const piece = { basis: 'per_serving' as const, servingGrams: null };
    expect(resolvePortion(piece, { servings: 2 })).toEqual({ ok: true, portion: { servings: 2, grams: null } });
    expect(resolvePortion(piece, { grams: 80 })).toEqual({ ok: false, problem: 'this serving has no weight; enter servings instead' });
  });
});

describe('snapshot', () => {
  it('an estimate scales and rounds OUTWARD — the range is never narrowed', () => {
    const s = snapshotNutrition(dal, 1.5);
    expect(s.macros).toEqual({ kcalLow: 180, kcalHigh: 278, proteinLow: 9, proteinHigh: 13.5, carbLow: 24, carbHigh: 34.5, fatLow: 4.5, fatHigh: 11.3 });
    expect(s.fibre).toBeNull();
    const third = snapshotNutrition(dal, 1 / 3);
    expect(third.macros.kcalLow).toBe(40);
    expect(third.macros.kcalHigh).toBe(62); // 61.67 → up
    expect(third.macros.fatHigh).toBe(2.5); // 2.5 exactly
    expect(third.macros.proteinLow).toBe(2); // 2 exactly
    expect(snapshotNutrition(dal, 0.37).macros.proteinLow).toBe(2.2); // 2.22 → down
  });

  it('an exact value stays exact — rounded to nearest on both ends', () => {
    const s = snapshotNutrition(honey, 0.21);
    expect(s.macros).toEqual({ kcalLow: 64, kcalHigh: 64, proteinLow: 0.1, proteinHigh: 0.1, carbLow: 17.3, carbHigh: 17.3, fatLow: 0, fatHigh: 0 });
    expect(s.fibre).toEqual({ low: 0, high: 0 }); // reported 0.2 × 0.21 = 0.04 → 0.0: a known, tiny amount
  });

  it('a snapshot is deterministic', () => {
    expect(snapshotNutrition(dal, 1.25)).toEqual(snapshotNutrition(dal, 1.25));
  });
});

describe('day rollup', () => {
  it('sums lows and highs; unknown fibre is counted, never added as 0', () => {
    const day = rollupDay([snapshotNutrition(dal, 1), snapshotNutrition(honey, 0.21), exactFoodNutrition({ kcal: 250, protein: 20, carb: 30, fat: 5, fibre: 3 })]);
    expect(day.macros).toEqual({ kcalLow: 434, kcalHigh: 499, proteinLow: 26.1, proteinHigh: 29.1, carbLow: 63.3, carbHigh: 70.3, fatLow: 8, fatHigh: 12.5 });
    expect(day.fibreKnown).toEqual({ low: 3, high: 3 });
    expect(day.fibreUnknownItems).toBe(1);
    expect(day.itemCount).toBe(3);
  });

  it('an empty day is zero consumed with nothing unknown', () => {
    expect(rollupDay([])).toEqual(EMPTY_DAY);
  });

  it('removing an item is the exact inverse of adding it (the cache stays equal to a recompute)', () => {
    const items = [snapshotNutrition(dal, 1.33), snapshotNutrition(honey, 0.7), exactFoodNutrition({ kcal: 99, protein: 1.1, carb: 2.2, fat: 3.3, fibre: null })];
    const all = rollupDay(items);
    expect(removeFromDay(all, items[1]!)).toEqual(rollupDay([items[0]!, items[2]!]));
    let running = EMPTY_DAY;
    for (const i of items) running = addToDay(running, i);
    for (const i of items) running = removeFromDay(running, i);
    expect(running).toEqual(EMPTY_DAY);
  });
});

describe('remaining', () => {
  const targets = { kcal: 2400, proteinG: 140, carbG: 290, fatG: 70 };

  it('below target: a range of what is left, state under', () => {
    const r = remainingForDay(rollupDay([snapshotNutrition(dal, 2)]), targets);
    expect(r.kcal).toEqual({ target: 2400, low: 2030, high: 2160, state: 'under' });
    expect(r.protein).toEqual({ target: 140, low: 122, high: 128, state: 'under' });
  });

  it('above target: negative remaining, state over — never clamped to 0', () => {
    const day = rollupDay([exactFoodNutrition({ kcal: 2520, protein: 150, carb: 300, fat: 80, fibre: 10 })]);
    const r = remainingForDay(day, targets);
    expect(r.kcal).toEqual({ target: 2400, low: -120, high: -120, state: 'over' });
    expect(r.protein.state).toBe('over');
  });

  it('a target inside the eaten range is "around" — whether it was passed is unknown', () => {
    const day = rollupDay([exactFoodNutrition({ kcal: 2300, protein: 100, carb: 250, fat: 60, fibre: null }), snapshotNutrition(dal, 1)]);
    expect(remainingForDay(day, targets).kcal).toEqual({ target: 2400, low: -85, high: -20, state: 'over' });
    const near = rollupDay([exactFoodNutrition({ kcal: 2250, protein: 100, carb: 250, fat: 60, fibre: null }), snapshotNutrition(dal, 1)]);
    expect(remainingForDay(near, targets).kcal).toEqual({ target: 2400, low: -35, high: 30, state: 'around' });
  });
});

describe('dates in the user zone', () => {
  it('IST boundaries: 23:59 and 00:01 land on their own days', () => {
    expect(localDateOf(new Date('2026-09-24T18:29:00Z'), 'Asia/Kolkata')).toBe('2026-09-24'); // 23:59 IST
    expect(localDateOf(new Date('2026-09-24T18:31:00Z'), 'Asia/Kolkata')).toBe('2026-09-25'); // 00:01 IST
    // A UTC evening that is already tomorrow in IST.
    expect(localDateOf(new Date('2026-09-24T20:00:00Z'), 'UTC')).toBe('2026-09-24');
    expect(localDateOf(new Date('2026-09-24T20:00:00Z'), 'Asia/Kolkata')).toBe('2026-09-25');
  });

  it('calendar arithmetic crosses months and years', () => {
    expect(addDays('2026-10-01', -1)).toBe('2026-09-30');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-09-24', -30)).toBe('2026-08-25');
  });

  it('today and 30 days back are allowed; tomorrow and day 31 are not', () => {
    expect(checkLogDate('2026-09-24', '2026-09-24')).toEqual({ ok: true });
    expect(checkLogDate('2026-08-25', '2026-09-24')).toEqual({ ok: true });
    expect(checkLogDate('2026-08-24', '2026-09-24')).toEqual({ ok: false, problem: 'too-old' });
    expect(checkLogDate('2026-09-25', '2026-09-24')).toEqual({ ok: false, problem: 'future' });
  });

  it('the default slot follows the local hour', () => {
    expect([7, 10, 11, 15, 16, 18, 19, 23].map(defaultMealSlot)).toEqual(['breakfast', 'breakfast', 'lunch', 'lunch', 'snacks', 'snacks', 'dinner', 'dinner']);
  });
});

describe('shared fixture with the app preview (owner J10)', () => {
  interface FixtureRow {
    kcalLow: number; kcalHigh: number; proteinLow: number; proteinHigh: number;
    carbLow: number; carbHigh: number; fatLow: number; fatHigh: number;
    fibreLow: number | null; fibreHigh: number | null;
  }
  interface Fixture {
    snapshots: { name: string; row: FixtureRow; servings: number; expected: FixtureRow }[];
    portions: { row: { basis: 'per_100g' | 'per_serving'; servingGrams: number | null }; input: { servings: number } | { grams: number }; expected: { ok: boolean; servings?: number; grams?: number | null } }[];
  }
  const fixture = JSON.parse(readFileSync(new URL('./fixtures/portion-preview.json', import.meta.url), 'utf8')) as Fixture;

  it('core snapshots equal the fixture the Dart preview is tested against', () => {
    for (const c of fixture.snapshots) {
      const r = c.row;
      const row: FoodNutritionRange = {
        macros: { kcalLow: r.kcalLow, kcalHigh: r.kcalHigh, proteinLow: r.proteinLow, proteinHigh: r.proteinHigh, carbLow: r.carbLow, carbHigh: r.carbHigh, fatLow: r.fatLow, fatHigh: r.fatHigh },
        fibre: r.fibreLow === null || r.fibreHigh === null ? null : { low: r.fibreLow, high: r.fibreHigh },
      };
      const s = snapshotNutrition(row, c.servings);
      expect({ ...s.macros, fibreLow: s.fibre?.low ?? null, fibreHigh: s.fibre?.high ?? null }, c.name).toEqual(c.expected);
    }
  });

  it('core portions equal the fixture', () => {
    for (const c of fixture.portions) {
      const r = resolvePortion(c.row, c.input);
      if (!c.expected.ok) expect(r.ok, JSON.stringify(c)).toBe(false);
      else expect(r, JSON.stringify(c)).toEqual({ ok: true, portion: { servings: c.expected.servings, grams: c.expected.grams } });
    }
  });
});
