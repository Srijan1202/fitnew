import { describe, expect, it } from 'vitest';

import {
  addSessionExerciseRequestSchema,
  completeSessionRequestSchema,
  logSetsRequestSchema,
  patchSessionExerciseRequestSchema,
  patchSetRequestSchema,
  sessionListQuerySchema,
  startSessionRequestSchema,
  workoutSessionSchema,
  SET_TYPES,
  SESSION_STATUSES,
  PR_TYPES,
} from './workout.js';

const uuid = (n: number) => `${String(n).padStart(8, '0')}-0000-4000-8000-000000000000`;
const at = '2026-09-21T10:00:00.000Z';

describe('workout contracts (Phase 5)', () => {
  it('vocabularies match §9.2', () => {
    expect(SET_TYPES).toEqual(['warmup', 'working', 'drop', 'backoff']);
    expect(SESSION_STATUSES).toEqual(['active', 'completed', 'abandoned']);
    expect(PR_TYPES).toEqual(['1rm_est', 'weight', 'reps', 'volume']);
  });

  it('start: client id required, programme day optional, unknown keys rejected', () => {
    expect(startSessionRequestSchema.safeParse({ clientSessionId: uuid(1), startedAt: at }).success).toBe(true);
    expect(startSessionRequestSchema.safeParse({ clientSessionId: uuid(1), programDayId: uuid(2), startedAt: at }).success).toBe(true);
    expect(startSessionRequestSchema.safeParse({ clientSessionId: 'nope', startedAt: at }).success).toBe(false);
    expect(startSessionRequestSchema.safeParse({ clientSessionId: uuid(1), startedAt: at, name: 'x' }).success).toBe(false);
  });

  it('log sets: 1–50, each names exactly one exercise id, defaults to a working set with no weight', () => {
    const base = { clientSetId: uuid(3), setIndex: 1, reps: 10, loggedAt: at };
    const ok = logSetsRequestSchema.safeParse({ sets: [{ ...base, sessionExerciseId: uuid(4) }] });
    expect(ok.success).toBe(true);
    if (ok.success) {
      expect(ok.data.sets[0]).toMatchObject({ setType: 'working', weightKg: null, rir: null });
      expect(ok.data.merge).toBe(false);
    }
    expect(logSetsRequestSchema.safeParse({ sets: [{ ...base, clientExerciseId: uuid(5) }] }).success).toBe(true);
    expect(logSetsRequestSchema.safeParse({ sets: [{ ...base }] }).success).toBe(false);
    expect(logSetsRequestSchema.safeParse({ sets: [{ ...base, sessionExerciseId: uuid(4), clientExerciseId: uuid(5) }] }).success).toBe(false);
    expect(logSetsRequestSchema.safeParse({ sets: [] }).success).toBe(false);
    expect(logSetsRequestSchema.safeParse({ sets: Array.from({ length: 51 }, (_, i) => ({ ...base, clientSetId: uuid(100 + i), sessionExerciseId: uuid(4) })) }).success).toBe(false);
    expect(logSetsRequestSchema.safeParse({ sets: [{ ...base, sessionExerciseId: uuid(4), rir: 6 }] }).success).toBe(false);
    expect(logSetsRequestSchema.safeParse({ sets: [{ ...base, sessionExerciseId: uuid(4), weightKg: -1 }] }).success).toBe(false);
  });

  it('a set patch and an exercise patch must change something', () => {
    expect(patchSetRequestSchema.safeParse({}).success).toBe(false);
    expect(patchSetRequestSchema.safeParse({ reps: 8 }).success).toBe(true);
    expect(patchSetRequestSchema.safeParse({ weightKg: null }).success).toBe(true);
    expect(patchSessionExerciseRequestSchema.safeParse({}).success).toBe(false);
    expect(patchSessionExerciseRequestSchema.safeParse({ removed: true }).success).toBe(true);
    expect(patchSessionExerciseRequestSchema.safeParse({ removed: false }).success).toBe(false);
    expect(patchSessionExerciseRequestSchema.safeParse({ supersetGroup: null }).success).toBe(true);
  });

  it('add exercise, complete, list query', () => {
    expect(addSessionExerciseRequestSchema.safeParse({ clientExerciseId: uuid(6), exerciseId: uuid(7) }).success).toBe(true);
    expect(completeSessionRequestSchema.safeParse({ completedAt: at }).success).toBe(true);
    expect(completeSessionRequestSchema.safeParse({ completedAt: at, notes: 'x'.repeat(1001) }).success).toBe(false);
    const q = sessionListQuerySchema.parse({ limit: '10' });
    expect(q.limit).toBe(10);
    expect(sessionListQuerySchema.safeParse({ limit: 51 }).success).toBe(false);
  });

  it('a session on the wire carries its client ids, targets, last performance and a nullable summary', () => {
    const session = {
      id: uuid(10), clientSessionId: uuid(11), status: 'active', programId: null, programDayId: null, name: 'Session',
      startedAt: at, completedAt: null, durationSeconds: null, notes: null, summary: null,
      exercises: [{
        id: uuid(12), clientExerciseId: uuid(13), exerciseId: uuid(14), slug: 'barbell-bench-press', name: 'Bench',
        movementPattern: 'horizontal-push', equipment: ['barbell'], difficulty: 'intermediate',
        primaryMuscles: ['chest'], secondaryMuscles: ['triceps'], incrementKg: 2.5, orderIndex: 0, supersetGroup: null,
        plannedExerciseId: null, targets: [], prefill: [], lastPerformance: null,
        sets: [{ id: uuid(15), clientSetId: uuid(16), setIndex: 1, setType: 'working', weightKg: 60, reps: 10, rir: 2, isPr: false, loggedAt: at, plannedSetId: null }],
      }],
    };
    expect(workoutSessionSchema.safeParse(session).success).toBe(true);
  });
});
