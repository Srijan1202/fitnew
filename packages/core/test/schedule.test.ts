import { describe, expect, it } from 'vitest';

import { cycleLayout, dayNumberOn, plusDays, sessionsPerWeek, upcomingDays, weekdayOf, type Schedule } from '../src/training/schedule.js';

const week: Schedule = { kind: 'week' };
const fiveDay: Schedule = { kind: 'cycle', start: '2026-11-10', length: 5 };

describe('schedule (F2)', () => {
  it('a week programme falls on the weekdays', () => {
    expect(weekdayOf('2026-11-09')).toBe(1); // Monday
    expect(weekdayOf('2026-11-15')).toBe(7); // Sunday
    expect(dayNumberOn(week, '2026-11-11')).toBe(3);
  });

  it('a cycle counts from its start, wraps, and works before the start too', () => {
    expect(upcomingDays(fiveDay, '2026-11-10', 7).map((d) => d.day)).toEqual([1, 2, 3, 4, 5, 1, 2]);
    expect(dayNumberOn(fiveDay, '2026-11-09')).toBe(5);
    expect(dayNumberOn(fiveDay, '2026-10-01')).toBe(((((-40 % 5) + 5) % 5) + 1));
    // Across a month and a year.
    expect(dayNumberOn({ kind: 'cycle', start: '2026-12-30', length: 3 }, '2027-01-02')).toBe(1);
    expect(plusDays('2026-12-31', 1)).toBe('2027-01-01');
  });

  it('a cycle from the sessions: on, then off, until every session is placed', () => {
    expect(cycleLayout(4, 4, 1)).toEqual([0, 1, 2, 3, null]);
    expect(cycleLayout(5, 4, 1)).toEqual([0, 1, 2, 3, null, 4, null]);
    expect(cycleLayout(3, 3, 0)).toEqual([0, 1, 2]);
    expect(cycleLayout(4, 2, 1)).toEqual([0, 1, null, 2, 3, null]);
    // Too short, too long, or nonsense.
    expect(cycleLayout(1, 1, 0)).toBeNull();
    expect(cycleLayout(6, 1, 2)).toBeNull();
    expect(cycleLayout(0, 3, 1)).toBeNull();
    expect(cycleLayout(3, 0, 1)).toBeNull();
    expect(cycleLayout(3, 3, -1)).toBeNull();
  });

  it('sessions per week: the week as it is; a cycle averaged over seven days', () => {
    expect(sessionsPerWeek(week, 4)).toBe(4);
    expect(sessionsPerWeek(fiveDay, 4)).toBe(6);
    expect(sessionsPerWeek({ kind: 'cycle', start: '2026-11-10', length: 7 }, 5)).toBe(5);
  });
});
