import { describe, expect, it } from 'vitest';

import { monthSpan, monthlyReport, type MonthlyReportInput } from '../src/progress/monthly.js';

const base = (over: Partial<MonthlyReportInput> = {}): MonthlyReportInput => ({
  month: '2026-10',
  from: '2026-10-01',
  to: '2026-10-31',
  today: '2026-11-10',
  sessionsCompleted: 0,
  sessionsPlannedPerWeek: null,
  muscles: [],
  prs: [],
  runs: [],
  days: [],
  targets: [],
  water: [],
  waterTargetMl: 2500,
  checkIns: [],
  trend: [],
  ...over,
});

describe('monthlyReport (beta 6.1)', () => {
  it('a full month: sessions against the plan, the most-worked muscles, records, runs, food, water, sleep and the trend', () => {
    const r = monthlyReport(
      base({
        sessionsCompleted: 15,
        sessionsPlannedPerWeek: 4,
        muscles: [
          { muscle: 'chest', hardSets: 48, tonnageKg: 9000.4 },
          { muscle: 'back', hardSets: 52, tonnageKg: 11000 },
          { muscle: 'quads', hardSets: 30, tonnageKg: 14000 },
          { muscle: 'calves', hardSets: 0, tonnageKg: 0 },
          { muscle: 'biceps', hardSets: 20, tonnageKg: 1500 },
          { muscle: 'triceps', hardSets: 20, tonnageKg: 1400 },
          { muscle: 'glutes', hardSets: 12, tonnageKg: 3000 },
        ],
        prs: [{ exerciseName: 'Bench' }, { exerciseName: 'Bench' }, { exerciseName: 'Squat' }],
        runs: [{ distanceM: 5040 }, { distanceM: 10020 }],
        days: [
          { date: '2026-09-30', itemCount: 4, kcalLow: 1000, kcalHigh: 1200, proteinHigh: 200 },
          { date: '2026-10-02', itemCount: 5, kcalLow: 2300, kcalHigh: 2500, proteinHigh: 150 },
          { date: '2026-10-03', itemCount: 0, kcalLow: 0, kcalHigh: 0, proteinHigh: 0 },
          { date: '2026-10-04', itemCount: 3, kcalLow: 1500, kcalHigh: 1700, proteinHigh: 90 },
        ],
        targets: [{ effectiveFrom: '2026-10-01', kcal: 2400, proteinG: 140 }],
        water: [
          { date: '2026-10-02', ml: 2500 },
          { date: '2026-10-03', ml: 1000 },
          { date: '2026-10-04', ml: 0 },
          { date: '2026-11-01', ml: 3000 },
        ],
        checkIns: [
          { date: '2026-10-02', sleepHours: 7.5 },
          { date: '2026-10-03', sleepHours: null },
          { date: '2026-10-05', sleepHours: 6 },
        ],
        trend: [
          { date: '2026-09-28', rawKg: 72, trendKg: 72 },
          { date: '2026-10-01', rawKg: 72, trendKg: 71.9 },
          { date: '2026-10-30', rawKg: 71, trendKg: 71.2 },
        ],
      }),
    );
    expect(r.complete).toBe(true);
    // 4 a week over 31 days is 18 planned.
    expect(r.training).toEqual({
      completed: 15,
      planned: 18,
      percent: 83,
      hardSets: 182,
      tonnageKg: 39900,
      topMuscles: [
        { muscle: 'back', hardSets: 52 },
        { muscle: 'chest', hardSets: 48 },
        { muscle: 'quads', hardSets: 30 },
        { muscle: 'biceps', hardSets: 20 },
        { muscle: 'triceps', hardSets: 20 },
      ],
    });
    expect(r.prs).toEqual({ count: 3, lifts: ['Bench', 'Squat'] });
    expect(r.running).toEqual({ runs: 2, km: 15.1 });
    expect(r.nutrition).toEqual({ loggedDays: 2, judgedDays: 2, proteinMet: 1, caloriesOn: 1, averageKcal: 2000 });
    expect(r.water).toEqual({ loggedDays: 2, daysAtTarget: 1, targetMl: 2500 });
    expect(r.recovery).toEqual({ checkIns: 3, averageSleepHours: 6.8 });
    expect(r.weight).toEqual({ startKg: 71.9, endKg: 71.2, changeKg: -0.7 });
    expect(r.highlights).toEqual([
      '15 of 18 planned sessions.',
      'Most work: back, chest, quads.',
      '3 personal records, on 2 lifts.',
      '2 runs, 15.1 km.',
      'Protein target reached on 1 of 2 logged days.',
      'Water target reached on 1 of 2 days with water logged.',
      'Trend weight down 0.7 kg.',
    ]);
  });

  it('a month still running plans only its days so far; an empty month says so plainly', () => {
    const r = monthlyReport(base({ month: '2026-11', from: '2026-11-01', to: '2026-11-30', today: '2026-11-07', sessionsPlannedPerWeek: 4 }));
    expect(r.complete).toBe(false);
    expect(r.training.planned).toBe(4);
    expect(r.nutrition.averageKcal).toBeNull();
    expect(r.recovery.averageSleepHours).toBeNull();
    expect(r.weight).toBeNull();
    expect(r.highlights).toEqual(['No sessions logged this month.', 'No food logged this month.']);
  });

  it('without a programme, sessions are counted alone; one session, one record, one run, a steady or rising trend; food without a target', () => {
    const r = monthlyReport(
      base({
        sessionsCompleted: 1,
        prs: [{ exerciseName: 'Row' }],
        runs: [{ distanceM: 3000 }],
        days: [{ date: '2026-10-02', itemCount: 2, kcalLow: 1000, kcalHigh: 1200, proteinHigh: 50 }],
        trend: [
          { date: '2026-10-01', rawKg: 70, trendKg: 70 },
          { date: '2026-10-20', rawKg: 70, trendKg: 70.05 },
        ],
      }),
    );
    expect(r.training.percent).toBeNull();
    expect(r.highlights).toEqual(['1 session.', '1 personal record, on 1 lift.', '1 run, 3.0 km.', 'Trend weight steady.']);
    const up = monthlyReport(base({ sessionsPlannedPerWeek: 0, sessionsCompleted: 2, trend: [{ date: '2026-10-01', rawKg: 70, trendKg: 70 }, { date: '2026-10-20', rawKg: 71, trendKg: 70.6 }] }));
    expect(up.training).toMatchObject({ planned: 0, percent: null });
    expect(up.highlights).toEqual(['2 sessions.', 'No food logged this month.', 'Trend weight up 0.6 kg.']);
  });

  it('monthSpan: the dates and the ISO weeks whose Thursday is in the month', () => {
    expect(monthSpan('2026-10')).toEqual({ from: '2026-10-01', to: '2026-10-31', isoWeeks: ['2026-W40', '2026-W41', '2026-W42', '2026-W43', '2026-W44'] });
    expect(monthSpan('2026-02').to).toBe('2026-02-28');
    // 1 Jan 2027 is a Friday: that week is 2026's W53, not January's.
    expect(monthSpan('2027-01').isoWeeks[0]).toBe('2027-W01');
  });
});
