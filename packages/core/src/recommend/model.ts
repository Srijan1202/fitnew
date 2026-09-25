/**
 * Pieces of `UserModel` assembly that carry business rules (Phase 11,
 * ADR-017). The API gathers the facts from its own data and calls these, so
 * the rules are pure, tested once, and never re-implemented per caller.
 */
import type { Goal } from '../nutrition/targets.js';
import { recommendCalorieAdjustment, summariseTrend, type WeightEntry } from '../nutrition/trend.js';
import type { CalorieAdjustmentFact, TrainingState } from './engine.js';

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

/** The goals the §13.2 policy has a target rate for; the rest hold weight (rate 0). */
function policyGoal(goal: Goal): 'muscle-gain' | 'fat-loss' | 'strength' | 'general' {
  return goal === 'muscle-gain' || goal === 'fat-loss' || goal === 'strength' ? goal : 'general';
}

/**
 * Phase 12: whether the §13.2 adjustment policy fires today, as the engine's
 * `calorie-adjust` fact. It reuses the existing deterministic pieces
 * unchanged — `summariseTrend` (EWMA, the 10-day reliability gate) and
 * `recommendCalorieAdjustment` (at most once per 7 days, only beyond
 * tolerance, a step capped at ±150 kcal). Null when there are no targets,
 * the trend is not yet reliable, or the policy does not fire.
 *
 * `daysSinceLastAdjustment` counts from the last target row this policy
 * created (null when it never has).
 */
export function calorieAdjustmentFrom(params: {
  readonly goal: Goal;
  readonly weights: readonly WeightEntry[];
  readonly targetKcal: number | null;
  readonly daysSinceLastAdjustment: number | null;
}): CalorieAdjustmentFact | null {
  if (params.targetKcal === null) return null;
  const trend = summariseTrend(params.weights);
  if (!trend.isReliable || trend.weeklyChangeKg === null || trend.currentTrendKg === null) return null;
  const decision = recommendCalorieAdjustment({
    goal: policyGoal(params.goal),
    weeklyChangeKg: trend.weeklyChangeKg,
    daysSinceLastAdjustment: params.daysSinceLastAdjustment ?? Number.MAX_SAFE_INTEGER,
    bodyweightKg: trend.currentTrendKg,
  });
  if (!decision.shouldAdjust) return null;
  return {
    currentKcal: params.targetKcal,
    newKcal: params.targetKcal + decision.deltaKcal,
    deltaKcal: decision.deltaKcal,
    weeklyChangeKg: trend.weeklyChangeKg,
  };
}
