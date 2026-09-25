import { describe, expect, it } from 'vitest';

import { addDays } from '../src/nutrition/log.js';
import { adjustTargets } from '../src/nutrition/targets.js';
import { computeTrend, recommendCalorieAdjustment, type WeightEntry } from '../src/nutrition/trend.js';
import {
  adherence,
  bestLifts,
  consistency,
  measurementProgress,
  targetOn,
  weightProgress,
  windowStart,
} from '../src/progress/summary.js';
import { ENGINE_VERSION, PRIORITIES, buildActions, wordReason } from '../src/recommend/engine.js';
import { COMPLETION_EVIDENCE, checkTransition } from '../src/recommend/events.js';
import { calorieAdjustmentFrom } from '../src/recommend/model.js';
import { estimate1RM } from '../src/training/progression.js';
import { model } from './today-fixtures.js';

const TODAY = '2026-09-24';
const series = (days: number, kg: (i: number) => number, end = TODAY): WeightEntry[] =>
  Array.from({ length: days }, (_, i) => ({ date: addDays(end, -(days - 1 - i)), kg: kg(i) }));

describe('Phase 12 — weight trend (EWMA, §13.2, §17)', () => {
  it('EWMA α = 0.1 against a hand-computed series', () => {
    const t = computeTrend([
      { date: '2026-09-01', kg: 80 },
      { date: '2026-09-02', kg: 81 },
      { date: '2026-09-03', kg: 79 },
    ]);
    // 80 → 80 + 0.1·(81 − 80) = 80.1 → 80.1 + 0.1·(79 − 80.1) = 79.99
    expect(t.map((p) => p.trendKg)).toEqual([80, 80.1, 79.99]);
    expect(t.map((p) => p.rawKg)).toEqual([80, 81, 79]);
  });

  it('30 days of noisy weights: the trend moves far less than the raw readings', () => {
    const noise = [0.9, -1.1, 0.4, -0.6, 1.2, -0.8, 0.3, -1.0, 0.7, -0.2];
    const w = weightProgress(series(30, (i) => 75 + noise[i % noise.length]!), TODAY, '30d');
    const steps = (xs: number[]) => xs.slice(1).map((x, i) => Math.abs(x - xs[i]!));
    const rawStep = Math.max(...steps(w.points.map((p) => p.rawKg)));
    const trendStep = Math.max(...steps(w.points.map((p) => p.trendKg)));
    expect(w.points).toHaveLength(30);
    // Raw readings jump up to 2 kg day to day; the trend never moves a quarter of a kilo.
    expect(rawStep).toBeCloseTo(2.0, 5);
    expect(trendStep).toBeLessThan(0.25);
    expect(w.isReliable).toBe(true);
  });

  it('no weekly rate before the 10-day gate: 9 days → null, 10 days → a number', () => {
    const nine = weightProgress(series(9, (i) => 80 - i * 0.1), TODAY, '30d');
    expect(nine.daysOfData).toBe(9);
    expect(nine.isReliable).toBe(false);
    expect(nine.weeklyChangeKg).toBeNull();
    const ten = weightProgress(series(10, (i) => 80 - i * 0.1), TODAY, '30d');
    expect(ten.isReliable).toBe(true);
    expect(ten.weeklyChangeKg).not.toBeNull();
    expect(ten.weeklyChangeKg!).toBeLessThan(0);
  });

  it('sparse history: the gate is the existing calendar span (D12 — the core is unchanged)', () => {
    const sparse = weightProgress([{ date: '2026-09-01', kg: 80 }, { date: '2026-09-20', kg: 79 }], TODAY, '30d');
    expect(sparse.daysOfData).toBe(20);
    expect(sparse.isReliable).toBe(true);
    expect(sparse.points).toHaveLength(2);
  });

  it('the window change needs ≥ 7 days between its readings; never a day-over-day figure', () => {
    const six = weightProgress(series(7, () => 80), TODAY, '30d'); // readings 6 days apart
    expect(six.windowChangeKg).toBeNull();
    expect(six.windowChangeDays).toBeNull();
    const seven = weightProgress(series(8, (i) => 80 - i * 0.2), TODAY, '30d');
    expect(seven.windowChangeDays).toBe(7);
    expect(seven.windowChangeKg).toBeLessThan(0);
    const one = weightProgress(series(2, (i) => 80 + i), TODAY, '30d');
    expect(one.windowChangeKg).toBeNull();
  });

  it('the trend is smoothed over the whole history, then cut to the window; future readings are ignored', () => {
    const history = [...series(60, () => 90, addDays(TODAY, -30)), ...series(30, () => 80)];
    const w = weightProgress([...history, { date: addDays(TODAY, 1), kg: 10 }], TODAY, '30d');
    expect(w.points[0]!.date).toBe(windowStart(TODAY, '30d'));
    // Carrying the earlier 90 kg level: the first in-window trend is far above 80.
    expect(w.points[0]!.trendKg).toBeGreaterThan(85);
    expect(w.points.some((p) => p.rawKg === 10)).toBe(false);
    expect(weightProgress([], TODAY, '30d')).toMatchObject({ points: [], currentTrendKg: null, weeklyChangeKg: null, windowChangeKg: null });
  });
});

