import { describe, expect, it } from 'vitest';
import { GOAL_TYPES, MIN_AGE_YEARS, goalTypeSchema } from './profile.js';
import { REQUIRED_STEPS, onboardingAnswerSchema } from './onboarding.js';

describe('goal vocabulary', () => {
  it('has exactly the six goals of spec §12.1, matching packages/core', () => {
    expect([...GOAL_TYPES].sort()).toEqual(
      ['fat-loss', 'general', 'maintenance', 'muscle-gain', 'recomposition', 'strength'].sort(),
    );
    expect(goalTypeSchema.safeParse('bulk').success).toBe(false);
  });
});

describe('onboarding answers', () => {
  it('rejects an unknown step and an answer with the wrong fields for its step', () => {
    expect(onboardingAnswerSchema.safeParse({ step: 'weight', kg: 70 }).success).toBe(false);
    expect(onboardingAnswerSchema.safeParse({ step: 'goal', sex: 'male' }).success).toBe(false);
  });

  it('about requires consent — health data is not collected without it', () => {
    const base = { step: 'about', sex: 'male', birthDate: '2000-01-01', heightCm: 175, weightKg: 70 };
    expect(onboardingAnswerSchema.safeParse(base).success).toBe(false);
    expect(
      onboardingAnswerSchema.safeParse({
        ...base,
        consent: { policyVersion: '2026-09-21', types: ['privacy-policy', 'health-data-processing'] },
      }).success,
    ).toBe(true);
  });

  it('a VIT student must pick a mess; a non-student may not', () => {
    expect(onboardingAnswerSchema.safeParse({ step: 'vit', isVitStudent: true, mess: null }).success).toBe(false);
    expect(onboardingAnswerSchema.safeParse({ step: 'vit', isVitStudent: false, mess: null }).success).toBe(true);
    expect(
      onboardingAnswerSchema.safeParse({
        step: 'vit',
        isVitStudent: true,
        mess: { providerId: 'vit-vellore', hostelId: 'mens', messId: 'veg' },
      }).success,
    ).toBe(true);
  });

  it('rejects implausible bodies as typos, not people', () => {
    const consent = { policyVersion: 'v', types: ['privacy-policy'] };
    const about = (heightCm: number, weightKg: number) =>
      onboardingAnswerSchema.safeParse({ step: 'about', sex: 'female', birthDate: '2000-01-01', heightCm, weightKg, consent }).success;
    expect(about(163, 59)).toBe(true);
    expect(about(16, 59)).toBe(false); // metres typed as cm
    expect(about(163, 5900)).toBe(false); // grams typed as kg
  });

  it('screen 6 (vit) is the only optional step', () => {
    expect(REQUIRED_STEPS).toEqual(['goal', 'about', 'experience', 'training', 'food']);
    expect(MIN_AGE_YEARS).toBe(18);
  });
});
