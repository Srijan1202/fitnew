/**
 * Phase 10 Amendment A/B — meal composition (ADR-016; plan §20–§21).
 * "FITOS recommends a MEAL, not merely the nutritionally cheapest dish."
 * The owner's test list 1–18, the September real-menu sweep, the latency
 * budget, and the four Phase 9 estimate corrections.
 */
import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { ALLERGENS, allergenStatus } from '../src/mess/allergens.js';
import { isAmbient } from '../src/mess/classify.js';
import {
  COMPONENT_CANDIDATES, PLATE_COMPONENTS, PLATE_DISH_CAPS, PLATE_MAX_DISHES, classifyComponent, partsOf,
  servingCap, structureOf, type MealComponent,
} from '../src/mess/components.js';
import { MESS_ESTIMATE_CORRECTIONS, capMessConfidence, enrichDish, estimateMessDish, estimateNutrition } from '../src/mess/nutrition.js';
import { parseMenuString } from '../src/mess/parse.js';
import { VIT_DESCRIPTORS, VIT_ENDPOINTS } from '../src/mess/providers/vit/config.js';
import { buildDay } from '../src/mess/providers/vit/provider.js';
import { isDietAllowed, scoreTerms, type DietPreference, type PlateRequest } from '../src/mess/recommend.js';
import {
  NOTHING_EATEN, recommendMeal, type DayTargets, type EatenRanges, type MealRecommendation, type MealRecommendationInput,
} from '../src/mess/recommendation.js';
import type { MacroRange, MealSlot, MessDay, MessItResponse, MessMeal } from '../src/mess/types.js';

/* ----------------------------------------------------------- fixtures -- */

const load = (path: string): MessItResponse =>
  JSON.parse(readFileSync(fileURLToPath(new URL(path, import.meta.url)), 'utf8')) as MessItResponse;
const NAMES = VIT_ENDPOINTS.map((e) => `hostel-${e.hostel}-mess-${e.mess}`);
const CAPTURE = new Map(NAMES.map((n) => [n, load(`./fixtures/messit-2026-09-24/${n}.json`)]));
const servesNonVeg = (n: string): boolean => {
  const e = VIT_ENDPOINTS.find((x) => `hostel-${x.hostel}-mess-${x.mess}` === n);
  return VIT_DESCRIPTORS.find((d) => d.hostelId === e?.hostelId && d.messId === e?.messId)?.servesNonVeg ?? true;
};
function stored(day: MessDay): MessDay {
  return {
    ...day,
    meals: day.meals.map((m) => ({
      ...m,
      dishes: m.dishes.map((d) => (d.nutrition === null ? d : { ...d, nutrition: { ...d.nutrition, confidence: capMessConfidence(d.nutrition.confidence) } })),
    })),
  };
}
const dayOf = (n: string, date: string): MessDay => stored(buildDay(CAPTURE.get(n)!, date, servesNonVeg(n)));
/** Every published September day of every mess. */
const SEPTEMBER: { name: string; date: string; day: MessDay }[] = NAMES.flatMap((n) =>
  CAPTURE.get(n)!.menu.filter((d) => d.date.startsWith('2026-09')).map((d) => ({ name: n, date: d.date, day: dayOf(n, d.date) })),
);

/** A synthetic one-meal day from menu text (the parser and estimates are the real ones). */
function menu(slot: MealSlot, raw: string, nonVeg = false): MessDay {
  const meal: MessMeal = { slot, rawMenu: raw, dishes: parseMenuString(raw, { messServesNonVeg: nonVeg }).map(enrichDish) };
  return stored({ date: '2026-09-24', meals: [meal], resolution: { kind: 'exact', date: '2026-09-24' } });
}

const TARGETS: DayTargets = { kcal: 2400, proteinG: 140, carbG: 290, fatG: 70 };
function input(over: Partial<MealRecommendationInput> & Pick<MealRecommendationInput, 'menu' | 'slot'>): MealRecommendationInput {
  return {
    diet: 'non-vegetarian', allergies: [], excludedDishIds: [], goal: 'muscle-gain', targets: TARGETS,
    eaten: NOTHING_EATEN, loggedSlots: [], varietyDays: {}, postWorkout: false, ...over,
  };
}

/** The first S24 run (owner, 2026-09-24): fat-loss, non-veg, women's special mess, three meals logged. */
const S24_DAY = dayOf('hostel-2-mess-1', '2026-09-24');
const S24_EATEN: EatenRanges = { kcalLow: 848, kcalHigh: 1213, proteinLow: 38.7, proteinHigh: 54.2, carbLow: 72, carbHigh: 104, fatLow: 39.2, fatHigh: 67.2 };
const s24 = (slot: MealSlot): MealRecommendation =>
  recommendMeal(input({
    menu: S24_DAY, slot, goal: 'fat-loss', targets: { kcal: 1774, proteinG: 135, carbG: 198, fatG: 49 },
    eaten: S24_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'],
  }));

