/**
 * What a set row opens with when a session starts (Phase 5).
 *
 * "What you did", not "what to do": the reps target comes from the plan
 * (the top of the range, as the day screen shows it), the weight from the
 * last completed session of the same exercise when there is one, else the
 * planned weight (which may be null — the engine never invents a load).
 * Nothing here compares sessions or decides a next step; that is Phase 6's
 * `recommendProgression`.
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
   * Phase 6 (owner decision 12.1): the progression engine's answer wins
   * over "last time" — its load when it prescribes one; after an
   * `increase-load` the row opens at the bottom of the range ("work back
   * up from repMin"), otherwise at the top as before.
   */
  readonly recommendation?: ProgressionRecommendation | null;
}

export function prefillSet(input: PrefillInput): SetPrefill {
  const { planned } = input;
  const rec = input.recommendation ?? null;
  if (rec !== null && rec.weightKg !== null && rec.action !== 'establish-baseline') {
    const sameIndex = input.lastPerformance.filter((s) => s.setType === 'working')[planned.setIndex - 1] ?? null;
    return {
      setIndex: planned.setIndex,
      reps: rec.action === 'increase-load' ? planned.repsMin : planned.repsMax,
      weightKg: rec.weightKg,
      rir: rec.targetRir,
      weightSource: 'recommendation',
      lastTime: sameIndex,
    };
  }
  const working = input.lastPerformance.filter((s) => s.setType === 'working');
  const sameIndex = working[planned.setIndex - 1] ?? null;
  const loaded = working.filter((s) => s.weightKg !== null && s.weightKg > 0);
  const lastWeight =
    sameIndex?.weightKg !== null && sameIndex?.weightKg !== undefined && sameIndex.weightKg > 0
      ? sameIndex.weightKg
      : loaded.length > 0
        ? Math.max(...loaded.map((s) => s.weightKg as number))
        : null;

  if (lastWeight !== null) {
    return { setIndex: planned.setIndex, reps: planned.repsMax, weightKg: lastWeight, rir: planned.rir, weightSource: 'last-session', lastTime: sameIndex };
  }
  return {
    setIndex: planned.setIndex,
    reps: planned.repsMax,
    weightKg: planned.weightKg,
    rir: planned.rir,
    weightSource: planned.weightKg === null ? 'none' : 'plan',
    lastTime: sameIndex,
  };
}
