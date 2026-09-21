/**
 * Personal records (Phase 5, §9.2 `exercise_prs`). Deterministic, no
 * dependencies: given what the user had done before and what they did in
 * this session, say which sets are records and why.
 *
 * Rules the owner approved (plan §8.1):
 *  - only `working` sets count — warm-ups, drop sets and back-off sets are
 *    stored and shown but never compete;
 *  - the first time a lift is logged is a baseline, not a record;
 *  - a tie is not a record.
 *
 * Nothing here prescribes anything. Records describe the past.
 */
import { estimate1RM } from './progression.js';

export type SetType = 'warmup' | 'working' | 'drop' | 'backoff';
export type PrType = '1rm_est' | 'weight' | 'reps' | 'volume';

export interface LoggedSet {
  /** The set_logs row id (or the client id until synced). */
  readonly id: string;
  readonly setType: SetType;
  readonly weightKg: number | null;
  readonly reps: number;
  readonly rir: number | null;
}

/** One earlier completed session's sets for the same exercise. */
export interface PriorSession {
  readonly sessionId: string;
  readonly sets: readonly LoggedSet[];
}

export interface PersonalRecord {
  readonly prType: PrType;
  /** The new best. */
  readonly value: number;
  /** What it beat. */
  readonly previous: number;
  /** The set that earned it (for `set_logs.is_pr` and `exercise_prs.set_log_id`). */
  readonly setLogId: string;
  /** Plain language, rendered verbatim. */
  readonly reason: string;
}

export interface DetectPrsInput {
  readonly prior: readonly PriorSession[];
  readonly current: readonly LoggedSet[];
}

const loaded = (s: LoggedSet): s is LoggedSet & { weightKg: number } =>
  s.setType === 'working' && s.weightKg !== null && s.weightKg > 0 && s.reps >= 1;

const round1 = (n: number): number => Math.round(n * 10) / 10;

/**
 * Records earned by `current` against everything in `prior`. Empty when
 * there is no loaded prior work (baseline) or nothing was beaten.
 */
export function detectPRs(input: DetectPrsInput): PersonalRecord[] {
  const priorSets = input.prior.flatMap((p) => p.sets).filter(loaded);
  const currentSets = input.current.filter(loaded);
  if (priorSets.length === 0 || currentSets.length === 0) return [];

  const records: PersonalRecord[] = [];

  // Heaviest weight for at least one rep.
  const bestWeight = Math.max(...priorSets.map((s) => s.weightKg));
  const heaviest = currentSets.reduce((a, b) => (b.weightKg > a.weightKg ? b : a));
  if (heaviest.weightKg > bestWeight) {
    records.push({
      prType: 'weight',
      value: heaviest.weightKg,
      previous: bestWeight,
      setLogId: heaviest.id,
      reason: `${heaviest.weightKg} kg is the most you have lifted on this exercise (previous best ${bestWeight} kg).`,
    });
  }

  // Most reps at the previous best weight (a new weight is already a record).
  const bestRepsAtBestWeight = Math.max(...priorSets.filter((s) => s.weightKg === bestWeight).map((s) => s.reps));
  const atBestWeight = currentSets.filter((s) => s.weightKg === bestWeight);
  if (atBestWeight.length > 0) {
    const most = atBestWeight.reduce((a, b) => (b.reps > a.reps ? b : a));
    if (most.reps > bestRepsAtBestWeight) {
      records.push({
        prType: 'reps',
        value: most.reps,
        previous: bestRepsAtBestWeight,
        setLogId: most.id,
        reason: `${most.reps} reps at ${bestWeight} kg beats your previous ${bestRepsAtBestWeight} at that weight.`,
      });
    }
  }

  // Estimated 1RM (Epley) — a display metric, never a prescription.
  const best1rm = Math.max(...priorSets.map((s) => estimate1RM(s.weightKg, s.reps)));
  const top1rm = currentSets.reduce((a, b) => (estimate1RM(b.weightKg, b.reps) > estimate1RM(a.weightKg, a.reps) ? b : a));
  const top1rmValue = estimate1RM(top1rm.weightKg, top1rm.reps);
  if (top1rmValue > best1rm) {
    records.push({
      prType: '1rm_est',
      value: top1rmValue,
      previous: best1rm,
      setLogId: top1rm.id,
      reason: `${top1rm.weightKg} kg × ${top1rm.reps} estimates a ${top1rmValue} kg one-rep max, up from ${best1rm} kg.`,
    });
  }

  // Session tonnage for the exercise against the best earlier session.
  const tonnage = (sets: readonly LoggedSet[]): number => round1(sets.filter(loaded).reduce((t, s) => t + s.weightKg * s.reps, 0));
  const bestVolume = Math.max(...input.prior.map((p) => tonnage(p.sets)));
  const currentVolume = tonnage(currentSets);
  if (currentVolume > bestVolume) {
    const last = currentSets[currentSets.length - 1]!;
    records.push({
      prType: 'volume',
      value: currentVolume,
      previous: bestVolume,
      setLogId: last.id,
      reason: `${currentVolume} kg of working volume on this exercise today, more than any earlier session (best ${bestVolume} kg).`,
    });
  }

  return records;
}
