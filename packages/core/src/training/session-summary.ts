/**
 * What a session amounted to (Phase 5). Pure arithmetic over logged sets:
 * duration, set counts, tonnage, hard sets per muscle. Hand-checkable and
 * tested against a hand calculation.
 *
 * Hard sets use the same weighting the generator plans with: a working set
 * counts 1 for each primary muscle and 0.5 for each secondary (§9.2
 * `exercise_muscles.contribution`). Warm-ups, drop sets and back-off sets
 * never count as hard sets; tonnage includes every set that moved a load
 * except warm-ups.
 */
import type { MuscleGroup } from './generator.js';
import { MUSCLE_GROUPS, SECONDARY_CONTRIBUTION } from './generator.js';
import type { LoggedSet } from './records.js';

export interface SummaryExercise {
  readonly exerciseId: string;
  readonly name: string;
  readonly primaryMuscles: readonly MuscleGroup[];
  readonly secondaryMuscles: readonly MuscleGroup[];
  readonly sets: readonly LoggedSet[];
}

export interface SummaryInput {
  readonly startedAt: string;
  readonly completedAt: string;
  readonly exercises: readonly SummaryExercise[];
}

export interface SessionSummary {
  readonly durationSeconds: number;
  readonly totalSets: number;
  readonly workingSets: number;
  readonly tonnageKg: number;
  readonly hardSetsByMuscle: Readonly<Record<MuscleGroup, number>>;
  /** Exercises with at least one working set. */
  readonly exercisesCompleted: number;
  /** Exercises in the session with no working set logged. */
  readonly exercisesSkipped: number;
}

const round1 = (n: number): number => Math.round(n * 10) / 10;

export function summarizeSession(input: SummaryInput): SessionSummary {
  const started = Date.parse(input.startedAt);
  const completed = Date.parse(input.completedAt);
  const durationSeconds = Number.isFinite(started) && Number.isFinite(completed) ? Math.max(0, Math.round((completed - started) / 1000)) : 0;

  const hard = {} as Record<MuscleGroup, number>;
  for (const m of MUSCLE_GROUPS) hard[m] = 0;
  let totalSets = 0;
  let workingSets = 0;
  let tonnage = 0;
  let completedExercises = 0;

  for (const x of input.exercises) {
    let workingHere = 0;
    for (const s of x.sets) {
      totalSets += 1;
      if (s.setType !== 'warmup' && s.weightKg !== null) tonnage += s.weightKg * s.reps;
      if (s.setType !== 'working') continue;
      workingSets += 1;
      workingHere += 1;
      for (const m of x.primaryMuscles) hard[m] += 1;
      for (const m of x.secondaryMuscles) hard[m] += SECONDARY_CONTRIBUTION;
    }
    if (workingHere > 0) completedExercises += 1;
  }

  return {
    durationSeconds,
    totalSets,
    workingSets,
    tonnageKg: round1(tonnage),
    hardSetsByMuscle: hard,
    exercisesCompleted: completedExercises,
    exercisesSkipped: input.exercises.length - completedExercises,
  };
}