const comps = (rec: MealRecommendation, rank = 0): MealComponent[] => (rec.plates[rank]?.items ?? []).map((i) => i.component);
const hasStaple = (c: readonly MealComponent[]) => c.includes('staple') || c.includes('complete');
const hasStrong = (c: readonly MealComponent[]) => c.includes('protein') || c.includes('complete');
const SUPPORTING: ReadonlySet<MealComponent> = new Set(['soup', 'beverage', 'fruit', 'crisp', 'dessert', 'condiment', 'veg', 'pulse-gravy', 'dairy', 'snack']);

/* ------------------------------------------------ component classifier -- */

describe('meal components (C1) — a separate classifier; Phase 9 role untouched', () => {
  it.each([
    ['Watermelon Juice', 'veg', 'beverage'], ['Fresh Juice', 'veg', 'beverage'], ['Mint Lemon', 'veg', 'beverage'],
    ['Tea', 'veg', 'beverage'], ['Dates Milkshake', 'veg', 'beverage'],
    ['Rasam', 'veg', 'soup'], ['Sweet Corn Soup', 'veg', 'soup'], ['Cream Of Veg Soup', 'veg', 'soup'],
    ['White Rice', 'veg', 'staple'], ['Phulka', 'veg', 'staple'], ['Idly', 'veg', 'staple'], ['Curd Rice', 'veg', 'staple'],
    ['Podi Dosa', 'veg', 'staple'], ['Podi Idly', 'veg', 'staple'], ['Pav Bhaji', 'veg', 'staple'], ['Idiyappam', 'veg', 'staple'],
    ['Chicken Biriyani', 'nonveg', 'complete'], ['Egg Fried Rice', 'egg', 'complete'], ['Chole Bhatura', 'veg', 'complete'],
    ['Dhal', 'veg', 'protein'], ['Paneer Butter Masala', 'veg', 'protein'], ['Chenna Masala', 'veg', 'protein'],
    ['Mixed Sprouts Sundal', 'veg', 'protein'], ['Tandoori Chicken', 'nonveg', 'protein'], ['Boiled Egg', 'egg', 'protein'],
    ['Sambar', 'veg', 'pulse-gravy'], ['Keerai Kootu', 'veg', 'pulse-gravy'], ['Kadi Pakora', 'veg', 'pulse-gravy'],
    ['Curd', 'veg', 'dairy'], ['Onion Raitha', 'veg', 'dairy'], ['Dahi Vada', 'veg', 'dairy'],
    ['Beetroot Poriyal', 'veg', 'veg'], ['Brinjal Fry', 'veg', 'veg'], ['Baby Corn Manchurian', 'veg', 'veg'], ['Vada Curry', 'veg', 'veg'],
    ['Seasonal Fruit', 'veg', 'fruit'], ['Banana', 'veg', 'fruit'],
    ['Sweet Corn Chaat', 'veg', 'snack'], ['Veg Puff', 'veg', 'snack'], ['Pani Puri (5 Nos)', 'veg', 'snack'], ['Spring Roll With Sauce', 'veg', 'snack'],
    ['Gulab Jamun', 'veg', 'dessert'], ['Ice Cream', 'veg', 'dessert'], ['Bread Halwa', 'veg', 'dessert'],
    ['Appalam', 'veg', 'crisp'], ['Rice Papad', 'veg', 'crisp'], ['Potato Chips', 'veg', 'crisp'],
    ['Peanut Chutney', 'veg', 'condiment'], ['Pickle', 'veg', 'condiment'], ['Tomato Thokku', 'veg', 'condiment'],
    ['Urapadai', 'unknown', 'other'], ['Something New', 'veg', 'other'],
  ] as const)('%s (%s) → %s', (name, diet, component) => {
    expect(classifyComponent(name, diet)).toBe(component);
  });

  it('generalises by term family, not dish lists: unseen names', () => {
    expect(classifyComponent('Drumstick Sambar', 'veg')).toBe('pulse-gravy');
    expect(classifyComponent('Chow Chow Poriyal', 'veg')).toBe('veg');
    expect(classifyComponent('Mango Juice', 'veg')).toBe('beverage');
    expect(classifyComponent('Tomato Soup', 'veg')).toBe('soup');
    expect(classifyComponent('Mushroom Biriyani', 'veg')).toBe('staple');
    expect(classifyComponent('Mutton Biriyani', 'nonveg')).toBe('complete');
  });

  it('every dish in the September capture, frozen (reviewed on any change)', async () => {
    const all = new Map<string, MealComponent>();
    for (const { day } of SEPTEMBER) for (const m of day.meals) for (const d of m.dishes) all.set(`${d.name} (${d.diet})`, classifyComponent(d.name, d.diet));
    const sorted = Object.fromEntries([...all.entries()].sort(([a], [b]) => a.localeCompare(b)));
    await expect(JSON.stringify(sorted, null, 2) + '\n').toMatchFileSnapshot('./fixtures/meal-components-2026-09.json');
  });

  it('what may go on a plate (C5: no drinks; C6: no dessert or crisp at lunch/dinner) and the caps', () => {
    const set = (s: MealSlot) => [...PLATE_COMPONENTS[s]].sort();
    expect(set('lunch')).toEqual(['complete', 'dairy', 'fruit', 'protein', 'pulse-gravy', 'soup', 'staple', 'veg']);
    expect(set('dinner')).toEqual(set('lunch'));
    expect(set('breakfast')).toEqual(['complete', 'dairy', 'fruit', 'protein', 'pulse-gravy', 'snack', 'staple', 'veg']);
    expect(set('snacks')).toEqual(['complete', 'crisp', 'dairy', 'dessert', 'fruit', 'protein', 'snack', 'staple']);
    for (const s of ['breakfast', 'lunch', 'snacks', 'dinner'] as const) {
      for (const never of ['beverage', 'condiment', 'other'] as const) expect(PLATE_COMPONENTS[s].has(never)).toBe(false);
    }
    expect(COMPONENT_CANDIDATES).toMatchObject({ staple: 3, complete: 2, protein: 3, 'pulse-gravy': 2, veg: 2, dairy: 1, soup: 1, fruit: 1, snack: 2, dessert: 2, crisp: 1 });
    expect(PLATE_MAX_DISHES).toEqual({ breakfast: 4, lunch: 5, snacks: 2, dinner: 5 });
    expect(PLATE_DISH_CAPS.lunch).toEqual({ staple: 2, complete: 1, protein: 2, 'pulse-gravy': 1, dairy: 1, veg: 2, soup: 1, fruit: 1 });
    expect(servingCap('White Rice', 'staple')).toBe(2);
    expect(servingCap('Phulka', 'staple')).toBe(3);
    expect(servingCap('Dhal', 'protein')).toBe(2);
    expect(servingCap('Curd', 'dairy')).toBe(1);
    expect(servingCap('Chicken Biriyani', 'complete')).toBe(1);
  });

  it('the owner\'s tiers', () => {
    const t = (slot: MealSlot, c: MealComponent[]) => structureOf(slot, partsOf(c));
    expect(t('lunch', ['staple', 'protein', 'veg'])).toEqual({ tier: 1, kind: 'complete-meal', missing: [] });
    expect(t('lunch', ['complete', 'veg'])?.tier).toBe(1);
    expect(t('lunch', ['staple', 'protein'])).toEqual({ tier: 2, kind: 'meal', missing: ['vegetable'] });
    expect(t('lunch', ['staple', 'pulse-gravy', 'veg'])).toEqual({ tier: 3, kind: 'meal-weak-protein', missing: ['strong-protein'] });
    expect(t('lunch', ['staple'])).toEqual({ tier: 4, kind: 'limited', missing: ['protein', 'vegetable'] });
    expect(t('lunch', ['protein', 'veg'])).toEqual({ tier: 5, kind: 'limited-no-staple', missing: ['staple'] });
    for (const bad of [['soup'], ['fruit'], ['veg'], ['soup', 'fruit', 'veg'], ['pulse-gravy', 'dairy']] as MealComponent[][]) {
      expect(t('dinner', bad)).toBeNull();
    }
    expect(t('breakfast', ['staple', 'protein'])).toEqual({ tier: 1, kind: 'complete-meal', missing: [] });
    expect(t('breakfast', ['staple', 'pulse-gravy'])?.kind).toBe('meal-weak-protein');
    expect(t('breakfast', ['staple'])?.kind).toBe('limited');
    expect(t('breakfast', ['protein'])?.kind).toBe('limited-no-staple');
    expect(t('breakfast', ['fruit'])).toBeNull();
    expect(t('snacks', ['snack'])).toEqual({ tier: 1, kind: 'snack', missing: [] });
    expect(t('snacks', ['fruit'])?.kind).toBe('snack');
  });
});

