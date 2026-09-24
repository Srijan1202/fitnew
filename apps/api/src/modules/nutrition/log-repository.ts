/**
 * Food logging data access (Phase 8). Drizzle only (§8.3).
 *
 * Ownership is enforced HERE, in every query: a caller reads and writes only
 * their own logs, days and saved meals.
 *
 * Every write that changes a day's items changes its `daily_nutrition` row in
 * the SAME transaction, by exactly the items' snapshot values — so the cache
 * always equals a recompute (`rebuildDailyNutrition`), which the tests check.
 */
import { and, asc, desc, eq, inArray, isNull, lte, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  dailyNutrition,
  foodLogItems,
  foodLogs,
  messes,
  nutritionTargets,
  savedMeals,
  users,
  type DailyNutritionRow,
  type FoodLogItemRow,
  type FoodLogRow,
  type NutritionTargetsRow,
  type SavedMealRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];
type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];

export interface LogWithItems {
  readonly log: FoodLogRow;
  readonly items: readonly FoodLogItemRow[];
  /** Phase 9: the code of the mess a `mess` log came from. */
  readonly messCode: string | null;
}

export type NewLogItem = Omit<typeof foodLogItems.$inferInsert, 'id' | 'foodLogId'>;

export interface NewLog {
  readonly userId: string;
  readonly clientLogId: string;
  readonly loggedAt: Date;
  readonly localDate: string;
  readonly mealSlot: FoodLogRow['mealSlot'];
  readonly entryMethod: FoodLogRow['entryMethod'];
  readonly savedMealId: string | null;
  /** Phase 9: the mess a `mess` log came from. */
  readonly messId?: string | null;
  readonly items: readonly NewLogItem[];
}

export interface RecentRow {
  readonly foodId: string;
  readonly loggedAt: Date;
  readonly basis: 'per_100g' | 'per_serving';
  readonly servingLabel: string;
  readonly servings: string;
}

/** Postgres unique_violation. */
function isUniqueViolation(error: unknown): boolean {
  let e: unknown = error;
  for (let i = 0; i < 4 && e !== null && typeof e === 'object'; i += 1) {
    if ((e as { code?: unknown }).code === '23505') return true;
    e = (e as { cause?: unknown }).cause;
  }
  return false;
}

/**
 * Adds (sign 1) or removes (sign −1) a set of items from the day's cache row.
 * Unknown fibre counts toward `fibre_unknown_items`, never toward the sums.
 */
async function adjustDay(tx: Tx, userId: string, localDate: string, items: readonly NewLogItem[] | readonly FoodLogItemRow[], sign: 1 | -1): Promise<void> {
  const sum = (pick: (i: NewLogItem | FoodLogItemRow) => string | null | undefined): string =>
    String(Math.round(sign * items.reduce((s, i) => s + Number(pick(i) ?? 0), 0) * 100) / 100 + 0);
  const unknown = sign * items.filter((i) => i.fibreLow === null || i.fibreLow === undefined).length;
  const count = sign * items.length;
  const v = {
    kcalLow: sum((i) => i.kcalLow),
    kcalHigh: sum((i) => i.kcalHigh),
    proteinLow: sum((i) => i.proteinLow),
    proteinHigh: sum((i) => i.proteinHigh),
    carbLow: sum((i) => i.carbLow),
    carbHigh: sum((i) => i.carbHigh),
    fatLow: sum((i) => i.fatLow),
    fatHigh: sum((i) => i.fatHigh),
    fibreKnownLow: sum((i) => i.fibreLow),
    fibreKnownHigh: sum((i) => i.fibreHigh),
  };
  const d = dailyNutrition;
  const increment = {
    kcalLow: sql`${d.kcalLow} + ${v.kcalLow}::numeric`,
    kcalHigh: sql`${d.kcalHigh} + ${v.kcalHigh}::numeric`,
    proteinLow: sql`${d.proteinLow} + ${v.proteinLow}::numeric`,
    proteinHigh: sql`${d.proteinHigh} + ${v.proteinHigh}::numeric`,
    carbLow: sql`${d.carbLow} + ${v.carbLow}::numeric`,
    carbHigh: sql`${d.carbHigh} + ${v.carbHigh}::numeric`,
    fatLow: sql`${d.fatLow} + ${v.fatLow}::numeric`,
    fatHigh: sql`${d.fatHigh} + ${v.fatHigh}::numeric`,
    fibreKnownLow: sql`${d.fibreKnownLow} + ${v.fibreKnownLow}::numeric`,
    fibreKnownHigh: sql`${d.fibreKnownHigh} + ${v.fibreKnownHigh}::numeric`,
    fibreUnknownItems: sql`${d.fibreUnknownItems} + ${unknown}`,
    itemCount: sql`${d.itemCount} + ${count}`,
    updatedAt: sql`now()`,
  };
  if (sign === -1) {
    // Removing: the day's row exists (its items were added through here). A plain
    // UPDATE — an upsert would first CHECK the negative would-be INSERT row.
    await tx.update(d).set(increment).where(and(eq(d.userId, userId), eq(d.localDate, localDate)));
    return;
  }
  await tx
    .insert(d)
    .values({ userId, localDate, ...v, fibreUnknownItems: unknown, itemCount: count })
    .onConflictDoUpdate({ target: [d.userId, d.localDate], set: increment });
}

