import { describe, expect, it } from 'vitest';

import {
  MEASUREMENT_SITES,
  PROGRESS_WINDOWS,
  logMeasurementRequestSchema,
  logWeightRequestSchema,
  progressSummaryQuerySchema,
  progressSummarySchema,
} from './progress.js';
import { todayReasonSchema } from './today.js';

const ID = '11111111-1111-4111-8111-111111111111';
const summary = {
  window: '30d',
  today: '2026-09-24',
  from: '2026-08-26',
  weight: { points: [{ date: '2026-09-24', rawKg: 75.4, trendKg: 75.1 }], currentTrendKg: 75.1, weeklyChangeKg: null, daysOfData: 9, isReliable: false, windowChangeKg: null, windowChangeDays: null },
  measurements: [{ site: 'waist', latest: { date: '2026-09-24', valueCm: 84.5 }, changeCm: -1.5, changeDays: 20 }],
  prs: [{ id: ID, exerciseId: ID, exerciseName: 'Bench', prType: 'weight', value: 85, previous: 80, reason: '85 kg beats 80 kg.', achievedOn: '2026-09-20' }],
  bestLifts: [{ exerciseId: ID, exerciseName: 'Bench', estimated1RmKg: 93.5, weightKg: 85, reps: 3, date: '2026-09-20' }],
  adherence: { protein: { met: 2, of: 4, percent: 50 }, calories: { met: 2, of: 4, percent: 50 }, loggedDays: 4, daysWithoutTarget: 0 },
  consistency: { weeks: [{ isoWeek: '2026-W39', completed: 2, planned: 2 }], completed: 2, planned: 2, percent: 100 },
};

describe('Progress contracts (Phase 12)', () => {
  it('vocabularies: two windows (30d default), five measurement sites', () => {
    expect([...PROGRESS_WINDOWS]).toEqual(['30d', '90d']);
    expect([...MEASUREMENT_SITES]).toEqual(['waist', 'chest', 'arm', 'thigh', 'hip']);
    expect(progressSummaryQuerySchema.parse({})).toEqual({ window: '30d' });
    expect(progressSummaryQuerySchema.safeParse({ window: '7d' }).success).toBe(false);
    expect(progressSummaryQuerySchema.safeParse({ window: '30d', since: 'yesterday' }).success).toBe(false);
  });

  it('the summary is strict; a change never covers less than 7 days', () => {
    expect(progressSummarySchema.safeParse(summary).success).toBe(true);
    expect(progressSummarySchema.safeParse({ ...summary, extra: 1 }).success).toBe(false);
    expect(progressSummarySchema.safeParse({ ...summary, weight: { ...summary.weight, windowChangeKg: -0.2, windowChangeDays: 1 } }).success).toBe(false);
    expect(progressSummarySchema.safeParse({ ...summary, weight: { ...summary.weight, sinceYesterdayKg: 0.3 } }).success).toBe(false);
  });

  it('weight and measurement writes: strict, plausible ranges, an optional yyyy-mm-dd date', () => {
    expect(logWeightRequestSchema.safeParse({ weightKg: 72.4 }).success).toBe(true);
    expect(logWeightRequestSchema.safeParse({ weightKg: 72.4, date: '2026-09-20' }).success).toBe(true);
    expect(logWeightRequestSchema.safeParse({ weightKg: 12 }).success).toBe(false);
    expect(logWeightRequestSchema.safeParse({ weightKg: 72, date: '20-09-2026' }).success).toBe(false);
    expect(logWeightRequestSchema.safeParse({ weightKg: 72, source: 'health-sync' }).success).toBe(false);
    expect(logMeasurementRequestSchema.safeParse({ site: 'waist', valueCm: 84.5 }).success).toBe(true);
    expect(logMeasurementRequestSchema.safeParse({ site: 'neck', valueCm: 40 }).success).toBe(false);
    expect(logMeasurementRequestSchema.safeParse({ site: 'arm', valueCm: 5 }).success).toBe(false);
  });

  it('TODAY: the calorie-adjust reason carries exactly its values; the delta is capped at ±150', () => {
    const ok = { code: 'calorie-target-off-trend', values: { currentKcal: 2200, newKcal: 2070, deltaKcal: -130, weeklyChangeKg: 0.7 } };
    expect(todayReasonSchema.safeParse(ok).success).toBe(true);
    expect(todayReasonSchema.safeParse({ ...ok, values: { ...ok.values, deltaKcal: -200 } }).success).toBe(false);
    expect(todayReasonSchema.safeParse({ ...ok, values: { ...ok.values, note: 'x' } }).success).toBe(false);
  });
});
