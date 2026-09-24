/**
 * Mess data access (Phase 9). Drizzle only (§8.3). Menus are never stored
 * parsed: this layer hands verbatim snapshots to the service, which parses
 * them with packages/core.
 */
import { and, asc, desc, eq, inArray, isNotNull, isNull, sql } from 'drizzle-orm';
import type { MessItResponse } from '@fitos/core/mess/types';

import type { DatabaseHandle } from '../../db/client.js';
import {
  foodLogItems,
  foodLogs,
  messDishCorrections,
  messDishNutrition,
  messMenuSnapshots,
  messProviders,
  messes,
  type MessDishCorrectionRow,
  type MessDishNutritionRow,
  type MessProviderRow,
  type MessRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface SnapshotRow {
  readonly id: string;
  readonly payload: MessItResponse;
  readonly lastSeenAt: Date;
}

export type NewDishNutrition = Omit<typeof messDishNutrition.$inferInsert, 'createdAt' | 'updatedAt' | 'foodId' | 'source'>;

export type NewCorrection = Omit<typeof messDishCorrections.$inferInsert, 'id' | 'status' | 'reviewedBy' | 'reviewedAt' | 'createdAt'>;

/** How many snapshots the cycle fallback reads at most (newest first). */
export const SNAPSHOT_FALLBACK_LIMIT = 60;

function toSnapshot(r: { id: string; rawPayload: unknown; lastSeenAt: Date }): SnapshotRow {
  return { id: r.id, payload: r.rawPayload as MessItResponse, lastSeenAt: r.lastSeenAt };
}

export class MessRepository {
  constructor(private readonly db: Db) {}

  // ------------------------------------------------------------ providers --

  async providers(): Promise<MessProviderRow[]> {
    return this.db.select().from(messProviders).orderBy(asc(messProviders.slug));
  }

  async providerBySlug(slug: string): Promise<MessProviderRow | null> {
    const [row] = await this.db.select().from(messProviders).where(eq(messProviders.slug, slug)).limit(1);
    return row ?? null;
  }

  async providerById(id: string): Promise<MessProviderRow | null> {
    const [row] = await this.db.select().from(messProviders).where(eq(messProviders.id, id)).limit(1);
    return row ?? null;
  }

  // --------------------------------------------------------------- messes --

  async messesOf(providerId: string): Promise<MessRow[]> {
    return this.db.select().from(messes).where(eq(messes.providerId, providerId)).orderBy(asc(messes.hostelId), asc(messes.messId));
  }

  async allMesses(): Promise<MessRow[]> {
    return this.db.select().from(messes).orderBy(asc(messes.hostelId), asc(messes.messId));
  }

  async messByCode(code: string): Promise<MessRow | null> {
    const [row] = await this.db.select().from(messes).where(eq(messes.code, code)).limit(1);
    return row ?? null;
  }

  async messById(id: string): Promise<MessRow | null> {
    const [row] = await this.db.select().from(messes).where(eq(messes.id, id)).limit(1);
    return row ?? null;
  }

  /** The mess a profile's three ids name, or null. */
  async messByRef(providerSlug: string, hostelId: string, messId: string): Promise<MessRow | null> {
    const [row] = await this.db
      .select({ mess: messes })
      .from(messes)
      .innerJoin(messProviders, eq(messProviders.id, messes.providerId))
      .where(and(eq(messProviders.slug, providerSlug), eq(messes.hostelId, hostelId), eq(messes.messId, messId)))
      .limit(1);
    return row?.mess ?? null;
  }

  async codesByIds(ids: readonly string[]): Promise<Map<string, string>> {
    if (ids.length === 0) return new Map();
    const rows = await this.db.select({ id: messes.id, code: messes.code }).from(messes).where(inArray(messes.id, [...ids]));
    return new Map(rows.map((r) => [r.id, r.code]));
  }

  // ------------------------------------------------------------ snapshots --

  /** The current payload: the one seen most recently. */
  async latestSnapshot(messId: string): Promise<SnapshotRow | null> {
    const [row] = await this.db
      .select({ id: messMenuSnapshots.id, rawPayload: messMenuSnapshots.rawPayload, lastSeenAt: messMenuSnapshots.lastSeenAt })
      .from(messMenuSnapshots)
      .where(eq(messMenuSnapshots.messId, messId))
      .orderBy(desc(messMenuSnapshots.lastSeenAt), desc(messMenuSnapshots.firstSeenAt))
      .limit(1);
    return row === undefined ? null : toSnapshot(row);
  }

  /** The most recently seen payload that publishes `date` (GIN on `dates`). */
  async newestSnapshotPublishing(messId: string, date: string): Promise<SnapshotRow | null> {
    const [row] = await this.db
      .select({ id: messMenuSnapshots.id, rawPayload: messMenuSnapshots.rawPayload, lastSeenAt: messMenuSnapshots.lastSeenAt })
      .from(messMenuSnapshots)
      .where(and(eq(messMenuSnapshots.messId, messId), sql`${messMenuSnapshots.dates} @> array[${date}]::text[]`))
      .orderBy(desc(messMenuSnapshots.lastSeenAt), desc(messMenuSnapshots.firstSeenAt))
      .limit(1);
    return row === undefined ? null : toSnapshot(row);
  }

  async recentSnapshots(messId: string, limit = SNAPSHOT_FALLBACK_LIMIT): Promise<SnapshotRow[]> {
    const rows = await this.db
      .select({ id: messMenuSnapshots.id, rawPayload: messMenuSnapshots.rawPayload, lastSeenAt: messMenuSnapshots.lastSeenAt })
      .from(messMenuSnapshots)
      .where(eq(messMenuSnapshots.messId, messId))
      .orderBy(desc(messMenuSnapshots.lastSeenAt), desc(messMenuSnapshots.firstSeenAt))
      .limit(limit);
    return rows.map(toSnapshot);
  }

  /** The last date any stored payload of each mess publishes. */
  async latestPublishedDates(messIds: readonly string[]): Promise<Map<string, string>> {
    if (messIds.length === 0) return new Map();
    const rows = await this.db.execute<{ mess_id: string; latest: string | null }>(sql`
      select ${messMenuSnapshots.messId} as mess_id, max(d) as latest
      from ${messMenuSnapshots}, unnest(${messMenuSnapshots.dates}) d
      where ${inArray(messMenuSnapshots.messId, [...messIds])}
      group by ${messMenuSnapshots.messId}
    `);
    return new Map(rows.flatMap((r) => (r.latest === null ? [] : [[r.mess_id, r.latest] as const])));
  }

  /**
   * Stores a fetched payload, or only marks it seen again when the same
   * payload is already stored (dedupe by hash, owner D3). Returns whether it
   * was new. The mess's status moves in the same transaction.
   */
  async recordSuccess(messId: string, payload: MessItResponse, payloadHash: string, at: Date): Promise<{ id: string; isNew: boolean }> {
    return this.db.transaction(async (tx) => {
      const dates = sql.join(payload.menu.map((d) => sql`${d.date}`), sql`, `);
      const rows = await tx.execute<{ id: string; is_new: boolean }>(sql`
        insert into ${messMenuSnapshots} (mess_id, raw_payload, payload_hash, dates, first_seen_at, last_seen_at)
        values (${messId}, ${JSON.stringify(payload)}::jsonb, ${payloadHash}, array[${dates}]::text[], ${at.toISOString()}::timestamptz, ${at.toISOString()}::timestamptz)
        on conflict (mess_id, payload_hash) do update set last_seen_at = greatest(${messMenuSnapshots.lastSeenAt}, excluded.last_seen_at)
        returning id, (xmax = 0) as is_new
      `);
      const row = rows[0];
      if (row === undefined) throw new Error('snapshot upsert returned nothing');
      await tx
        .update(messes)
        .set({
          lastAttemptAt: at,
          lastSuccessAt: at,
          lastError: null,
          consecutiveFailures: 0,
          ...(row.is_new ? { lastChangedAt: at } : {}),
        })
        .where(eq(messes.id, messId));
      return { id: row.id, isNew: row.is_new };
    });
  }

  async recordFailure(messId: string, error: 'unreachable' | 'malformed', at: Date): Promise<void> {
    await this.db
      .update(messes)
      .set({ lastAttemptAt: at, lastError: error, consecutiveFailures: sql`${messes.consecutiveFailures} + 1` })
      .where(eq(messes.id, messId));
  }

  // ------------------------------------------------------------ nutrition --

  async nutritionFor(slugs: readonly string[]): Promise<Map<string, MessDishNutritionRow>> {
    const unique = [...new Set(slugs)];
    if (unique.length === 0) return new Map();
    const rows = await this.db.select().from(messDishNutrition).where(inArray(messDishNutrition.dishSlug, unique));
    return new Map(rows.map((r) => [r.dishSlug, r]));
  }

  /** Owner D6: first sighting writes the estimate; a re-run never overwrites it. */
  async insertNutritionIfAbsent(rows: readonly NewDishNutrition[]): Promise<number> {
    if (rows.length === 0) return 0;
    const inserted = await this.db
      .insert(messDishNutrition)
      .values([...rows])
      .onConflictDoNothing({ target: messDishNutrition.dishSlug })
      .returning({ slug: messDishNutrition.dishSlug });
    return inserted.length;
  }

  // ---------------------------------------------------------- corrections --

  /** Retry-safe by (user, clientCorrectionId): a replay returns the stored row. */
  async insertCorrection(input: NewCorrection): Promise<{ row: MessDishCorrectionRow; created: boolean }> {
    const [row] = await this.db
      .insert(messDishCorrections)
      .values(input)
      .onConflictDoNothing({ target: [messDishCorrections.userId, messDishCorrections.clientCorrectionId] })
      .returning();
    if (row !== undefined) return { row, created: true };
    const [existing] = await this.db
      .select()
      .from(messDishCorrections)
      .where(and(eq(messDishCorrections.userId, input.userId), eq(messDishCorrections.clientCorrectionId, input.clientCorrectionId)))
      .limit(1);
    if (existing === undefined) throw new Error('correction vanished after a conflict');
    return { row: existing, created: false };
  }

  /** Which of these dishes this user has a pending correction for. */
  async pendingCorrectionSlugs(userId: string, slugs: readonly string[]): Promise<Set<string>> {
    const unique = [...new Set(slugs)];
    if (unique.length === 0) return new Set();
    const rows = await this.db
      .selectDistinct({ slug: messDishCorrections.dishSlug })
      .from(messDishCorrections)
      .where(and(eq(messDishCorrections.userId, userId), eq(messDishCorrections.status, 'pending'), inArray(messDishCorrections.dishSlug, unique)));
    return new Set(rows.map((r) => r.slug));
  }

  // ------------------------------------------------------------ user logs --

  /** The mess dishes this user logged on `localDate` (live logs only). */
  async loggedDishes(userId: string, localDate: string): Promise<{ dishSlug: string; mealSlot: 'breakfast' | 'lunch' | 'snacks' | 'dinner'; clientLogId: string }[]> {
    const rows = await this.db
      .select({ dishSlug: foodLogItems.messDishSlug, mealSlot: foodLogs.mealSlot, clientLogId: foodLogs.clientLogId })
      .from(foodLogItems)
      .innerJoin(foodLogs, eq(foodLogs.id, foodLogItems.foodLogId))
      .where(and(eq(foodLogs.userId, userId), eq(foodLogs.localDate, localDate), isNull(foodLogs.deletedAt), isNotNull(foodLogItems.messDishSlug)))
      .orderBy(asc(foodLogs.loggedAt), asc(foodLogItems.position));
    return rows.flatMap((r) => (r.dishSlug === null ? [] : [{ dishSlug: r.dishSlug, mealSlot: r.mealSlot, clientLogId: r.clientLogId }]));
  }
}
