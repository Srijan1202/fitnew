import { describe, expect, it } from 'vitest';

import type { ProfileBundle } from '../user/repository.js';
import { answeredSteps, hashIp, missingRequired, nextStage } from './service.js';

const user = { timezone: 'Asia/Kolkata', locale: 'en-IN' };
const empty: ProfileBundle = {
  user, profile: null, goal: null, diet: null, allergies: [], preferences: null, latestWeight: null, targets: null,
};
const profile = {
  userId: 'u', sex: 'male' as const, birthDate: '2000-01-01', heightCm: '175.0',
  experienceLevel: 'intermediate' as const, trainingDaysPerWeek: 4, activityLevel: 'light' as const,
  preferredSessionMinutes: null, trainingLocation: 'commercial-gym' as const, equipment: ['barbell' as const],
  isVitStudent: false, messProviderId: null, messHostelId: null, messMessId: null,
  onboardingStage: 'goal' as const, createdAt: new Date(), updatedAt: new Date(),
};
const goal = { id: 'g', userId: 'u', goalType: 'fat-loss' as const, targetWeightKg: null, startedAt: new Date(), endedAt: null };
const weight = { id: 'w', userId: 'u', measuredOn: '2026-09-21', weightKg: '80.00', source: 'onboarding' as const, createdAt: new Date(), deletedAt: null };
const diet = { userId: 'u', dietType: 'vegetarian' as const, excludedDishIds: [], budgetTier: null, createdAt: new Date(), updatedAt: new Date() };

describe('answeredSteps — derived from what is stored, never from a flag', () => {
  it('is empty for a brand-new user', () => {
    expect(answeredSteps(empty)).toEqual([]);
  });

  it('marks "about" only when sex, birth date, height AND a weight reading exist', () => {
    const noWeight = { ...empty, profile };
    expect(answeredSteps(noWeight)).not.toContain('about');
    const withWeight = { ...empty, profile, latestWeight: weight };
    expect(answeredSteps(withWeight)).toContain('about');
  });

  it('reports steps in §32 screen order regardless of the order answered', () => {
    const all = { ...empty, profile, goal, latestWeight: weight, diet };
    expect(answeredSteps(all)).toEqual(['goal', 'about', 'experience', 'training', 'food', 'vit']);
  });

  it('treats "vit" as answered for a non-student too (isVitStudent = false is an answer)', () => {
    expect(answeredSteps({ ...empty, profile: { ...profile, isVitStudent: false } })).toContain('vit');
    expect(answeredSteps({ ...empty, profile: { ...profile, isVitStudent: null } })).not.toContain('vit');
  });
});

describe('nextStage — the first unanswered screen', () => {
  it('starts at goal', () => {
    expect(nextStage([], false)).toBe('goal');
  });

  it('skips answered steps in order, so "back" and re-answering never move it backwards', () => {
    expect(nextStage(['goal'], false)).toBe('about');
    expect(nextStage(['goal', 'about', 'experience'], false)).toBe('training');
    // Answering food before training still points at the first gap.
    expect(nextStage(['goal', 'about', 'experience', 'food'], false)).toBe('training');
  });

  it('is complete once everything including the optional step is answered', () => {
    expect(nextStage(['goal', 'about', 'experience', 'training', 'food', 'vit'], false)).toBe('complete');
  });

  it('a completed profile stays complete even if a step were somehow re-opened', () => {
    expect(nextStage(['goal'], true)).toBe('complete');
  });
});

describe('missingRequired — what blocks /complete', () => {
  it('does not require vit', () => {
    expect(missingRequired(['goal', 'about', 'experience', 'training', 'food'])).toEqual([]);
  });

  it('lists every required gap', () => {
    expect(missingRequired(['goal', 'food'])).toEqual(['about', 'experience', 'training']);
  });
});

describe('hashIp', () => {
  it('is deterministic per salt and never contains the address', () => {
    const a = hashIp('203.0.113.9', 's1');
    expect(a).toBe(hashIp('203.0.113.9', 's1'));
    expect(a).not.toBe(hashIp('203.0.113.9', 's2'));
    expect(a).not.toContain('203');
    expect(a).toMatch(/^[0-9a-f]{64}$/);
  });
});
