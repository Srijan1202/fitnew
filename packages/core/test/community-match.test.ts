import { describe, expect, it } from 'vitest';

import {
  MATCH_RESULT_SHOWN_DAYS,
  matchDaysLeft,
  matchResult,
  matchResultLine,
  matchWeekOver,
  matchWeekStarted,
  nextWeekFrom,
  perMember,
} from '../src/community/match.js';

describe('club vs club (beta 6.5, K3)', () => {
  it('a match is for the coming week, Monday to Sunday', () => {
    // 2026-11-23 is a Monday.
    expect(nextWeekFrom('2026-11-23')).toBe('2026-11-30');
    expect(nextWeekFrom('2026-11-29')).toBe('2026-11-30');
    expect(MATCH_RESULT_SHOWN_DAYS).toBe(7);
  });

  it('days left: 7 before it starts, counting today during it, 0 after', () => {
    expect(matchDaysLeft('2026-11-30', '2026-11-27')).toBe(7);
    expect(matchDaysLeft('2026-11-30', '2026-11-30')).toBe(7);
    expect(matchDaysLeft('2026-11-30', '2026-12-06')).toBe(1);
    expect(matchDaysLeft('2026-11-30', '2026-12-07')).toBe(0);
  });

  it('members are fixed once the week starts; the result once it is over everywhere', () => {
    expect(matchWeekStarted('2026-11-30', '2026-11-29')).toBe(false);
    expect(matchWeekStarted('2026-11-30', '2026-11-30')).toBe(true);
    expect(matchWeekOver('2026-11-30', '2026-12-07')).toBe(false);
    expect(matchWeekOver('2026-11-30', '2026-12-08')).toBe(true);
  });

  it('the score is the average per member, to 0.1, so size does not decide it', () => {
    expect(perMember('sessions', 24, 10)).toBe(2.4);
    expect(perMember('sessions', 7, 3)).toBe(2.3);
    expect(perMember('distance', 52_500, 5)).toBe(10.5);
    expect(perMember('active-days', 0, 0)).toBe(0);
  });

  it('the result, and the one push from each club’s side', () => {
    expect(matchResult(2.4, 2.1)).toBe('won');
    expect(matchResult(2.1, 2.4)).toBe('lost');
    expect(matchResult(2, 2)).toBe('drew');
    expect(matchResultLine('Hostel A', 'Gym B', 'sessions', 2.4, 2.1)).toEqual({ title: 'Hostel A won against Gym B', body: '2.4 to 2.1 sessions per member.' });
    expect(matchResultLine('Gym B', 'Hostel A', 'distance', 2.1, 2.4)).toEqual({ title: 'Gym B lost to Hostel A', body: '2.1 to 2.4 km per member.' });
    expect(matchResultLine('Gym B', 'Hostel A', 'active-days', 3, 3)).toEqual({ title: 'Gym B drew with Hostel A', body: '3 to 3 active days per member.' });
  });
});
