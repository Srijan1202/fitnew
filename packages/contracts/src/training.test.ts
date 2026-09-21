import { describe, expect, it } from 'vitest';
import {
  PROGRAM_SOURCES,
  SPLIT_TYPES,
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

  it('per-set targets: exactly setCount entries, ordered reps, nullable weight', () => {
    const set = { repsMin: 10, repsMax: 10, weightKg: 40, rir: 2 };
    expect(customExerciseSchema.safeParse({ ...ex, sets: [set, set, set] }).success).toBe(true);
    expect(customExerciseSchema.safeParse({ ...ex, sets: [set, set] }).success).toBe(false);
    expect(customExerciseSchema.safeParse({ ...ex, sets: [{ ...set, repsMin: 12, repsMax: 8 }, set, set] }).success).toBe(false);
    expect(customExerciseSchema.safeParse({ ...ex, sets: [{ ...set, weightKg: null }, set, set] }).success).toBe(true);
    expect(customExerciseSchema.safeParse({ ...ex, startingWeightKg: 42.5 }).success).toBe(true);
    expect(customExerciseSchema.safeParse({ ...ex, startingWeightKg: -1 }).success).toBe(false);
  });

  it('an edited row may name the planned exercise it continues (stable ids across auto-save)', () => {
    expect(customExerciseSchema.safeParse({ ...ex, id: '9e3d3f6a-0b7a-4a52-9a52-1f5f0f6f6f6f' }).success).toBe(true);
    expect(customExerciseSchema.safeParse({ ...ex, id: 'not-a-uuid' }).success).toBe(false);
  });

  it('a day patch must change something', () => {
    expect(patchProgramDayRequestSchema.safeParse({}).success).toBe(false);
    expect(patchProgramDayRequestSchema.safeParse({ sessionName: 'Arms' }).success).toBe(true);
    expect(patchProgramDayRequestSchema.safeParse({ exercises: [] }).success).toBe(false);
    expect(patchProgramDayRequestSchema.safeParse({ focus: ['chest'] }).success).toBe(true);
  });

  it('split types cover the generator splits, every template slug and custom; sources include template', () => {
    for (const t of ['full-body', 'upper-lower', 'push-pull-legs', 'bro-split', 'two-muscle', 'push-pull-legs-6', 'custom']) {
      expect(SPLIT_TYPES).toContain(t);
    }
    expect(PROGRAM_SOURCES).toEqual(['generated', 'template', 'custom']);
  });

  it('generate accepts only the two profile overrides', () => {
    expect(generateProgramRequestSchema.safeParse({}).success).toBe(true);
    expect(generateProgramRequestSchema.safeParse({ daysPerWeek: 7 }).success).toBe(false);
    expect(generateProgramRequestSchema.safeParse({ goal: 'strength' }).success).toBe(false);
  });
});
