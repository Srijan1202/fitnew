import { describe, expect, it } from 'vitest';

import { boardKey, keptPlanPct, onBoard, placesMoved, plannedBetween, rankBy, type BoardCounts } from '../src/community/board.js';

const row = (handle: string, c: Partial<BoardCounts> = {}) => ({ handle, sessions: 0, runM: 0, streak: 0, activeDays: 0, keptPct: null, ...c });

describe('Community boards (beta 6.2)', () => {
  it('each metric ranks by itself first, then the telling counts', () => {
    const r = row('a', { sessions: 3, runM: 5000, streak: 9, activeDays: 4, keptPct: 75 });
    expect(boardKey('sessions', r)).toEqual([3, 5000, 9]);
    expect(boardKey('distance', r)).toEqual([5000, 3, 9]);
    expect(boardKey('streak', r)).toEqual([9, 3, 5000]);
    expect(boardKey('active-days', r)).toEqual([4, 3, 5000]);
    expect(boardKey('plan', r)).toEqual([75, 3, 9]);
    expect(boardKey('plan', row('b'))).toEqual([-1, 0, 0]);
  });

  it('the plan board takes only people with a plan; the others take everyone', () => {
    expect(onBoard('plan', row('a'))).toBe(false);
    expect(onBoard('plan', row('a', { keptPct: 0 }))).toBe(true);
    expect(onBoard('sessions', row('a'))).toBe(true);
  });

  it('the plan kept: done of planned, at most 100 %, none without a plan', () => {
    expect(keptPlanPct(2, 3)).toBe(67);
    expect(keptPlanPct(5, 3)).toBe(100);
    expect(keptPlanPct(-1, 3)).toBe(0);
    expect(keptPlanPct(2, 0)).toBeNull();
  });

  it('planned days between two dates: weekdays for a week, cycle days for a cycle', () => {
    // Mon 2026-11-09 to Sun 2026-11-15; training Mon, Wed, Fri.
    expect(plannedBetween({ kind: 'week' }, new Set([1, 3, 5]), '2026-11-09', '2026-11-15')).toBe(3);
    expect(plannedBetween({ kind: 'week' }, new Set([1, 3, 5]), '2026-11-09', '2026-11-10')).toBe(1);
    // 4 on, 1 off from Tuesday: days 1–4 train, day 5 rests.
    const cycle = { kind: 'cycle' as const, start: '2026-11-10', length: 5 };
    expect(plannedBetween(cycle, new Set([1, 2, 3, 4]), '2026-11-10', '2026-11-16')).toBe(6);
    expect(plannedBetween(cycle, new Set([1]), '2026-11-12', '2026-11-11')).toBe(0);
  });

  it('places moved: up is positive, unknown is null', () => {
    expect(placesMoved(5, 2)).toBe(3);
    expect(placesMoved(1, 4)).toBe(-3);
    expect(placesMoved(null, 2)).toBeNull();
    expect(placesMoved(2, null)).toBeNull();
  });

  it('ranks share a place on a tie, best first, by handle after that', () => {
    const ranked = rankBy([row('cara', { sessions: 2 }), row('abe', { sessions: 4 }), row('bea', { sessions: 2 }), row('dan', { sessions: 1 })], 'sessions');
    expect(ranked.map((r) => [r.handle, r.rank])).toEqual([['abe', 1], ['bea', 2], ['cara', 2], ['dan', 4]]);
    // The plan board leaves out people with no plan.
    expect(rankBy([row('a', { keptPct: 50 }), row('b')], 'plan').map((r) => r.handle)).toEqual(['a']);
  });
});
