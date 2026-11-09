import { describe, expect, it } from 'vitest';

import { liftHistory } from '../src/progress/lift-history.js';

const set = (weightKg: number | null, reps: number, setIndex = 1) => ({ setIndex, weightKg, reps, rir: 2 });

describe('liftHistory (E3)', () => {
  it('summarises each session, newest first, and marks the records', () => {
    const h = liftHistory([
      { sessionId: 'b', date: '2026-11-03', sets: [set(60, 5), set(62.5, 3, 2)] },
      { sessionId: 'a', date: '2026-10-27', sets: [set(60, 6), set(60, 8, 2)] },
      { sessionId: 'c', date: '2026-11-10', sets: [set(60, 5), set(50, 5, 2), set(60, 4, 3)] },
    ]);
    expect(h.sessions.map((s) => s.sessionId)).toEqual(['c', 'b', 'a']);
    const [c, b, a] = h.sessions;
    // a: 60 × 8 is the top set (same weight, more reps); Epley 76 kg.
    expect(a).toMatchObject({ topSet: { weightKg: 60, reps: 8 }, estimated1RmKg: 76, volumeKg: 840, reps: 14, record: true });
    // b: the heavier set is the top set; its best estimate (70) does not beat 76.
    expect(b).toMatchObject({ topSet: { weightKg: 62.5, reps: 3 }, estimated1RmKg: 70, record: false });
    expect(c!.record).toBe(false);
    expect(h.best).toEqual({ estimated1RmKg: 76, date: '2026-10-27' });
  });

  it('bodyweight sets count reps only; a session with no weight is never a record', () => {
    const h = liftHistory([{ sessionId: 'p', date: '2026-11-01', sets: [set(null, 12), set(0, 10, 2)] }]);
    expect(h.sessions[0]).toMatchObject({ topSet: null, estimated1RmKg: null, volumeKg: 0, reps: 22, record: false });
    expect(h.best).toBeNull();
  });

  it('a later equal estimate is not a record; a same-day pair orders by session id', () => {
    const h = liftHistory([
      { sessionId: 'y', date: '2026-11-01', sets: [set(100, 1)] },
      { sessionId: 'x', date: '2026-11-01', sets: [set(100, 1), set(90, 0, 2)] },
    ]);
    expect(h.sessions.map((s) => [s.sessionId, s.record])).toEqual([['y', false], ['x', true]]);
    expect(liftHistory([]).sessions).toEqual([]);
  });
});
