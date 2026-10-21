/**
 * Phase 14 — the deterministic guards around AI output (§19.2; ADR-020).
 */
import { describe, expect, it } from 'vitest';

import {
  PLAUSIBLE_PER_100G,
  checkEstimate,
  checkExplanation,
  draftOf,
  lowestConfidence,
  numbersIn,
  numbersInPayload,
} from '../src/ai/guard.js';
import { choosePortion, normaliseUnit } from '../src/ai/portion.js';

describe('the draft contract (§19.2)', () => {
  it('every draft is ai-draft and requires confirmation', () => {
    const d = draftOf({ items: [] }, 'medium');
    expect(d).toEqual({ data: { items: [] }, confidence: 'medium', source: 'ai-draft', requiresConfirmation: true });
  });

  it('a draft is only as sure as its weakest part', () => {
    expect(lowestConfidence(['high', 'high'])).toBe('high');
    expect(lowestConfidence(['high', 'medium'])).toBe('medium');
    expect(lowestConfidence(['medium', 'low', 'high'])).toBe('low');
    expect(lowestConfidence([])).toBe('high');
  });
});

describe('numbers in text', () => {
  it('digits, separators, decimals, fractions and words', () => {
    expect([...numbersIn('Move your target to 2,146 kcal, down 130 from 2276.')].sort()).toEqual(['130', '2146', '2276']);
    expect(numbersIn('0.5 kg a week')).toEqual(new Set(['0.5']));
    expect(numbersIn('about 1/2 a katori')).toEqual(new Set(['0.5', '1', '2']));
    expect(numbersIn('three sets, twice a week')).toEqual(new Set(['3', '2']));
    expect(numbersIn('a dozen, forty-seven times')).toEqual(new Set(['12', '40', '7']));
    expect(numbersIn('1200.0 equals 1200')).toEqual(new Set(['1200']));
    expect(numbersIn('no numbers here')).toEqual(new Set());
  });

  it('a payload contributes its numbers, nested, with and without sign', () => {
    const p = { headline: 'Move your target to 2146 kcal', values: { deltaKcal: -130, weeklyChangeKg: 0.7, list: ['Push A', 3] } };
    const n = numbersInPayload(p);
    for (const x of ['2146', '-130', '130', '0.7', '3']) expect(n.has(x), x).toBe(true);
  });
});

describe('§19.2: an explanation containing a number absent from the input is discarded', () => {
  const input = {
    headline: 'Move your target to 2146 kcal',
    detail: 'Your trend weight is rising about 0.70 kg a week. Moving the target down by 130 kcal (from 2276) keeps it on track.',
    values: { currentKcal: 2276, newKcal: 2146, deltaKcal: -130, weeklyChangeKg: 0.7 },
  };

  it('a faithful rephrasing passes', () => {
    expect(checkExplanation('You are gaining a little too fast, so FITOS suggests eating 130 kcal less: 2146 instead of 2276.', input)).toEqual({ ok: true });
    expect(checkExplanation('Your weight trend is climbing faster than your goal wants. Eating a bit less keeps you on track.', input)).toEqual({ ok: true });
  });

  it('a new number — digit or word — is caught', () => {
    expect(checkExplanation('Cut 200 kcal a day.', input)).toEqual({ ok: false, reason: 'new-number', numbers: ['200'] });
    expect(checkExplanation('Do this for four weeks.', input)).toMatchObject({ ok: false, reason: 'new-number', numbers: ['4'] });
    expect(checkExplanation('You will lose 0.5 kg.', input)).toMatchObject({ ok: false, reason: 'new-number' });
  });

  it('empty or long-winded answers are not explanations', () => {
    expect(checkExplanation('   ', input)).toEqual({ ok: false, reason: 'empty' });
    expect(checkExplanation('x'.repeat(601), input)).toEqual({ ok: false, reason: 'too-long' });
  });
});

