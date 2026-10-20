/**
 * Readiness assembly (Phase 13, §18; ADR-019): the user's own rows → core's
 * `readinessOn` / `lowReadinessRun`. No rule lives here; every number is
 * core's. Used by Recovery (the display), by the deload state (the
 * three-day escalation) and by TODAY (the recovery fields).
 */
import { addDays } from '@fitos/core/nutrition/log';
import {
  ADHERENCE_WINDOW_DAYS,
  LOW_READINESS_RUN_MAX,
  SLEEP_WINDOW_DAYS,
  lowReadinessRun,
  readinessOn,
  type Readiness,
} from '@fitos/core/recovery/readiness';
import type { SessionLog } from '@fitos/core/training/progression';

import type { DatabaseHandle } from '../../db/client.js';
import { ProgressRepository } from '../progress/repository.js';
import { TrainingRepository, type ProgramBundle } from '../training/repository.js';
import { ProgressionAssembler, localDate } from '../workout/progression.js';
import { WorkoutRepository, type PriorWork } from '../workout/repository.js';
import { RecoveryRepository, toCheckIn } from './repository.js';

/** What the deload state needs from recovery (kept narrow so workout does not depend on the rest). */
export interface LowReadinessSource {
  lowDays(userId: string, today: string, tz: string, known: { program: ProgramBundle | null; prior: readonly PriorWork[] }): Promise<number>;
}

export interface ReadinessAssessment {
  readonly readiness: Readiness | null;
  readonly lowDays: number;
}

const num = (s: string | null): number | null => (s === null ? null : Number(s));

export class ReadinessAssembler implements LowReadinessSource {
  constructor(
    private readonly recovery: RecoveryRepository,
    private readonly workout: WorkoutRepository,
    private readonly training: TrainingRepository,
    private readonly progress: ProgressRepository,
  ) {}

  static forDb(db: DatabaseHandle['db']): ReadinessAssembler {
    return new ReadinessAssembler(new RecoveryRepository(db), new WorkoutRepository(db), new TrainingRepository(db), new ProgressRepository(db));
  }

  /**
   * Per programme lift, its completed sessions as core reads them — deload-week
   * sessions left out, exactly as Phase 6 does (owner 12.4). Oldest first.
   */
  static lifts(program: ProgramBundle | null, prior: readonly PriorWork[], tz: string): SessionLog[][] {
    const window = ProgressionAssembler.deloadWindow(program);
    const by = new Map<string, SessionLog[]>();
    for (const p of prior) {
      if (window !== null && p.completedAt >= window.startedAt && p.completedAt < window.endsAt) continue;
      const list = by.get(p.exerciseId) ?? [];
      list.push({ date: localDate(p.completedAt, tz), sets: p.sets.map((s) => ({ weightKg: num(s.weightKg) ?? 0, reps: s.reps, rir: s.rir })) });
      by.set(p.exerciseId, list);
    }
    return [...by.values()].map((l) => l.reverse());
  }

  /**
   * Today's readiness and the run of days under 35. Cheap when there is
   * nothing to judge: no check-in today or yesterday reads nothing else.
   */
  async assess(
    userId: string,
    today: string,
    tz: string,
    known?: { program: ProgramBundle | null; prior: readonly PriorWork[] },
  ): Promise<ReadinessAssessment> {
    // The run reaches back LOW_READINESS_RUN_MAX days from yesterday at most; each day's sleep window 6 more.
    const oldest = addDays(today, -(LOW_READINESS_RUN_MAX + SLEEP_WINDOW_DAYS));
    const checkIns = (await this.recovery.checkIns(userId, oldest, today)).map(toCheckIn);
    const dates = new Set(checkIns.map((c) => c.date));
    if (!dates.has(today) && !dates.has(addDays(today, -1))) return { readiness: null, lowDays: 0 };

    // The programme and its history, and the food, are independent reads: run them together.
    const training = async (): Promise<{ program: ProgramBundle | null; prior: readonly PriorWork[] }> => {
      if (known !== undefined) return known;
      const program = await this.training.activeProgram(userId);
      const prior = program === null ? [] : await this.workout.priorWork(userId, [...new Set(program.exercises.map((x) => x.exerciseId))]);
      return { program, prior };
    };
    const [{ program, prior }, nutritionDays, targets] = await Promise.all([
      training(),
      this.progress.nutritionDays(userId, addDays(oldest, -ADHERENCE_WINDOW_DAYS), addDays(today, -1)),
      this.progress.targets(userId),
    ]);
    const lifts = ReadinessAssembler.lifts(program, prior, tz);

    const memo = new Map<string, Readiness | null>();
    const on = (day: string): Readiness | null => {
      if (!memo.has(day)) memo.set(day, readinessOn({ day, checkIns, lifts, nutritionDays, targets }));
      return memo.get(day)!;
    };
    return { readiness: on(today), lowDays: lowReadinessRun((d) => on(d)?.score ?? null, today) };
  }

  async lowDays(userId: string, today: string, tz: string, known: { program: ProgramBundle | null; prior: readonly PriorWork[] }): Promise<number> {
    return (await this.assess(userId, today, tz, known)).lowDays;
  }
}
