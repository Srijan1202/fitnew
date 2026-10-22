/**
 * Phase 19 (ADR-027): the weekly progress report — every rule, every branch
 * (§26.1). Unlogged days are unknown, never misses.
 */
import { describe, expect, it } from 'vitest';

import { STEADY_KG, weeklyReport, type WeeklyReportInput } from '../src/progress/weekly.js';

const base: WeeklyReportInput = {
  isoWeek: '2026-W43',
  from: '2026-10-19',
  to: '2026-10-25',
  today: '2026-10-26',
  sessionsCompleted: 3,
  sessionsPlanned: 4,
  volume: [],
  prs: [],
  days: [],
  targets: [{ effectiveFrom: '2026-10-01', kcal: 2400, proteinG: 140 }],
  trend: [],
};
const day = (date: string, kcalLow: number, kcalHigh: number, proteinHigh: number, itemCount = 3) => ({ date, itemCount, kcalLow, kcalHigh, proteinHigh });
const point = (date: string, trendKg: number) => ({ date, rawKg: trendKg, trendKg });

describe('weeklyReport', () => {
  it('a full week: sessions against the plan, volume bands, records, protein, the trend', () => {
    const r = weeklyReport({
      ...base,
      volume: [
        { muscle: 'chest', hardSets: 12, status: 'mev-to-mav' },
        { muscle: 'back', hardSets: 14, status: 'mev-to-mav' },
        { muscle: 'calves', hardSets: 2, status: 'below-mev' },
        { muscle: 'biceps', hardSets: 1, status: 'below-mv' },
        { muscle: 'quads', hardSets: 22, status: 'at-mrv' },
        { muscle: 'abs', hardSets: 0, status: 'none' },
      ],
      prs: [{ exerciseName: 'Bench Press' }, { exerciseName: 'Squat' }, { exerciseName: 'Bench Press' }],
      days: [
        day('2026-10-19', 2300, 2500, 150),
        day('2026-10-20', 1500, 1700, 90),
        day('2026-10-21', 0, 0, 0, 0), // nothing logged: unknown, not a miss
        day('2026-10-18', 2400, 2400, 200), // before the week
        day('2026-10-26', 2400, 2400, 200), // after it
      ],
      trend: [point('2026-10-17', 71.0), point('2026-10-19', 70.8), point('2026-10-22', 70.6), point('2026-10-25', 70.4)],
    });
    expect(r.complete).toBe(true);
    expect(r.training).toEqual({ completed: 3, planned: 4, percent: 75 });
    expect(r.volume).toEqual({ totalHardSets: 51, productive: ['chest', 'back'], below: ['calves', 'biceps'], above: ['quads'] });
    expect(r.prs).toEqual({ count: 3, lifts: ['Bench Press', 'Squat'] });
    expect(r.nutrition).toEqual({ loggedDays: 2, judgedDays: 2, proteinMet: 1, caloriesOn: 1 });
    expect(r.weight).toEqual({ startKg: 70.8, endKg: 70.4, changeKg: -0.4 });
    expect(r.highlights).toEqual([
      '3 of 4 planned sessions.',
      'Chest and back in the productive range (MEV to MAV).',
      'Below MEV: calves and biceps.',
      'Above MAV: quads. Watch recovery.',
      '3 personal records: Bench Press and Squat.',
      'Protein target reached on 1 of 2 logged days.',
      'Trend weight down 0.4 kg.',
    ]);
  });

  it('an empty week, still running: says so and nothing else', () => {
    const r = weeklyReport({ ...base, today: '2026-10-25', sessionsCompleted: 0 });
    expect(r.complete).toBe(false);
    expect(r.weight).toBeNull();
    expect(r.highlights).toEqual(['No sessions logged this week.', 'No food logged this week.']);
  });

  it('without a programme the count stands alone; one session is singular; more than planned caps at 100 %', () => {
    expect(weeklyReport({ ...base, sessionsPlanned: null, sessionsCompleted: 1 }).highlights[0]).toBe('1 session.');
    expect(weeklyReport({ ...base, sessionsPlanned: null, sessionsCompleted: 2 }).highlights[0]).toBe('2 sessions.');
    expect(weeklyReport({ ...base, sessionsPlanned: 0, sessionsCompleted: 2 }).training.percent).toBeNull();
    expect(weeklyReport({ ...base, sessionsPlanned: 3, sessionsCompleted: 5 }).training.percent).toBe(100);
  });

  it('one record is singular; three muscles are listed with commas', () => {
    const r = weeklyReport({
      ...base,
      prs: [{ exerciseName: 'Row' }],
      volume: ['glutes', 'hamstrings', 'shoulders'].map((m) => ({ muscle: m, hardSets: 10, status: 'mev-to-mav' as const })),
    });
    expect(r.highlights).toContain('1 personal record: Row.');
    expect(r.highlights).toContain('Glutes, hamstrings and shoulders in the productive range (MEV to MAV).');
  });

  it('logged days before any target are counted as logged but not judged; one judged day is singular', () => {
    const early = weeklyReport({ ...base, targets: [], days: [day('2026-10-20', 2000, 2200, 100)] });
    expect(early.nutrition).toEqual({ loggedDays: 1, judgedDays: 0, proteinMet: 0, caloriesOn: 0 });
    expect(early.highlights.some((h) => h.startsWith('Protein') || h.startsWith('No food'))).toBe(false);
    const one = weeklyReport({ ...base, days: [day('2026-10-20', 2400, 2600, 150)] });
    expect(one.highlights).toContain('Protein target reached on 1 of 1 logged day.');
  });

  it('the trend: up, steady within the noise, or unknown with one reading', () => {
    expect(weeklyReport({ ...base, trend: [point('2026-10-19', 70), point('2026-10-25', 70.3)] }).highlights.at(-1)).toBe('Trend weight up 0.3 kg.');
    const steady = weeklyReport({ ...base, trend: [point('2026-10-19', 70), point('2026-10-25', 70 + STEADY_KG / 2)] });
    expect(steady.highlights.at(-1)).toBe('Trend weight steady.');
    expect(weeklyReport({ ...base, trend: [point('2026-10-20', 70)] }).weight).toBeNull();
  });
});

describe('isoWeekDates', () => {
  it('Monday to Sunday of an ISO week, the inverse of isoWeekKey (a year whose 4 January is a Sunday, and one where it is not)', async () => {
    const { isoWeekDates, isoWeekKey } = await import('../src/training/mesocycle.js');
    expect(isoWeekDates('2026-W43')).toEqual({ from: '2026-10-19', to: '2026-10-25' });
    expect(isoWeekDates('2026-W01')).toEqual({ from: '2025-12-29', to: '2026-01-04' });
    expect(isoWeekDates('2027-W01')).toEqual({ from: '2027-01-04', to: '2027-01-10' });
    for (const d of ['2026-01-01', '2026-06-15', '2027-12-31', '2028-02-29']) {
      const { from, to } = isoWeekDates(isoWeekKey(d));
      expect(d >= from && d <= to).toBe(true);
    }
    expect(() => isoWeekDates('2026-43')).toThrow(RangeError);
  });
});
