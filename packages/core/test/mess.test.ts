import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { parseMenuString, splitMenuString, slugifyDish } from '../src/mess/parse.js';
import { classifyDiet, classifyRole } from '../src/mess/classify.js';
import { buildDay, detectCycleLength, isMessItResponse, resolveMenuDate, VITMessProvider } from '../src/mess/providers/vit/provider.js';
import { VIT_ENDPOINTS, MESSIT_BASE_URL } from '../src/mess/providers/vit/config.js';
import { enrichDish } from '../src/mess/nutrition.js';
import { isDietAllowed, suggestPlates } from '../src/mess/recommend.js';
import type { MessItResponse, MessMeal } from '../src/mess/types.js';

function fixture(name: string): MessItResponse {
  const path = fileURLToPath(new URL(`./fixtures/${name}.json`, import.meta.url));
  return JSON.parse(readFileSync(path, 'utf8')) as MessItResponse;
}

const mensVeg = fixture('hostel-1-mess-2');
const mensNonVeg = fixture('hostel-1-mess-3');
const mensSpecial = fixture('hostel-1-mess-1');
const womensNonVeg = fixture('hostel-2-mess-3');
const womensSpecial = fixture('hostel-2-mess-1');
const womensVeg = fixture('hostel-2-mess-2');

/* ------------------------------------------------------------------ config */

describe('endpoint config', () => {
  it('derives all six URLs from the documented pattern', () => {
    expect(VIT_ENDPOINTS).toHaveLength(6);
    expect(VIT_ENDPOINTS.map((e) => e.url)).toContain(`${MESSIT_BASE_URL}/hostel-1-mess-2.json`);
    expect(VIT_ENDPOINTS.map((e) => e.url)).toContain(`${MESSIT_BASE_URL}/hostel-2-mess-1.json`);
  });
});

/* ------------------------------------------------------------- wire format */

describe('wire format validation', () => {
  it('accepts every real captured response', () => {
    for (const r of [mensVeg, mensNonVeg, mensSpecial, womensNonVeg, womensSpecial, womensVeg]) {
      expect(isMessItResponse(r)).toBe(true);
    }
  });

  it('rejects a response missing the menu array', () => {
    expect(isMessItResponse({ hostel: 1, mess: 2 })).toBe(false);
    expect(isMessItResponse(null)).toBe(false);
  });
});

/* ------------------------------------------------------------------ parser */

describe('splitMenuString', () => {
  it('drops empty segments from real double-comma defects', () => {
    // hostel-2-mess-3, 2026-09-07 lunch: "...Butter milk,, White Rice..."
    const parts = splitMenuString('Roti, Toor Dhal, Butter milk,, White Rice');
    expect(parts).toEqual(['Roti', 'Toor Dhal', 'Butter milk', 'White Rice']);
  });

  it('repairs the orphaned "White" fragment seen in hostel-1-mess-3', () => {
    // Real defect: "Rajma Masala, White, Egg Fried Rice, White Rice"
    const parts = splitMenuString('Rajma Masala, White, Egg Fried Rice, White Rice');
    expect(parts).toContain('White Egg Fried Rice');
    expect(parts).not.toContain('White');
  });
});

