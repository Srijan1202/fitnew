import { describe, expect, it } from 'vitest';
import {
  customExerciseSchema,
  generateProgramRequestSchema,
  patchProgramDayRequestSchema,
  putProgramRequestSchema,
} from './training.js';

const ex = { exerciseId: '11111111-1111-4111-8111-111111111111', setCount: 3, repMin: 6, repMax: 12, targetRir: 2 };

describe('custom programme', () => {
  it('requires 2–6 distinct training days, each with at least one exercise', () => {
    const ok = putProgramRequestSchema.safeParse({
      name: 'Mine',
      days: [
        { dayOfWeek: 1, sessionName: 'A', exercises: [ex] },
        { dayOfWeek: 4, sessionName: 'B', exercises: [ex] },
      ],
    });
    expect(ok.success).toBe(true);
    expect(
      putProgramRequestSchema.safeParse({ name: 'x', days: [{ dayOfWeek: 1, sessionName: 'A', exercises: [ex] }] }).success,
    ).toBe(false);
    const dup = putProgramRequestSchema.safeParse({
      name: 'x',
      days: [
        { dayOfWeek: 2, sessionName: 'A', exercises: [ex] },
        { dayOfWeek: 2, sessionName: 'B', exercises: [ex] },
      ],
    });
    expect(dup.success).toBe(false);
    const empty = putProgramRequestSchema.safeParse({
      name: 'x',
      days: [
        { dayOfWeek: 1, sessionName: 'A', exercises: [] },
        { dayOfWeek: 4, sessionName: 'B', exercises: [ex] },
      ],
    });
    expect(empty.success).toBe(false);
  });

  it('a rep range must be ordered, and unknown keys are rejected', () => {
    expect(customExerciseSchema.safeParse({ ...ex, repMin: 12, repMax: 6 }).success).toBe(false);
    expect(customExerciseSchema.safeParse({ ...ex, weightKg: 60 }).success).toBe(false);
    expect(customExerciseSchema.safeParse({ ...ex, incrementKg: 2.5 }).success).toBe(true);
  });

  it('a day patch must change something', () => {
    expect(patchProgramDayRequestSchema.safeParse({}).success).toBe(false);
    expect(patchProgramDayRequestSchema.safeParse({ sessionName: 'Arms' }).success).toBe(true);
    expect(patchProgramDayRequestSchema.safeParse({ exercises: [] }).success).toBe(false);
  });

  it('generate accepts only the two profile overrides', () => {
    expect(generateProgramRequestSchema.safeParse({}).success).toBe(true);
    expect(generateProgramRequestSchema.safeParse({ daysPerWeek: 7 }).success).toBe(false);
    expect(generateProgramRequestSchema.safeParse({ goal: 'strength' }).success).toBe(false);
  });
});
