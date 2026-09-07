import { describe, expect, it } from 'vitest';
import { buildActions, topActions } from '../src/recommend/engine.js';
import type { UserModel } from '../src/recommend/engine.js';
import { recommendProgression } from '../src/training/progression.js';

const BASE: UserModel = {
  goal: 'muscle-gain',
  dietPreference: 'non-vegetarian',
  todaysSessionName: 'Pull — Back / Biceps',
  todaysSessionMinutes: 58,
  workoutCompletedToday: false,
  daysSinceLastWorkout: 1,
  neglectedMuscles: [],
  leadLiftProgression: null,
  newPrToday: null,
  kcalConsumed: 1720,
  kcalTarget: 2400,
  proteinConsumed: 92,
  proteinTarget: 150,
  nextMealSlot: 'dinner',
  messConfigured: true,
  loggedWeightToday: true,
  daysSinceWeighIn: 0,
  pendingCalorieAdjustment: null,
  stepsToday: 6000,
  weeklyAdherence: 0.86,
};

const model = (over: Partial<UserModel>): UserModel => ({ ...BASE, ...over });

describe('TODAY decision engine', () => {
  it('leads with the workout on a training day', () => {
    const [first] = buildActions(BASE);
    expect(first?.kind).toBe('start-workout');
    expect(first?.headline).toBe('Pull — Back / Biceps');
    expect(first?.detail).toContain('58');
  });

  it('surfaces the protein gap with the actual shortfall', () => {
    const protein = buildActions(BASE).find((a) => a.kind === 'eat-protein');
    expect(protein).toBeDefined();
    expect(protein?.headline).toBe('58 g protein to go'); // 150 - 92
    expect(protein?.detail).toContain('680'); // 2400 - 1720
  });

  it('puts a deload warning above everything else', () => {
    const progression = recommendProgression({
      history: [
        { date: '2026-09-01', sets: [{ weightKg: 60, reps: 10, rir: 3 }, { weightKg: 60, reps: 10, rir: 3 }, { weightKg: 60, reps: 10, rir: 3 }] },
        { date: '2026-09-04', sets: [{ weightKg: 60, reps: 9, rir: 2 }, { weightKg: 60, reps: 9, rir: 2 }, { weightKg: 60, reps: 9, rir: 2 }] },
        { date: '2026-09-08', sets: [{ weightKg: 60, reps: 8, rir: 0 }, { weightKg: 60, reps: 7, rir: 0 }, { weightKg: 60, reps: 7, rir: 0 }] },
      ],
      target: { repMin: 8, repMax: 10, targetRir: 2, sets: 3, incrementKg: 2.5 },
    });
    expect(progression.action).toBe('deload');

    const [first] = buildActions(model({ leadLiftProgression: progression }));
    expect(first?.kind).toBe('deload');
  });

  it('does not offer a rest day and a deload at the same time', () => {
    const progression = { action: 'deload' as const, weightKg: 54, repTarget: '8–10', targetRir: 4, reason: 'Fatigue.' };
    const actions = buildActions(model({ todaysSessionName: null, leadLiftProgression: progression }));
    expect(actions.some((a) => a.kind === 'deload')).toBe(true);
    expect(actions.some((a) => a.kind === 'rest-day')).toBe(false);
  });

  it('gives a rest day something to do rather than a shrug', () => {
    const rest = buildActions(model({ todaysSessionName: null, todaysSessionMinutes: null }))
      .find((a) => a.kind === 'rest-day');
    expect(rest).toBeDefined();
    expect(rest?.detail).toContain('Growth happens now');
    expect(rest?.headline).not.toContain('😴');
  });

  it('never shows both eat-protein and eat-meal', () => {
    for (const proteinConsumed of [0, 50, 92, 120, 150]) {
      const actions = buildActions(model({ proteinConsumed }));
      const eating = actions.filter((a) => a.kind === 'eat-protein' || a.kind === 'eat-meal');
      expect(eating.length).toBeLessThanOrEqual(1);
    }
  });

  it('stops nagging about food once protein is on track', () => {
    const actions = buildActions(model({ proteinConsumed: 140, kcalConsumed: 2300 }));
    expect(actions.some((a) => a.kind === 'eat-protein')).toBe(false);
    expect(actions.some((a) => a.kind === 'eat-meal')).toBe(false);
  });

  it('says nothing about food after the last meal has passed', () => {
    const actions = buildActions(model({ nextMealSlot: null, proteinConsumed: 60 }));
    expect(actions.some((a) => a.kind === 'eat-protein')).toBe(false);
  });

  it('does not ask for a weigh-in when one is already logged', () => {
    expect(buildActions(BASE).some((a) => a.kind === 'log-weight')).toBe(false);
    const stale = buildActions(model({ loggedWeightToday: false, daysSinceWeighIn: 3 }));
    expect(stale.some((a) => a.kind === 'log-weight')).toBe(true);
  });

  it('only suggests a walk on a non-training day', () => {
    const training = buildActions(model({ stepsToday: 1200 }));
    expect(training.some((a) => a.kind === 'add-steps')).toBe(false);
    const rest = buildActions(model({ stepsToday: 1200, todaysSessionName: null }));
    expect(rest.some((a) => a.kind === 'add-steps')).toBe(true);
  });

  it('reports the basis of every action so the UI can label estimates', () => {
    for (const action of buildActions(BASE)) {
      expect(['logged', 'calculated', 'estimated']).toContain(action.basis);
    }
  });

  it('caps the surface to a few actions and keeps them ordered', () => {
    const actions = topActions(
      model({
        neglectedMuscles: ['Legs'],
        newPrToday: 'Deadlift 120 kg × 5',
        loggedWeightToday: false,
        daysSinceWeighIn: 4,
        pendingCalorieAdjustment: { deltaKcal: 120, reason: 'Trend has stalled.' },
      }),
    );
    expect(actions).toHaveLength(4);
    const priorities = actions.map((a) => a.priority);
    expect([...priorities].sort((a, b) => b - a)).toEqual(priorities);
  });

  it('is deterministic for identical state', () => {
    expect(buildActions(BASE)).toEqual(buildActions(BASE));
  });
});
