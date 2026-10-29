/**
 * Beta 4.5 (owner 2026-10-30): speed, lifetime and consistency badges —
 * every rule and branch (§26.1).
 */
import { describe, expect, it } from 'vitest';

import {
  CONSISTENCY_BADGES,
  LIFETIME_BADGES,
  SPEED_BADGES,
  consistencyBadges,
  lifetimeBadges,
  speedBadges,
  type BadgeRun,
} from '../src/running/badges.js';

const at = (d: string, h = 7) => new Date(`${d}T0${h}:00:00Z`);
const run = (localDate: string, km = 5): BadgeRun => ({ startedAt: at(localDate), localDate, distanceM: km * 1000 });

describe('the badges', () => {
  it('seven speed, five lifetime, three consistency; two with a reward', () => {
    expect(SPEED_BADGES).toHaveLength(7);
    expect(LIFETIME_BADGES).toHaveLength(5);
    expect(CONSISTENCY_BADGES).toHaveLength(3);
    const rewarded = [...SPEED_BADGES, ...LIFETIME_BADGES, ...CONSISTENCY_BADGES].filter((b) => b.reward !== null).map((b) => b.id);
    expect(rewarded).toEqual(['speed-5k-20', 'total-1000k']);
  });
});

describe('speed', () => {
  it('the first effort under each time earns it; exactly the time does not', () => {
    const got = speedBadges([
      { key: '5k', seconds: 1500, startedAt: at('2026-10-01') }, // 25:00 exactly: under 30 only
      { key: '5k', seconds: 1499.9, startedAt: at('2026-10-10') }, // under 25
      { key: '5k', seconds: 1450, startedAt: at('2026-10-05') }, // earlier and faster: under 25 here
      { key: '10k', seconds: 3599, startedAt: at('2026-10-07') },
      { key: '1k', seconds: 200, startedAt: at('2026-10-02') },
    ]);
    expect(got.get('speed-5k-30')).toEqual(at('2026-10-01'));
    expect(got.get('speed-5k-25')).toEqual(at('2026-10-05'));
    expect(got.has('speed-5k-20')).toBe(false);
    expect(got.get('speed-10k-60')).toEqual(at('2026-10-07'));
    expect(got.has('speed-10k-50')).toBe(false);
    expect(speedBadges([])).toEqual(new Map());
  });
});

describe('lifetime', () => {
  it('dated by the run that takes the total past each mark, in the order run', () => {
    const runs = [run('2026-10-03', 30), run('2026-10-01', 25), run('2026-10-05', 50)];
    const got = lifetimeBadges(runs);
    // 25 + 30 = 55 km on the 3rd; + 50 = 105 km on the 5th.
    expect(got.get('total-50k')).toEqual(at('2026-10-03'));
    expect(got.get('total-100k')).toEqual(at('2026-10-05'));
    expect(got.has('total-250k')).toBe(false);
    expect(lifetimeBadges([run('2026-10-01', 1000)]).size).toBe(5);
  });
});

describe('consistency', () => {
  it('four weeks in a row: dated by the first run of the fourth week', () => {
    const got = consistencyBadges(
      [run('2026-10-05'), run('2026-10-14'), run('2026-10-15'), run('2026-10-19'), run('2026-10-27'), run('2026-10-29')],
      null,
    );
    expect(got.get('weeks-4')).toEqual(at('2026-10-27'));
    expect(got.has('three-in-a-week')).toBe(false);
    expect(got.has('plan-finished')).toBe(false);
  });

  it('a gap starts the count again; across the new year too', () => {
    const gap = consistencyBadges([run('2026-10-05'), run('2026-10-12'), run('2026-10-26'), run('2026-11-02'), run('2026-11-09')], null);
    expect(gap.has('weeks-4')).toBe(false);
    const year = consistencyBadges([run('2026-12-14'), run('2026-12-21'), run('2026-12-28'), run('2027-01-04')], null);
    expect(year.get('weeks-4')).toEqual(at('2027-01-04'));
  });

  it('three runs in one week: the third; and a finished plan', () => {
    const got = consistencyBadges([run('2026-10-26'), run('2026-10-28'), run('2026-11-01'), run('2026-11-02')], at('2026-11-01', 9));
    expect(got.get('three-in-a-week')).toEqual(at('2026-11-01'));
    expect(got.get('plan-finished')).toEqual(at('2026-11-01', 9));
  });
});
