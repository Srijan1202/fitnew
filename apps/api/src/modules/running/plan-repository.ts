/**
 * Running plans: reads and writes (beta 4.1, ADR-039). Drizzle only; every
 * query is scoped to one user.
 */
import { and, asc, eq, gte, inArray, lte, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { plannedRuns, runningPlans, runs, type PlannedRunRow, type RunningPlanRow } from '../../db/schema.js';

type Db = DatabaseHandle['db'];
export type NewPlan = typeof runningPlans.$inferInsert;
export type NewPlannedRun = Omit<typeof plannedRuns.$inferInsert, 'planId' | 'userId'>;

export class PlanRepository {
  constructor(private readonly db: Db) {}

  async active(userId: string): Promise<RunningPlanRow | null> {
    const [row] = await this.db
      .select()
      .from(runningPlans)
      .where(and(eq(runningPlans.userId, userId), eq(runningPlans.status, 'active')))
      .limit(1);
    return row ?? null;
  }

  async runsOf(planId: string): Promise<PlannedRunRow[]> {
    return this.db.select().from(plannedRuns).where(eq(plannedRuns.planId, planId)).orderBy(asc(plannedRuns.date), asc(plannedRuns.createdAt));
  }

  /**
   * The new plan replaces the active one in one transaction: the old one is
   * stopped and its runs still to come go (the done and skipped ones stay
   * with it, for the record).
   */
  async replace(userId: string, today: string, plan: NewPlan, planned: readonly NewPlannedRun[]): Promise<RunningPlanRow> {
    return this.db.transaction(async (tx) => {
      const old = await tx
        .update(runningPlans)
        .set({ status: 'stopped', endedAt: sql`now()` })
        .where(and(eq(runningPlans.userId, userId), eq(runningPlans.status, 'active')))
        .returning({ id: runningPlans.id });
      if (old.length > 0) {
        await tx
          .delete(plannedRuns)
          .where(and(inArray(plannedRuns.planId, old.map((o) => o.id)), eq(plannedRuns.status, 'planned'), gte(plannedRuns.date, today)));
      }
      const [row] = await tx.insert(runningPlans).values(plan).returning();
      if (planned.length > 0) {
        await tx.insert(plannedRuns).values(planned.map((p) => ({ ...p, planId: row!.id, userId })));
      }
      return row!;
    });
  }

  /** Stops the active plan; its runs still to come go. False when there is none. */
  async stop(userId: string, today: string): Promise<boolean> {
    return this.db.transaction(async (tx) => {
      const old = await tx
        .update(runningPlans)
        .set({ status: 'stopped', endedAt: sql`now()` })
        .where(and(eq(runningPlans.userId, userId), eq(runningPlans.status, 'active')))
        .returning({ id: runningPlans.id });
      if (old.length === 0) return false;
      await tx.delete(plannedRuns).where(and(eq(plannedRuns.planId, old[0]!.id), eq(plannedRuns.status, 'planned'), gte(plannedRuns.date, today)));
      return true;
    });
  }

  async mine(userId: string, id: string): Promise<PlannedRunRow | null> {
    const [row] = await this.db
      .select()
      .from(plannedRuns)
      .where(and(eq(plannedRuns.userId, userId), eq(plannedRuns.id, id)))
      .limit(1);
    return row ?? null;
  }

  async update(id: string, set: Partial<Pick<PlannedRunRow, 'status' | 'date' | 'movedFrom' | 'runId'>>): Promise<PlannedRunRow> {
    const [row] = await this.db.update(plannedRuns).set(set).where(eq(plannedRuns.id, id)).returning();
    return row!;
  }

  /** The active plan's runs on a local date, in plan order. */
  async on(userId: string, date: string): Promise<PlannedRunRow[]> {
    return this.db
      .select({ p: plannedRuns })
      .from(plannedRuns)
      .innerJoin(runningPlans, eq(runningPlans.id, plannedRuns.planId))
      .where(and(eq(plannedRuns.userId, userId), eq(plannedRuns.date, date), eq(runningPlans.status, 'active')))
      .orderBy(asc(plannedRuns.createdAt))
      .then((rows) => rows.map((r) => r.p));
  }

  /** The active plan's runs between two local dates (inclusive). */
  async between(userId: string, from: string, to: string): Promise<PlannedRunRow[]> {
    return this.db
      .select({ p: plannedRuns })
      .from(plannedRuns)
      .innerJoin(runningPlans, eq(runningPlans.id, plannedRuns.planId))
      .where(and(eq(plannedRuns.userId, userId), gte(plannedRuns.date, from), lte(plannedRuns.date, to), eq(runningPlans.status, 'active')))
      .orderBy(asc(plannedRuns.date))
      .then((rows) => rows.map((r) => r.p));
  }

  /** Links a run to a planned run, if it is still planned (a race of two runs links one). */
  async link(plannedId: string, runId: string): Promise<boolean> {
    const rows = await this.db
      .update(plannedRuns)
      .set({ status: 'done', runId })
      .where(and(eq(plannedRuns.id, plannedId), eq(plannedRuns.status, 'planned')))
      .returning({ id: plannedRuns.id });
    return rows.length > 0;
  }

  /** The planned run a run did, if any. */
  async plannedFor(runId: string): Promise<string | null> {
    const [row] = await this.db.select({ id: plannedRuns.id }).from(plannedRuns).where(eq(plannedRuns.runId, runId)).limit(1);
    return row?.id ?? null;
  }

  /** A run is being deleted: the planned run it did is planned again. */
  async unlink(runId: string): Promise<void> {
    await this.db.update(plannedRuns).set({ status: 'planned', runId: null }).where(eq(plannedRuns.runId, runId));
  }

  /** Runs (local dates of their start) with minutes and effort, for running load. */
  async loads(userId: string, fromInstant: Date): Promise<{ startedAt: Date; durationSeconds: number; effort: number | null }[]> {
    return this.db
      .select({ startedAt: runs.startedAt, durationSeconds: runs.durationSeconds, effort: runs.effort })
      .from(runs)
      .where(and(eq(runs.userId, userId), gte(runs.startedAt, fromInstant)));
  }
}