describe('Phase 12 — measurements', () => {
  it('latest per site; a change only across ≥ 7 days inside the window', () => {
    const m = measurementProgress(
      [
        { date: addDays(TODAY, -40), site: 'waist', valueCm: 90 },
        { date: addDays(TODAY, -20), site: 'waist', valueCm: 86 },
        { date: TODAY, site: 'waist', valueCm: 84.5 },
        { date: addDays(TODAY, -3), site: 'arm', valueCm: 35 },
        { date: TODAY, site: 'arm', valueCm: 35.5 },
      ],
      TODAY,
      '30d',
    );
    const waist = m.find((x) => x.site === 'waist')!;
    expect(waist.latest).toEqual({ date: TODAY, valueCm: 84.5 });
    expect(waist.changeCm).toBe(-1.5); // from the earliest IN the window (86), not the older 90
    expect(waist.changeDays).toBe(20);
    const arm = m.find((x) => x.site === 'arm')!;
    expect(arm.changeCm).toBeNull(); // 3 days: too short
    expect(m.map((x) => x.site)).toEqual(['waist', 'arm']);
  });
});

describe('Phase 12 — adherence (owner D6)', () => {
  const targets = [
    { effectiveFrom: '2026-01-01', kcal: 2000, proteinG: 100 },
    { effectiveFrom: addDays(TODAY, -2), kcal: 2500, proteinG: 150 },
  ];

  it('only logged days count; protein met at the HIGH end; calories on target when the range overlaps ± 10 %', () => {
    const a = adherence(
      [
        { date: addDays(TODAY, -5), itemCount: 3, kcalLow: 1700, kcalHigh: 1850, proteinHigh: 100 }, // protein met (=), kcal overlaps 1800–2200
        { date: addDays(TODAY, -4), itemCount: 2, kcalLow: 1500, kcalHigh: 1790, proteinHigh: 99 }, // neither (1790 < 1800)
        { date: addDays(TODAY, -3), itemCount: 0, kcalLow: 0, kcalHigh: 0, proteinHigh: 0 }, // not a logged day
        // The target changes: judged against 2500 kcal / 150 g.
        { date: addDays(TODAY, -1), itemCount: 4, kcalLow: 2700, kcalHigh: 2900, proteinHigh: 120 }, // kcal overlaps 2250–2750, protein not
        { date: TODAY, itemCount: 4, kcalLow: 2760, kcalHigh: 2900, proteinHigh: 160 }, // protein met, kcal above band
      ],
      targets,
      TODAY,
      '30d',
    );
    expect(a.loggedDays).toBe(4);
    expect(a.protein).toEqual({ met: 2, of: 4, percent: 50 });
    expect(a.calories).toEqual({ met: 2, of: 4, percent: 50 });
    expect(a.daysWithoutTarget).toBe(0);
  });

  it('no logged days → 0 of 0 and a null %; days before any target are not judged', () => {
    expect(adherence([], targets, TODAY, '30d')).toEqual({
      protein: { met: 0, of: 0, percent: null },
      calories: { met: 0, of: 0, percent: null },
      loggedDays: 0,
      daysWithoutTarget: 0,
    });
    const early = adherence([{ date: TODAY, itemCount: 1, kcalLow: 1, kcalHigh: 2, proteinHigh: 1 }], [], TODAY, '30d');
    expect(early.loggedDays).toBe(1);
    expect(early.daysWithoutTarget).toBe(1);
    expect(early.protein.of).toBe(0);
  });

  it('outside the window does not count; the target in effect is the latest effective_from ≤ the day', () => {
    const a = adherence([{ date: addDays(TODAY, -30), itemCount: 1, kcalLow: 2000, kcalHigh: 2000, proteinHigh: 200 }], targets, TODAY, '30d');
    expect(a.loggedDays).toBe(0);
    expect(targetOn(targets, addDays(TODAY, -3))!.kcal).toBe(2000);
    expect(targetOn(targets, addDays(TODAY, -2))!.kcal).toBe(2500);
    expect(targetOn(targets, '2025-12-31')).toBeNull();
  });
});