describe('§19.2: implausible macros are rejected', () => {
  it('a plausible estimate passes', () => {
    // 1 katori dal: 150 g, 180 kcal, 9 g protein, 22 g carbs, 6 g fat.
    expect(checkEstimate({ grams: 150, kcal: 180, proteinG: 9, carbG: 22, fatG: 6 })).toEqual({ ok: true });
    expect(checkEstimate({ grams: null, kcal: 250, proteinG: 8, carbG: 30, fatG: 10 })).toEqual({ ok: true });
  });

  it('over 900 kcal or 90 g protein per 100 g is rejected', () => {
    expect(PLAUSIBLE_PER_100G).toMatchObject({ kcal: 900, protein: 90 });
    expect(checkEstimate({ grams: 50, kcal: 500, proteinG: 2, carbG: 2, fatG: 54 })).toMatchObject({ ok: false, problem: 'more than 900 kcal per 100 g' });
    expect(checkEstimate({ grams: 100, kcal: 400, proteinG: 95, carbG: 0, fatG: 2 })).toMatchObject({ ok: false, problem: 'more than 90 g protein per 100 g' });
  });

  it('nonsense values, impossible weights and energy that cannot add up are rejected', () => {
    expect(checkEstimate({ grams: 100, kcal: Number.NaN, proteinG: 1, carbG: 1, fatG: 1 }).ok).toBe(false);
    expect(checkEstimate({ grams: 100, kcal: 100, proteinG: -1, carbG: 1, fatG: 1 }).ok).toBe(false);
    expect(checkEstimate({ grams: 0, kcal: 100, proteinG: 5, carbG: 10, fatG: 4 }).ok).toBe(false);
    expect(checkEstimate({ grams: null, kcal: 4000, proteinG: 100, carbG: 400, fatG: 150 }).ok).toBe(false);
    expect(checkEstimate({ grams: 200, kcal: 900, proteinG: 5, carbG: 10, fatG: 5 })).toMatchObject({ ok: false, problem: "calories don't add up to the macros" });
  });
});


describe('choosing a FITOS portion for a parsed food (numbers from the database, not the model)', () => {
  const chapati = [
    { basis: 'per_serving' as const, servingLabel: '1 piece (40 g)', servingGrams: 40 },
    { basis: 'per_100g' as const, servingLabel: '100 g', servingGrams: 100 },
  ];
  const dal = [
    { basis: 'per_serving' as const, servingLabel: '1 katori (150 g)', servingGrams: 150 },
    { basis: 'per_100g' as const, servingLabel: '100 g', servingGrams: 100 },
  ];

  it('units are normalised', () => {
    expect(normaliseUnit('Grams')).toBe('g');
    expect(normaliseUnit('katoris')).toBe('katori');
    expect(normaliseUnit('pcs')).toBe('piece');
    expect(normaliseUnit('glass')).toBe('glass');
  });

  it('a unit the food serves in picks that serving, exactly', () => {
    expect(choosePortion(chapati, { quantity: 2, unit: 'pieces', grams: null })).toEqual({ row: 0, servings: 2, exact: true });
    expect(choosePortion(dal, { quantity: 1.5, unit: 'katori', grams: 300 })).toEqual({ row: 0, servings: 1.5, exact: true });
  });

  it('a count meets a serving that counts the food ("2 eggs"), not a measure ("1 katori") — found in the live smoke', () => {
    const eggs = [{ basis: 'per_serving' as const, servingLabel: '2 eggs', servingGrams: 110 }];
    expect(choosePortion(eggs, { quantity: 2, unit: 'piece', grams: 100 })).toEqual({ row: 0, servings: 1, exact: true });
    expect(choosePortion(eggs, { quantity: 3, unit: 'pcs', grams: null })).toEqual({ row: 0, servings: 1.5, exact: true });
    // A measured serving is not a count: two "pieces" of dal stay a guess.
    expect(choosePortion(dal, { quantity: 2, unit: 'piece', grams: null })?.exact).toBe(false);
  });

  it('grams or ml go by weight, per 100 g first', () => {
    expect(choosePortion(dal, { quantity: 250, unit: 'g', grams: 250 })).toEqual({ row: 1, servings: 2.5, exact: true });
    expect(choosePortion([{ basis: 'per_serving', servingLabel: '1 glass (250 ml)', servingGrams: 250 }], { quantity: 500, unit: 'ml', grams: null })).toEqual({ row: 0, servings: 2, exact: true });
  });

  it('an unknown unit falls back to the weight guess, then to servings — never exact', () => {
    expect(choosePortion(dal, { quantity: 1, unit: 'bowl', grams: 200 })).toEqual({ row: 1, servings: 2, exact: false });
    expect(choosePortion(dal, { quantity: 2, unit: 'bowl', grams: null })).toEqual({ row: 0, servings: 2, exact: false });
    expect(choosePortion([{ basis: 'per_100g', servingLabel: '100 g', servingGrams: 100 }], { quantity: 1, unit: 'plate', grams: null })).toEqual({ row: 0, servings: 1, exact: false });
  });

  it('servings stay within 0.1–20 in hundredths; nothing to choose from → null', () => {
    expect(choosePortion(chapati, { quantity: 50, unit: 'piece', grams: null })?.servings).toBe(20);
    expect(choosePortion(dal, { quantity: 5, unit: 'g', grams: null })?.servings).toBe(0.1);
    expect(choosePortion(dal, { quantity: 1, unit: 'katori', grams: null })?.servings).toBe(1);
    expect(choosePortion([], { quantity: 1, unit: 'piece', grams: null })).toBeNull();
    expect(choosePortion(chapati, { quantity: 0, unit: 'piece', grams: null })).toBeNull();
  });
});
