import { describe, expect, it } from 'vitest';

import {
  GUIDE_MAX_ITEMS,
  GUIDE_MAX_OPTIONS,
  guidePrompt,
  haveAllowed,
  messDishAllowed,
  readGuideAnswer,
  remainingOf,
  roundServings,
  scaleMacros,
  sumMacros,
  type GuideCandidate,
} from '../src/ai/guide.js';
import type { MacroRange } from '../src/mess/types.js';

/** Beta 3.6 (owner, F15): the AI food guide's rules. */
const m = (kcal: number, protein: number): MacroRange => ({
  kcalLow: kcal - 10,
  kcalHigh: kcal + 10,
  proteinLow: protein - 1,
  proteinHigh: protein + 1,
  carbLow: 10,
  carbHigh: 12,
  fatLow: 2,
  fatHigh: 3,
});
const c = (id: string, name: string, source: 'mess' | 'have' = 'have'): GuideCandidate => ({
  id,
  source,
  name,
  servingLabel: '1 serving',
  macros: m(200, 10),
  caution: [],
});
const CANDIDATES = [c('M1', 'Paneer butter masala', 'mess'), c('H1', 'Boiled eggs'), c('H2', 'Banana')];

describe('what may be suggested', () => {
  it('a mess dish keeps the Phase 10 hard rules: diet, and allergens confirmed free', () => {
    expect(messDishAllowed('Chapati', 'veg', 'vegetarian', [])).toBe(true);
    expect(messDishAllowed('Chicken curry', 'nonveg', 'vegetarian', [])).toBe(false);
    expect(messDishAllowed('Egg curry', 'egg', 'eggetarian', [])).toBe(true);
    expect(messDishAllowed('Peanut chutney', 'veg', 'non-vegetarian', ['peanut'])).toBe(false);
  });

  it('something the person has: refused when its name breaks their diet or holds their allergen; unknown allergens are a caution', () => {
    expect(haveAllowed('Chicken sandwich', 'vegetarian', [])).toEqual({ ok: false, caution: [] });
    expect(haveAllowed('Chicken sandwich', 'non-vegetarian', [])).toEqual({ ok: true, caution: [] });
    expect(haveAllowed('Boiled eggs', 'vegetarian', [])).toEqual({ ok: false, caution: [] });
    expect(haveAllowed('Boiled eggs', 'eggetarian', [])).toEqual({ ok: true, caution: [] });
    expect(haveAllowed('Peanut butter', 'vegetarian', ['peanut'])).toEqual({ ok: false, caution: [] });
    // "Chocolate cake" likely holds egg.
    expect(haveAllowed('Chocolate cake', 'non-vegetarian', ['egg'])).toEqual({ ok: false, caution: [] });
    // Oats: the name cannot rule wheat out, so it is allowed with a caution.
    expect(haveAllowed('Oats', 'vegetarian', ['wheat', 'wheat'])).toEqual({ ok: true, caution: ['wheat'] });
    // Banana is known to be free of peanut.
    expect(haveAllowed('Banana', 'vegetarian', ['peanut'])).toEqual({ ok: true, caution: [] });
  });
});

describe("the model's answer, checked", () => {
  it('not the agreed shape: null', () => {
    expect(readGuideAnswer(null, CANDIDATES)).toBeNull();
    expect(readGuideAnswer('options', CANDIDATES)).toBeNull();
    expect(readGuideAnswer({ options: 'x' }, CANDIDATES)).toBeNull();
  });

  it('known ids only, once each, servings in quarters within 0.25–4, empty options dropped, defaults for missing words', () => {
    const answer = {
      options: [
        null,
        'a string',
        { title: 'Nothing real', items: [{ id: 'X9', servings: 1 }] },
        { title: '  Paneer plate  ', why: ' Protein. ', items: [{ id: 'M1', servings: 1.3 }, { id: 'M1', servings: 2 }, { id: 'H2', servings: 9 }, { id: 'H1', servings: 0.05 }, { id: 'H1', servings: 'two' }, { id: 7 }, null, { id: 'H1', servings: -1 }] },
        { items: [{ id: ' H1 ', servings: 2 }] },
        { title: 'No items' },
      ],
    };
    expect(readGuideAnswer(answer, CANDIDATES)).toEqual([
      { title: 'Paneer plate', why: 'Protein.', items: [{ id: 'M1', servings: 1.25 }, { id: 'H2', servings: 4 }, { id: 'H1', servings: 0.25 }] },
      { title: 'A plate', why: '', items: [{ id: 'H1', servings: 2 }] },
    ]);
  });

  it(`at most ${GUIDE_MAX_OPTIONS} options of ${GUIDE_MAX_ITEMS} items`, () => {
    const many = Array.from({ length: 8 }, (_, i) => c(`H${i}`, `Food ${i}`));
    const items = many.map((x) => ({ id: x.id, servings: 1 }));
    const r = readGuideAnswer({ options: Array.from({ length: 5 }, () => ({ title: 't', items })) }, many)!;
    expect(r).toHaveLength(GUIDE_MAX_OPTIONS);
    expect(r[0]!.items).toHaveLength(GUIDE_MAX_ITEMS);
  });

  it('servings round to the nearest quarter', () => {
    expect(roundServings(1.12)).toBe(1);
    expect(roundServings(1.13)).toBe(1.25);
    expect(roundServings(0)).toBe(0.25);
    expect(roundServings(10)).toBe(4);
  });
});

describe('the numbers are the candidates own', () => {
  it('scaled outward and summed', () => {
    const one = m(200, 10);
    expect(scaleMacros(one, 1.5)).toEqual({ kcalLow: 285, kcalHigh: 315, proteinLow: 13, proteinHigh: 17, carbLow: 15, carbHigh: 18, fatLow: 3, fatHigh: 5 });
    expect(sumMacros([])).toEqual({ kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0, carbLow: 0, carbHigh: 0, fatLow: 0, fatHigh: 0 });
    expect(sumMacros([one, one]).kcalHigh).toBe(420);
  });

  it('what is left of the day, from the middle of what was eaten, never below 0', () => {
    expect(remainingOf(null, { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0 })).toBeNull();
    expect(remainingOf({ kcal: 2400, proteinG: 120 }, { kcalLow: 900, kcalHigh: 1100, proteinLow: 50, proteinHigh: 60 })).toEqual({ kcal: 1400, proteinG: 65 });
    expect(remainingOf({ kcal: 1000, proteinG: 50 }, { kcalLow: 1500, kcalHigh: 1700, proteinLow: 60, proteinHigh: 70 })).toEqual({ kcal: 0, proteinG: 0 });
  });
});

describe('the prompt', () => {
  it('lists every candidate by id with its serving and rough numbers, what is left, and what they feel like', () => {
    const p = guidePrompt({ slot: 'dinner', candidates: CANDIDATES, remaining: { kcal: 700, proteinG: 40 }, feel: 'something spicy' });
    expect(p.system).toContain('Use only ids from the list');
    expect(p.user).toContain('Meal: dinner.');
    expect(p.user).toContain('Left for today: about 700 kcal and 40 g protein.');
    expect(p.user).toContain('They feel like: something spicy');
    expect(p.user).toContain('M1: Paneer butter masala (from the mess), 1 serving = 1 serving, about 200 kcal and 10 g protein');
    expect(p.user).toContain('H1: Boiled eggs (they have it)');
    const bare = guidePrompt({ slot: 'lunch', candidates: [], remaining: null, feel: null });
    expect(bare.user).toContain('They have no targets set.');
    expect(bare.user).toContain('No preference given.');
  });
});