describe('Phase 12 — training consistency (owner D7)', () => {
  it('completed per ISO week vs the programme days inside the window, partial weeks planned only for their own days', () => {
    // 2026-09-24 is a Thursday. A 30-day window starts Wed 2026-08-26.
    const c = consistency(['2026-08-24', '2026-08-26', '2026-09-01', '2026-09-03', '2026-09-22', '2026-09-24'], [1, 3, 5], TODAY, '30d');
    expect(windowStart(TODAY, '30d')).toBe('2026-08-26');
    // First week (W35): Wed 26 and Fri 28 are planned (Mon 24 is outside); only the 26th counts as done.
    expect(c.weeks[0]).toEqual({ isoWeek: '2026-W35', completed: 1, planned: 2 });
    // Current week (W39): Mon 21 and Wed 23 planned so far; Fri 25 is not planned yet.
    expect(c.weeks[c.weeks.length - 1]).toEqual({ isoWeek: '2026-W39', completed: 2, planned: 2 });
    expect(c.weeks).toHaveLength(5);
    expect(c.completed).toBe(5);
    expect(c.planned).toBe(2 + 3 + 3 + 3 + 2);
    expect(c.percent).toBe(Math.round((5 / 13) * 100));
  });

  it('no programme → planned and % are null; the sessions still count', () => {
    const c = consistency(['2026-09-24'], null, TODAY, '30d');
    expect(c.planned).toBeNull();
    expect(c.percent).toBeNull();
    expect(c.completed).toBe(1);
  });

  it('90-day window spans the right ISO weeks, including a year boundary', () => {
    const c = consistency([], [1], '2027-01-05', '90d');
    expect(c.weeks[0]!.isoWeek).toBe('2026-W41');
    expect(c.weeks[c.weeks.length - 1]!.isoWeek).toBe('2027-W01');
  });
});

describe('Phase 12 — strength', () => {
  it('Epley per lift, best per lift, ties keep the earliest; bodyweight sets skipped', () => {
    const b = bestLifts([
      { exerciseId: 'b', exerciseName: 'Bench', date: '2026-09-10', weightKg: 80, reps: 5 },
      { exerciseId: 'b', exerciseName: 'Bench', date: '2026-09-17', weightKg: 85, reps: 3 },
      { exerciseId: 's', exerciseName: 'Squat', date: '2026-09-11', weightKg: 100, reps: 1 },
      { exerciseId: 's', exerciseName: 'Squat', date: '2026-09-18', weightKg: 100, reps: 1 },
      { exerciseId: 'p', exerciseName: 'Pull-up', date: '2026-09-18', weightKg: 0, reps: 10 },
    ]);
    expect(estimate1RM(80, 5)).toBe(93.3);
    expect(estimate1RM(85, 3)).toBe(93.5);
    expect(b).toEqual([
      { exerciseId: 'b', exerciseName: 'Bench', estimated1RmKg: 93.5, weightKg: 85, reps: 3, date: '2026-09-17' },
      { exerciseId: 's', exerciseName: 'Squat', estimated1RmKg: 100, weightKg: 100, reps: 1, date: '2026-09-11' },
    ]);
  });
});

