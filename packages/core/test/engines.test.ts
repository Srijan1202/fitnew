import { describe, expect, it } from 'vitest';

import { computeTargets, mifflinStJeor, proteinPerKg, remaining } from '../src/nutrition/targets.js';
import {
  computeTrend, estimateAdaptiveTdee, recommendCalorieAdjustment, summariseTrend,
} from '../src/nutrition/trend.js';
import { estimate1RM, recommendProgression } from '../src/training/progression.js';
import type { SessionLog, ExerciseTarget } from '../src/training/progression.js';
import type { WeightEntry } from '../src/nutrition/trend.js';

/* ------------------------------------------------------------------ targets */

describe('calorie and macro targets', () => {
  it('matches the published Mifflin-St Jeor result', () => {
    // 25y male, 180cm, 75kg -> 750 + 1125 - 125 + 5 = 1755
    expect(mifflinStJeor({ sex: 'male', ageYears: 25, heightCm: 180, weightKg: 75 })).toBe(1755);
    // Female uses -161 instead of +5, so exactly 166 kcal lower.
    expect(mifflinStJeor({ sex: 'female', ageYears: 25, heightCm: 180, weightKg: 75 })).toBe(1589);
  });

  it('puts a muscle-gain target above maintenance and fat-loss below', () => {
    const base = {
      sex: 'male' as const, ageYears: 21, heightCm: 175, weightKg: 59,
      activity: 'light' as const, trainingDaysPerWeek: 4,
    };
    const gain = computeTargets({ ...base, goal: 'muscle-gain' });
    const loss = computeTargets({ ...base, goal: 'fat-loss' });
    expect(gain.kcal).toBeGreaterThan(gain.tdee);
    expect(loss.kcal).toBeLessThan(loss.tdee);
  });

  it('raises protein in a deficit to protect lean mass', () => {
    expect(proteinPerKg('fat-loss')).toBeGreaterThan(proteinPerKg('muscle-gain'));
    expect(proteinPerKg('muscle-gain')).toBeGreaterThanOrEqual(1.6);
    // Morton et al. 2018 puts the plateau at ~1.62 g/kg and a prudent ceiling at
    // ~2.2 g/kg. Nothing we prescribe should exceed that ceiling.
    expect(proteinPerKg('fat-loss')).toBeLessThanOrEqual(2.2);
  });

  it('keeps macros consistent with the calorie target', () => {
    const t = computeTargets({
      sex: 'male', ageYears: 21, heightCm: 175, weightKg: 59,
      activity: 'light', trainingDaysPerWeek: 4, goal: 'muscle-gain',
    });
    const fromMacros = t.proteinG * 4 + t.carbG * 4 + t.fatG * 9;
    expect(Math.abs(fromMacros - t.kcal)).toBeLessThanOrEqual(6); // rounding only
  });

  it('always explains where the numbers came from', () => {
    const t = computeTargets({
      sex: 'female', ageYears: 20, heightCm: 162, weightKg: 54,
      activity: 'moderate', trainingDaysPerWeek: 3, goal: 'fat-loss',
    });
    expect(t.rationale.length).toBeGreaterThanOrEqual(4);
    expect(t.rationale.join(' ')).toContain('Mifflin-St Jeor');
  });

  it('never reports negative remaining macros', () => {
    const targets = computeTargets({
      sex: 'male', ageYears: 21, heightCm: 175, weightKg: 59,
      activity: 'light', trainingDaysPerWeek: 4, goal: 'muscle-gain',
    });
    const r = remaining({ kcalConsumed: 99_999, proteinConsumed: 500, targets });
    expect(r.kcal).toBe(0);
    expect(r.protein).toBe(0);
  });
});

/* -------------------------------------------------------------------- trend */

function series(startKg: number, dailyDelta: number, days: number, noise: number[] = []): WeightEntry[] {
  const out: WeightEntry[] = [];
  const start = Date.parse('2026-08-01T00:00:00Z');
  for (let i = 0; i < days; i += 1) {
    const date = new Date(start + i * 86_400_000).toISOString().slice(0, 10);
    out.push({ date, kg: Number((startKg + dailyDelta * i + (noise[i] ?? 0)).toFixed(2)) });
  }
  return out;
}

