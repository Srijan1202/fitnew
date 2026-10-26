/**
 * Beta 3.3 (ADR-018 amendment): the streak and the weekly goal ring — every
 * rule, every branch (§26.1).
 */
import { describe, expect, it } from 'vitest';

import { STREAK_LOOKBACK_DAYS, isoWeekday, streak, weekGoal, type StreakInput } from '../src/progress/streak.js';

// 2026-10-24 is a Saturday.
const base: StreakInput = {
  today: '2026-10-24',
  activeDays: new Set(),
  restWeekdays: new Set(),
  skippedDays: new Set(),
  firstDay: '2026-10-01',
};
const days = (...d: string[]) => new Set(d);

describe('streak', () => {
  it('nothing logged: 0, best 0', () => {
    expect(streak(base)).toEqual({ current: 0, best: 0, todayCounted: false, todayRest: false });
  });

  it('consecutive logged days count, today included', () => {
    expect(streak({ ...base, activeDays: days('2026-10-22', '2026-10-23', '2026-10-24') })).toEqual({ current: 3, best: 3, todayCounted: true, todayRest: false });
  });

  it('today not logged yet does not break the run', () => {
    expect(streak({ ...base, activeDays: days('2026-10-22', '2026-10-23') })).toEqual({ current: 2, best: 2, todayCounted: false, todayRest: false });
  });

  it('a day without a log ends the run; the best run is kept', () => {
    const r = streak({ ...base, activeDays: days('2026-10-10', '2026-10-11', '2026-10-12', '2026-10-14', '2026-10-15'), today: '2026-10-15' });
    expect(r).toEqual({ current: 2, best: 3, todayCounted: true, todayRest: false });
  });

  it('a missed yesterday resets to 0 even if today is not logged', () => {
    expect(streak({ ...base, activeDays: days('2026-10-21', '2026-10-22') })).toEqual({ current: 0, best: 2, todayCounted: false, todayRest: false });
  });

  it('beta 3.8: a planned rest day inside a run counts by itself', () => {
    // Thursday 2026-10-22 is a rest day (weekday 4).
    const r = streak({ ...base, restWeekdays: new Set([4]), activeDays: days('2026-10-21', '2026-10-23', '2026-10-24') });
    expect(r).toEqual({ current: 4, best: 4, todayCounted: true, todayRest: false });
  });

  it('beta 3.8: a rest day today continues the run and counts already', () => {
    // Saturday 2026-10-24 (today) is a rest day (weekday 6).
    const r = streak({ ...base, restWeekdays: new Set([6]), activeDays: days('2026-10-22', '2026-10-23') });
    expect(r).toEqual({ current: 3, best: 3, todayCounted: true, todayRest: true });
  });

  it('beta 3.8: a rest day never starts a run (nothing logged before it): excused, not counted', () => {
    const r = streak({ ...base, restWeekdays: new Set([4, 6]), activeDays: days('2026-10-23') });
    // Thu rest (no run yet) adds nothing; Fri logged; Sat rest (today) continues it.
    expect(r).toEqual({ current: 2, best: 2, todayCounted: true, todayRest: true });
    const idle = streak({ ...base, restWeekdays: new Set([6]) });
    expect(idle).toEqual({ current: 0, best: 0, todayCounted: false, todayRest: true });
  });

  it('a logged rest day still counts', () => {
    const r = streak({ ...base, restWeekdays: new Set([4]), activeDays: days('2026-10-21', '2026-10-22', '2026-10-23') });
    expect(r.current).toBe(3);
  });

  it('the Skip today day is excused', () => {
    const r = streak({ ...base, skippedDays: days('2026-10-23'), activeDays: days('2026-10-22', '2026-10-24') });
    expect(r).toEqual({ current: 2, best: 2, todayCounted: true, todayRest: false });
  });

  it('rest days alone never make a run', () => {
    expect(streak({ ...base, restWeekdays: new Set([1, 2, 3, 4, 5, 6, 7]) }).current).toBe(0);
  });

  it('days before the first day are not looked at', () => {
    const r = streak({ ...base, firstDay: '2026-10-23', activeDays: days('2026-10-20', '2026-10-23') });
    expect(r).toEqual({ current: 1, best: 1, todayCounted: false, todayRest: false });
  });

  it('without a first day (or one older than the window) the full window is looked at', () => {
    const old = '2026-10-24';
    const longAgo = new Set<string>();
    // A 3-day run just inside the window, then nothing.
    const edge = new Date(Date.UTC(2026, 9, 24 - STREAK_LOOKBACK_DAYS)).toISOString().slice(0, 10);
    longAgo.add(edge);
    expect(streak({ ...base, today: old, firstDay: null, activeDays: longAgo }).best).toBe(1);
    expect(streak({ ...base, today: old, firstDay: '2020-01-01', activeDays: longAgo }).best).toBe(1);
  });
});

describe('isoWeekday', () => {
  it('Monday is 1 and Sunday is 7', () => {
    expect(isoWeekday('2026-10-19')).toBe(1);
    expect(isoWeekday('2026-10-25')).toBe(7);
  });
});

describe('weekGoal', () => {
  it('counts this ISO week only, against the planned days', () => {
    expect(weekGoal('2026-10-24', ['2026-10-18', '2026-10-19', '2026-10-21', '2026-10-21', '2026-10-26'], 4)).toEqual({ done: 3, planned: 4 });
  });

  it('no programme: no ring', () => {
    expect(weekGoal('2026-10-24', ['2026-10-21'], 0)).toBeNull();
  });
});
