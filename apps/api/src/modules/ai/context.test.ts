/**
 * Beta 5.4 (owner): what FITOS AI now knows — today's food (never another
 * day), today's readiness and the week's check-ins, the weight trend and the
 * mess with today's menu — each projected small; and the chat's "trying
 * again" event while the model is busy.
 */
import type { NutritionDay, ProgressSummary, RecoveryLog, RecoveryToday } from '@fitos/contracts';
import { describe, expect, it } from 'vitest';

import { CONTEXT_FOOD_ITEMS, CONTEXT_MESS_DISHES, UserContextAssembler, messContextOf, type FitosAiContext } from './context-assembler.js';
import type { AiProvider, AiRequest, AiResponse } from './provider.js';
import { AiService, type AiStreamEvent } from './service.js';
import { ToolRegistry, type ToolServices } from './tools.js';

const totals = (kcal: [number, number], protein: [number, number]) => ({
  kcalLow: kcal[0], kcalHigh: kcal[1], proteinLow: protein[0], proteinHigh: protein[1], carbLow: 200, carbHigh: 220, fatLow: 30, fatHigh: 30,
  fibreKnownLow: 0, fibreKnownHigh: 0, fibreUnknownItems: 0,
});

function item(name: string, kcal: [number, number], protein: [number, number]) {
  return {
    id: '00000000-0000-4000-8000-000000000001', position: 0, foodId: null, messDishSlug: null, foodName: name, foodSource: 'estimated',
    basis: 'per_serving', servingLabel: '1 piece', servingGrams: null, servings: 3, grams: null,
    kcalLow: kcal[0], kcalHigh: kcal[1], proteinLow: protein[0], proteinHigh: protein[1], carbLow: 0, carbHigh: 0, fatLow: 0, fatHigh: 0,
    fibreLow: null, fibreHigh: null, confidence: 'medium',
  };
}

function day(items: ReturnType<typeof item>[], kcal: [number, number] = [1241, 1436]): NutritionDay {
  return {
    date: '2026-11-03', today: '2026-11-03', timezone: 'Asia/Kolkata',
    targets: null,
    totals: totals(kcal, [36, 45]),
    remaining: {
      kcal: { target: 2877, low: 2877 - kcal[1], high: 2877 - kcal[0], state: 'under' },
      protein: { target: 130, low: 85, high: 94, state: 'under' },
      carb: { target: 432, low: 210, high: 232, state: 'under' },
      fat: { target: 70, low: 40, high: 40, state: 'under' },
    },
    logs: [{ id: 'l', clientLogId: 'c', loggedAt: '2026-11-03T14:00:00.000Z', localDate: '2026-11-03', mealSlot: 'dinner', entryMethod: 'mess', savedMealId: null, messCode: null, items, totals: totals(kcal, [36, 45]) }],
  } as unknown as NutritionDay;
}

describe('UserContextAssembler.foodOf — today only, bounded (beta 5.4)', () => {
  it("today's totals, what is left, the meals and the dishes; a range where the log holds estimates", () => {
    const f = UserContextAssembler.foodOf(day([item('Masala Uthappam', [600, 600], [16, 16]), item('Dhal', [300, 348], [12, 14])]));
    expect(f).toEqual({
      date: '2026-11-03',
      eaten: { kcal: '1241–1436', proteinG: '36–45', carbG: '200–220', fatG: '30' },
      left: { kcal: '1441–1636', proteinG: '85–94' },
      mealsLogged: ['dinner'],
      items: [
        { meal: 'dinner', food: 'Masala Uthappam', portion: '3 × 1 piece', kcal: '600', proteinG: '16' },
        { meal: 'dinner', food: 'Dhal', portion: '3 × 1 piece', kcal: '300–348', proteinG: '12–14' },
      ],
      moreItems: 0,
      includesEstimates: true,
    });
    // Exact numbers are not estimates.
    expect(UserContextAssembler.foodOf(day([item('Egg', [78, 78], [6, 6])], [78, 78])).includesEstimates).toBe(true); // protein still a range
  });

  it(`keeps at most ${CONTEXT_FOOD_ITEMS} dishes and says how many more`, () => {
    const many = Array.from({ length: CONTEXT_FOOD_ITEMS + 4 }, (_, i) => item(`Dish ${i}`, [100, 100], [5, 5]));
    const f = UserContextAssembler.foodOf(day(many));
    expect(f.items).toHaveLength(CONTEXT_FOOD_ITEMS);
    expect(f.moreItems).toBe(4);
  });
});

