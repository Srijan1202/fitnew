/**
 * Phase 5 core: records, session summary, prefill, mesocycle week. All
 * deterministic; every expectation is a hand calculation.
 */
import { describe, expect, it } from 'vitest';

import { MUSCLE_GROUPS } from '../src/training/generator.js';
import { advancesWeek, isoWeekKey, mesocycleWeekFrom, MESOCYCLE_WEEK_CAP } from '../src/training/mesocycle.js';
import { prefillSet } from '../src/training/prefill.js';
import { estimate1RM } from '../src/training/progression.js';
import { detectPRs, type LoggedSet, type PriorSession, type SetType } from '../src/training/records.js';
import { summarizeSession } from '../src/training/session-summary.js';

let n = 0;
const set = (weightKg: number | null, reps: number, rir: number | null = 2, setType: SetType = 'working'): LoggedSet => ({
  id: `s${++n}`,
  setType,
  weightKg,
  reps,
  rir,
});
const session = (sessionId: string, ...sets: LoggedSet[]): PriorSession => ({ sessionId, sets });

/* ------------------------------------------------------------- records -- */

describe('detectPRs (owner 8.1: only working sets, baseline is not a PR, ties are not PRs)', () => {
  const prior = [session('a', set(60, 10), set(60, 9), set(60, 8)), session('b', set(60, 10), set(60, 10), set(60, 9))];
  // best weight 60, best reps at 60 = 10, best 1RM = estimate1RM(60,10)=80, best volume = b: 60*29 = 1740

  it('the first session of a lift is a baseline: no records', () => {
    expect(detectPRs({ prior: [], current: [set(100, 10), set(100, 10)] })).toEqual([]);
  });

  it('prior sessions with only unloaded or non-working sets are still a baseline', () => {
    expect(detectPRs({ prior: [session('w', set(40, 12, 3, 'warmup'), set(null, 12))], current: [set(60, 10)] })).toEqual([]);
  });

  it('a heavier set is a weight PR; the estimated 1RM moves only when Epley says so', () => {
    // 62.5 × 8 estimates 79.2 kg — heavier bar, LOWER estimate than 60 × 10 (80 kg).
    const heavy = set(62.5, 8);
    const prs = detectPRs({ prior, current: [heavy, set(62.5, 7), set(60, 8)] });
    expect(prs.map((p) => p.prType)).toEqual(['weight']);
    expect(prs[0]).toMatchObject({ value: 62.5, previous: 60, setLogId: heavy.id });
    // 62.5 × 10 estimates 83.3 kg: weight AND 1RM. Volume 625+625+480 = 1730 < 1740: no volume PR.
    const both = detectPRs({ prior, current: [set(62.5, 10), set(62.5, 10), set(60, 8)] });
    expect(both.map((p) => p.prType)).toEqual(['weight', '1rm_est']);
    expect(both[1]).toMatchObject({ value: estimate1RM(62.5, 10), previous: 80 });
    for (const p of [...prs, ...both]) expect(p.reason.length).toBeGreaterThan(10);
  });

  it('more reps at the best weight is a reps PR; equalling it is not', () => {
    const eleven = set(60, 11);
    const prs = detectPRs({ prior, current: [eleven, set(60, 10), set(60, 9)] });
    expect(prs.find((p) => p.prType === 'reps')).toMatchObject({ value: 11, previous: 10, setLogId: eleven.id });
    expect(detectPRs({ prior, current: [set(60, 10), set(60, 10), set(60, 9)] }).map((p) => p.prType)).toEqual([]);
  });

  it('a lighter session with more total volume is a volume PR only', () => {
    const prs = detectPRs({ prior, current: [set(55, 12), set(55, 12), set(55, 12)] }); // 1980
    expect(prs.map((p) => p.prType)).toEqual(['volume']);
    expect(prs[0]).toMatchObject({ value: 1980, previous: 1740 });
  });

  it('drop and warm-up sets in the current session never earn records', () => {
    const prs = detectPRs({ prior, current: [set(60, 10), set(80, 3, 0, 'drop'), set(100, 1, 0, 'warmup')] });
    expect(prs).toEqual([]);
  });

  it('is deterministic and never returns a record without a reason', () => {
    const current = [set(65, 6), set(65, 6)];
    const a = detectPRs({ prior, current });
    const b = detectPRs({ prior, current });
    expect(a).toEqual(b);
    expect(a.every((p) => p.reason.length > 0)).toBe(true);
  });
});

/* ------------------------------------------------------------- summary -- */