describe('weight trend', () => {
  it('smooths a single-day spike instead of following it', () => {
    const entries = series(70, 0, 20);
    const spiked = entries.map((e, i) => (i === 19 ? { ...e, kg: 73 } : e));
    const points = computeTrend(spiked);
    const last = points[points.length - 1];
    expect(last?.rawKg).toBe(73);
    // Trend absorbs only ~10% of a 3 kg jump.
    expect(last?.trendKg).toBeLessThan(70.5);
  });

  it('sorts unsorted input before smoothing', () => {
    const entries = [...series(70, 0.05, 12)].reverse();
    const points = computeTrend(entries);
    const dates = points.map((p) => p.date);
    expect([...dates].sort()).toEqual(dates);
  });

  it('refuses to report a weekly rate without enough data', () => {
    const summary = summariseTrend(series(70, 0.02, 5));
    expect(summary.isReliable).toBe(false);
    expect(summary.weeklyChangeKg).toBeNull();
    expect(summary.currentTrendKg).not.toBeNull();
  });

  it('detects a real gaining trend through daily noise', () => {
    const noise = Array.from({ length: 40 }, (_, i) => (i % 2 === 0 ? 0.6 : -0.6));
    const summary = summariseTrend(series(59, 0.03, 40, noise));
    expect(summary.isReliable).toBe(true);
    expect(summary.weeklyChangeKg).toBeGreaterThan(0.1);
  });
});

describe('adaptive TDEE', () => {
  it('returns null when weight data is too thin to support an estimate', () => {
    const result = estimateAdaptiveTdee({
      entries: series(70, 0, 5),
      intake: Array.from({ length: 20 }, (_, i) => ({
        date: new Date(Date.parse('2026-08-01T00:00:00Z') + i * 86_400_000).toISOString().slice(0, 10),
        kcal: 2500,
      })),
    });
    expect(result).toBeNull();
  });

  it('recovers maintenance when weight is genuinely stable', () => {
    const days = 30;
    const entries = series(70, 0, days);
    const intake = entries.map((e) => ({ date: e.date, kcal: 2500 }));
    const tdee = estimateAdaptiveTdee({ entries, intake });
    expect(tdee).not.toBeNull();
    expect(Math.abs((tdee ?? 0) - 2500)).toBeLessThan(60);
  });

  it('estimates a surplus when weight is climbing', () => {
    const days = 30;
    const entries = series(70, 0.03, days); // ~0.21 kg/week
    const intake = entries.map((e) => ({ date: e.date, kcal: 3000 }));
    const tdee = estimateAdaptiveTdee({ entries, intake });
    expect(tdee).not.toBeNull();
    expect(tdee!).toBeLessThan(3000); // expenditure below intake
  });
});

describe('calorie adjustment policy', () => {
  const base = { bodyweightKg: 60, daysSinceLastAdjustment: 14 };

  it('does not adjust without a reliable trend', () => {
    const r = recommendCalorieAdjustment({ ...base, goal: 'muscle-gain', weeklyChangeKg: null });
    expect(r.shouldAdjust).toBe(false);
  });

  it('does not adjust twice within a week', () => {
    const r = recommendCalorieAdjustment({
      ...base, daysSinceLastAdjustment: 3, goal: 'fat-loss', weeklyChangeKg: 0.4,
    });
    expect(r.shouldAdjust).toBe(false);
    expect(r.reason).toContain('less than a week');
  });

  it('holds steady when the trend is on target', () => {
    // Muscle gain target is 0.0035 * 60 = 0.21 kg/week.
    const r = recommendCalorieAdjustment({ ...base, goal: 'muscle-gain', weeklyChangeKg: 0.21 });
    expect(r.shouldAdjust).toBe(false);
  });

  it('raises calories when a bulk has stalled', () => {
    const r = recommendCalorieAdjustment({ ...base, goal: 'muscle-gain', weeklyChangeKg: -0.3 });
    expect(r.shouldAdjust).toBe(true);
    expect(r.deltaKcal).toBeGreaterThan(0);
  });

  it('lowers calories when a cut has stalled', () => {
    const r = recommendCalorieAdjustment({ ...base, goal: 'fat-loss', weeklyChangeKg: 0.2 });
    expect(r.shouldAdjust).toBe(true);
    expect(r.deltaKcal).toBeLessThan(0);
  });

  it('never moves calories by more than 150 in one step', () => {
    const r = recommendCalorieAdjustment({ ...base, goal: 'fat-loss', weeklyChangeKg: 3 });
    expect(Math.abs(r.deltaKcal)).toBeLessThanOrEqual(150);
  });
});

/* -------------------------------------------------------------- progression */

