/**
 * Phase 18 (§26.1: 100 % branch coverage on every decision function) — the
 * edge cases the feature suites did not reach: refusals, fallbacks, empty
 * inputs and tie-breaks. Each test names the rule it pins.
 */
import { describe, expect, it } from 'vitest';

import { endpointHealth } from '../src/admin/admin.js';
import { checkEstimate } from '../src/ai/guard.js';
import { choosePortion } from '../src/ai/portion.js';
import { allergenStatus } from '../src/mess/allergens.js';
import { parseMenuString } from '../src/mess/parse.js';
import { descriptorFor, endpointFor } from '../src/mess/providers/vit/config.js';
import { VITMessProvider, buildDay, detectCycleLength, isMessItResponse, resolveMenuDate } from '../src/mess/providers/vit/provider.js';
import { mergeSnapshots } from '../src/mess/snapshots.js';
import type { MessItResponse } from '../src/mess/types.js';
import { TEMPLATES, render } from '../src/notify/copy.js';
import { validateFoodNutrition, widenFoodNutrition } from '../src/nutrition/food.js';
import { remaining } from '../src/nutrition/targets.js';
import { bestLifts } from '../src/progress/summary.js';
import { canonicalJson } from '../src/recommend/hash.js';
import { buildActions, wordReason } from '../src/recommend/engine.js';
import { model } from './today-fixtures.js';

describe('admin & AI guards', () => {
  it('failing with no success ever: the hours are unknown, not zero', () => {
    expect(endpointHealth({ lastSuccessAt: null, consecutiveFailures: 5 }, new Date())).toEqual({ state: 'failing', hoursSinceSuccess: null });
  });

  it('§19.2 bounds per 100 g also hold for carbohydrate and fat', () => {
    expect(checkEstimate({ grams: 100, kcal: 450, proteinG: 2, carbG: 110, fatG: 1 })).toMatchObject({ ok: false, problem: expect.stringContaining('carbs') });
    expect(checkEstimate({ grams: 100, kcal: 850, proteinG: 0, carbG: 0, fatG: 101 })).toMatchObject({ ok: false, problem: expect.stringContaining('fat') });
  });

  it('portions: a label without a count (or a zero count) is one; weighed rows prefer per 100 g, then serving rows in order', () => {
    const rows = [
      { basis: 'per_serving' as const, servingLabel: 'serving', servingGrams: 150 },
      { basis: 'per_serving' as const, servingLabel: '0 bowls', servingGrams: 300 },
      { basis: 'per_100g' as const, servingLabel: '100 g', servingGrams: 100 },
    ];
    expect(choosePortion(rows, { quantity: 200, unit: 'g', grams: null })).toEqual({ row: 2, servings: 2, exact: true });
    expect(choosePortion(rows, { quantity: 2, unit: 'serving', grams: null })).toEqual({ row: 0, servings: 2, exact: true });
    expect(choosePortion(rows, { quantity: 3, unit: 'bowl', grams: null })).toEqual({ row: 1, servings: 3, exact: true });
  });
});

