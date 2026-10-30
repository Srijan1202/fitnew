/**
 * Beta 4.4 (owner 2026-10-29): plans with 1 or 2 runs a week, for every
 * distance; the beginner run/walk on 1–3 — every rule and branch (§26.1).
 */
import { describe, expect, it } from 'vitest';

import { STREAK_CALENDAR_DAYS, STREAK_GRID_DAYS, streakCalendar, streakDays } from '../src/progress/streak.js';
import { PLAN_GOALS, PLAN_WEEKS, generatePlan, type PlanInput } from '../src/running/plan.js';

const runner = (over: Partial<PlanInput>): PlanInput => ({
  goal: '10k',
  level: 'runner',
  vdot: 45,
  daysPerWeek: 1,
  weekdays: [7],
  longRunWeekday: 7,
  startDate: '2026-11-02',
  ...over,
});

describe('one run a week', () => {
  it('5K and 10K: a longer easy run and a faster session in turn, the race at the end', () => {
    for (const goal of ['5k', '10k'] as const) {
      const p = generatePlan(runner({ goal }));
      expect(p.runs).toHaveLength(PLAN_WEEKS[goal]);
      expect(p.runs.map((r) => r.kind)).toEqual(['long', 'intervals', 'long', 'tempo', 'long', 'intervals', 'long', 'race']);
      expect(new Set(p.runs.map((r) => r.week)).size).toBe(PLAN_WEEKS[goal]);
    }
  });

  it('half and marathon: the long run every week, building, then the race', () => {
    for (const goal of ['half', 'marathon'] as const) {
      const p = generatePlan(runner({ goal }));
      expect(p.runs).toHaveLength(PLAN_WEEKS[goal]);
      expect(p.runs.slice(0, -1).every((r) => r.kind === 'long')).toBe(true);
      expect(p.runs.at(-1)!.kind).toBe('race');
      const longest = Math.max(...p.runs.slice(0, -1).map((r) => r.distanceM!));
      expect(longest).toBeGreaterThan(p.runs[0]!.distanceM!);
    }
  });
});

describe('two runs a week', () => {
  it('the long run and one faster session, intervals and tempo in turn', () => {
    for (const goal of PLAN_GOALS) {
      const p = generatePlan(runner({ goal, daysPerWeek: 2, weekdays: [3, 7] }));
      const week1 = p.runs.filter((r) => r.week === 1).map((r) => r.kind);
      const week2 = p.runs.filter((r) => r.week === 2).map((r) => r.kind);
      expect(week1).toEqual(['intervals', 'long']);
      expect(week2).toEqual(['tempo', 'long']);
      expect(p.runs.filter((r) => r.week === PLAN_WEEKS[goal]).map((r) => r.kind)).toContain('race');
    }
  });
});

describe('the beginner run/walk on fewer days', () => {
  it('two days: run/walks, with the 5K trial on the last day of week 8', () => {
    const p = generatePlan(runner({ goal: '5k', level: 'beginner', vdot: null, daysPerWeek: 2, weekdays: [2, 6], longRunWeekday: 6 }));
    expect(p.runs.filter((r) => r.week === 1).every((r) => r.kind === 'run-walk')).toBe(true);
    const last = p.runs.filter((r) => r.week === 8);
    expect(last.map((r) => r.kind)).toEqual(['easy', 'race']);
  });

  it('one day: the week’s run/walk, and the 5K trial in week 8', () => {
    const p = generatePlan(runner({ goal: '5k', level: 'beginner', vdot: null, daysPerWeek: 1, weekdays: [6], longRunWeekday: 6 }));
    expect(p.runs).toHaveLength(8);
    expect(p.runs.at(-1)!.kind).toBe('race');
  });

  it('refuses four days or more', () => {
    expect(() =>
      generatePlan(runner({ goal: '5k', level: 'beginner', vdot: null, daysPerWeek: 4, weekdays: [1, 3, 5, 7], longRunWeekday: 7 })),
    ).toThrow('1, 2 or 3 days');
  });
});

describe('the streak page’s 4 weeks (beta 4.4)', () => {
  it('each day as the streak sees it, oldest first', () => {
    const days = streakDays({
      today: '2026-10-29',
      activeDays: new Set(['2026-10-27', '2026-10-25']),
      restWeekdays: new Set([7]),
      skippedDays: new Set(['2026-10-28']),
      firstDay: '2026-10-05',
    });
    expect(days).toHaveLength(STREAK_GRID_DAYS);
    expect(days[0]).toEqual({ date: '2026-10-02', status: 'before' });
    const at = (d: string) => days.find((x) => x.date === d)!.status;
    expect(at('2026-10-25')).toBe('logged');
    expect(at('2026-10-18')).toBe('rest');
    expect(at('2026-10-28')).toBe('skipped');
    expect(at('2026-10-26')).toBe('missed');
    expect(at('2026-10-29')).toBe('today');
    expect(days.at(-1)!.date).toBe('2026-10-29');
    // No first day: nothing is "before".
    expect(streakDays({ today: '2026-10-29', activeDays: new Set(['2026-10-29']), restWeekdays: new Set(), skippedDays: new Set(), firstDay: null }, 2))
      .toEqual([{ date: '2026-10-28', status: 'missed' }, { date: '2026-10-29', status: 'logged' }]);
  });
});

describe('the streak page’s month calendar (beta 4.8, owner)', () => {
  const base = {
    today: '2026-10-30',
    activeDays: new Set(['2026-10-25', '2026-10-26', '2026-10-30']),
    restWeekdays: new Set([7]),
    skippedDays: new Set<string>(),
  };

  it('a planned rest day stays a rest day with only a meal; a workout or a run on it is logged', () => {
    // 25 Oct is a Sunday (rest) with a meal only; 26 Oct a Monday with a meal.
    const days = streakDays({ ...base, firstDay: '2026-09-21', trainedDays: new Set(['2026-10-30']) }, 7);
    const at = (d: string) => days.find((x) => x.date === d)!.status;
    expect(at('2026-10-25')).toBe('rest');
    expect(at('2026-10-26')).toBe('logged');
    expect(at('2026-10-30')).toBe('logged');
    expect(streakDays({ ...base, firstDay: null, trainedDays: new Set(['2026-10-25']) }, 7).find((x) => x.date === '2026-10-25')!.status).toBe('logged');
  });

  it('every day from the first of the joining month to today, oldest first', () => {
    const cal = streakCalendar({ ...base, firstDay: '2026-09-21', trainedDays: new Set() });
    expect(cal[0]).toEqual({ date: '2026-09-01', status: 'before' });
    expect(cal.find((x) => x.date === '2026-09-21')!.status).toBe('missed');
    expect(cal.at(-1)).toEqual({ date: '2026-10-30', status: 'logged' });
    expect(cal).toHaveLength(60);
  });

  it('at most a year back (from that month’s first day); no first day looks back the year too', () => {
    const old = streakCalendar({ ...base, firstDay: '2024-01-15' });
    expect(old[0]!.date).toBe('2025-10-01');
    expect(old.length).toBeLessThanOrEqual(STREAK_CALENDAR_DAYS + 31);
    expect(streakCalendar({ ...base, firstDay: null })[0]!.date).toBe('2025-10-01');
  });
});
