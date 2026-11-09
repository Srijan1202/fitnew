import { describe, expect, it } from 'vitest';

import { planWeek, type WeekPlanInput } from '../src/mess/week-plan.js';
import type { MessDay, MessDish, MealSlot } from '../src/mess/types.js';

const nut = (kcal: number, protein: number) => ({
  servingLabel: '1 serving',
  servingGrams: 150,
  macros: { kcalLow: kcal - 10, kcalHigh: kcal + 10, proteinLow: protein - 1, proteinHigh: protein + 1, carbLow: 20, carbHigh: 24, fatLow: 6, fatHigh: 8 },
  confidence: 'medium' as const,
  source: 'estimated-table' as const,
});
const dish = (id: string, name: string, kcal: number, protein: number, over: Partial<MessDish> = {}): MessDish => ({
  id, name, raw: name, label: null, diet: 'veg', role: 'protein', alternatives: [], alternativeDiets: [], isAmbient: false, nutrition: nut(kcal, protein), ...over,
});
const meal = (slot: MealSlot, dishes: MessDish[]) => ({ slot, dishes, rawMenu: '' });
const day = (date: string, kind: 'exact' | 'cycle-inferred' | 'unavailable' = 'exact', slots: MealSlot[] = ['lunch', 'dinner']): MessDay => ({
  date,
  meals: slots.map((s) =>
    meal(s, [
      dish('phulka', 'Phulka', 80, 3, { role: 'staple' }),
      dish('rice', 'White Rice', 200, 4, { role: 'staple' }),
      dish('paneer-a', 'Paneer Butter Masala', 250, 12),
      dish('paneer-b', 'Kadai Paneer', 250, 12),
      dish('dal', 'Dal Tadka', 150, 8, { role: 'legume' }),
    ]),
  ),
  resolution:
    kind === 'exact'
      ? { kind, date }
      : kind === 'cycle-inferred'
        ? { kind, date, sourceDate: '2026-10-01', cycleLengthDays: 28 }
        : { kind, date, latestAvailable: null },
});
const input = (days: MessDay[], over: Partial<WeekPlanInput> = {}): WeekPlanInput => ({
  days,
  diet: 'vegetarian',
  allergies: [],
  excludedDishIds: [],
  goal: 'muscle-gain',
  targets: { kcal: 2400, proteinG: 140, carbG: 300, fatG: 70 },
  history: {},
  ...over,
});
const paneerOf = (d: ReturnType<typeof planWeek>[number], slot: MealSlot) =>
  d.meals.find((m) => m.slot === slot)!.plate!.items.map((i) => i.dishId).filter((id) => id.startsWith('paneer'));

describe('planWeek (beta 6.1)', () => {
  it('a plate for every served meal, in meal order; the totals are the plates added up; the basis is kept', () => {
    const plan = planWeek(input([day('2026-11-10'), day('2026-11-11', 'cycle-inferred')]));
    expect(plan.map((d) => d.basis)).toEqual(['published', 'inferred']);
    const [first] = plan;
    expect(first!.meals.map((m) => [m.slot, m.status])).toEqual([['lunch', 'ok'], ['dinner', 'ok']]);
    const sum = first!.meals.reduce((a, m) => a + m.plate!.macros.kcalLow, 0);
    expect(first!.totals.kcalLow).toBeCloseTo(sum, 5);
  });

  it('variety: a paneer planned yesterday gives way to the other today; history counts for the first days', () => {
    const small = { targets: { kcal: 1500, proteinG: 70, carbG: 180, fatG: 50 }, goal: 'general' as const };
    const plan = planWeek(input([day('2026-11-10', 'exact', ['lunch']), day('2026-11-11', 'exact', ['lunch'])], small));
    const d1 = paneerOf(plan[0]!, 'lunch');
    const d2 = paneerOf(plan[1]!, 'lunch');
    expect(d1).toHaveLength(1);
    expect(d2).not.toEqual(d1);
    // Eaten in the days before: the other paneer leads from the first day.
    const before = planWeek(input([day('2026-11-10', 'exact', ['lunch'])], { ...small, history: { [d1[0]!]: 2 } }));
    expect(paneerOf(before[0]!, 'lunch')).not.toEqual(d1);
    // A long week: day 4's choice no longer sees day 0's history.
    const long = planWeek(input(['10', '11', '12', '13', '14'].map((n) => day(`2026-11-${n}`, 'exact', ['lunch'])), { ...small, history: { x: 1 } }));
    expect(long).toHaveLength(5);
  });

  it('no menu: no meals; no targets: the recommender says so and nothing is planned; a meal with no dishes is not served', () => {
    const [none] = planWeek(input([day('2026-11-10', 'unavailable')]));
    expect(none).toMatchObject({ basis: null, meals: [] });
    const [noTargets] = planWeek(input([day('2026-11-10')], { targets: null }));
    expect(noTargets!.meals.every((m) => m.status === 'no-targets' && m.plate === null)).toBe(true);
    expect(noTargets!.totals.kcalHigh).toBe(0);
    const empty: MessDay = { ...day('2026-11-10'), meals: [meal('breakfast', []), ...day('2026-11-10').meals] };
    expect(planWeek(input([empty]))[0]!.meals.map((m) => m.slot)).toEqual(['lunch', 'dinner']);
  });
});
