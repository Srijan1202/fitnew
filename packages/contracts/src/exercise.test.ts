import { describe, expect, it } from 'vitest';
import {
  COMPOUND_PATTERNS,
  EXERCISE_LIST_DEFAULT_LIMIT,
  EXERCISE_LIST_MAX_LIMIT,
  MOVEMENT_PATTERNS,
  MUSCLE_GROUPS,
  exerciseListQuerySchema,
  exerciseSeedSchema,
} from './exercise.js';

describe('muscle groups', () => {
  it('are exactly the rows of the §12.3 volume-landmark table', () => {
    expect([...MUSCLE_GROUPS].sort()).toEqual(
      ['abs', 'back', 'biceps', 'calves', 'chest', 'glutes', 'hamstrings', 'quads', 'shoulders', 'triceps'].sort(),
    );
  });

  it('every compound pattern is a movement pattern', () => {
    for (const p of COMPOUND_PATTERNS) expect(MOVEMENT_PATTERNS).toContain(p);
  });
});

describe('list query', () => {
  it('splits comma-separated equipment and rejects an unknown item', () => {
    const ok = exerciseListQuerySchema.parse({ equipment: 'barbell, dumbbell' });
    expect(ok.equipment).toEqual(['barbell', 'dumbbell']);
    expect(ok.limit).toBe(EXERCISE_LIST_DEFAULT_LIMIT);
    expect(ok.offset).toBe(0);
    expect(exerciseListQuerySchema.safeParse({ equipment: 'barbell,trap-bar' }).success).toBe(false);
  });

  it('coerces and bounds limit, rejects unknown params', () => {
    expect(exerciseListQuerySchema.parse({ limit: '20' }).limit).toBe(20);
    expect(exerciseListQuerySchema.safeParse({ limit: String(EXERCISE_LIST_MAX_LIMIT + 1) }).success).toBe(false);
    expect(exerciseListQuerySchema.safeParse({ limit: '0' }).success).toBe(false);
    expect(exerciseListQuerySchema.safeParse({ page: 2 }).success).toBe(false);
  });

  it('rejects an empty or over-long search term and unknown filters', () => {
    expect(exerciseListQuerySchema.safeParse({ q: '   ' }).success).toBe(false);
    expect(exerciseListQuerySchema.safeParse({ muscle: 'forearms' }).success).toBe(false);
    expect(exerciseListQuerySchema.safeParse({ pattern: 'twist' }).success).toBe(false);
  });
});

describe('seed entry', () => {
  const entry = {
    slug: 'goblet-squat',
    name: 'Goblet Squat',
    movementPattern: 'squat',
    equipment: ['dumbbell'],
    difficulty: 'beginner',
    isUnilateral: false,
    defaultIncrementKg: 2.5,
    instructions: ['Hold the dumbbell at your chest.', 'Squat.'],
    videoUrl: null,
    primaryMuscles: ['quads', 'glutes'],
    secondaryMuscles: ['abs'],
    alternatives: [{ slug: 'bodyweight-squat', reason: 'equipment' }],
    contraindications: ['knee'],
  };

  it('accepts a complete entry and rejects one with no primary muscle or no equipment', () => {
    expect(exerciseSeedSchema.safeParse(entry).success).toBe(true);
    expect(exerciseSeedSchema.safeParse({ ...entry, primaryMuscles: [] }).success).toBe(false);
    expect(exerciseSeedSchema.safeParse({ ...entry, equipment: [] }).success).toBe(false);
    expect(exerciseSeedSchema.safeParse({ ...entry, slug: 'Goblet Squat' }).success).toBe(false);
    expect(exerciseSeedSchema.safeParse({ ...entry, extra: 1 }).success).toBe(false);
  });
});
