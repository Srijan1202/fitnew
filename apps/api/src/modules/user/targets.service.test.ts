import { describe, expect, it } from 'vitest';

import type { ProfileBundle } from './repository.js';
import { ageYears, targetInputFrom, todayIn } from './targets.service.js';

describe('todayIn — "today" is the user’s day, not the server’s (§9.1)', () => {
  // 2026-09-21T20:30Z is the 21st in London but already the 22nd in Kolkata
  // (UTC+5:30) and still the 21st in New York.
  const instant = new Date('2026-09-21T20:30:00Z');

  it('rolls the date at the user’s midnight', () => {
    expect(todayIn('Asia/Kolkata', instant)).toBe('2026-09-22');
    expect(todayIn('Europe/London', instant)).toBe('2026-09-21');
    expect(todayIn('America/New_York', instant)).toBe('2026-09-21');
    expect(todayIn('UTC', instant)).toBe('2026-09-21');
  });

  it('always yields yyyy-mm-dd', () => {
    expect(todayIn('Asia/Kolkata')).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

describe('ageYears — the 18+ gate must be exact to the day', () => {
  it('counts a birthday that has happened this year', () => {
    expect(ageYears('2008-09-21', '2026-09-21')).toBe(18); // 18th birthday today
    expect(ageYears('2008-09-20', '2026-09-21')).toBe(18); // yesterday
  });

  it('does not count a birthday that has not happened yet this year', () => {
    expect(ageYears('2008-09-22', '2026-09-21')).toBe(17); // tomorrow — still 17
    expect(ageYears('2008-12-01', '2026-09-21')).toBe(17);
  });

  it('handles month boundaries and leap days', () => {
    expect(ageYears('2000-02-29', '2026-02-28')).toBe(25);
    expect(ageYears('2000-02-29', '2026-03-01')).toBe(26);
  });
});

describe('targetInputFrom — names exactly what the engine still lacks', () => {
  const user = { displayName: null, timezone: 'Asia/Kolkata', locale: 'en-IN' };
  const empty: ProfileBundle = {
    user,
    profile: null,
    goal: null,
    diet: null,
    allergies: [],
    preferences: null,
    latestWeight: null,
    targets: null,
  };
  const goal = { id: 'g', userId: 'u', goalType: 'muscle-gain' as const, targetWeightKg: null, startedAt: new Date(), endedAt: null };
  const weight = { id: 'w', userId: 'u', measuredOn: '2026-09-21', weightKg: '59.00', source: 'onboarding' as const, createdAt: new Date(), deletedAt: null };
  const profile = {
    userId: 'u', sex: 'female' as const, birthDate: '2006-01-15', heightCm: '163.0',
    experienceLevel: 'beginner' as const, trainingDaysPerWeek: 4, activityLevel: 'light' as const,
    preferredSessionMinutes: null, trainingLocation: 'campus-gym' as const, equipment: ['dumbbell' as const],
    isVitStudent: true, messProviderId: null, messHostelId: null, messMessId: null,
    onboardingStage: 'food' as const, createdAt: new Date(), updatedAt: new Date(),
  };

  it('reports missing pieces in the order onboarding collects them', () => {
    expect(targetInputFrom(empty)).toEqual({ missing: 'profile' });
    expect(targetInputFrom({ ...empty, profile })).toEqual({ missing: 'goal' });
    expect(targetInputFrom({ ...empty, profile, goal })).toEqual({ missing: 'weight' });
    expect(targetInputFrom({ ...empty, profile: { ...profile, activityLevel: null }, goal, latestWeight: weight })).toEqual({ missing: 'activityLevel' });
  });

  it('assembles the engine input, converting numerics and computing age in the user zone', () => {
    const r = targetInputFrom({ ...empty, profile, goal, latestWeight: weight });
    expect('input' in r).toBe(true);
    if ('input' in r) {
      expect(r.input).toEqual({
        sex: 'female',
        ageYears: ageYears('2006-01-15', todayIn('Asia/Kolkata')),
        heightCm: 163,
        weightKg: 59,
        activity: 'light',
        goal: 'muscle-gain',
        trainingDaysPerWeek: 4,
      });
      expect(typeof r.input.heightCm).toBe('number'); // numeric columns arrive as strings
    }
  });
});