describe('parseMenuString', () => {
  it('strips the "Non Veg :" label and tags the dish non-veg', () => {
    const dishes = parseMenuString(
      'Phulka, Dhal Tadka, Non Veg : Chicken gravy, Sweet :  Gulab Jamun',
      { messServesNonVeg: true },
    );
    const chicken = dishes.find((d) => d.name.toLowerCase().includes('chicken'));
    expect(chicken).toBeDefined();
    expect(chicken?.name).toBe('Chicken Gravy');
    expect(chicken?.label).toBe('Non Veg');
    expect(chicken?.diet).toBe('nonveg');

    const sweet = dishes.find((d) => d.label === 'Sweet');
    expect(sweet?.name).toBe('Gulab Jamun');
  });

  it('handles the colon-without-space variant "Non Veg: Boiled Egg"', () => {
    const dishes = parseMenuString('Set Dosai, Vada curry, Non Veg: Boiled Egg', {
      messServesNonVeg: true,
    });
    const egg = dishes.find((d) => d.name.includes('Egg'));
    expect(egg?.diet).toBe('egg');
    expect(egg?.label).toBe('Non Veg');
  });

  it('splits "/" alternatives, keeping the first as primary', () => {
    const dishes = parseMenuString('Coconut Rice / Tamarind Rice, Rasam', {
      messServesNonVeg: false,
    });
    const rice = dishes[0];
    expect(rice?.name).toBe('Coconut Rice');
    expect(rice?.alternatives).toEqual(['Tamarind Rice']);
  });

  it('deduplicates repeated tokens within one meal', () => {
    // hostel-1-mess-1, 2026-08-06 snacks: "Masala Vada, Tea, Coffee, Milk, Tea"
    const dishes = parseMenuString('Masala Vada, Tea, Coffee, Milk, Tea', {
      messServesNonVeg: true,
    });
    const teas = dishes.filter((d) => d.id === 'tea');
    expect(teas).toHaveLength(1);
  });

  it('marks staple beverages and spreads as ambient', () => {
    const dishes = parseMenuString('Podi Idly, Vada, Bread, Butter, Jam, Tea, Coffee, Milk', {
      messServesNonVeg: true,
    });
    expect(dishes.find((d) => d.id === 'bread')?.isAmbient).toBe(true);
    expect(dishes.find((d) => d.id === 'podi-idly')?.isAmbient).toBe(false);
  });

  it('produces stable ids that ignore piece counts', () => {
    expect(slugifyDish('Veg Cutlet (2 Nos)')).toBe('veg-cutlet');
    expect(slugifyDish('Veg. Cutlet (2 Nos)')).toBe('veg-cutlet');
  });
});

/* -------------------------------------------------------------- diet safety */

describe('diet classification', () => {
  it('detects meat and egg inline, without a label', () => {
    // The men's non-veg mess does NOT label; chicken appears inline.
    expect(classifyDiet('Chicken Biryani')).toBe('nonveg');
    expect(classifyDiet('Fish Fry')).toBe('nonveg');
    expect(classifyDiet('Egg Burji')).toBe('egg');
    expect(classifyDiet('French Toast')).toBe('egg');
    expect(classifyDiet('Cheese Omelette')).toBe('egg');
  });

  it('does not false-positive on vegetarian dishes', () => {
    expect(classifyDiet('Meal Maker Pulav')).toBe('veg');
    expect(classifyDiet('Veg Manchurian')).toBe('veg');
    expect(classifyDiet('Paneer Butter Masala')).toBe('veg');
    expect(classifyDiet('Gobi Manchurian')).toBe('veg');
    expect(classifyDiet('White Rice')).toBe('veg');
  });

  it('leaves a genuinely ambiguous dish unknown in a meat-serving mess', () => {
    // "Salna" is a real menu item and may or may not be meat-based.
    const dishes = parseMenuString('Salna', { messServesNonVeg: true });
    expect(dishes[0]?.diet).toBe('unknown');
  });

  it('treats an ambiguous dish in a veg-only mess as veg', () => {
    const dishes = parseMenuString('Salna', { messServesNonVeg: false });
    expect(dishes[0]?.diet).toBe('veg');
  });

  it('excludes unknown-diet dishes from vegetarian plates (fail safe)', () => {
    expect(isDietAllowed('unknown', 'vegetarian')).toBe(false);
    expect(isDietAllowed('egg', 'vegetarian')).toBe(false);
    expect(isDietAllowed('egg', 'eggetarian')).toBe(true);
    expect(isDietAllowed('nonveg', 'eggetarian')).toBe(false);
    expect(isDietAllowed('nonveg', 'non-vegetarian')).toBe(true);
  });
});