const BENCH: ExerciseTarget = { repMin: 8, repMax: 10, targetRir: 2, sets: 3, incrementKg: 2.5 };

function session(date: string, weightKg: number, reps: number[], rir: number | null = 2): SessionLog {
  return { date, sets: reps.map((r) => ({ weightKg, reps: r, rir })) };
}

describe('progressive overload', () => {
  it('asks for a baseline when there is no history', () => {
    const rec = recommendProgression({ history: [], target: BENCH });
    expect(rec.action).toBe('establish-baseline');
    expect(rec.weightKg).toBeNull();
    expect(rec.reason).toContain('baseline');
  });

  it('increases load after clearing the top of the rep range', () => {
    const rec = recommendProgression({
      history: [session('2026-09-01', 60, [10, 10, 10], 1)],
      target: BENCH,
    });
    expect(rec.action).toBe('increase-load');
    expect(rec.weightKg).toBe(62.5);
    expect(rec.reason).toContain('62.5');
  });

  it('does not increase load when RIR says the sets were not close enough', () => {
    const rec = recommendProgression({
      history: [session('2026-09-01', 60, [10, 10, 10], 4)],
      target: BENCH,
    });
    expect(rec.action).toBe('add-reps');
    expect(rec.weightKg).toBe(60);
  });

  it('holds and adds reps mid-range', () => {
    const rec = recommendProgression({
      history: [session('2026-09-01', 60, [9, 8, 8], 2)],
      target: BENCH,
    });
    expect(rec.action).toBe('add-reps');
  });

  it('reduces load when the user falls below the rep floor', () => {
    const rec = recommendProgression({
      history: [session('2026-09-01', 70, [6, 5, 5], 0)],
      target: BENCH,
    });
    expect(rec.action).toBe('reduce-load');
    expect(rec.weightKg).toBe(67.5);
  });

  it('holds when reps decline across sessions without RIR drift', () => {
    const rec = recommendProgression({
      history: [
        session('2026-09-01', 60, [10, 10, 10], 2),
        session('2026-09-04', 60, [10, 9, 9], 2),
        session('2026-09-08', 60, [9, 8, 8], 2),
      ],
      target: BENCH,
    });
    expect(rec.action).toBe('hold');
    expect(rec.weightKg).toBe(60);
    expect(rec.reason).toContain('rebuild');
  });

  it('never jumps the weight up after one off session', () => {
    // Peak, then a single dip. The weight must not increase.
    const rec = recommendProgression({
      history: [
        session('2026-09-01', 60, [10, 10, 9], 2),
        session('2026-09-04', 60, [10, 10, 10], 2),
        session('2026-09-08', 60, [9, 8, 8], 2),
      ],
      target: BENCH,
    });
    expect(rec.action).toBe('add-reps');
    expect(rec.weightKg).toBe(60);
  });

  it('calls a deload when reps decline and the same load feels harder', () => {
    const rec = recommendProgression({
      history: [
        session('2026-09-01', 60, [10, 10, 10], 3),
        session('2026-09-04', 60, [9, 9, 9], 2),
        session('2026-09-08', 60, [8, 7, 7], 0),
      ],
      target: BENCH,
    });
    expect(rec.action).toBe('deload');
    expect(rec.weightKg).toBe(54); // 90% of 60
    expect(rec.targetRir).toBeGreaterThan(BENCH.targetRir);
    expect(rec.reason).toContain('fatigue');
  });

  it('is deterministic and order-independent on input', () => {
    const sessions = [
      session('2026-09-08', 60, [10, 10, 10], 1),
      session('2026-09-01', 60, [8, 8, 8], 3),
    ];
    const a = recommendProgression({ history: sessions, target: BENCH });
    const b = recommendProgression({ history: [...sessions].reverse(), target: BENCH });
    expect(a).toEqual(b);
    expect(a.action).toBe('increase-load');
  });

  it('always returns a reason a user could act on', () => {
    const rec = recommendProgression({
      history: [session('2026-09-01', 60, [10, 10, 10], 1)],
      target: BENCH,
    });
    expect(rec.reason.length).toBeGreaterThan(20);
  });
});

describe('estimated 1RM', () => {
  it('returns the lifted weight for a true single', () => {
    expect(estimate1RM(100, 1)).toBe(100);
  });

  it('follows the Epley formula', () => {
    expect(estimate1RM(60, 10)).toBeCloseTo(80, 1);
  });

  it('is zero for a set with no reps', () => {
    expect(estimate1RM(60, 0)).toBe(0);
  });
});
