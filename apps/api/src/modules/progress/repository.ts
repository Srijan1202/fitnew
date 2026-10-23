/**
 * Progress reads and writes (Phase 12, ADR-018). Drizzle only; every query
 * is scoped to one user and excludes soft-deleted rows. Reads are indexed
 * range queries the service runs in parallel — no per-row follow-ups.
 */
import { and, asc, desc, eq, gt, gte, isNull, lte, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  bodyMeasurements,
  bodyMetrics,
  dailyNutrition,
  exercisePrs,
  exercises,
  nutritionTargets,
  programDays,
  programs,
  sessionExercises,
  setLogs,
  userRewards,
  users,
  workoutSessions,
  type BodyMeasurementRow,
  type BodyMetricRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

const asDate = (v: string | Date): Date => (v instanceof Date ? v : new Date(v));

export class ProgressRepository {
  constructor(private readonly db: Db) {}

  /* ------------------------------------------------------------ reads -- */

  /** Every live weight reading, oldest first — the EWMA needs the whole history. */
  async weights(userId: string): Promise<{ date: string; kg: number }[]> {
    const rows = await this.db
      .select({ date: bodyMetrics.measuredOn, kg: bodyMetrics.weightKg })
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), isNull(bodyMetrics.deletedAt)))
      .orderBy(asc(bodyMetrics.measuredOn));
    return rows.map((r) => ({ date: r.date, kg: Number(r.kg) }));
  }

  /** Every live measurement (all sites), oldest first. A person has few. */
  async measurements(userId: string): Promise<{ date: string; site: BodyMeasurementRow['site']; valueCm: number }[]> {
    const rows = await this.db
      .select({ date: bodyMeasurements.measuredOn, site: bodyMeasurements.site, valueCm: bodyMeasurements.valueCm })
      .from(bodyMeasurements)
      .where(and(eq(bodyMeasurements.userId, userId), isNull(bodyMeasurements.deletedAt)))
      .orderBy(asc(bodyMeasurements.measuredOn));
    return rows.map((r) => ({ date: r.date, site: r.site, valueCm: Number(r.valueCm) }));
  }

  /** The day cache (§9.4) for local dates in [from, to]. */
  async nutritionDays(userId: string, from: string, to: string): Promise<{ date: string; itemCount: number; kcalLow: number; kcalHigh: number; proteinHigh: number }[]> {
    const rows = await this.db
      .select({
        date: dailyNutrition.localDate,
        itemCount: dailyNutrition.itemCount,
        kcalLow: dailyNutrition.kcalLow,
        kcalHigh: dailyNutrition.kcalHigh,
        proteinHigh: dailyNutrition.proteinHigh,
      })
      .from(dailyNutrition)
      .where(and(eq(dailyNutrition.userId, userId), gte(dailyNutrition.localDate, from), lte(dailyNutrition.localDate, to)));
    return rows.map((r) => ({ date: r.date, itemCount: r.itemCount, kcalLow: Number(r.kcalLow), kcalHigh: Number(r.kcalHigh), proteinHigh: Number(r.proteinHigh) }));
  }

  /** Every target row, oldest first (the one in effect on a day is the latest effective_from ≤ it, then the latest created). */
  async targets(userId: string): Promise<{ effectiveFrom: string; kcal: number; proteinG: number }[]> {
    return this.db
      .select({ effectiveFrom: nutritionTargets.effectiveFrom, kcal: nutritionTargets.kcal, proteinG: nutritionTargets.proteinG })
      .from(nutritionTargets)
      .where(eq(nutritionTargets.userId, userId))
      .orderBy(asc(nutritionTargets.effectiveFrom), asc(nutritionTargets.createdAt));
  }

  /** Completion instants of completed sessions in [from, to] (the caller keeps the local window). */
  async completedAt(userId: string, from: Date, to: Date): Promise<Date[]> {
    const rows = await this.db
      .select({ at: workoutSessions.completedAt })
      .from(workoutSessions)
      .where(
        and(
          eq(workoutSessions.userId, userId),
          eq(workoutSessions.status, 'completed'),
          isNull(workoutSessions.deletedAt),
          gte(workoutSessions.completedAt, from),
          lte(workoutSessions.completedAt, to),
        ),
      );
    return rows.flatMap((r) => (r.at === null ? [] : [asDate(r.at)]));
  }

  /** ISO weekdays (1–7) of the active programme's training days; null without a programme. */
  async plannedDays(userId: string): Promise<number[] | null> {
    const [program] = await this.db
      .select({ id: programs.id })
      .from(programs)
      .where(and(eq(programs.userId, userId), eq(programs.active, true), isNull(programs.deletedAt)))
      .limit(1);
    if (program === undefined) return null;
    const days = await this.db
      .select({ dow: programDays.dayOfWeek })
      .from(programDays)
      .where(and(eq(programDays.programId, program.id), eq(programDays.isRest, false)));
    return days.map((d) => d.dow).sort((a, b) => a - b);
  }

  /** Beta 3.3: days with any food logged in [from, to]. */
  async loggedDays(userId: string, from: string, to: string): Promise<string[]> {
    const rows = await this.db
      .select({ date: dailyNutrition.localDate })
      .from(dailyNutrition)
      .where(and(eq(dailyNutrition.userId, userId), gte(dailyNutrition.localDate, from), lte(dailyNutrition.localDate, to), gt(dailyNutrition.itemCount, 0)));
    return rows.map((r) => r.date);
  }

  /** Beta 3.4: records each reward not yet earned; returns the ones earned just now. */
  async grantRewards(userId: string, rewards: readonly string[]): Promise<string[]> {
    if (rewards.length === 0) return [];
    const rows = await this.db
      .insert(userRewards)
      .values(rewards.map((reward) => ({ userId, reward })))
      .onConflictDoNothing()
      .returning({ reward: userRewards.reward });
    const fresh = new Set(rows.map((r) => r.reward));
    return rewards.filter((r) => fresh.has(r));
  }

  /** Beta 3.3: when the account started, and the day the active programme last skipped (ADR-030). */
  async streakContext(userId: string): Promise<{ createdAt: Date; skippedOn: string | null }> {
    const [user] = await this.db.select({ createdAt: users.createdAt }).from(users).where(eq(users.id, userId)).limit(1);
    const [program] = await this.db
      .select({ skippedOn: programs.skippedOn })
      .from(programs)
      .where(and(eq(programs.userId, userId), eq(programs.active, true), isNull(programs.deletedAt)))
      .limit(1);
    return { createdAt: asDate(user!.createdAt), skippedOn: program?.skippedOn ?? null };
  }

  /** Records achieved in [from, to], newest first, with the lift's name. */
  async prs(userId: string, from: Date, to: Date): Promise<{ id: string; exerciseId: string; exerciseName: string; prType: 'weight' | 'reps' | '1rm_est' | 'volume'; value: number; previous: number; reason: string; achievedAt: Date }[]> {
    const rows = await this.db
      .select({
        id: exercisePrs.id,
        exerciseId: exercisePrs.exerciseId,
        exerciseName: exercises.name,
        prType: exercisePrs.prType,
        value: exercisePrs.value,
        previous: exercisePrs.previous,
        reason: exercisePrs.reason,
        achievedAt: exercisePrs.achievedAt,
      })
      .from(exercisePrs)
      .innerJoin(exercises, eq(exercises.id, exercisePrs.exerciseId))
      .where(and(eq(exercisePrs.userId, userId), gte(exercisePrs.achievedAt, from), lte(exercisePrs.achievedAt, to)))
      .orderBy(desc(exercisePrs.achievedAt), asc(exercisePrs.id));
    return rows.map((r) => ({ ...r, value: Number(r.value), previous: Number(r.previous) }));
  }

  /** Loaded working sets of completed sessions in [from, to], with the lift's name. */
  async workingSets(userId: string, from: Date, to: Date): Promise<{ exerciseId: string; exerciseName: string; completedAt: Date; weightKg: number; reps: number }[]> {
    const rows = await this.db
      .select({
        exerciseId: sessionExercises.exerciseId,
        exerciseName: exercises.name,
        completedAt: sql<Date>`${workoutSessions.completedAt}`.mapWith(asDate),
        weightKg: setLogs.weightKg,
        reps: setLogs.reps,
      })
      .from(setLogs)
      .innerJoin(sessionExercises, eq(sessionExercises.id, setLogs.sessionExerciseId))
      .innerJoin(workoutSessions, eq(workoutSessions.id, sessionExercises.sessionId))
      .innerJoin(exercises, eq(exercises.id, sessionExercises.exerciseId))
      .where(
        and(
          eq(workoutSessions.userId, userId),
          eq(workoutSessions.status, 'completed'),
          isNull(workoutSessions.deletedAt),
          isNull(sessionExercises.removedAt),
          isNull(setLogs.deletedAt),
          eq(setLogs.setType, 'working'),
          sql`${setLogs.weightKg} > 0`,
          gte(workoutSessions.completedAt, from),
          lte(workoutSessions.completedAt, to),
        ),
      );
    return rows.map((r) => ({ ...r, weightKg: Number(r.weightKg) }));
  }

  /* ----------------------------------------------------------- writes -- */

  /**
   * One reading per local day: a new date inserts, the same date replaces
   * (a soft-deleted row comes back). `created` says which. Never touches
   * the nutrition targets (owner D5).
   */
  async upsertWeight(userId: string, date: string, weightKg: number): Promise<{ row: BodyMetricRow; created: boolean }> {
    return this.db.transaction(async (tx) => {
      const [before] = await tx
        .select({ deletedAt: bodyMetrics.deletedAt })
        .from(bodyMetrics)
        .where(and(eq(bodyMetrics.userId, userId), eq(bodyMetrics.measuredOn, date)))
        .for('update');
      const [row] = await tx
        .insert(bodyMetrics)
        .values({ userId, measuredOn: date, weightKg: weightKg.toFixed(2), source: 'manual' })
        .onConflictDoUpdate({
          target: [bodyMetrics.userId, bodyMetrics.measuredOn],
          set: { weightKg: weightKg.toFixed(2), source: 'manual', deletedAt: null },
        })
        .returning();
      return { row: row!, created: before === undefined || before.deletedAt !== null };
    });
  }

  /** One reading per local day and site: the same semantics as [upsertWeight]. */
  async upsertMeasurement(
    userId: string,
    date: string,
    site: BodyMeasurementRow['site'],
    valueCm: number,
  ): Promise<{ row: BodyMeasurementRow; created: boolean }> {
    return this.db.transaction(async (tx) => {
      const [before] = await tx
        .select({ deletedAt: bodyMeasurements.deletedAt })
        .from(bodyMeasurements)
        .where(and(eq(bodyMeasurements.userId, userId), eq(bodyMeasurements.measuredOn, date), eq(bodyMeasurements.site, site)))
        .for('update');
      const [row] = await tx
        .insert(bodyMeasurements)
        .values({ userId, measuredOn: date, site, valueCm: valueCm.toFixed(1) })
        .onConflictDoUpdate({
          target: [bodyMeasurements.userId, bodyMeasurements.measuredOn, bodyMeasurements.site],
          set: { valueCm: valueCm.toFixed(1), deletedAt: null, updatedAt: sql`now()` },
        })
        .returning();
      return { row: row!, created: before === undefined || before.deletedAt !== null };
    });
  }
}
