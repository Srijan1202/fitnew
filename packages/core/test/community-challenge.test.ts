import { describe, expect, it } from 'vitest';

import {
  CHALLENGE_METRICS,
  CHALLENGE_TARGET_MAX,
  CHALLENGE_TARGET_MIN,
  challengeReachedLine,
  challengeTitle,
  daysLeft,
  inTargetUnit,
  isReached,
  monthOf,
  monthOverEverywhere,
  monthRange,
  suggestTarget,
} from '../src/community/challenge.js';

describe('club challenges (beta 6.5, K2)', () => {
  it('three metrics, a calendar month each', () => {
    expect(CHALLENGE_METRICS).toEqual(['sessions', 'distance', 'active-days']);
    expect(monthOf('2026-12-31')).toBe('2026-12');
    expect(monthRange('2026-12')).toEqual({ from: '2026-12-01', to: '2026-12-31' });
    expect(monthRange('2026-02')).toEqual({ from: '2026-02-01', to: '2026-02-28' });
    expect(monthRange('2028-02')).toEqual({ from: '2028-02-01', to: '2028-02-29' });
  });

  it('distance is counted in metres and set in kilometres', () => {
    expect(inTargetUnit('distance', 12_345)).toBe(12.3);
    expect(inTargetUnit('sessions', 7)).toBe(7);
    expect(isReached('distance', 199_999, 200)).toBe(false);
    expect(isReached('distance', 200_000, 200)).toBe(true);
    expect(isReached('sessions', 199, 200)).toBe(false);
    expect(isReached('active-days', 200, 200)).toBe(true);
  });

  it('the title is made from the numbers', () => {
    expect(challengeTitle('sessions', 200, '2026-12')).toBe('200 sessions together in December');
    expect(challengeTitle('distance', 1500, '2027-01')).toBe('1,500 km together in January');
    expect(challengeTitle('active-days', 300, '2026-11')).toBe('300 active days together in November');
    expect(challengeReachedLine('VIT Hostel A', '200 sessions together in December')).toEqual({
      title: 'VIT Hostel A reached its goal',
      body: '200 sessions together in December. Done together.',
    });
  });

  it('days left count today; a month is over everywhere two days after it ends', () => {
    expect(daysLeft('2026-12', '2026-12-01')).toBe(31);
    expect(daysLeft('2026-12', '2026-12-31')).toBe(1);
    expect(daysLeft('2026-12', '2027-01-01')).toBe(0);
    expect(monthOverEverywhere('2026-12', '2027-01-01')).toBe(false);
    expect(monthOverEverywhere('2026-12', '2027-01-02')).toBe(true);
  });

  it('the suggestion: the last 4 weeks scaled to the month, plus 10%, a multiple of 5, within the limits', () => {
    // 100 sessions in 28 days → 31 days → 110.7 → +10% = 121.8 → 125.
    expect(suggestTarget('sessions', 100, '2026-12')).toBe(125);
    // 400 km in 28 days, February 2026 (28 days) → 440.
    expect(suggestTarget('distance', 400_000, '2026-02')).toBe(440);
    expect(suggestTarget('active-days', 0, '2026-12')).toBe(CHALLENGE_TARGET_MIN);
    expect(suggestTarget('sessions', 10_000_000, '2026-12')).toBe(CHALLENGE_TARGET_MAX);
  });
});
