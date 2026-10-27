import { describe, expect, it } from 'vitest';

import { createRunRequestSchema, patchRunRequestSchema, runGoalSchema, runListQuerySchema } from './running.js';

const outdoor = {
  clientRunId: '4f1c8f3e-6a0b-4d55-9a57-2f0c3c5a9b01',
  kind: 'outdoor',
  name: 'Morning run',
  startedAt: '2026-10-27T01:00:00.000Z',
  endedAt: '2026-10-27T01:31:00.000Z',
  durationSeconds: 1800,
  goal: { kind: 'free', value: null },
  track: { v: 1, points: '', breaks: [], elevation: false },
};

/** The outdoor run without its track. */
function withoutTrack(): Record<string, unknown> {
  const copy: Record<string, unknown> = { ...outdoor };
  delete copy['track'];
  return copy;
}

describe('running contracts (beta 4.0)', () => {
  it('a goal: free has no value; the others stay inside their limits', () => {
    expect(runGoalSchema.safeParse({ kind: 'free', value: null }).success).toBe(true);
    expect(runGoalSchema.safeParse({ kind: 'free', value: 5 }).success).toBe(false);
    expect(runGoalSchema.safeParse({ kind: 'distance', value: 5000 }).success).toBe(true);
    expect(runGoalSchema.safeParse({ kind: 'distance', value: 50 }).success).toBe(false);
    expect(runGoalSchema.safeParse({ kind: 'time', value: null }).success).toBe(false);
    expect(runGoalSchema.safeParse({ kind: 'pace', value: 330 }).success).toBe(true);
    expect(runGoalSchema.safeParse({ kind: 'pace', value: 1300 }).success).toBe(false);
  });

  it('an outdoor run needs a track and no typed distance', () => {
    expect(createRunRequestSchema.safeParse(outdoor).success).toBe(true);
    expect(createRunRequestSchema.safeParse(withoutTrack()).success).toBe(false);
    expect(createRunRequestSchema.safeParse({ ...outdoor, distanceM: 5000 }).success).toBe(false);
  });

  it('a treadmill run needs a distance and no track', () => {
    const base = withoutTrack();
    expect(createRunRequestSchema.safeParse({ ...base, kind: 'treadmill', distanceM: 5000 }).success).toBe(true);
    expect(createRunRequestSchema.safeParse({ ...base, kind: 'treadmill' }).success).toBe(false);
    expect(createRunRequestSchema.safeParse({ ...outdoor, kind: 'treadmill', distanceM: 5000 }).success).toBe(false);
  });

  it('the time: ends after it starts, active time inside it, 48 hours at most', () => {
    expect(createRunRequestSchema.safeParse({ ...outdoor, endedAt: '2026-10-27T00:59:00.000Z' }).success).toBe(false);
    expect(createRunRequestSchema.safeParse({ ...outdoor, durationSeconds: 1862 }).success).toBe(false);
    expect(createRunRequestSchema.safeParse({ ...outdoor, durationSeconds: 1861 }).success).toBe(true);
    expect(createRunRequestSchema.safeParse({ ...outdoor, endedAt: '2026-10-30T01:00:00.000Z' }).success).toBe(false);
  });

  it('a patch changes something', () => {
    expect(patchRunRequestSchema.safeParse({}).success).toBe(false);
    expect(patchRunRequestSchema.safeParse({ effort: null }).success).toBe(true);
    expect(patchRunRequestSchema.safeParse({ name: '  ' }).success).toBe(false);
  });

  it('the list query reads a page size from the query string', () => {
    expect(runListQuerySchema.parse({ limit: '5' })).toEqual({ limit: 5 });
    expect(runListQuerySchema.safeParse({ limit: '0' }).success).toBe(false);
  });
});