export class FoodLogRepository {
  constructor(private readonly db: Db) {}

  async timezoneOf(userId: string): Promise<string> {
    const [row] = await this.db.select({ timezone: users.timezone }).from(users).where(eq(users.id, userId)).limit(1);
    return row?.timezone ?? 'Asia/Kolkata';
  }

  /** The target row in effect on `date` (owner J2): the latest `effective_from ≤ date`. */
  async targetsOn(userId: string, date: string): Promise<NutritionTargetsRow | null> {
    const [row] = await this.db
      .select()
      .from(nutritionTargets)
      .where(and(eq(nutritionTargets.userId, userId), lte(nutritionTargets.effectiveFrom, date)))
      .orderBy(desc(nutritionTargets.effectiveFrom), desc(nutritionTargets.createdAt))
      .limit(1);
    return row ?? null;
  }

  private async withItems(logs: readonly FoodLogRow[]): Promise<LogWithItems[]> {
    if (logs.length === 0) return [];
    const items = await this.db
      .select()
      .from(foodLogItems)
      .where(inArray(foodLogItems.foodLogId, logs.map((l) => l.id)))
      .orderBy(asc(foodLogItems.foodLogId), asc(foodLogItems.position));
    const messIds = [...new Set(logs.flatMap((l) => (l.messId === null ? [] : [l.messId])))];
    const codes =
      messIds.length === 0
        ? new Map<string, string>()
        : new Map((await this.db.select({ id: messes.id, code: messes.code }).from(messes).where(inArray(messes.id, messIds))).map((r) => [r.id, r.code]));
    return logs.map((log) => ({
      log,
      items: items.filter((i) => i.foodLogId === log.id),
      messCode: log.messId === null ? null : (codes.get(log.messId) ?? null),
    }));
  }

  /** Any log with this client id, deleted or not (a replay must find it either way). */
  async byClientId(userId: string, clientLogId: string): Promise<LogWithItems | null> {
    const [log] = await this.db
      .select()
      .from(foodLogs)
      .where(and(eq(foodLogs.userId, userId), eq(foodLogs.clientLogId, clientLogId)))
      .limit(1);
    if (log === undefined) return null;
    const [withItems] = await this.withItems([log]);
    return withItems ?? null;
  }

  /** The day's live logs in the order they were eaten. */
  async dayLogs(userId: string, localDate: string): Promise<LogWithItems[]> {
    const logs = await this.db
      .select()
      .from(foodLogs)
      .where(and(eq(foodLogs.userId, userId), eq(foodLogs.localDate, localDate), isNull(foodLogs.deletedAt)))
      .orderBy(asc(foodLogs.loggedAt), asc(foodLogs.createdAt));
    return this.withItems(logs);
  }