describe('summarizeSession — hand calculation', () => {
  const s = summarizeSession({
    startedAt: '2026-09-21T10:00:00.000Z',
    completedAt: '2026-09-21T10:52:30.000Z',
    exercises: [
      {
        exerciseId: 'sq', name: 'Squat', primaryMuscles: ['quads', 'glutes'], secondaryMuscles: ['hamstrings', 'abs'],
        sets: [set(40, 8, null, 'warmup'), set(80, 8), set(80, 8), set(80, 7)],
      },
      {
        exerciseId: 'bp', name: 'Bench', primaryMuscles: ['chest'], secondaryMuscles: ['triceps', 'shoulders'],
        sets: [set(60, 10), set(60, 9), set(40, 12, 0, 'drop')],
      },
      { exerciseId: 'row', name: 'Row', primaryMuscles: ['back'], secondaryMuscles: ['biceps'], sets: [] },
    ],
  });

  it('duration, counts, tonnage', () => {
    expect(s.durationSeconds).toBe(52 * 60 + 30);
    expect(s.totalSets).toBe(7);
    expect(s.workingSets).toBe(5);
    // tonnage excludes the warm-up: 80*23 + 60*19 + 40*12 = 1840 + 1140 + 480
    expect(s.tonnageKg).toBe(3460);
    expect(s.exercisesCompleted).toBe(2);
    expect(s.exercisesSkipped).toBe(1);
  });

  it('hard sets: 1 per primary, 0.5 per secondary, working sets only', () => {
    expect(s.hardSetsByMuscle.quads).toBe(3);
    expect(s.hardSetsByMuscle.glutes).toBe(3);
    expect(s.hardSetsByMuscle.hamstrings).toBe(1.5);
    expect(s.hardSetsByMuscle.abs).toBe(1.5);
    expect(s.hardSetsByMuscle.chest).toBe(2);
    expect(s.hardSetsByMuscle.triceps).toBe(1);
    expect(s.hardSetsByMuscle.shoulders).toBe(1);
    expect(s.hardSetsByMuscle.back).toBe(0);
    for (const m of MUSCLE_GROUPS) expect(typeof s.hardSetsByMuscle[m]).toBe('number');
  });

  it('a session with no sets is zeros, not NaN', () => {
    const empty = summarizeSession({ startedAt: 'x', completedAt: 'y', exercises: [] });
    expect(empty).toMatchObject({ durationSeconds: 0, totalSets: 0, workingSets: 0, tonnageKg: 0, exercisesCompleted: 0, exercisesSkipped: 0 });
  });
});

/* ------------------------------------------------------------- prefill -- */

describe('prefillSet — what you did, never what to do', () => {
  const planned = { setIndex: 2, repsMin: 6, repsMax: 12, weightKg: null, rir: 1 };

  it('no history, no planned weight: target reps, no weight', () => {
    expect(prefillSet({ planned, lastPerformance: [] })).toEqual({
      setIndex: 2, reps: 12, weightKg: null, rir: 1, weightSource: 'none', lastTime: null,
    });
  });

  it('no history, planned weight: the plan', () => {
    expect(prefillSet({ planned: { ...planned, weightKg: 42.5 }, lastPerformance: [] })).toMatchObject({ weightKg: 42.5, weightSource: 'plan' });
  });

  it('history: the same set index last time, weight from it, reps still the target', () => {
    const last = [set(60, 10), set(62.5, 8), set(60, 9)];
    const p = prefillSet({ planned: { ...planned, weightKg: 40 }, lastPerformance: last });
    expect(p.weightKg).toBe(62.5);
    expect(p.reps).toBe(12);
    expect(p.weightSource).toBe('last-session');
    expect(p.lastTime).toBe(last[1]);
  });

  it('history shorter than the plan: the top working weight last time', () => {
    const p = prefillSet({ planned: { ...planned, setIndex: 4 }, lastPerformance: [set(60, 10), set(65, 6)] });
    expect(p.weightKg).toBe(65);
    expect(p.lastTime).toBeNull();
  });

  it('last time only had warm-ups or unloaded sets: fall back to the plan', () => {
    expect(prefillSet({ planned, lastPerformance: [set(30, 10, null, 'warmup'), set(null, 12)] })).toMatchObject({ weightKg: null, weightSource: 'none' });
  });

  it('never increases the load on its own (no progression here)', () => {
    const p = prefillSet({ planned: { ...planned, setIndex: 1 }, lastPerformance: [set(60, 12, 0), set(60, 12, 0), set(60, 12, 0)] });
    expect(p.weightKg).toBe(60);
  });
});

/* ----------------------------------------------------------- mesocycle -- */

describe('mesocycle week (owner 8.2: first completed session of a new ISO week, cap 8)', () => {
  it('ISO week keys: Monday starts the week, Sunday ends it, year boundaries follow ISO', () => {
    expect(isoWeekKey('2026-09-21')).toBe('2026-W39'); // Monday
    expect(isoWeekKey('2026-09-27')).toBe('2026-W39'); // Sunday, same week
    expect(isoWeekKey('2026-09-28')).toBe('2026-W40'); // next Monday
    expect(isoWeekKey('2027-01-01')).toBe('2026-W53'); // Friday of ISO week 53 of 2026
    expect(isoWeekKey('2027-01-04')).toBe('2027-W01');
    expect(() => isoWeekKey('21/09/2026')).toThrow(RangeError);
  });

  it('no completed sessions: week 1', () => {
    expect(mesocycleWeekFrom([])).toBe(1);
  });

  it('several sessions in one week stay week 1; the next week is week 2', () => {
    expect(mesocycleWeekFrom(['2026-09-21', '2026-09-23', '2026-09-27'])).toBe(1);
    expect(mesocycleWeekFrom(['2026-09-21', '2026-09-23', '2026-09-28'])).toBe(2);
  });

  it('a skipped week does not count: weeks are counted when trained, not elapsed', () => {
    expect(mesocycleWeekFrom(['2026-09-21', '2026-10-05'])).toBe(2);
  });

  it('caps at 8', () => {
    const dates = Array.from({ length: 12 }, (_, i) => `2026-${String(3 + Math.floor(i / 4)).padStart(2, '0')}-${String(1 + (i % 4) * 7).padStart(2, '0')}`);
    expect(new Set(dates.map(isoWeekKey)).size).toBeGreaterThan(MESOCYCLE_WEEK_CAP);
    expect(mesocycleWeekFrom(dates)).toBe(MESOCYCLE_WEEK_CAP);
  });

  it('advancesWeek says whether this completion moves the programme on', () => {
    expect(advancesWeek(['2026-09-21'], '2026-09-25')).toBe(false);
    expect(advancesWeek(['2026-09-21'], '2026-09-28')).toBe(true);
    expect(advancesWeek([], '2026-09-21')).toBe(false); // the first session is week 1 either way
  });
});