describe('readiness, weight and the mess (beta 5.4)', () => {
  const log = (date: string, sleep: number): RecoveryLog =>
    ({ date, sleepHours: sleep, sleepQuality: 4, soreness: 2, energy: 4, stress: 2, source: 'manual' }) as RecoveryLog;

  it("today's readiness with its advice, and the last 7 check-ins oldest first", () => {
    const today = { date: '2026-11-03', log: log('2026-11-03', 7.5), readiness: { score: 90, band: 'ready', advice: 'Train as planned.', components: [], lowDays: 0 } } as unknown as RecoveryToday;
    const days = Array.from({ length: 9 }, (_, i) => log(`2026-10-${String(26 + i).padStart(2, '0')}`, 7));
    const r = UserContextAssembler.readinessOf(today, days);
    expect(r.checkedInToday).toBe(true);
    expect(r.today).toEqual({ score: 90, band: 'ready', advice: 'Train as planned.' });
    expect(r.lastDays).toHaveLength(7);
    expect(r.lastDays[0]).toEqual({ date: '2026-10-28', sleepHours: 7, sleepQuality: 4, soreness: 2, energy: 4, stress: 2 });
    // No check-in today: nothing invented.
    const none = UserContextAssembler.readinessOf({ date: '2026-11-03', log: null, readiness: null } as RecoveryToday, []);
    expect(none).toEqual({ checkedInToday: false, today: null, lastDays: [] });
  });

  it('the weight trend, never the readings', () => {
    const p = { weight: { points: [{ date: '2026-11-02', kg: 72 }], currentTrendKg: 72, weeklyChangeKg: null, daysOfData: 1, isReliable: false, windowChangeKg: null, windowChangeDays: null } } as unknown as ProgressSummary;
    const w = UserContextAssembler.weightOf(p);
    expect(w).toEqual({ trendKg: 72, weeklyChangeKg: null, change30DaysKg: null, daysOfData: 1, reliable: false });
    expect(JSON.stringify(w)).not.toContain('points');
  });

  it("the mess and today's menu: published, inferred or none; dish names only, bounded", () => {
    const row = { hostelLabel: "Men's Hostel", messLabel: 'Non-Vegetarian' };
    const meals = [{ slot: 'dinner', dishes: Array.from({ length: CONTEXT_MESS_DISHES + 3 }, (_, i) => ({ name: `Dish ${i}`, id: `d${i}` })) }];
    const inferred = messContextOf(row, '2026-11-03', { resolution: { kind: 'cycle-inferred' }, meals });
    expect(inferred).toMatchObject({ hostel: "Men's Hostel", mess: 'Non-Vegetarian', menuDate: '2026-11-03', menu: 'inferred' });
    expect(inferred.meals[0]!.dishes).toHaveLength(CONTEXT_MESS_DISHES);
    expect(messContextOf(row, '2026-11-03', { resolution: { kind: 'exact' }, meals }).menu).toBe('published');
    expect(messContextOf(row, '2026-11-03', { resolution: { kind: 'unavailable' }, meals })).toMatchObject({ menu: 'none', meals: [] });
  });
});

describe('the chat while the model is busy (beta 5.4)', () => {
  it('streams a retry event when the provider asks again, then the answer', async () => {
    const provider: AiProvider = {
      name: 'fake',
      model: 'fake-1',
      generate: async () => {
        throw new Error('not used');
      },
      generateStream: async (req: AiRequest, onText): Promise<AiResponse> => {
        req.onRetry?.();
        onText('Train as planned today: readiness 90.');
        return { text: 'Train as planned today: readiness 90.', toolCalls: [], finishReason: 'stop', model: 'fake-lite' };
      },
    };
    const context = { generatedAt: '2026-11-03T08:00:00.000Z', profile: { displayName: null, timezone: 'Asia/Kolkata' }, today: null } as unknown as FitosAiContext;
    const assembler = { assemble: async () => context } as unknown as UserContextAssembler;
    const service = new AiService(provider, { assembler, tools: new ToolRegistry({} as ToolServices) });
    const events: AiStreamEvent[] = [];
    const out = await service.chat('u1', { message: 'How hard should I train today?', history: [] }, false, (e) => events.push(e));
    expect(events[0]).toEqual({ type: 'retry' });
    expect(events.some((e) => e.type === 'text')).toBe(true);
    expect(out.text).toContain('readiness 90');
  });
});