  async dayTotals(userId: string, localDate: string): Promise<DailyNutritionRow | null> {
    const [row] = await this.db
      .select()
      .from(dailyNutrition)
      .where(and(eq(dailyNutrition.userId, userId), eq(dailyNutrition.localDate, localDate)))
      .limit(1);
    return row ?? null;
  }

  /**
   * Inserts the log, its items and the day's cache change in one
   * transaction. A replay (same user + client id) inserts nothing and
   * returns `created: false`; so does the loser of a concurrent race.
   */
  async insertLog(input: NewLog): Promise<{ created: boolean }> {
    try {
      return await this.db.transaction(async (tx) => {
        const [row] = await tx
          .insert(foodLogs)
          .values({
            userId: input.userId,
            clientLogId: input.clientLogId,
            loggedAt: input.loggedAt,
            localDate: input.localDate,
            mealSlot: input.mealSlot,
            entryMethod: input.entryMethod,
            savedMealId: input.savedMealId,
            messId: input.messId ?? null,
          })
          .onConflictDoNothing({ target: [foodLogs.userId, foodLogs.clientLogId] })
          .returning({ id: foodLogs.id });
        if (row === undefined) return { created: false };
        await tx.insert(foodLogItems).values(input.items.map((i) => ({ ...i, foodLogId: row.id })));
        await adjustDay(tx, input.userId, input.localDate, input.items, 1);
        return { created: true };
      });
    } catch (error) {
      if (isUniqueViolation(error)) return { created: false };
      throw error;
    }
  }

  /**
   * Soft-deletes the whole log (owner J9) and takes its items off the day.
   * `deleted`: false when it was already deleted (an idempotent replay);
   * null when there is no such log for this user.
   */
  async deleteLog(userId: string, clientLogId: string): Promise<{ deleted: boolean; localDate: string } | null> {
    return this.db.transaction(async (tx) => {
      const [gone] = await tx
        .update(foodLogs)
        .set({ deletedAt: sql`now()`, updatedAt: sql`now()` })
        .where(and(eq(foodLogs.userId, userId), eq(foodLogs.clientLogId, clientLogId), isNull(foodLogs.deletedAt)))
        .returning({ id: foodLogs.id, localDate: foodLogs.localDate });
      if (gone !== undefined) {
        const items = await tx.select().from(foodLogItems).where(eq(foodLogItems.foodLogId, gone.id));
        await adjustDay(tx, userId, gone.localDate, items, -1);
        // A day with nothing left has no cache row — exactly what a rebuild produces.
        await tx
          .delete(dailyNutrition)
          .where(and(eq(dailyNutrition.userId, userId), eq(dailyNutrition.localDate, gone.localDate), eq(dailyNutrition.itemCount, 0)));
        return { deleted: true, localDate: gone.localDate };
      }
      const [already] = await tx
        .select({ localDate: foodLogs.localDate })
        .from(foodLogs)
        .where(and(eq(foodLogs.userId, userId), eq(foodLogs.clientLogId, clientLogId)))
        .limit(1);
      return already === undefined ? null : { deleted: false, localDate: already.localDate };
    });
  }

  /** Each food's most recent live use by this user, newest first (owner J13). */
  async recentFoods(userId: string, limit: number): Promise<RecentRow[]> {
    const rows = await this.db.execute<{ food_id: string; logged_at: string; basis: 'per_100g' | 'per_serving'; serving_label: string; servings: string }>(sql`
      select * from (
        select distinct on (i.food_id) i.food_id, l.logged_at, i.basis, i.serving_label, i.servings
        from ${foodLogItems} i
        join ${foodLogs} l on l.id = i.food_log_id
        where l.user_id = ${userId} and l.deleted_at is null and i.food_id is not null and i.basis is not null
        order by i.food_id, l.logged_at desc, l.created_at desc, i.position
      ) r
      order by r.logged_at desc, r.food_id
      limit ${limit}
    `);
    return rows.map((r) => ({
      foodId: r.food_id,
      loggedAt: new Date(r.logged_at),
      basis: r.basis,
      servingLabel: r.serving_label,
      servings: r.servings,
    }));
  }

  // ------------------------------------------------------------ saved meals --

