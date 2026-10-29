/**
 * Running reads and writes (beta 4.0, ADR-038). Drizzle only; every query is
 * scoped to one user.
 */
import { and, desc, eq, isNull, lt, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { bodyMetrics, runs, users, type RunRow } from '../../db/schema.js';

type Db = DatabaseHandle['db'];
export type NewRun = typeof runs.$inferInsert;

export interface Totals {
  readonly runs: number;
  readonly distanceM: number;
  readonly durationSeconds: number;
}

export class RunningRepository {
  constructor(private readonly db: Db) {}

  async timezoneOf(userId: string): Promise<string> {
    const [row] = await this.db.select({ timezone: users.timezone }).from(users).where(eq(users.id, userId)).limit(1);
    return row?.timezone ?? 'Asia/Kolkata';
  }

  /** The weight on the run's day: the latest reading on or before it, else the first after. */
  async weightOn(userId: string, date: string): Promise<number | null> {
    const [row] = await this.db
      .select({ kg: bodyMetrics.weightKg })
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), isNull(bodyMetrics.deletedAt)))
      .orderBy(desc(sql`${bodyMetrics.measuredOn} <= ${date}`), sql`case when ${bodyMetrics.measuredOn} <= ${date} then ${bodyMetrics.measuredOn} end desc nulls last`, bodyMetrics.measuredOn)
      .limit(1);
    return row === undefined ? null : Number(row.kg);
  }

  /** By the phone's id, whoever owns it (the caller checks the owner). */
  async byClientId(clientRunId: string): Promise<RunRow | null> {
    const [row] = await this.db.select().from(runs).where(eq(runs.clientRunId, clientRunId)).limit(1);
    return row ?? null;
  }

  /** Beta 4.5: the run imported from this Health Connect record, if any. */
  async byExternalId(userId: string, externalId: string): Promise<RunRow | null> {
    const [row] = await this.db
      .select()
      .from(runs)
      .where(and(eq(runs.userId, userId), eq(runs.externalId, externalId)))
      .limit(1);
    return row ?? null;
  }

  async mine(userId: string, clientRunId: string): Promise<RunRow | null> {
    const [row] = await this.db
      .select()
      .from(runs)
      .where(and(eq(runs.userId, userId), eq(runs.clientRunId, clientRunId)))
      .limit(1);
    return row ?? null;
  }

  /** Inserts once: a replay of the same client id inserts nothing and returns null. */
  async insert(values: NewRun): Promise<RunRow | null> {
    const [row] = await this.db.insert(runs).values(values).onConflictDoNothing({ target: runs.clientRunId }).returning();
    return row ?? null;
  }

  /** Newest first; `before` is a `started_at` (exclusive). */
  async page(userId: string, before: Date | null, limit: number): Promise<RunRow[]> {
    return this.db
      .select()
      .from(runs)
      .where(and(eq(runs.userId, userId), before === null ? undefined : lt(runs.startedAt, before)))
      .orderBy(desc(runs.startedAt), desc(runs.id))
      .limit(limit);
  }

  /** Runs that started on or after a local date, in the user's timezone. */
  async totalsSince(userId: string, timeZone: string, fromDate: string): Promise<Totals> {
    const [row] = await this.db
      .select({
        runs: sql<number>`count(*)::int`,
        distanceM: sql<string>`coalesce(sum(${runs.distanceM}), 0)`,
        durationSeconds: sql<number>`coalesce(sum(${runs.durationSeconds}), 0)::int`,
      })
      .from(runs)
      .where(and(eq(runs.userId, userId), sql`(${runs.startedAt} at time zone ${timeZone})::date >= ${fromDate}::date`));
    return { runs: row!.runs, distanceM: Number(row!.distanceM), durationSeconds: row!.durationSeconds };
  }

  async patch(userId: string, clientRunId: string, set: Partial<Pick<RunRow, 'name' | 'note' | 'effort'>>): Promise<RunRow | null> {
    const [row] = await this.db
      .update(runs)
      .set({ ...set, updatedAt: sql`now()` })
      .where(and(eq(runs.userId, userId), eq(runs.clientRunId, clientRunId)))
      .returning();
    return row ?? null;
  }

  async remove(userId: string, clientRunId: string): Promise<boolean> {
    const rows = await this.db
      .delete(runs)
      .where(and(eq(runs.userId, userId), eq(runs.clientRunId, clientRunId)))
      .returning({ id: runs.id });
    return rows.length > 0;
  }
}