describe('Phase 12 — calorie-adjust (TODAY band 55, today-2)', () => {
  const gaining = series(21, (i) => 70 + i * 0.1); // ~+0.7 kg/week trend

  it('the fact reuses summariseTrend + recommendCalorieAdjustment exactly', () => {
    const fact = calorieAdjustmentFrom({ goal: 'fat-loss', weights: gaining, targetKcal: 2200, daysSinceLastAdjustment: null });
    expect(fact).not.toBeNull();
    expect(Math.abs(fact!.deltaKcal)).toBeLessThanOrEqual(150);
    expect(fact!.deltaKcal % 10 === 0).toBe(true);
    expect(fact!.deltaKcal).toBeLessThan(0); // gaining on fat loss → down
    expect(fact!.newKcal).toBe(2200 + fact!.deltaKcal);
    const direct = recommendCalorieAdjustment({ goal: 'fat-loss', weeklyChangeKg: fact!.weeklyChangeKg, daysSinceLastAdjustment: 1e9, bodyweightKg: 70 + 20 * 0.1 });
    expect(direct.shouldAdjust).toBe(true);
  });

  it('never before the reliability gate, without targets, or within 7 days of the last adjustment', () => {
    expect(calorieAdjustmentFrom({ goal: 'fat-loss', weights: gaining.slice(-9), targetKcal: 2200, daysSinceLastAdjustment: null })).toBeNull();
    expect(calorieAdjustmentFrom({ goal: 'fat-loss', weights: gaining, targetKcal: null, daysSinceLastAdjustment: null })).toBeNull();
    expect(calorieAdjustmentFrom({ goal: 'fat-loss', weights: gaining, targetKcal: 2200, daysSinceLastAdjustment: 6 })).toBeNull();
    expect(calorieAdjustmentFrom({ goal: 'fat-loss', weights: gaining, targetKcal: 2200, daysSinceLastAdjustment: 7 })).not.toBeNull();
    // On pace: nothing to adjust.
    const steady = series(21, () => 70);
    expect(calorieAdjustmentFrom({ goal: 'maintenance', weights: steady, targetKcal: 2200, daysSinceLastAdjustment: null })).toBeNull();
  });

  it('the engine ranks it at 55 (between rest-day and celebrate-pr), advisory and completable; version today-2', () => {
    expect(ENGINE_VERSION).toBe('today-2');
    expect(PRIORITIES['calorie-adjust']).toBe(55);
    const adj = { currentKcal: 2200, newKcal: 2070, deltaKcal: -130, weeklyChangeKg: 0.7 };
    const all = buildActions(model({ nutrition: { adjustment: adj } as never }));
    const a = all.find((x) => x.kind === 'calorie-adjust');
    expect(a).toBeDefined();
    expect(a).toMatchObject({ priority: 55, basis: 'calculated', target: 'eat', subjectKey: '', reason: { code: 'calorie-target-off-trend', values: adj } });
    expect(a!.headline).toBe('Move your target to 2070 kcal');
    expect(a!.detail).toContain('down by 130 kcal (from 2200)');
    expect(a!.detail).toContain('Nothing changes unless you accept.');
    expect(buildActions(model({})).some((x) => x.kind === 'calorie-adjust')).toBe(false);
    // Between rest-day (60) and celebrate-pr (50) in the ranked list.
    const i = all.findIndex((x) => x.kind === 'calorie-adjust');
    expect(all.slice(0, i).every((x) => x.priority >= 55)).toBe(true);
    expect(all.slice(i + 1).every((x) => x.priority <= 55)).toBe(true);
    expect(COMPLETION_EVIDENCE['calorie-adjust']).toBe('target-adjusted');
    expect(checkTransition('calorie-adjust', ['shown', 'accepted'], 'completed')).toEqual({ outcome: 'record' });
    expect(checkTransition('calorie-adjust', ['shown'], 'completed')).toEqual({ outcome: 'reject', code: 'not-accepted' });
  });

  it('words come only from the values', () => {
    const w = wordReason({ code: 'calorie-target-off-trend', values: { currentKcal: 1900, newKcal: 2050, deltaKcal: 150, weeklyChangeKg: -0.123 } });
    expect(w.headline).toBe('Move your target to 2050 kcal');
    expect(w.detail).toBe('Your trend weight is falling about 0.12 kg a week, off pace for your goal. Moving the target up by 150 kcal (from 1900) keeps it on track. Nothing changes unless you accept.');
  });

  it('adjustTargets: protein unchanged, the fat floor, carbs take the remainder, fibre 14 g/1000 kcal (§13.1)', () => {
    expect(adjustTargets({ proteinG: 150 }, 2070, 72)).toEqual({ kcal: 2070, proteinG: 150, fatG: 58, carbG: 237, fiberG: 29 });
    // The 0.8 g/kg floor wins for a heavier user at low kcal.
    expect(adjustTargets({ proteinG: 180 }, 1800, 110).fatG).toBe(88);
  });
});
