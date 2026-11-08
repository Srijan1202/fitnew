/**
 * Beta 6.0 (F7, ADR-059): water reads and writes. Drizzle only; every query
 * is scoped to one user.
 */
import { and, desc, eq, getTableColumns, isNull, lte, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { bodyMetrics, waterLogs, type WaterLogRow } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export class WaterRepository {
  constructor(private readonly db: Db) {}

  async day(userId: string, date: string): Promise<WaterLogRow | null> {
    const [row] = await this.db
      .select()
      .from(waterLogs)
      .where(and(eq(waterLogs.userId, userId), eq(waterLogs.loggedOn, date)))
      .limit(1);
    return row ?? null;
  }

  /** The day's total is REPLACED by what is sent; `created` comes from the same statement. */
  async set(userId: string, date: string, ml: number): Promise<{ row: WaterLogRow; created: boolean }> {
    const [out] = await this.db
      .insert(waterLogs)
      .values({ userId, loggedOn: date, ml })
      .onConflictDoUpdate({ target: [waterLogs.userId, waterLogs.loggedOn], set: { ml, updatedAt: sql`now()` } })
      .returning({ ...getTableColumns(waterLogs), created: sql<boolean>`(xmax = 0)` });
    const { created, ...row } = out!;
    return { row, created };
  }

  /** The latest weigh-in on or before [date], in kg (null when there is none). */
  async weightOn(userId: string, date: string): Promise<number | null> {
    const [row] = await this.db
      .select({ kg: bodyMetrics.weightKg })
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), lte(bodyMetrics.measuredOn, date), isNull(bodyMetrics.deletedAt)))
      .orderBy(desc(bodyMetrics.measuredOn))
      .limit(1);
    return row === undefined ? null : Number(row.kg);
  }
}