describe('role classification', () => {
  it('puts butter milk in dairy, not beverage', () => {
    expect(classifyRole('Butter Milk', 'veg')).toBe('dairy');
    expect(classifyRole('Cold Milk', 'veg')).toBe('beverage');
  });

  it('classifies staples, legumes and protein correctly', () => {
    expect(classifyRole('White Rice', 'veg')).toBe('staple');
    expect(classifyRole('Phulka', 'veg')).toBe('staple');
    expect(classifyRole('Dhal Tadka', 'veg')).toBe('legume');
    expect(classifyRole('Sambar', 'veg')).toBe('legume');
    expect(classifyRole('Paneer Butter Masala', 'veg')).toBe('protein');
    expect(classifyRole('Chicken Gravy', 'nonveg')).toBe('protein');
  });
});

/* ------------------------------------------------------- date resolution */

describe('menu date resolution', () => {
  it('returns an exact hit when the endpoint has today', () => {
    const resolution = resolveMenuDate(mensVeg, '2026-09-07');
    expect(resolution.kind).toBe('exact');
  });

  it('detects the 14-day publication cycle', () => {
    expect(detectCycleLength(mensVeg)).toBe(14);
  });

  it('falls back to a cycle-inferred menu when the endpoint is stale', () => {
    // hostel-1-mess-3 was stale at capture: August only, nothing for 2026-09-07.
    const resolution = resolveMenuDate(mensNonVeg, '2026-09-07');
    expect(resolution.kind).toBe('cycle-inferred');
    if (resolution.kind === 'cycle-inferred') {
      expect(resolution.cycleLengthDays).toBe(14);
      // 2026-08-24 is exactly 14 days before the target and is published.
      expect(resolution.sourceDate).toBe('2026-08-24');
    }
  });

  it('reports unavailable rather than throwing when nothing can be resolved', () => {
    const empty: MessItResponse = { hostel: 1, mess: 2, menu: [] };
    const resolution = resolveMenuDate(empty, '2026-09-07');
    expect(resolution.kind).toBe('unavailable');
    if (resolution.kind === 'unavailable') expect(resolution.latestAvailable).toBeNull();
  });

  it('never silently presents an inferred menu as exact', () => {
    const day = buildDay(mensNonVeg, '2026-09-07', true);
    expect(day.resolution.kind).not.toBe('exact');
    expect(day.meals.length).toBeGreaterThan(0);
  });
});

/* ------------------------------------------------------------- buildDay */

describe('buildDay', () => {
  it('maps numeric types to the four meal slots', () => {
    const day = buildDay(mensVeg, '2026-09-07', false);
    expect(day.meals.map((m) => m.slot)).toEqual(['breakfast', 'lunch', 'snacks', 'dinner']);
  });

  it('preserves the verbatim upstream string for every meal', () => {
    const day = buildDay(mensVeg, '2026-09-07', false);
    const lunch = day.meals.find((m) => m.slot === 'lunch');
    expect(lunch?.rawMenu).toContain('Kadai Panneer');
  });

  it('attaches an estimated nutrition range to known dishes', () => {
    const day = buildDay(mensVeg, '2026-09-07', false);
    const lunch = day.meals.find((m) => m.slot === 'lunch');
    const rice = lunch?.dishes.find((d) => d.id === 'white-rice');
    expect(rice?.nutrition?.source).toBe('estimated-table');
    expect(rice?.nutrition?.macros.kcalLow).toBeLessThan(rice?.nutrition?.macros.kcalHigh ?? 0);
  });

  it('drops unknown meal types instead of guessing', () => {
    const odd: MessItResponse = {
      hostel: 1, mess: 2,
      menu: [{ date: '2026-09-07', menu: [{ type: 9, menu: 'Mystery Item' }] }],
    };
    expect(buildDay(odd, '2026-09-07', false).meals).toHaveLength(0);
  });
});

/* ------------------------------------------------------------- provider */

