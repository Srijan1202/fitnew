/**
 * Food library data access (Phase 7). Drizzle only (§8.3).
 *
 * Visibility is enforced HERE, in every query: a caller sees global foods
 * (no owner) and their own custom foods, never another user's.
 */
import { randomUUID } from 'node:crypto';
import { and, asc, eq, inArray, isNull, or, sql, type SQL } from 'drizzle-orm';
import { FOOD_SOURCES, sourceRank } from '@fitos/core/nutrition/food';

import type { DatabaseHandle } from '../../db/client.js';
import { foodAliases, foodNutrition, foods, type FoodNutritionRow, type FoodRow } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

/** Search tiers, best first: exact name, exact alias, prefix, word prefix, fuzzy. */
export type SearchTier = 0 | 1 | 2 | 3 | 4;

export interface SearchHit {
  readonly id: string;
  readonly tier: SearchTier;
}

/** Trigram word-similarity a fuzzy match must reach. */
export const FUZZY_THRESHOLD = 0.4;

/** §13.3 precedence as SQL, generated from core so the two cannot drift. */
const sourceRankSql = sql.raw(
  `case f.source ${FOOD_SOURCES.map((s) => `when '${s}' then ${sourceRank(s)}`).join(' ')} else 99 end`,
);

export interface FoodDetailRows {
  readonly food: FoodRow;
  readonly nutrition: readonly FoodNutritionRow[];
  readonly aliases: readonly string[];
}

export interface NewCustomFood {
  readonly ownerUserId: string;
  readonly clientFoodId: string;
  readonly name: string;
  readonly brand: string | null;
  readonly nutrition: Omit<typeof foodNutrition.$inferInsert, 'id' | 'foodId' | 'position'>;
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

export class FoodRepository {
  constructor(private readonly db: Db) {}

  /** `q` is already normalised (core `normaliseFoodText`): only a-z, 0-9 and single spaces. */
  async search(q: string, userId: string, limit: number): Promise<SearchHit[]> {
    const aliasEquals = sql`exists (select 1 from ${foodAliases} a where a.food_id = f.id and a.alias = ${q})`;
    const aliasStarts = sql`exists (select 1 from ${foodAliases} a where a.food_id = f.id and a.alias like ${q} || '%')`;
    const aliasWord = sql`exists (select 1 from ${foodAliases} a where a.food_id = f.id and a.alias like '% ' || ${q} || '%')`;
    const rows = await this.db.execute<{ id: string; tier: number }>(sql`
      select c.id, c.tier from (
        select f.id, f.name, f.search_name,
          ${sourceRankSql} as source_rank,
          case
            when f.search_name = ${q} then 0
            when ${aliasEquals} then 1
            when f.search_name like ${q} || '%' or ${aliasStarts} then 2
            when f.search_name like '% ' || ${q} || '%' or ${aliasWord} then 3
            else 4
          end as tier,
          greatest(
            word_similarity(${q}, f.search_name),
            coalesce((select max(word_similarity(${q}, a.alias)) from ${foodAliases} a where a.food_id = f.id), 0)
          ) as sim
        from ${foods} f
        where f.owner_user_id is null or f.owner_user_id = ${userId}
      ) c
      where c.tier < 4 or c.sim >= ${FUZZY_THRESHOLD}
      order by c.tier, c.sim desc, c.source_rank, length(c.search_name), c.search_name, c.id
      limit ${limit}
    `);
    return rows.map((r) => ({ id: r.id, tier: Number(r.tier) as SearchTier }));
  }

  /** Foods by id, visible to `userId` only, with rows and aliases, in the order of `ids`. */
  async details(ids: readonly string[], userId: string): Promise<FoodDetailRows[]> {
    if (ids.length === 0) return [];
    const visible: SQL = or(isNull(foods.ownerUserId), eq(foods.ownerUserId, userId)) as SQL;
    const [foodRows, nutritionRows, aliasRows] = await Promise.all([
      this.db.select().from(foods).where(and(inArray(foods.id, [...ids]), visible)),
      this.db.select().from(foodNutrition).where(inArray(foodNutrition.foodId, [...ids])).orderBy(asc(foodNutrition.foodId), asc(foodNutrition.position)),
      this.db.select().from(foodAliases).where(inArray(foodAliases.foodId, [...ids])).orderBy(asc(foodAliases.foodId), asc(foodAliases.alias)),
    ]);
    const byId = new Map(foodRows.map((f) => [f.id, f]));
    const out: FoodDetailRows[] = [];
    for (const id of ids) {
      const food = byId.get(id);
      if (food === undefined) continue;
      out.push({
        food,
        nutrition: nutritionRows.filter((n) => n.foodId === id),
        aliases: aliasRows.filter((a) => a.foodId === id).map((a) => a.alias),
      });
    }
    return out;
  }

  async findCustomByClientId(ownerUserId: string, clientFoodId: string): Promise<string | null> {
    const [row] = await this.db
      .select({ id: foods.id })
      .from(foods)
      .where(and(eq(foods.ownerUserId, ownerUserId), eq(foods.clientFoodId, clientFoodId)))
      .limit(1);
    return row?.id ?? null;
  }

  /**
   * Creates the custom food, or returns the one this user already created
   * with the same `clientFoodId` (a retry). A concurrent duplicate that loses
   * the race on the unique index resolves to the winner.
   */
  async createCustom(input: NewCustomFood): Promise<{ id: string; created: boolean }> {
    const existing = await this.findCustomByClientId(input.ownerUserId, input.clientFoodId);
    if (existing !== null) return { id: existing, created: false };
    try {
      const id = await this.db.transaction(async (tx) => {
        const [food] = await tx
          .insert(foods)
          .values({
            slug: `custom-${randomUUID()}`,
            name: input.name,
            brand: input.brand,
            barcode: null,
            source: 'user',
            sourceRef: 'Custom food · entered from a label',
            isVerified: false,
            ownerUserId: input.ownerUserId,
            clientFoodId: input.clientFoodId,
          })
          .returning({ id: foods.id });
        const foodId = (food as { id: string }).id;
        await tx.insert(foodNutrition).values({ ...input.nutrition, foodId, position: 0 });
        return foodId;
      });
      return { id, created: true };
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const winner = await this.findCustomByClientId(input.ownerUserId, input.clientFoodId);
      if (winner === null) throw error;
      return { id: winner, created: false };
    }
  }
}
