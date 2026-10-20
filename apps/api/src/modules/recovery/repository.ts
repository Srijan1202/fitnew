/**
 * Recovery reads and writes (Phase 13, ADR-019). Drizzle only; every query is
 * scoped to one user. The check-in is the only thing stored — readiness is
 * computed on read (§9.4).
 */
import { and, asc, eq, getTableColumns, gte, lte, sql } from 'drizzle-orm';

import type { RecoveryCheckIn } from '@fitos/core/recovery/readiness';

import type { DatabaseHandle } from '../../db/client.js';
import { recoveryLogs, type RecoveryLogRow } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

/** The §18 values of a check-in, as sent (null = not answered). */
export interface CheckInValues {
  readonly sleepHours: number | null;
  readonly sleepQuality: number | null;
  readonly soreness: number | null;
  readonly energy: number | null;
  readonly stress: number | null;
}

export function toCheckIn(row: RecoveryLogRow): RecoveryCheckIn {
  return {
    date: row.loggedOn,
    sleepHours: row.sleepHours === null ? null : Number(row.sleepHours),
    sleepQuality: row.sleepQuality,
    soreness: row.soreness,
    energy: row.energy,
    stress: row.stress,
  };
}

export class RecoveryRepository {
  constructor(private readonly db: Db) {}

  /** Check-ins between two local dates (inclusive), oldest first — one indexed range read. */
  async checkIns(userId: string, from: string, to: string): Promise<RecoveryLogRow[]> {
    return this.db
      .select()
      .from(recoveryLogs)
      .where(and(eq(recoveryLogs.userId, userId), gte(recoveryLogs.loggedOn, from), lte(recoveryLogs.loggedOn, to)))
      .orderBy(asc(recoveryLogs.loggedOn));
  }

  /**
   * One check-in per local day: a new date inserts; the same date is
   * REPLACED by what is sent (an unanswered value becomes null). `created`
   * comes from the same statement (`xmax = 0` on a fresh insert), so two
   * racing first writes cannot both claim it.
   */
  async upsert(userId: string, date: string, v: CheckInValues): Promise<{ row: RecoveryLogRow; created: boolean }> {
    const values = {
      sleepHours: v.sleepHours === null ? null : v.sleepHours.toFixed(1),
      sleepQuality: v.sleepQuality,
      soreness: v.soreness,
      energy: v.energy,
      stress: v.stress,
    };
    const [out] = await this.db
      .insert(recoveryLogs)
      .values({ userId, loggedOn: date, source: 'manual', ...values })
      .onConflictDoUpdate({
        target: [recoveryLogs.userId, recoveryLogs.loggedOn],
        set: { ...values, source: 'manual', updatedAt: sql`now()` },
      })
      .returning({ ...getTableColumns(recoveryLogs), created: sql<boolean>`(xmax = 0)` });
    const { created, ...row } = out!;
    return { row, created };
  }
}