/* ---------------------------------------------------- owner tests 1–4 -- */

describe('the S24 cases (owner tests 1–4)', () => {
  it('1. Watermelon Juice can never be a breakfast plate', () => {
    const rec = s24('breakfast');
    expect(rec.status).toBe('ok');
    for (const p of rec.plates) expect(p.items.some((i) => i.name === 'Watermelon Juice')).toBe(false);
    expect(hasStaple(comps(rec)) && hasStrong(comps(rec))).toBe(true);
    expect(rec.dishes.find((o) => o.dish.name === 'Watermelon Juice')!.reasons).toEqual([{ code: 'not-a-meal-component', component: 'beverage' }]);
    // A breakfast of only juice and fruit is no meal at all.
    expect(recommendMeal(input({ menu: menu('breakfast', 'Watermelon Juice, Papaya'), slot: 'breakfast', diet: 'vegetarian' })).status).toBe('no-meal');
  });

  it('2. Rice alone is limited, not a complete lunch', () => {
    const lunch = s24('lunch');
    expect(lunch.plates[0]!.structure.kind).toBe('complete-meal');
    expect(lunch.plates[0]!.items.length).toBeGreaterThan(1);
    const onlyRice = recommendMeal(input({ menu: menu('lunch', 'White Rice, Rasam, Appalam'), slot: 'lunch', diet: 'vegetarian' }));
    expect(onlyRice.plates[0]!.structure).toEqual({ tier: 4, kind: 'limited', missing: ['protein', 'vegetable'] });
    expect(onlyRice.plates[0]!.reasons).toContainEqual({ code: 'limited-menu', missing: ['protein', 'vegetable'] });
  });

  it('3. Rasam alone is never dinner', () => {
    const dinner = s24('dinner');
    expect(dinner.plates[0]!.items.map((i) => i.name)).not.toEqual(['Rasam']);
    for (const p of dinner.plates) expect(hasStaple(p.items.map((i) => i.component))).toBe(true);
    expect(recommendMeal(input({ menu: menu('dinner', 'Rasam, Seasonal Fruit'), slot: 'dinner', diet: 'vegetarian' })).status).toBe('no-meal');
  });

  it('4. staple + protein + vegetable beats a single supporting dish structurally, even where the supporting dish scores higher', () => {
    const day = menu('lunch', 'White Rice, Dhal, Beetroot Poriyal, Rasam');
    // Protein done, fat spent, a small kcal share: nutritionally, Rasam alone "wins".
    const rec = recommendMeal(input({
      menu: day, slot: 'lunch', goal: 'fat-loss', targets: { kcal: 2400, proteinG: 140, carbG: 290, fatG: 70 },
      eaten: { ...NOTHING_EATEN, kcalLow: 1800, kcalHigh: 1900, proteinLow: 139.5, proteinHigh: 145, fatLow: 60, fatHigh: 72 }, loggedSlots: ['breakfast'],
    }));
    expect(rec.status).toBe('ok');
    const meal = rec.plates[0]!;
    expect(meal.structure.kind).toBe('complete-meal');
    const rasam = day.meals[0]!.dishes.find((d) => d.name === 'Rasam')!.nutrition!.macros;
    const req = { meal: day.meals[0]!, remainingKcal: rec.target!.kcal, remainingProtein: rec.target!.protein, remainingCarb: rec.target!.carb, remainingFat: rec.target!.fat, normalKcal: 2400 * 0.35, normalCarb: 290 * 0.35, normalFat: 70 * 0.35, diet: 'non-vegetarian', goal: 'fat-loss' } as const;
    const rasamScore = scoreTerms({ macros: rasam, itemCount: 1, totalServings: 1, request: req }).score;
    expect(rasamScore).toBeGreaterThan(meal.score);
    expect(meal.reasons.some((r) => r.code === 'kcal-over' || r.code === 'kcal-may-exceed')).toBe(true);
    for (const p of rec.plates) expect(p.items.length).toBeGreaterThan(1);
  });
});