describe('mess', () => {
  it('allergen status of a name that normalises to nothing is unknown', () => {
    expect(allergenStatus('!!!', 'milk', 'veg')).toBe('unknown');
  });

  it('a segment that is only a label, or only separators, is no dish', () => {
    expect(parseMenuString('Non Veg: , / , Idli', { messServesNonVeg: true }).map((d) => d.name)).toEqual(['Idli']);
  });

  it('unknown hostel or mess: no endpoint, no descriptor; the provider refuses', async () => {
    expect(endpointFor('nowhere', 'veg')).toBeNull();
    expect(descriptorFor('mens', 'nowhere')).toBeNull();
    await expect(new VITMessProvider(async () => ({}) as never).getDay({ providerId: 'vit-vellore', hostelId: 'x', messId: 'y' }, '2026-10-22')).rejects.toThrow(/Unknown VIT mess/);
  });

  it('a payload day that is not an object fails validation', () => {
    expect(isMessItResponse({ hostel: 1, mess: 1, menu: [null] })).toBe(false);
  });

  const weekOf = (dates: string[], menus: string[]): MessItResponse => ({
    hostel: 1,
    mess: 1,
    menu: dates.map((date, i) => ({ date, menu: [{ type: 1, menu: menus[i % menus.length]! }] })),
  });
  const days = (from: string, n: number): string[] =>
    Array.from({ length: n }, (_, i) => new Date(Date.parse(`${from}T00:00:00Z`) + i * 86_400_000).toISOString().slice(0, 10));

  it('cycle detection: two confirming pairs and no contradiction find the cycle; projection only forward; no congruent date is unavailable', () => {
    const r = weekOf(days('2026-10-01', 9), ['Idli', 'Poha', 'Dosa', 'Upma', 'Puri', 'Pongal', 'Vada']);
    expect(detectCycleLength(r)).toBe(7);
    expect(resolveMenuDate(r, '2026-10-15')).toEqual({ kind: 'cycle-inferred', date: '2026-10-15', sourceDate: '2026-10-08', cycleLengthDays: 7 });
    // Before the published data: nothing to project from.
    expect(resolveMenuDate(r, '2026-09-20')).toEqual({ kind: 'unavailable', date: '2026-09-20', latestAvailable: '2026-10-09' });
    const day = buildDay(r, '2026-10-15', false);
    expect(day.resolution.kind).toBe('cycle-inferred');
    expect(day.meals[0]!.dishes[0]!.name).toBe('Idli');
  });

  it('no dates at all: unavailable with no latest; an unavailable day has no meals', () => {
    const empty: MessItResponse = { hostel: 1, mess: 1, menu: [] };
    expect(resolveMenuDate(empty, '2026-10-22')).toEqual({ kind: 'unavailable', date: '2026-10-22', latestAvailable: null });
    expect(buildDay(empty, '2026-10-22', true).meals).toEqual([]);
    expect(mergeSnapshots([])).toEqual({ hostel: 0, mess: 0, menu: [] });
  });
});

describe('notifications, foods, targets, progress', () => {
  it('a template rendered without its slot says nothing there rather than "undefined"', () => {
    const t = TEMPLATES.find((x) => x.id === 'wr-c1')!;
    expect(render(t, { name: 'Asha' }).title).toBe(' in an hour');
  });

  it('widening refuses a fraction outside [0, 1); fibre above 100 g per 100 g is an issue', () => {
    const n = { macros: { kcalLow: 100, kcalHigh: 120, proteinLow: 1, proteinHigh: 2, carbLow: 10, carbHigh: 12, fatLow: 1, fatHigh: 2 }, fibre: { low: 1, high: 101 } };
    expect(() => widenFoodNutrition(n, 1)).toThrow(RangeError);
    expect(() => widenFoodNutrition(n, -0.1)).toThrow(RangeError);
    expect(validateFoodNutrition(n, 'per_100g')).toContainEqual({ field: 'fibre', problem: 'more than 100 g per 100 g' });
  });

  it('remaining with zero targets: no division, zero per cent', () => {
    expect(remaining({ kcalConsumed: 300, proteinConsumed: 10, targets: { kcal: 0, proteinG: 0, carbG: 0, fatG: 0 } as never })).toEqual({ kcal: 0, protein: 0, kcalPercent: 0, proteinPercent: 0 });
  });

  it('best lifts with the same name are ordered by id', () => {
    const lifts = bestLifts([
      { exerciseId: 'b', exerciseName: 'Row', date: '2026-10-01', weightKg: 50, reps: 8 },
      { exerciseId: 'a', exerciseName: 'Row', date: '2026-10-01', weightKg: 40, reps: 8 },
    ]);
    expect(lifts.map((l) => l.exerciseId)).toEqual(['a', 'b']);
  });
});

describe('TODAY engine & hashing', () => {
  it('canonical JSON: refuses non-finite numbers; undefined stays null in arrays and drops in objects; keys sorted', () => {
    expect(() => canonicalJson(Number.NaN)).toThrow(/non-finite/);
    expect(canonicalJson(undefined)).toBe('null');
    expect(canonicalJson([1, undefined])).toBe('[1,null]');
    expect(canonicalJson({ b: 1, a: undefined, c: { z: 1, y: 2 } })).toBe('{"b":1,"c":{"y":2,"z":1}}');
  });

  it('words for a reason with missing values read as empty and zero; a steady trend says so', () => {
    const w = wordReason({ code: 'calorie-target-off-trend', values: {} } as never);
    expect(w.detail).toContain('holding steady');
    expect(w.headline).toContain('0');
  });

  it('a rest day without targets says nothing about them', () => {
    const rest = buildActions(model({ training: { sessionName: null }, nutrition: { targets: null } })).find((a) => a.kind === 'rest-day')!;
    expect(rest.reason.values).toMatchObject({ kcalTarget: null, proteinTarget: null });
  });
});
