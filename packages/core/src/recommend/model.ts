/**
 * Pieces of `UserModel` assembly that carry business rules (Phase 11,
 * ADR-017). The API gathers the facts from its own data and calls these, so
 * the rules are pure, tested once, and never re-implemented per caller.
 */
import type { TrainingState } from './engine.js';

/** One planned exercise of today's session, as the API knows it (`/training/today`). */
export interface PlannedExerciseFacts {
  readonly exerciseId: string;
  readonly exerciseName: string;
  /** Its progression decision for today, if any. */
  readonly progression: { readonly action: string; readonly weightKg: number | null; readonly repTarget: string } | null;
  /**
   * Body parts of the user's ACTIVE limitations that rule this exercise out
   * (limitation × `exercise_contraindications`); empty when it is not ruled out.
   */
  readonly ruledOutBy: readonly string[];
  /** The library's safer swap when it is ruled out (`substitution.alternative`), else null. */
  readonly swap: { readonly exerciseId: string; readonly exerciseName: string } | null;
}

/**
 * Today's load increases and limitation swaps, in plan order.
 *
 * Owner Q1: an exercise ruled out by an active limitation never produces a
 * load increase — it is left out of `increaseLoad` here, before the engine
 * sees it, whether or not a safer swap exists. The engine keeps a single
 * limitation rule (`injured-limitation`, P1).
 */
export function trainingFromPlan(
  exercises: readonly PlannedExerciseFacts[],
): Pick<TrainingState, 'increaseLoad' | 'limitationSwaps'> {
  const ruledOut = (e: PlannedExerciseFacts): boolean => e.ruledOutBy.length > 0;
  return {
    increaseLoad: exercises
      .filter((e) => !ruledOut(e) && e.progression?.action === 'increase-load')
      .map((e) => ({ exerciseId: e.exerciseId, exerciseName: e.exerciseName, weightKg: e.progression!.weightKg, repTarget: e.progression!.repTarget })),
    limitationSwaps: exercises.filter(ruledOut).map((e) => ({
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      bodyParts: [...e.ruledOutBy].sort(),
      alternativeId: e.swap?.exerciseId ?? null,
      alternativeName: e.swap?.exerciseName ?? null,
    })),
  };
}
