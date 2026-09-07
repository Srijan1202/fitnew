/**
 * Progressive overload. Fully deterministic — given the same history this
 * always returns the same recommendation, and always returns the reason.
 *
 * Model: double progression with RIR-based autoregulation.
 *  - Work up the rep range at a fixed load.
 *  - Once every working set hits the top of the range at or below target RIR,
 *    add the smallest useful increment and drop back to the bottom of the range.
 *  - If performance regresses across consecutive sessions, do NOT add load.
 *    Repeated regression plus RIR drift is a fatigue signal, not a motivation
 *    problem, and the correct response is a deload.
 */

export interface SetLog {
  readonly weightKg: number;
  readonly reps: number;
  /** Reps in reserve the user reported. Null when they didn't record it. */
  readonly rir: number | null;
}

export interface SessionLog {
  readonly date: string; // ISO yyyy-mm-dd
  readonly sets: readonly SetLog[];
}

export interface ExerciseTarget {
  readonly repMin: number;
  readonly repMax: number;
  readonly targetRir: number;
  readonly sets: number;
  /** Smallest plate jump available. Upper body typically 2.5 kg, lower 5 kg. */
  readonly incrementKg: number;
}

export type ProgressionAction =
  | 'increase-load'
  | 'add-reps'
  | 'hold'
  | 'reduce-load'
  | 'deload'
  | 'establish-baseline';

export interface ProgressionRecommendation {
  readonly action: ProgressionAction;
  readonly weightKg: number | null;
  readonly repTarget: string;
  readonly targetRir: number;
  /** Plain-language justification. Rendered verbatim; an LLM may rephrase it. */
  readonly reason: string;
}

/** Best single set of a session, by tonnage, used to compare sessions. */
function topSet(session: SessionLog): SetLog | null {
  let best: SetLog | null = null;
  for (const set of session.sets) {
    if (best === null || set.weightKg * set.reps > best.weightKg * best.reps) best = set;
  }
  return best;
}

function workingWeight(session: SessionLog): number | null {
  const weights = session.sets.map((s) => s.weightKg).filter((w) => w > 0);
  if (weights.length === 0) return null;
  return Math.max(...weights);
}

/** Every working set reached repMax at or below the RIR target. */
function clearedTopOfRange(session: SessionLog, target: ExerciseTarget): boolean {
  const working = workingWeight(session);
  if (working === null) return false;
  const workingSets = session.sets.filter((s) => s.weightKg === working);
  if (workingSets.length < target.sets) return false;
  return workingSets.every((s) => s.reps >= target.repMax && (s.rir === null || s.rir <= target.targetRir));
}

/** Total reps at the top working weight — the comparison metric across sessions. */
function workingReps(session: SessionLog): number {
  const working = workingWeight(session);
  if (working === null) return 0;
  return session.sets.filter((s) => s.weightKg === working).reduce((sum, s) => sum + s.reps, 0);
}

/**
 * RIR drift: the same load feeling harder over time. Two consecutive sessions
 * where mean RIR fell while reps did not improve is our fatigue trigger.
 */
function meanRir(session: SessionLog): number | null {
  const values = session.sets.map((s) => s.rir).filter((r): r is number => r !== null);
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

export interface ProgressionInput {
  /** Most recent last. Only the final three sessions influence the decision. */
  readonly history: readonly SessionLog[];
  readonly target: ExerciseTarget;
}

export function recommendProgression(input: ProgressionInput): ProgressionRecommendation {
  const { target } = input;
  const repTarget = `${target.repMin}\u2013${target.repMax}`;
  const history = [...input.history].sort((a, b) => a.date.localeCompare(b.date));
  const recent = history.slice(-3);
  const last = recent[recent.length - 1];

  if (last === undefined) {
    return {
      action: 'establish-baseline',
      weightKg: null,
      repTarget,
      targetRir: target.targetRir,
      reason: 'No history for this lift yet. Pick a weight you could do for a couple more reps than the target and log it \u2014 this session becomes your baseline.',
    };
  }

  const lastWeight = workingWeight(last);
  if (lastWeight === null) {
    return {
      action: 'establish-baseline',
      weightKg: null,
      repTarget,
      targetRir: target.targetRir,
      reason: 'Last session had no recorded working weight, so there is nothing to progress from.',
    };
  }

  // --- fatigue check runs before any load increase -------------------------
  const previous = recent[recent.length - 2];
  const beforeThat = recent[recent.length - 3];

  if (previous !== undefined && beforeThat !== undefined) {
    const sameLoad =
      workingWeight(previous) === lastWeight && workingWeight(beforeThat) === lastWeight;
    const repsDeclining =
      workingReps(last) < workingReps(previous) && workingReps(previous) <= workingReps(beforeThat);
    const lastRir = meanRir(last);
    const olderRir = meanRir(beforeThat);
    const rirDrifting = lastRir !== null && olderRir !== null && lastRir < olderRir;

    if (sameLoad && repsDeclining && rirDrifting) {
      return {
        action: 'deload',
        weightKg: Math.round(lastWeight * 0.9 * 2) / 2,
        repTarget,
        targetRir: target.targetRir + 2,
        reason: `Reps have dropped across three sessions at ${lastWeight} kg while the sets felt harder. That is accumulated fatigue, not lost strength. Take one lighter week at about 90% load and the reps come back.`,
      };
    }
    if (sameLoad && repsDeclining) {
      return {
        action: 'hold',
        weightKg: lastWeight,
        repTarget,
        targetRir: target.targetRir,
        reason: `Reps slipped at ${lastWeight} kg last session. Stay at this weight and rebuild the reps before adding load.`,
      };
    }
  }

  // --- normal progression --------------------------------------------------
  if (clearedTopOfRange(last, target)) {
    const next = Math.round((lastWeight + target.incrementKg) * 2) / 2;
    return {
      action: 'increase-load',
      weightKg: next,
      repTarget,
      targetRir: target.targetRir,
      reason: `You hit ${target.repMax} reps on every working set at ${lastWeight} kg with ${target.targetRir} RIR or less. Move to ${next} kg and work back up from ${target.repMin}.`,
    };
  }

  const best = topSet(last);
  if (best !== null && best.reps < target.repMin) {
    const reduced = Math.round(Math.max(0, lastWeight - target.incrementKg) * 2) / 2;
    return {
      action: 'reduce-load',
      weightKg: reduced,
      repTarget,
      targetRir: target.targetRir,
      reason: `Your best set at ${lastWeight} kg was ${best.reps} reps, below the ${target.repMin}-rep floor. Drop to ${reduced} kg so you are training in the intended range.`,
    };
  }

  return {
    action: 'add-reps',
    weightKg: lastWeight,
    repTarget,
    targetRir: target.targetRir,
    reason: `Stay at ${lastWeight} kg and add reps. Once all ${target.sets} sets reach ${target.repMax} at ${target.targetRir} RIR, the weight goes up.`,
  };
}

/** Epley estimated 1RM. Used for progress display only, never for prescription. */
export function estimate1RM(weightKg: number, reps: number): number {
  if (reps <= 0) return 0;
  if (reps === 1) return weightKg;
  return Number((weightKg * (1 + reps / 30)).toFixed(1));
}