describe('VITMessProvider', () => {
  it('fetches once and serves subsequent reads from cache', async () => {
    let calls = 0;
    const provider = new VITMessProvider(async () => {
      calls += 1;
      return mensVeg;
    });
    const ref = { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' };
    await provider.getDay(ref, '2026-09-07');
    await provider.getDay(ref, '2026-09-01');
    expect(calls).toBe(1);
  });

  it('rejects a malformed upstream payload rather than rendering nonsense', async () => {
    const provider = new VITMessProvider(async () => ({ oops: true }) as unknown as MessItResponse);
    await expect(
      provider.getDay({ providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' }, '2026-09-07'),
    ).rejects.toThrow(/unexpected shape/);
  });

  it('exposes all six messes', async () => {
    const messes = await new VITMessProvider(async () => mensVeg).listMesses();
    expect(messes).toHaveLength(6);
  });
});

/* ---------------------------------------------------------- recommender */

function mealFrom(response: MessItResponse, date: string, servesNonVeg: boolean, slot: string): MessMeal {
  const day = buildDay(response, date, servesNonVeg);
  const meal = day.meals.find((m) => m.slot === slot);
  if (meal === undefined) throw new Error(`no ${slot} on ${date}`);
  return meal;
}

describe('plate recommender', () => {
  it('never puts a non-veg dish on a vegetarian plate', () => {
    const dinner = mealFrom(womensNonVeg, '2026-09-11', true, 'dinner');
    // This dinner really does contain "Non Veg : Tandoori Chicken".
    expect(dinner.dishes.some((d) => d.diet === 'nonveg')).toBe(true);

    const plates = suggestPlates({
      meal: dinner,
      remainingKcal: 700,
      remainingProtein: 55,
      diet: 'vegetarian',
      goal: 'muscle-gain',
    });
    expect(plates.length).toBeGreaterThan(0);
    for (const plate of plates) {
      for (const item of plate.items) {
        const dish = dinner.dishes.find((d) => d.id === item.dishId);
        expect(dish?.diet).toBe('veg');
      }
    }
  });

  it('does put chicken on a non-vegetarian plate when protein is short', () => {
    const dinner = mealFrom(womensNonVeg, '2026-09-11', true, 'dinner');
    const plates = suggestPlates({
      meal: dinner,
      remainingKcal: 700,
      remainingProtein: 55,
      diet: 'non-vegetarian',
      goal: 'muscle-gain',
    });
    const top = plates[0];
    expect(top).toBeDefined();
    expect(top?.items.some((i) => i.name.toLowerCase().includes('chicken'))).toBe(true);
  });

  it('respects a tight calorie budget on a fat-loss goal', () => {
    const lunch = mealFrom(mensVeg, '2026-09-07', false, 'lunch');
    const plates = suggestPlates({
      meal: lunch,
      remainingKcal: 450,
      remainingProtein: 35,
      diet: 'vegetarian',
      goal: 'fat-loss',
    });
    const top = plates[0];
    expect(top).toBeDefined();
    // Midpoint calories should not blow far past the budget.
    const mid = ((top?.macros.kcalLow ?? 0) + (top?.macros.kcalHigh ?? 0)) / 2;
    expect(mid).toBeLessThan(650);
  });

  it('returns macros as ranges, never point values', () => {
    const lunch = mealFrom(mensVeg, '2026-09-07', false, 'lunch');
    const [top] = suggestPlates({
      meal: lunch,
      remainingKcal: 800,
      remainingProtein: 50,
      diet: 'vegetarian',
      goal: 'muscle-gain',
    });
    expect(top).toBeDefined();
    expect(top!.macros.kcalHigh).toBeGreaterThan(top!.macros.kcalLow);
    expect(top!.reasons.length).toBeGreaterThan(0);
    expect(['high', 'medium', 'low']).toContain(top!.confidence);
  });

  it('honours excluded dishes', () => {
    const lunch = mealFrom(mensVeg, '2026-09-07', false, 'lunch');
    const plates = suggestPlates({
      meal: lunch,
      remainingKcal: 800,
      remainingProtein: 50,
      diet: 'vegetarian',
      goal: 'muscle-gain',
      excludedDishIds: ['white-rice'],
    });
    for (const plate of plates) {
      expect(plate.items.some((i) => i.dishId === 'white-rice')).toBe(false);
    }
  });

  it('returns an empty list rather than inventing food when nothing qualifies', () => {
    const empty: MessMeal = { slot: 'dinner', dishes: [], rawMenu: '' };
    expect(
      suggestPlates({
        meal: empty,
        remainingKcal: 600,
        remainingProtein: 40,
        diet: 'vegetarian',
        goal: 'general',
      }),
    ).toEqual([]);
  });
});

/* ------------------------------------------------------------ enrichment */

describe('nutrition enrichment', () => {
  it('is a no-op when nutrition is already present (user corrections win)', () => {
    const [dish] = parseMenuString('White Rice', { messServesNonVeg: false });
    const corrected = {
      ...dish!,
      nutrition: {
        servingLabel: '1 katori', servingGrams: 150,
        macros: { kcalLow: 200, kcalHigh: 200, proteinLow: 4, proteinHigh: 4, carbLow: 44, carbHigh: 44, fatLow: 1, fatHigh: 1 },
        confidence: 'high' as const, source: 'user-corrected' as const,
      },
    };
    expect(enrichDish(corrected).nutrition?.source).toBe('user-corrected');
  });
});
/* ==========================================================================
 * The two remaining endpoints - women's special and women's vegetarian.
 *
 * Captured live 2026-09-07. Both were FRESH (full September, dates already
 * sorted), the opposite of the men's non-veg and special endpoints which were
 * August-only at the same moment. Freshness is per-endpoint, not a property of
 * the provider.
 *
 * The vegetarian mess is the only fixture in the suite that exercises the
 * `messServesNonVeg: false` branch of the diet resolver against real data.
 * ========================================================================== */

describe("women's special mess (hostel-2-mess-1)", () => {
  it('was fresh at capture: the capture date resolves exactly', () => {
    expect(resolveMenuDate(womensSpecial, '2026-09-07').kind).toBe('exact');
  });

  it('detects the same 14-day cycle as the other endpoints', () => {
    expect(detectCycleLength(womensSpecial)).toBe(14);
  });

  it('infers forward from a published date exactly one cycle back', () => {
    const resolution = resolveMenuDate(womensSpecial, '2026-09-29');
    expect(resolution.kind).toBe('cycle-inferred');
    if (resolution.kind === 'cycle-inferred') {
      expect(resolution.sourceDate).toBe('2026-09-15');
      expect(resolution.cycleLengthDays).toBe(14);
    }
  });

  it('handles both "Non Veg :" and "Non Veg:" spacing within one endpoint', () => {
    // 09-01 lunch uses "Non Veg : Chicken gravy"; 09-07 breakfast uses
    // "Non Veg: Boiled Egg" with no space. Both real, same file.
    const lunch = mealFrom(womensSpecial, '2026-09-01', true, 'lunch');
    const chicken = lunch.dishes.find((d) => d.name === 'Chicken Gravy');
    expect(chicken?.label).toBe('Non Veg');
    expect(chicken?.diet).toBe('nonveg');

    const breakfast = mealFrom(womensSpecial, '2026-09-07', true, 'breakfast');
    const egg = breakfast.dishes.find((d) => d.name === 'Boiled Egg');
    expect(egg?.label).toBe('Non Veg');
    expect(egg?.diet).toBe('egg');
  });

  it('strips the "Veg :" label without corrupting the dish name', () => {
    const breakfast = mealFrom(womensSpecial, '2026-09-07', true, 'breakfast');
    const sundal = breakfast.dishes.find((d) => d.label === 'Veg');
    expect(sundal?.name).toBe('Multi Grain Sundal');
    expect(sundal?.diet).toBe('veg');
  });

  it('leaves the real ambiguous dish "Salna" unknown in a meat-serving mess', () => {
    const lunch = mealFrom(womensSpecial, '2026-09-06', true, 'lunch');
    const salna = lunch.dishes.find((d) => d.id === 'salna');
    expect(salna).toBeDefined();
    expect(salna?.diet).toBe('unknown');
  });

  /**
   * SLOW (~36s) AND DELIBERATELY LEFT THAT WAY.
   *
   * This menu yields 9 plate candidates where every previous fixture yielded 6,
   * which enumerates 7,374 serving combinations instead of 574. Measured on
   * 2026-09-07: 574 combos = 131ms, 7,374 combos = 38,803ms. That is ~13x the
   * search space for ~296x the time, because `suggestPlates` dedupes its
   * results with an O(n^2) `findIndex` that recomputes each plate's key string
   * on every comparison.
   *
   * Spec §31 Phase 10 requires plate recommendation under 100ms, so this is a
   * real defect that Phase 10 must fix — not a property of this test. The test
   * is kept on the expensive menu on purpose: shrinking the input to make the
   * suite fast would hide the only evidence we have that the recommender does
   * not scale to a full mess menu.
   *
   * The assertion itself is the load-bearing one from §14.5: a vegetarian must
   * never be served a non-veg dish, checked against a menu that really does
   * contain "Non Veg : Chicken gravy".
   */
  it('never puts a non-veg dish on a vegetarian plate from a real labelled menu', () => {
    const lunch = mealFrom(womensSpecial, '2026-09-01', true, 'lunch');
    expect(lunch.dishes.some((d) => d.diet === 'nonveg')).toBe(true);

    const plates = suggestPlates({
      meal: lunch,
      remainingKcal: 700,
      remainingProtein: 45,
      diet: 'vegetarian',
      goal: 'muscle-gain',
    });
    expect(plates.length).toBeGreaterThan(0);
    for (const plate of plates) {
      for (const item of plate.items) {
        expect(lunch.dishes.find((d) => d.id === item.dishId)?.diet).toBe('veg');
      }
    }
  });
});

describe("women's vegetarian mess (hostel-2-mess-2)", () => {
  it('was fresh at capture and detects the 14-day cycle', () => {
    expect(resolveMenuDate(womensVeg, '2026-09-07').kind).toBe('exact');
    expect(detectCycleLength(womensVeg)).toBe(14);
  });

  it('publishes no meat or egg on any day of the captured slice', () => {
    const offending: string[] = [];
    for (const day of womensVeg.menu) {
      for (const meal of buildDay(womensVeg, day.date, false).meals) {
        for (const dish of meal.dishes) {
          if (dish.diet === 'nonveg' || dish.diet === 'egg') {
            offending.push(`${day.date} ${meal.slot} ${dish.name}=${dish.diet}`);
          }
        }
      }
    }
    expect(offending).toEqual([]);
  });

  it('never uses a "Non Veg" label, unlike the other messes', () => {
    for (const day of womensVeg.menu) {
      for (const entry of day.menu) {
        expect(entry.menu).not.toMatch(/non\s*veg\s*:/i);
      }
    }
  });

  /**
   * THE `messServesNonVeg: false` BRANCH.
   *
   * `resolveDiet` treats an unrecognised dish as `veg` in a mess that serves no
   * meat, and leaves it `unknown` in one that does. Until this fixture existed
   * that branch had no real-data coverage.
   *
   * "Salna" is the ideal witness: a genuinely ambiguous name appearing in BOTH
   * captured women's endpoints on the same date, because the vegetarian menu is
   * the special menu with the non-veg items removed. Same input string, two
   * different correct answers.
   */
  it('resolves an unrecognised dish as veg here and unknown in the meat-serving mess', () => {
    const vegLunch = mealFrom(womensVeg, '2026-09-06', false, 'lunch');
    const specialLunch = mealFrom(womensSpecial, '2026-09-06', true, 'lunch');

    const salnaHere = vegLunch.dishes.find((d) => d.id === 'salna');
    const salnaThere = specialLunch.dishes.find((d) => d.id === 'salna');

    // Same dish string, same date, both real.
    expect(salnaHere?.raw).toBe(salnaThere?.raw);
    expect(salnaHere?.diet).toBe('veg');
    expect(salnaThere?.diet).toBe('unknown');
  });

  it('applies the same branch to "Pasta", which no keyword list recognises', () => {
    const vegBreakfast = mealFrom(womensVeg, '2026-09-07', false, 'breakfast');
    const specialBreakfast = mealFrom(womensSpecial, '2026-09-07', true, 'breakfast');

    expect(vegBreakfast.dishes.find((d) => d.id === 'pasta')?.diet).toBe('veg');
    expect(specialBreakfast.dishes.find((d) => d.id === 'pasta')?.diet).toBe('unknown');
  });

  it('still builds a vegetarian plate from a mess that carries no veg labels', () => {
    // The fail-safe must stay survivable: a veg-only mess should produce a
    // plate, not an empty list.
    const lunch = mealFrom(womensVeg, '2026-09-07', false, 'lunch');
    const plates = suggestPlates({
      meal: lunch,
      remainingKcal: 700,
      remainingProtein: 40,
      diet: 'vegetarian',
      goal: 'muscle-gain',
    });
    expect(plates.length).toBeGreaterThan(0);
    expect(plates[0]?.items.length).toBeGreaterThan(0);
  });
});

describe('defects observed in the women-hostel endpoints', () => {
  it('drops the empty segment from "Mix Dhal,," without losing a dish', () => {
    const dinner = mealFrom(womensVeg, '2026-09-02', false, 'dinner');
    expect(dinner.rawMenu).toContain('Mix Dhal,,');
    expect(dinner.dishes.some((d) => d.id === 'mix-dhal')).toBe(true);
    expect(dinner.dishes.every((d) => d.name.length > 0)).toBe(true);
  });

  it('drops the empty segment from "Butter milk,," and keeps White Rice', () => {
    const lunch = mealFrom(womensVeg, '2026-09-07', false, 'lunch');
    expect(lunch.rawMenu).toContain('Butter milk,,');
    expect(lunch.dishes.some((d) => d.id === 'butter-milk')).toBe(true);
    expect(lunch.dishes.some((d) => d.id === 'white-rice')).toBe(true);
  });

  it('splits "Dhal,White Rice" despite the missing space after the comma', () => {
    const lunch = mealFrom(womensVeg, '2026-09-06', false, 'lunch');
    expect(lunch.rawMenu).toContain('Dhal,White Rice');
    expect(lunch.dishes.some((d) => d.id === 'dhal')).toBe(true);
    expect(lunch.dishes.some((d) => d.id === 'white-rice')).toBe(true);
  });

  it('tolerates the double space after a colon in "Sweet :  Gulab Jamun"', () => {
    const lunch = mealFrom(womensSpecial, '2026-09-01', true, 'lunch');
    expect(lunch.rawMenu).toContain('Sweet :  Gulab Jamun');
    expect(lunch.dishes.find((d) => d.label === 'Sweet')?.name).toBe('Gulab Jamun');
  });

  it('trims the trailing space inside "Veg : Chettinad Veg Biriyani "', () => {
    const lunch = mealFrom(womensSpecial, '2026-09-06', true, 'lunch');
    expect(lunch.rawMenu).toContain('Chettinad Veg Biriyani ,');
    expect(lunch.dishes.find((d) => d.id === 'chettinad-veg-biriyani')?.name).toBe(
      'Chettinad Veg Biriyani',
    );
  });

  it('produces a stable id for "Veg. Cutlet (2 Nos)" from real data', () => {
    const snacks = mealFrom(womensVeg, '2026-09-01', false, 'snacks');
    expect(snacks.rawMenu).toBe('Veg. Cutlet (2 Nos)');
    expect(snacks.dishes[0]?.id).toBe('veg-cutlet');
  });
});
