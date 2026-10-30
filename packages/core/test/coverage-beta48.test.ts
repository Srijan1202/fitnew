/**
 * Beta 4.8: vitest 5's coverage counts both arms of every `if` (an implicit
 * else included) and every function, where vitest 2 did not. These cases
 * cover what that newly counted — each a real input the functions take.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';

import { numbersIn, numbersInPayload } from '../src/ai/guard.js';
import { formatEstimate } from '../src/mess/nutrition.js';
import { defaultFetcher, detectCycleLength } from '../src/mess/providers/vit/provider.js';
import { scorePlate, scoreTerms, type PlateRequest } from '../src/mess/recommend.js';
import { resolveDayFromSnapshots } from '../src/mess/snapshots.js';
import type { MessItResponse, MessMeal } from '../src/mess/types.js';
import { measurementProgress } from '../src/progress/summary.js';
import { wordReason } from '../src/recommend/engine.js';
import { daysSinceTrained, type VolumeSet } from '../src/training/volume.js';

describe('coverage under vitest 5 (beta 4.8)', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('the AI guard skips a division by zero, a number too long to be finite, and values that are not text or numbers', () => {
    expect([...numbersIn('5/0')]).toEqual(['5', '0']);
    expect([...numbersIn('9'.repeat(400))]).toEqual([]);
    expect([...numbersInPayload({ ok: true, none: null, nothing: undefined })]).toEqual([]);
  });

  it('a mess estimate reads "~" when its range rounds to one value', () => {
    expect(formatEstimate(10.2, 10.4, ' g')).toBe('~10 g');
    expect(formatEstimate(10, 20, ' g')).toBe('10–20 g');
  });

  it('scorePlate is the score of scoreTerms', () => {
    const meal = { slot: 'lunch', dishes: [] } as unknown as MessMeal;
    const request: PlateRequest = {
      meal,
      remainingKcal: 600,
      remainingProtein: 40,
      remainingCarb: 70,
      remainingFat: 20,
      diet: 'non-vegetarian',
      goal: 'fat-loss',
    };
    const input = {
      macros: { kcalLow: 500, kcalHigh: 560, proteinLow: 30, proteinHigh: 34, carbLow: 60, carbHigh: 66, fatLow: 15, fatHigh: 18 },
      itemCount: 3,
      totalServings: 3,
      request,
    };
    expect(scorePlate(input)).toBe(scoreTerms(input).score);
  });

  it('the live MessIT fetcher returns the JSON, and says which URL failed', async () => {
    const body = { hostel: 1, mess: 2, menu: [] };
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: true, status: 200, json: async () => body })));
    expect(await defaultFetcher('https://example.test/menu')).toEqual(body);
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 503, json: async () => ({}) })));
    await expect(defaultFetcher('https://example.test/menu')).rejects.toThrow('MessIT 503 for https://example.test/menu');
  });

  it('a day without a breakfast is left out of the cycle check', () => {
    const response: MessItResponse = {
      hostel: 1,
      mess: 1,
      menu: [{ date: '2026-10-01', menu: [{ type: 2, menu: 'Rice' }] }],
    };
    expect(detectCycleLength(response)).toBeNull();
  });

  it('several snapshots with no cycle between them: the day is unavailable', () => {
    const snap = (id: string, date: string, menu: string) => ({
      id,
      payload: { hostel: 1, mess: 1, menu: [{ date, menu: [{ type: 1, menu }] }] } satisfies MessItResponse,
    });
    const r = resolveDayFromSnapshots([snap('b', '2026-10-02', 'Idli'), snap('a', '2026-10-01', 'Dosa')], '2026-10-20', true);
    expect(r.snapshotId).toBeNull();
    expect(r.day.resolution.kind).toBe('unavailable');
  });

  it('one reading of a site has no change to show', () => {
    const [waist] = measurementProgress([{ date: '2026-10-20', site: 'waist', valueCm: 80 }], '2026-10-30', '30d');
    expect(waist).toMatchObject({ changeCm: null, changeDays: null });
  });

  it('a rest day with a programme but no next session yet; records in reps and in volume', () => {
    const rest = wordReason({
      code: 'rest-day',
      values: { hasProgramme: true, nextSessionName: null, nextSessionDate: null, kcalTarget: null, proteinTarget: null, readiness: null },
    } as never);
    expect(rest.detail).not.toContain('Next:');
    const pr = (prType: string) =>
      wordReason({ code: 'pr-today', values: { exerciseName: 'Squat', prType, value: 12, previous: 10, count: 1 } } as never);
    expect(pr('reps').detail).toBe('12 reps, up from 10.');
    expect(pr('volume').detail).toBe('12 kg lifted in one set, up from 10 kg.');
  });

  it('days since a muscle was trained: the newest set wins whichever order the sets come in', () => {
    const set = (localDate: string): VolumeSet => ({
      localDate,
      exerciseId: 'x',
      primaryMuscles: ['chest'],
      secondaryMuscles: [],
      setType: 'working',
      weightKg: 50,
      reps: 8,
    });
    expect(daysSinceTrained([set('2026-10-28'), set('2026-10-20')], 'chest', '2026-10-30')).toBe(2);
  });
});
