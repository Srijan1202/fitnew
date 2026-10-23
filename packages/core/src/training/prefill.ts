/**
 * What a set row opens with when a session starts (Phase 5).
 *
 * "What you did", not "what to do" (owner, 2026-10-23, superseding 12.1 for
 * the prefill): a set opens at last time's weight AND reps for that set, so
 * the lifter starts from exactly where they left off and decides when to
 * progress. The progression engine's answer is shown beside it with a
 * one-tap "Apply" (the app), not written into the rows. Only a deload week
 * (planned, lighter) still opens at the engine's load. With no history, the
 * plan: its top reps and its weight (which may be null — the engine never
 * invents a load).
 */
import type { ProgressionRecommendation } from './progression.js';
import type { LoggedSet } from './records.js';

export interface PlannedSetTarget {
  readonly setIndex: number;
  readonly repsMin: number;
  readonly repsMax: number;
  readonly weightKg: number | null;
  readonly rir: number;
}

export interface SetPrefill {
  readonly setIndex: number;
  readonly reps: number;
  readonly weightKg: number | null;
  readonly rir: number;
  /** Where the weight came from. */
  readonly weightSource: 'recommendation' | 'last-session' | 'plan' | 'none';
  /** Last time's matching set, for the "last time: 60 kg × 10 @ 2" line. */
  readonly lastTime: LoggedSet | null;
}

export interface PrefillInput {
  readonly planned: PlannedSetTarget;
  /** Working sets of the most recent completed session for this exercise, in set order; empty when none. */
  readonly lastPerformance: readonly LoggedSet[];
  /**
   * The progression engine's answer. Only a `deload` (a planned lighter
   * week) sets the rows: its load and RIR at the plan's top reps. Any other
   * action is the app's one-tap suggestion, not the prefill (owner,
   * 2026-10-23).
   */
  readonly recommendation?: ProgressionRecommendation | null;
}

export function prefillSet(input: PrefillInput): SetPrefill {
  const { planned } = input;
  const rec = input.recommendation ?? null;
  const working = input.lastPerformance.filter((s) => s.setType === 'working');
  const sameIndex = working[planned.setIndex - 1] ?? null;
  if (rec !== null && rec.action === 'deload' && rec.weightKg !== null) {
    return { setIndex: planned.setIndex, reps: planned.repsMax, weightKg: rec.weightKg, rir: rec.targetRir, weightSource: 'recommendation', lastTime: sameIndex };
  }
  const loaded = working.filter((s) => s.weightKg !== null && s.weightKg > 0);
  const lastWeight =
    sameIndex?.weightKg !== null && sameIndex?.weightKg !== undefined && sameIndex.weightKg > 0
      ? sameIndex.weightKg
      : loaded.length > 0
        ? Math.max(...loaded.map((s) => s.weightKg as number))
        : null;
  // Last time's reps for this set; a set beyond last time's count keeps the plan's top.
  const reps = sameIndex !== null && sameIndex.reps > 0 ? sameIndex.reps : planned.repsMax;

  if (lastWeight !== null) {
    return { setIndex: planned.setIndex, reps, weightKg: lastWeight, rir: planned.rir, weightSource: 'last-session', lastTime: sameIndex };
  }
  return {
    setIndex: planned.setIndex,
    reps,
    weightKg: planned.weightKg,
    rir: planned.rir,
    weightSource: planned.weightKg === null ? 'none' : 'plan',
    lastTime: sameIndex,
  };
}
