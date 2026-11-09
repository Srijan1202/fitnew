/**
 * Beta 6.1 (E3): one lift's whole history, for its History screen. Display
 * only — the progression engine never reads this.
 *
 * Per session: the top set (heaviest, then most reps), the best estimated
 * 1RM (Epley, as everywhere on Progress), the volume (kg × reps) and the
 * reps. A session is a `record` when its best estimate beats every earlier
 * session's. Bodyweight sets (no weight) count reps only.
 */
import { estimate1RM } from '../training/progression.js';

export interface LiftSet {
  readonly setIndex: number;
  readonly weightKg: number | null;
  readonly reps: number;
  readonly rir: number | null;
}

export interface LiftSession {
  readonly sessionId: string;
  /** Local yyyy-mm-dd. */
  readonly date: string;
  readonly sets: readonly LiftSet[];
}

export interface LiftSessionSummary extends LiftSession {
  readonly topSet: { readonly weightKg: number; readonly reps: number } | null;
  readonly estimated1RmKg: number | null;
  readonly volumeKg: number;
  readonly reps: number;
  readonly record: boolean;
}

export interface LiftHistory {
  /** Newest first. */
  readonly sessions: LiftSessionSummary[];
  readonly best: { readonly estimated1RmKg: number; readonly date: string } | null;
}

/** [sessions] in any order; the answer is newest first. */
export function liftHistory(sessions: readonly LiftSession[]): LiftHistory {
  const oldestFirst = [...sessions].sort((a, b) => a.date.localeCompare(b.date) || a.sessionId.localeCompare(b.sessionId));
  let best: LiftHistory['best'] = null;
  const out = oldestFirst.map((s): LiftSessionSummary => {
    let topSet: LiftSessionSummary['topSet'] = null;
    let e1rm: number | null = null;
    let volume = 0;
    let reps = 0;
    for (const set of s.sets) {
      reps += set.reps;
      const w = set.weightKg ?? 0;
      if (w <= 0 || set.reps < 1) continue;
      volume += w * set.reps;
      if (topSet === null || w > topSet.weightKg || (w === topSet.weightKg && set.reps > topSet.reps)) topSet = { weightKg: w, reps: set.reps };
      const e = estimate1RM(w, set.reps);
      if (e1rm === null || e > e1rm) e1rm = e;
    }
    const record = e1rm !== null && (best === null || e1rm > best.estimated1RmKg);
    if (record) best = { estimated1RmKg: e1rm!, date: s.date };
    return { ...s, topSet, estimated1RmKg: e1rm, volumeKg: Math.round(volume * 10) / 10, reps, record };
  });
  return { sessions: out.reverse(), best };
}