  async savedMeals(userId: string): Promise<SavedMealRow[]> {
    return this.db.select().from(savedMeals).where(eq(savedMeals.userId, userId)).orderBy(desc(savedMeals.createdAt), asc(savedMeals.id));
  }

  async savedMeal(userId: string, id: string): Promise<SavedMealRow | null> {
    const [row] = await this.db.select().from(savedMeals).where(and(eq(savedMeals.userId, userId), eq(savedMeals.id, id))).limit(1);
    return row ?? null;
  }

  async savedMealByClientId(userId: string, clientMealId: string): Promise<SavedMealRow | null> {
    const [row] = await this.db
      .select()
      .from(savedMeals)
      .where(and(eq(savedMeals.userId, userId), eq(savedMeals.clientMealId, clientMealId)))
      .limit(1);
    return row ?? null;
  }

  /** Retry-safe: the same client id returns the meal already saved. */
  async insertSavedMeal(input: { userId: string; clientMealId: string; name: string; items: unknown[] }): Promise<{ row: SavedMealRow; created: boolean }> {
    const [row] = await this.db
      .insert(savedMeals)
      .values(input)
      .onConflictDoNothing({ target: [savedMeals.userId, savedMeals.clientMealId] })
      .returning();
    if (row !== undefined) return { row, created: true };
    const existing = await this.savedMealByClientId(input.userId, input.clientMealId);
    if (existing === null) throw new Error('saved meal vanished after a conflict');
    return { row: existing, created: false };
  }

  /** Hard delete (§9.1 soft-deletes only the listed tables). Logs made from it keep their items. */
  async deleteSavedMeal(userId: string, id: string): Promise<boolean> {
    const gone = await this.db.delete(savedMeals).where(and(eq(savedMeals.userId, userId), eq(savedMeals.id, id))).returning({ id: savedMeals.id });
    return gone.length > 0;
  }

  /** Live logs of this user by client id, in the order the ids were given. */
  async logsByClientIds(userId: string, clientLogIds: readonly string[]): Promise<LogWithItems[]> {
    const logs = await this.db
      .select()
      .from(foodLogs)
      .where(and(eq(foodLogs.userId, userId), inArray(foodLogs.clientLogId, [...clientLogIds]), isNull(foodLogs.deletedAt)));
    const byClient = new Map(logs.map((l) => [l.clientLogId, l]));
    const ordered = clientLogIds.map((id) => byClient.get(id)).filter((l): l is FoodLogRow => l !== undefined);
    return this.withItems(ordered);
  }
}

/**
 * §9.4: rebuild `daily_nutrition` from the live item snapshots — for one user
 * or everyone. Days with no live items are removed. Used by
 * `pnpm db:rebuild-nutrition` and by the test that proves the cache honest.
 */
export async function rebuildDailyNutrition(db: Db, userId?: string): Promise<{ days: number }> {
  return db.transaction(async (tx) => {
    const scope = userId === undefined ? sql`true` : sql`l.user_id = ${userId}`;
    await tx.execute(userId === undefined ? sql`delete from ${dailyNutrition}` : sql`delete from ${dailyNutrition} where user_id = ${userId}`);
    const rows = await tx.execute<{ n: number }>(sql`
      with inserted as (
        insert into ${dailyNutrition} (user_id, local_date, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high,
          fat_low, fat_high, fibre_known_low, fibre_known_high, fibre_unknown_items, item_count)
        select l.user_id, l.local_date,
          sum(i.kcal_low), sum(i.kcal_high), sum(i.protein_low), sum(i.protein_high), sum(i.carb_low), sum(i.carb_high),
          sum(i.fat_low), sum(i.fat_high), coalesce(sum(i.fibre_low), 0), coalesce(sum(i.fibre_high), 0),
          count(*) filter (where i.fibre_low is null), count(*)
        from ${foodLogs} l join ${foodLogItems} i on i.food_log_id = l.id
        where l.deleted_at is null and ${scope}
        group by l.user_id, l.local_date
        returning 1
      ) select count(*)::int as n from inserted
    `);
    return { days: Number(rows[0]?.n ?? 0) };
  });
}
