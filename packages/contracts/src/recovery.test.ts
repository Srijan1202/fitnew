import { describe, expect, it } from 'vitest';

import {
  READINESS_BANDS,
  READINESS_COMPONENTS,
  RECOVERY_DAYS_BACK,
  logRecoveryRequestSchema,
  recoveryTodaySchema,
} from './recovery.js';
import { todayReasonSchema } from './today.js';
import { deloadStateSchema } from './workout.js';

const log = { date: '2026-09-24', sleepHours: 6.5, sleepQuality: 3, soreness: 2, energy: 4, stress: null, source: 'manual' };
const readiness = {
  score: 71,
  band: 'advisory',
  advice: 'A little under par. Train as planned and notice how the sets feel.',
  components: READINESS_COMPONENTS.map((key) => ({ key, penalty: key === 'sleep' ? 10 : 0, max: 10, available: key !== 'adherence' })),
  lowDays: 0,
};

describe('Recovery contracts (Phase 13)', () => {
  it('vocabularies: four bands, the five §18 components, seven days back', () => {
    expect([...READINESS_BANDS]).toEqual(['ready', 'advisory', 'reduce', 'rest']);
    expect([...READINESS_COMPONENTS]).toEqual(['sleep', 'soreness', 'energy', 'performance', 'adherence']);
    expect(RECOVERY_DAYS_BACK).toBe(7);
  });

  it('today: strict; readiness null until the check-in; every component listed', () => {
    expect(recoveryTodaySchema.safeParse({ date: '2026-09-24', log: null, readiness: null }).success).toBe(true);
    expect(recoveryTodaySchema.safeParse({ date: '2026-09-24', log, readiness }).success).toBe(true);
    expect(recoveryTodaySchema.safeParse({ date: '2026-09-24', log, readiness: { ...readiness, score: 101 } }).success).toBe(false);
    expect(recoveryTodaySchema.safeParse({ date: '2026-09-24', log, readiness: { ...readiness, components: readiness.components.slice(1) } }).success).toBe(false);
    expect(recoveryTodaySchema.safeParse({ date: '2026-09-24', log, readiness, extra: 1 }).success).toBe(false);
    expect(recoveryTodaySchema.safeParse({ date: '2026-09-24', log: { ...log, source: 'health-sync' }, readiness }).success).toBe(false);
  });

  it('the check-in: every value optional, the scales 1–5, sleep 0–24 h, nothing else', () => {
    expect(logRecoveryRequestSchema.safeParse({}).success).toBe(true); // "at least one" is the server's 422
    expect(logRecoveryRequestSchema.safeParse({ sleepHours: 7.5, sleepQuality: 4, soreness: 1, energy: 5, stress: 2, date: '2026-09-24' }).success).toBe(true);
    expect(logRecoveryRequestSchema.safeParse({ soreness: null }).success).toBe(true);
    for (const bad of [{ soreness: 0 }, { energy: 6 }, { stress: 2.5 }, { sleepHours: -1 }, { sleepHours: 25 }, { date: '24-09-2026' }, { mood: 3 }, { readiness: 80 }]) {
      expect(logRecoveryRequestSchema.safeParse(bad).success, JSON.stringify(bad)).toBe(false);
    }
  });

  it('TODAY: low-readiness only below 55, bands reduce/rest; the rest day carries readiness; deload has a readiness trigger', () => {
    const r = (values: unknown) => todayReasonSchema.safeParse({ code: 'readiness-low', values }).success;
    expect(r({ readiness: 48, band: 'reduce', accessories: ['Curl'], lowDays: 0 })).toBe(true);
    expect(r({ readiness: 20, band: 'rest', accessories: [], lowDays: 3 })).toBe(true);
    expect(r({ readiness: 60, band: 'advisory', accessories: [], lowDays: 0 })).toBe(false);
    expect(r({ readiness: 60, band: 'reduce', accessories: [], lowDays: 0 })).toBe(false);
    const rest = { hasProgramme: true, nextSessionName: null, nextSessionDate: null, kcalTarget: null, proteinTarget: null };
    expect(todayReasonSchema.safeParse({ code: 'rest-day', values: { ...rest, readiness: 82 } }).success).toBe(true);
    expect(todayReasonSchema.safeParse({ code: 'rest-day', values: { ...rest, readiness: null } }).success).toBe(true);
    expect(todayReasonSchema.safeParse({ code: 'deload-offered', values: { trigger: 'readiness' } }).success).toBe(true);
    expect(deloadStateSchema.safeParse({ state: 'offered', trigger: 'readiness', reason: 'r', endsOn: null }).success).toBe(true);
  });
});
