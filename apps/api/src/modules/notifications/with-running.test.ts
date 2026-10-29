import { describe, expect, it } from 'vitest';

import { withRunning } from './service.js';

/**
 * Beta 4.1 (ADR-039 C4/C5): the running plan in the reminders. 2026-10-27 is
 * a Tuesday (2), 2026-10-29 a Thursday (4), 2026-11-01 a Sunday (7).
 */
describe('withRunning', () => {
  const gym = { 1: 'Push', 4: 'Legs' };

  it('no plan: the gym programme as it was, and a day with a run counts as trained', () => {
    expect(withRunning(gym, ['2026-10-26'], ['2026-10-26'], [], ['2026-10-27', '2026-10-26'])).toEqual({
      programme: gym,
      skippedDates: ['2026-10-26'],
      completedDates: ['2026-10-26', '2026-10-27'],
      runWeekdays: [],
    });
    expect(withRunning(null, [], [], [], []).programme).toBeNull();
  });

  it('a plan run’s weekday is a training day named after the run; a gym weekday keeps the gym session', () => {
    const r = withRunning(
      gym,
      [],
      [],
      [
        { date: '2026-10-27', title: 'Easy 5 km', status: 'planned' },
        { date: '2026-10-29', title: 'Tempo 20 min', status: 'planned' },
        { date: '2026-11-01', title: 'Long run 10 km', status: 'skipped' },
      ],
      [],
    );
    expect(r.programme).toEqual({ 1: 'Push', 2: 'Easy 5 km', 4: 'Legs', 7: 'Long run 10 km' });
    // Beta 4.4 (E27): the run weekdays, for the run's words (Thursday stays the gym's).
    expect(r.runWeekdays).toEqual([2, 7]);
    // The skipped long run is a skipped day: no reminder, no "missed".
    expect(r.skippedDates).toEqual(['2026-11-01']);
  });

  it('with no gym programme, the plan alone makes the training days; the earliest run names a weekday', () => {
    const r = withRunning(
      null,
      [],
      [],
      [
        { date: '2026-10-27', title: 'Easy 5 km', status: 'done' },
        { date: '2026-11-03', title: 'Intervals: 6 × 400 m', status: 'planned' },
      ],
      ['2026-10-27'],
    );
    expect(r.programme).toEqual({ 2: 'Easy 5 km' });
    expect(r.completedDates).toEqual(['2026-10-27']);
  });

  it('a skipped run on a gym weekday does not skip the gym session', () => {
    const r = withRunning(gym, [], [], [{ date: '2026-10-29', title: 'Easy 5 km', status: 'skipped' }], []);
    expect(r.skippedDates).toEqual([]);
    expect(r.programme).toEqual(gym);
  });
});
