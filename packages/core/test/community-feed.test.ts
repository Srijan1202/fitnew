import { describe, expect, it } from 'vitest';

import {
  FEED_KINDS,
  KUDOS_PUSH_FROM_HOUR,
  STREAK_MILESTONES,
  kudosLine,
  kudosPushDue,
  nudgeState,
  periodFrom,
  postFrom,
  streakPostDue,
} from '../src/community/feed.js';

describe('Community that talks (beta 6.3)', () => {
  it('four kinds of post, and milestones in order', () => {
    expect(FEED_KINDS).toEqual(['session', 'run', 'record', 'streak']);
    expect([...STREAK_MILESTONES].sort((a, b) => a - b)).toEqual(STREAK_MILESTONES);
  });

  it('posts start from the later of sharing switched on and two days back', () => {
    expect(postFrom('2026-11-12', '2026-11-01')).toBe('2026-11-10');
    expect(postFrom('2026-11-12', '2026-11-11')).toBe('2026-11-11');
  });

  it('a streak posts the highest milestone it passed, once per streak', () => {
    expect(streakPostDue(6, '2026-11-12', '2026-11-10')).toBeNull();
    expect(streakPostDue(7, '2026-11-12', '2026-11-10')).toEqual({ milestone: 7, reachedOn: '2026-11-12', ref: '7:2026-11-06' });
    // Reached yesterday, still in the window.
    expect(streakPostDue(8, '2026-11-12', '2026-11-10')).toEqual({ milestone: 7, reachedOn: '2026-11-11', ref: '7:2026-11-05' });
    // Reached before sharing was switched on: nothing.
    expect(streakPostDue(20, '2026-11-12', '2026-11-10')).toBeNull();
    expect(streakPostDue(100, '2026-11-12', '2026-11-12')?.ref).toBe('100:2026-08-05');
  });

  it('the kudos summary goes once, in the evening', () => {
    expect(kudosPushDue(KUDOS_PUSH_FROM_HOUR - 1, '2026-11-12', null)).toBe(false);
    expect(kudosPushDue(19, '2026-11-12', null)).toBe(true);
    expect(kudosPushDue(22, '2026-11-12', '2026-11-11')).toBe(true);
    expect(kudosPushDue(22, '2026-11-12', '2026-11-12')).toBe(false);
    expect(kudosPushDue(23, '2026-11-12', null)).toBe(false);
  });

  it('the kudos line names one or two, then counts', () => {
    expect(kudosLine([])).toBe('');
    expect(kudosLine(['asha'])).toBe('@asha cheered you.');
    expect(kudosLine(['asha', 'ravi'])).toBe('@asha and @ravi cheered you.');
    expect(kudosLine(['asha', 'ravi', 'meera', 'dev'])).toBe('@asha and 3 others cheered you.');
  });

  it('a friend can be nudged after three quiet days, once a week', () => {
    const now = new Date('2026-11-12T10:00:00Z');
    expect(nudgeState(null, '2026-11-12', null, now)).toBe('can');
    expect(nudgeState('2026-11-10', '2026-11-12', null, now)).toBe('active');
    expect(nudgeState('2026-11-09', '2026-11-12', null, now)).toBe('can');
    expect(nudgeState('2026-11-09', '2026-11-12', new Date('2026-11-06T10:00:01Z'), now)).toBe('sent');
    expect(nudgeState('2026-11-09', '2026-11-12', new Date('2026-11-05T10:00:00Z'), now)).toBe('can');
    expect(nudgeState('2026-11-12', '2026-11-12', new Date('2026-11-11T10:00:00Z'), now)).toBe('sent');
  });

  it('a period runs from Monday, the 1st, or the day of joining', () => {
    expect(periodFrom('week', '2026-11-12', '2026-11-01')).toBe('2026-11-09');
    expect(periodFrom('week', '2026-11-09', '2026-11-01')).toBe('2026-11-09');
    expect(periodFrom('month', '2026-11-12', '2026-11-01')).toBe('2026-11-01');
    expect(periodFrom('all', '2026-11-12', '2026-10-24')).toBe('2026-10-24');
    // A join "after" today (another time zone) starts today.
    expect(periodFrom('all', '2026-11-12', '2026-11-13')).toBe('2026-11-12');
  });
});
