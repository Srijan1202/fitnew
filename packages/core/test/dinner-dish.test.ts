import { describe, expect, it } from 'vitest';

import type { MessDish, MessMeal } from '../src/mess/types.js';
import { BANNED, TEMPLATES, render } from '../src/notify/copy.js';
import { DISH_PROTEIN_MIN_G, proteinDishOf } from '../src/notify/dinner-dish.js';
import { chooseVariant, planNotifications, type PlanFacts } from '../src/notify/planner.js';
import { instantAt } from '../src/notify/time.js';
import { DEFAULT_NOTIFY_SETTINGS, NOTIFY_KINDS } from '../src/notify/types.js';

const nut = (protein: number) => ({
  macros: { kcalLow: 250, kcalHigh: 300, proteinLow: protein - 2, proteinHigh: protein + 2, carbLow: 10, carbHigh: 12, fatLow: 8, fatHigh: 10 },
  servingLabel: '1 katori',
  servingGrams: 150,
  confidence: 'medium' as const,
  source: 'estimated-table' as const,
});
const dish = (id: string, name: string, protein: number | null, over: Partial<MessDish> = {}): MessDish => ({
  id, name, raw: name, label: null, diet: 'veg', role: 'protein', alternatives: [], alternativeDiets: [], isAmbient: false,
  nutrition: protein === null ? null : nut(protein), ...over,
});
const dinner = (...dishes: MessDish[]): MessMeal => ({ slot: 'dinner', dishes, rawMenu: '' });
const veg = { diet: 'vegetarian' as const, allergies: [], excludedDishIds: [] };

describe('proteinDishOf (E17)', () => {
  it('names the dish with the most protein a serving that passes the filters', () => {
    const menu = dinner(dish('paneer-butter-masala', 'Paneer Butter Masala', 16), dish('dal-tadka', 'Dal Tadka', 11), dish('chicken-curry', 'Chicken Curry', 24, { diet: 'nonveg' }));
    expect(proteinDishOf(menu, veg)).toEqual({ name: 'Paneer Butter Masala', proteinG: 16 });
    expect(proteinDishOf(menu, { ...veg, diet: 'non-vegetarian' })).toEqual({ name: 'Chicken Curry', proteinG: 24 });
    // A dish they dislike is never named; a dairy allergy rules out paneer.
    expect(proteinDishOf(menu, { ...veg, excludedDishIds: ['paneer-butter-masala'] })).toEqual({ name: 'Dal Tadka', proteinG: 11 });
    expect(proteinDishOf(menu, { ...veg, allergies: ['milk' as const] })?.name).not.toBe('Paneer Butter Masala');
  });

  it('nothing under the minimum, nothing without an estimate or a menu; ties go to the name', () => {
    expect(proteinDishOf(dinner(dish('rice', 'Jeera Rice', DISH_PROTEIN_MIN_G - 4)), veg)).toBeNull();
    expect(proteinDishOf(dinner(dish('mystery', 'Mystery Curry', null)), veg)).toBeNull();
    expect(proteinDishOf(undefined, veg)).toBeNull();
    const tie = dinner(dish('b', 'Rajma', 14), dish('a', 'Chole', 14), dish('c', 'Soya Curry', 14));
    expect(proteinDishOf(tie, veg)!.name).toBe('Chole');
  });
});

describe('the protein nudge names the dish (E17)', () => {
  const TZ = 'Asia/Kolkata';
  const facts = (over: Partial<PlanFacts> = {}): PlanFacts => ({
    now: instantAt('2026-10-19', 9 * 60, TZ),
    timeZone: TZ,
    seed: 'user-1',
    name: 'Srijan Srivastava',
    settings: { ...DEFAULT_NOTIFY_SETTINGS, kinds: Object.fromEntries(NOTIFY_KINDS.map((k) => [k, k === 'protein-gap'])) as typeof DEFAULT_NOTIFY_SETTINGS.kinds },
    programme: null,
    sessionStarts: [],
    completedDates: [],
    foodLogs: [],
    weighIns: [],
    checkIns: [],
    proteinMetDates: [],
    proteinTargetG: 120,
    todayProteinHigh: 30,
    readinessBand: null,
    skippedDates: [],
    history: [],
    ...over,
  });

  it('on a day with a dish, its words name it; on a day without, the ordinary words', () => {
    const plan = planNotifications(facts({ dinnerDishes: { '2026-10-19': { name: 'Paneer Butter Masala', proteinG: 16 } } }));
    const today = plan.find((p) => p.localDate === '2026-10-19' && p.kind === 'protein-gap')!;
    expect(today.variant.startsWith('pg-d-')).toBe(true);
    expect(`${today.title} ${today.body}`).toContain('Paneer Butter Masala');
    expect(today.body).toContain('16 g');
    expect(today.why).toContain("Paneer Butter Masala has the most protein a serving on the mess's published dinner menu");
    const tomorrow = plan.find((p) => p.localDate === '2026-10-20' && p.kind === 'protein-gap')!;
    expect(tomorrow.variant.startsWith('pg-d-')).toBe(false);
  });

  it('every dish line keeps the guardrails, fills both slots, and is chosen only with a dish', () => {
    const named = TEMPLATES.filter((t) => t.needs?.includes('dish') === true);
    expect(named.map((t) => t.tone).sort()).toEqual(['cheeky', 'cheeky', 'cheeky', 'gentle', 'gentle']);
    for (const t of named) {
      const r = render(t, { name: 'Srijan', dish: 'Egg Curry', dishProtein: 14 });
      expect(`${r.title} ${r.body}`).not.toMatch(BANNED);
      expect(`${r.title} ${r.body}`).not.toMatch(/\{/);
    }
    expect(chooseVariant('protein-gap', 'gentle', { name: null, target: 120 }, undefined, [], '2026-10-19', 'u')!.id.startsWith('pg-d-')).toBe(false);
    expect(chooseVariant('protein-gap', 'gentle', { name: null, target: 120, dish: 'Egg Curry', dishProtein: 14 }, undefined, [], '2026-10-19', 'u')!.id.startsWith('pg-d-')).toBe(true);
  });
});