/* --------------------------------------------------- the September sweep -- */

type Persona = Omit<MealRecommendationInput, 'menu' | 'slot'>;
const P = (o: Partial<Persona>): Persona => ({ ...input({ menu: S24_DAY, slot: 'lunch' }), ...o });
const PERSONAS: Record<string, Persona> = {
  'veg-muscle': P({ diet: 'vegetarian', goal: 'muscle-gain' }),
  'veg-fatloss': P({ diet: 'vegetarian', goal: 'fat-loss', targets: { kcal: 1774, proteinG: 135, carbG: 198, fatG: 49 } }),
  'egg-general': P({ diet: 'eggetarian', goal: 'general' }),
  'nonveg-muscle': P({ diet: 'non-vegetarian', goal: 'muscle-gain' }),
  'fat-budget-spent': P({ diet: 'non-vegetarian', goal: 'fat-loss', targets: { kcal: 1774, proteinG: 135, carbG: 198, fatG: 49 }, eaten: S24_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'] }),
  'veg-peanut-milk': P({ diet: 'vegetarian', goal: 'general', allergies: ['peanut', 'milk'] }),
};

describe('the September real-menu sweep (every mess, every day, every meal, six personas)', () => {
  it('a meal, never the cheapest dish; safety intact; deterministic', { timeout: 600_000 }, () => {
    let plates = 0;
    let recs = 0;
    for (const { name, date, day } of SEPTEMBER) {
      for (const meal of day.meals) {
        const slot = meal.slot;
        for (const [pk, persona] of Object.entries(PERSONAS)) {
          const rec = recommendMeal({ ...persona, menu: day, slot });
          recs += 1;
          const where = `${name} ${date} ${slot} ${pk}`;
          for (const p of rec.plates) {
            plates += 1;
            const c = p.items.map((i) => i.component);
            // 8. drinks never on a plate; 9. no dessert or crisp at lunch/dinner.
            expect(c, where).not.toContain('beverage');
            expect(c, where).not.toContain('condiment');
            if (slot === 'lunch' || slot === 'dinner') {
              expect(c, where).not.toContain('dessert');
              expect(c, where).not.toContain('crisp');
            }
            if (slot !== 'snacks') {
              // Never a single supporting item; never soup/juice/fruit as the meal.
              expect(hasStaple(c) || hasStrong(c), where).toBe(true);
              expect(c.every((x) => SUPPORTING.has(x)), where).toBe(false);
            } else {
              expect(p.structure.kind, where).toBe('snack');
            }
            // 5/6. diet and allergy safety, primary and every alternative.
            for (const item of p.items) {
              const dish = meal.dishes.find((d) => d.id === item.dishId)!;
              expect(isDietAllowed(dish.diet, persona.diet as DietPreference), where).toBe(true);
              for (const a of dish.alternativeDiets) expect(isDietAllowed(a, persona.diet as DietPreference), where).toBe(true);
              for (const allergen of persona.allergies) {
                expect(allergenStatus(dish.name, allergen, dish.diet), where).toBe('free');
                dish.alternatives.forEach((alt, i) => expect(allergenStatus(alt, allergen, dish.alternativeDiets[i]!), where).toBe('free'));
              }
            }
          }
          // No lunch/dinner top plate lacks a staple when the filtered menu has one.
          if ((slot === 'lunch' || slot === 'dinner') && rec.plates.length > 0) {
            const stapleOnMenu = rec.dishes.some((o) => {
              const k = classifyComponent(o.dish.name, o.dish.diet);
              return (k === 'staple' || k === 'complete') && (o.onPlate || o.reasons.some((r) => r.code === 'not-chosen' || r.code === 'not-top-candidate'));
            });
            if (stapleOnMenu) expect(hasStaple(comps(rec)), where).toBe(true);
          }
          // 10. alternatives differ by a meaningful anchor.
          const anchors = rec.plates.map((p) => new Set(p.items.filter((i) => slot === 'snacks' || ['staple', 'complete', 'protein'].includes(i.component)).map((i) => i.dishId)));
          for (let a = 0; a < anchors.length; a += 1) {
            for (let b = a + 1; b < anchors.length; b += 1) {
              const A = anchors[a]!, B = anchors[b]!;
              const aInB = [...A].every((x) => B.has(x));
              const bInA = [...B].every((x) => A.has(x));
              expect(aInB || bInA, `${where} plates ${a + 1}/${b + 1}`).toBe(false);
            }
          }
        }
      }
    }
    expect(recs).toBeGreaterThan(3000);
    expect(plates).toBeGreaterThan(5000);
  });

  it('15. deterministic: every real meal twice, identical', { timeout: 300_000 }, () => {
    for (const { day } of SEPTEMBER.filter((_, i) => i % 5 === 0)) {
      for (const meal of day.meals) {
        const i = { ...PERSONAS['veg-muscle']!, menu: day, slot: meal.slot };
        expect(recommendMeal(i)).toEqual(recommendMeal(i));
      }
    }
  });
});

/* ------------------------------------------------------- snacks, C3, C4 -- */

describe('snacks, alternatives, statuses', () => {
  it('7. corn alone stays a valid snack, labelled a snack', () => {
    const rec = s24('snacks');
    expect(rec.status).toBe('ok');
    expect(rec.plates[0]!.items.map((i) => i.name)).toEqual(['Sweet Corn Chaat']);
    expect(rec.plates[0]!.structure.kind).toBe('snack');
    expect(rec.plates[0]!.reasons).toContainEqual({ code: 'meal-structure', kind: 'snack' });
  });

  it('10. alternatives replace an anchor; a rasam or curd swap is not an alternative; fewer when the menu cannot', () => {
    const rich = recommendMeal(input({ menu: menu('lunch', 'White Rice, Phulka, Dhal, Palak Paneer, Chenna Masala, Beetroot Poriyal, Rasam, Curd'), slot: 'lunch', diet: 'vegetarian' }));
    expect(rich.plates.length).toBe(3);
    const sets = rich.plates.map((p) => p.items.filter((i) => ['staple', 'protein'].includes(i.component)).map((i) => i.dishId).sort().join('+'));
    expect(new Set(sets).size).toBe(3);
    const thin = recommendMeal(input({ menu: menu('lunch', 'White Rice, Dhal, Beetroot Poriyal, Rasam, Curd'), slot: 'lunch', diet: 'vegetarian' }));
    expect(thin.plates.length).toBe(1); // one staple, one protein: no meaningful alternative exists
  });

  it('11. no-meal vs nothing-fits', () => {
    const noMeal = recommendMeal(input({ menu: menu('lunch', 'Rasam, Seasonal Fruit, Appalam, Gulab Jamun'), slot: 'lunch', diet: 'vegetarian' }));
    expect(noMeal).toMatchObject({ status: 'no-meal', plates: [], smallestMealKcal: null });
    expect(noMeal.dishes.find((o) => o.dish.name === 'Appalam')!.reasons).toEqual([{ code: 'not-a-meal-component', component: 'crisp' }]);
    expect(noMeal.dishes.find((o) => o.dish.name === 'Gulab Jamun')!.reasons).toEqual([{ code: 'not-a-meal-component', component: 'dessert' }]);

    const day = menu('lunch', 'White Rice, Dhal, Beetroot Poriyal');
    // 100 kcal left today: even the smallest meal (Rice + Dhal) goes over the whole day.
    const fits = recommendMeal(input({ menu: day, slot: 'lunch', eaten: { ...NOTHING_EATEN, kcalLow: 2200, kcalHigh: 2300 }, loggedSlots: ['breakfast'] }));
    expect(fits.status).toBe('nothing-fits');
    expect(fits.target!.dayRemainingKcal).toBe(100);
    expect(fits.smallestMealKcal).toBe(175 + 120);
    expect(fits.plates).toEqual([]);
    // 400 kcal left today: over this meal's share, but within the day → the meal, with an honest kcal reason.
    const over = recommendMeal(input({ menu: day, slot: 'lunch', eaten: { ...NOTHING_EATEN, kcalLow: 1900, kcalHigh: 2000 }, loggedSlots: ['breakfast'] }));
    expect(over.status).toBe('ok');
    expect(over.plates[0]!.structure.kind).toBe('complete-meal');
    expect(over.plates[0]!.reasons.some((r) => r.code === 'kcal-over' || r.code === 'kcal-may-exceed')).toBe(true);
    // Nothing safe stays its own status.
    expect(recommendMeal(input({ menu: menu('lunch', 'Chicken Gravy, Egg Curry'), slot: 'lunch', diet: 'vegetarian' })).status).toBe('nothing-safe');
  });

  it('the best meal that fits the day is offered; calories never push a plate into a limited tier', () => {
    // Real menu (women's veg, 7 Sep), the S24 state: the complete meal (Chole Bhatura + Sabji,
    // at least 645 kcal) does not fit the 561 kcal left today; Rice + Sambar + Sabji does.
    const rec = recommendMeal(input({
      menu: dayOf('hostel-2-mess-2', '2026-09-07'), slot: 'dinner', goal: 'fat-loss',
      targets: { kcal: 1774, proteinG: 135, carbG: 198, fatG: 49 }, eaten: S24_EATEN, loggedSlots: ['breakfast', 'lunch', 'snacks'],
    }));
    expect(rec.status).toBe('ok');
    const top = rec.plates[0]!;
    expect(top.structure.kind).toBe('meal-weak-protein');
    expect(top.macros.kcalLow).toBeLessThanOrEqual(561);
    for (const p of rec.plates) expect(p.macros.kcalLow).toBeLessThanOrEqual(rec.target!.dayRemainingKcal);
    // With room for only a bowl of dal, a menu with a staple says nothing-fits, not "dal alone as lunch".
    const tight = recommendMeal(input({
      menu: menu('lunch', 'White Rice, Dhal, Beetroot Poriyal'), slot: 'lunch',
      eaten: { ...NOTHING_EATEN, kcalLow: 2200, kcalHigh: 2270 }, loggedSlots: ['breakfast'],
    }));
    expect(tight.target!.dayRemainingKcal).toBe(130);
    expect(tight.status).toBe('nothing-fits'); // Dhal alone (120 kcal) would fit, but is not a meal here.
  });

  it('12. limited-menu names only what the menu (after your filters) lacks', () => {
    const r = (raw: string, slot: MealSlot = 'lunch') => recommendMeal(input({ menu: menu(slot, raw), slot, diet: 'vegetarian' })).plates[0]!;
    expect(r('White Rice, Dhal').reasons).toContainEqual({ code: 'limited-menu', missing: ['vegetable'] });
    expect(r('White Rice, Dhal').structure.kind).toBe('meal');
    const weak = r('White Rice, Sambar, Beetroot Poriyal');
    expect(weak.structure.kind).toBe('meal-weak-protein');
    expect(weak.reasons).toContainEqual({ code: 'limited-menu', missing: ['strong-protein'] });
    expect(r('Dhal, Beetroot Poriyal').structure.kind).toBe('limited-no-staple');
    expect(r('Idly, Coconut Chutney', 'breakfast').reasons).toContainEqual({ code: 'limited-menu', missing: ['protein'] });
    const full = r('White Rice, Dhal, Beetroot Poriyal');
    expect(full.reasons.some((x) => x.code === 'limited-menu')).toBe(false);
    expect(full.reasons).toEqual(expect.arrayContaining([
      { code: 'meal-structure', kind: 'complete-meal' },
      { code: 'staple-anchor', dishSlug: 'white-rice' },
      { code: 'protein-anchor', dishSlug: 'dhal', strength: 'strong' },
      { code: 'vegetable-component', dishSlug: 'beetroot-poriyal' },
    ]));
  });

  it('the smallest valid meal is never cut off by a tight kcal ceiling; servings are not inflated', () => {
    const rec = s24('breakfast'); // a 255 kcal target
    const p = rec.plates[0]!;
    expect(p.structure.kind).toBe('complete-meal');
    for (const i of p.items) expect(i.servings).toBeLessThanOrEqual(servingCap(i.name, i.component));
  });
});

/* ------------------------------------------- ambient, by head noun -- */

describe('ambient items are the accompaniment itself, not a dish that names one (owner blocker 1)', () => {
  it.each([
    // False positives of the old anywhere-in-the-name match: real dishes.
    ['Paneer Butter Masala', false], ['Butter Chicken Masala', false], ['Spring Roll With Sauce', false],
    ['Bread Halwa', false], ['Milk Peda', false], ['Butter Naan', false],
    // Genuine ambient accompaniments stay ambient.
    ['Garlic Sauce', true], ['Pickle', true], ['Mango Pickle', true], ['Butter', true], ['Bread', true], ['Jam', true],
    ['Butter Milk', true], ['Tea', true], ['Masala Tea', true], ['Coffee', true], ['Milk', true], ['Cold Milk', true],
    ['Rose Milk', true], ['Chocos', true], ['Corn Flakes', true],
  ] as const)('%s → ambient %s', (name, ambient) => {
    expect(isAmbient(name)).toBe(ambient);
  });

  it('Paneer Butter Masala and Butter Chicken Masala reach plates; Garlic Sauce and Butter do not', () => {
    const veg = recommendMeal(input({ menu: menu('lunch', 'White Rice, Paneer Butter Masala, Beetroot Poriyal, Pickle'), slot: 'lunch', diet: 'vegetarian' }));
    expect(veg.plates[0]!.items.map((i) => i.name)).toContain('Paneer Butter Masala');
    expect(veg.dishes.find((o) => o.dish.name === 'Pickle')!.reasons).toEqual([{ code: 'ambient' }]);
    const nonveg = recommendMeal(input({ menu: menu('dinner', 'Phulka, Butter Chicken Masala, Garlic Sauce, Mix Veg Gravy', true), slot: 'dinner' }));
    expect(nonveg.plates[0]!.items.map((i) => i.name)).toContain('Butter Chicken Masala');
    expect(nonveg.dishes.find((o) => o.dish.name === 'Garlic Sauce')!.reasons).toEqual([{ code: 'ambient' }]);
    const breakfast = recommendMeal(input({ menu: menu('breakfast', 'Bread, Butter, Jam, Idly, Sambar', true), slot: 'breakfast' }));
    for (const n of ['Bread', 'Butter', 'Jam']) expect(breakfast.dishes.find((o) => o.dish.name === n)!.reasons).toEqual([{ code: 'ambient' }]);
  });

  it('the real men’s special snack of 9 Sep (Spring Roll With Sauce) is a snack again, not no-meal', () => {
    const day = dayOf('hostel-1-mess-1', '2026-09-09');
    const rec = recommendMeal(input({ menu: day, slot: 'snacks' }));
    expect(rec.status).toBe('ok');
    expect(rec.plates[0]!.items.map((i) => i.name)).toEqual(['Spring Roll With Sauce']);
    expect(rec.plates[0]!.structure.kind).toBe('snack');
  });
});

/* ---------------------------------------------------------------- F1 -- */

describe('F1 — over-penalties against a normal-sized meal (owner C2)', () => {
  const meal: MessMeal = { slot: 'dinner', dishes: [], rawMenu: '' };
  const plate = (kcal: number, carb: number, fat: number): MacroRange => ({
    kcalLow: kcal, kcalHigh: kcal, proteinLow: 20, proteinHigh: 20, carbLow: carb, carbHigh: carb, fatLow: fat - 3, fatHigh: fat + 3,
  });
  const req = (o: Partial<PlateRequest>): PlateRequest => ({
    meal, remainingKcal: 561, remainingProtein: 96, remainingCarb: 94, remainingFat: 0, diet: 'non-vegetarian', goal: 'fat-loss',
    normalKcal: 1774 * 0.3, normalCarb: 198 * 0.3, normalFat: 49 * 0.3, ...o,
  });

  it('13. fat target 0 no longer costs hundreds of points (pinned: 18 g of fat at dinner, 49 g a day)', () => {
    const t = scoreTerms({ macros: plate(500, 60, 18), itemCount: 4, totalServings: 4, request: req({}) });
    expect(t.fatPenalty).toBeCloseTo(50 * 18 / 14.7, 10); // 61.22…
    expect(t.fatPenalty).toBeCloseTo(61.2245, 3);
    // Before F1 (no normal meal given) the same plate cost 850.
    const { normalKcal: _k, normalCarb: _c, normalFat: _f, ...preF1 } = req({});
    const old = scoreTerms({ macros: plate(500, 60, 18), itemCount: 4, totalServings: 4, request: preF1 });
    expect(old.fatPenalty).toBeCloseTo(850, 10);
  });

  it('14. carb target 0 behaves the same way; post-workout halves it and the reward stays bounded', () => {
    const t = scoreTerms({ macros: plate(500, 60, 10), itemCount: 4, totalServings: 4, request: req({ remainingCarb: 0 }) });
    expect(t.carbPenalty).toBeCloseTo(40 * 60 / 59.4, 10); // 40.40…
    const post = scoreTerms({ macros: plate(500, 60, 10), itemCount: 4, totalServings: 4, request: req({ remainingCarb: 0, postWorkout: true }) });
    expect(post.carbPenalty).toBeCloseTo(20 * 60 / 59.4, 10);
    expect(post.carbReward).toBe(20);
  });

  it('a remaining target larger than a normal meal keeps the ADR-015 denominator', () => {
    const t = scoreTerms({ macros: plate(500, 60, 30), itemCount: 4, totalServings: 4, request: req({ remainingFat: 20 }) });
    expect(t.fatPenalty).toBeCloseTo(50 * 10 / 20, 10);
  });

  it('the kcal over-term uses the same rule; the under-term is unchanged', () => {
    const over = scoreTerms({ macros: plate(700, 60, 10), itemCount: 4, totalServings: 4, request: req({ remainingKcal: 100 }) });
    expect(over.kcalPenalty).toBeCloseTo(180 * 600 / (1774 * 0.3), 10);
    const under = scoreTerms({ macros: plate(300, 60, 10), itemCount: 4, totalServings: 4, request: req({ remainingKcal: 561 }) });
    expect(under.kcalPenalty).toBeCloseTo(35 * 261 / 561, 10);
  });
});

/* --------------------------------------------------------- performance -- */

describe('16. latency: every real September meal under 100 ms', () => {
  it('each meal (median of 3), all personas', { timeout: 600_000 }, () => {
    let worst = { ms: 0, where: '' };
    for (const { name, date, day } of SEPTEMBER) {
      for (const meal of day.meals) {
        for (const [pk, persona] of Object.entries(PERSONAS)) {
          const times: number[] = [];
          for (let i = 0; i < 3; i += 1) {
            const t = performance.now();
            recommendMeal({ ...persona, menu: day, slot: meal.slot });
            times.push(performance.now() - t);
          }
          times.sort((a, b) => a - b);
          if (times[1]! > worst.ms) worst = { ms: times[1]!, where: `${name} ${date} ${meal.slot} ${pk}` };
        }
      }
    }
    expect(worst.ms, worst.where).toBeLessThan(100);
  });
});

/* ------------------------------------------------- 17. estimate fixes -- */

describe('17. the four Phase 9 estimate corrections (Amendment B)', () => {
  const macros = (n: string) => estimateMessDish(n, 'other')!.macros;

  it('each is an existing entry or a sum of existing entries', () => {
    expect(estimateMessDish('Curd Rice', 'dairy')).toMatchObject({ servingLabel: '1 katori', servingGrams: 180, confidence: 'medium' });
    expect(macros('Curd Rice')).toEqual({ kcalLow: 180, kcalHigh: 260, proteinLow: 5, proteinHigh: 8, carbLow: 30, carbHigh: 40, fatLow: 4, fatHigh: 8 });
    expect(estimateMessDish('Rice Papad', 'fried')).toMatchObject({ servingLabel: '1 small portion', servingGrams: 25, confidence: 'low' });
    expect(macros('Rice Papad')).toEqual(estimateNutrition('Papad', 'other')!.macros);
    expect(estimateMessDish('Chole Bhatura', 'legume')).toMatchObject({ servingLabel: '1 plate (2 bhatura + chole)', servingGrams: 330, confidence: 'low' });
    const chole = estimateNutrition('Chole', 'other')!.macros;
    const bhatura = estimateNutrition('Bhatura', 'other')!.macros;
    expect(macros('Chole Bhatura')).toEqual({
      kcalLow: chole.kcalLow + 2 * bhatura.kcalLow, kcalHigh: chole.kcalHigh + 2 * bhatura.kcalHigh,
      proteinLow: chole.proteinLow + 2 * bhatura.proteinLow, proteinHigh: chole.proteinHigh + 2 * bhatura.proteinHigh,
      carbLow: chole.carbLow + 2 * bhatura.carbLow, carbHigh: chole.carbHigh + 2 * bhatura.carbHigh,
      fatLow: chole.fatLow + 2 * bhatura.fatLow, fatHigh: chole.fatHigh + 2 * bhatura.fatHigh,
    });
    expect(macros('Chole Bhatura')).toEqual({ kcalLow: 590, kcalHigh: 870, proteinLow: 17, proteinHigh: 27, carbLow: 80, carbHigh: 112, fatLow: 20, fatHigh: 41 });
    expect(estimateMessDish('Dahi Vada', 'dairy')).toMatchObject({ servingLabel: '2 pieces in curd', servingGrams: 230, confidence: 'low' });
    expect(macros('Dahi Vada')).toEqual({ kcalLow: 305, kcalHigh: 485, proteinLow: 10, proteinHigh: 18, carbLow: 31, carbHigh: 48, fatLow: 15, fatHigh: 29.5 });
    expect(MESS_ESTIMATE_CORRECTIONS.map((c) => c.terms)).toEqual([['curd rice'], ['rice papad'], ['chole bhatura'], ['dahi vada']]);
  });

  it('mess path only: the Phase 7 path (estimateNutrition) is unchanged', () => {
    expect(estimateNutrition('Curd Rice', 'other')!.macros.kcalHigh).toBe(105);
    expect(estimateNutrition('Rice Papad', 'other')!.macros.kcalHigh).toBe(215);
    expect(estimateNutrition('White Rice', 'other')).toEqual(estimateMessDish('White Rice', 'staple'));
  });

  it('the mirror and the recommender use the corrected estimate', () => {
    const [dish] = parseMenuString('Curd Rice', { messServesNonVeg: false }).map(enrichDish);
    expect(dish!.nutrition!.macros.kcalLow).toBe(180);
    const rec = recommendMeal(input({ menu: menu('dinner', 'Curd Rice, Dhal, Beetroot Poriyal'), slot: 'dinner', diet: 'vegetarian' }));
    const item = rec.plates[0]!.items.find((i) => i.dishId === 'curd-rice')!;
    expect(item.component).toBe('staple');
    expect(item.macros.kcalLow).toBe(180 * item.servings);
  });
});

// Vocabulary guard: the allergen list is shared with the contract.
it('ten allergens', () => expect(ALLERGENS.length).toBe(10));
