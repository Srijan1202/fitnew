/**
 * Loading database/seeds/foods.json into Postgres (Phase 7). Validated with
 * the contract schema first — a bad row fails the run before anything is
 * written — then applied in ONE transaction, idempotent by slug: foods are
 * upserted, and each seeded food's nutrition rows and aliases are replaced
 * wholesale. Custom (user-owned) foods are never touched. Run before a
 * release (the seed job), never on server boot.
 */
import { readFileSync } from 'node:fs';
import { inArray, sql } from 'drizzle-orm';
import type { FoodSeed } from '@fitos/contracts';

import { createDatabase } from '../client.js';
import { foodAliases, foodNutrition, foods } from '../schema.js';
import { FOOD_SEED_FILE, parseSeedFile } from './format.js';

export function readFoodSeed(path = FOOD_SEED_FILE): FoodSeed[] {
  return parseSeedFile(readFileSync(path, 'utf8'));
}

export interface FoodSeedResult {
  readonly foods: number;
  readonly nutritionRows: number;
  readonly aliases: number;
}

const num = (v: number): string => String(v);
const numOrNull = (v: number | null): string | null => (v === null ? null : String(v));

export async function seedFoods(connectionString: string, entries: readonly FoodSeed[] = readFoodSeed()): Promise<FoodSeedResult> {
  const { db, client } = createDatabase(connectionString);
  try {
    return await db.transaction(async (tx) => {
      const upserted = await tx
        .insert(foods)
        .values(
          entries.map((f) => ({
            slug: f.slug,
            name: f.name,
            brand: f.brand,
            barcode: f.barcode,
            source: f.source,
            sourceRef: f.sourceRef,
            isVerified: f.isVerified,
          })),
        )
        .onConflictDoUpdate({
          target: foods.slug,
          set: {
            name: sql`excluded.name`,
            brand: sql`excluded.brand`,
            barcode: sql`excluded.barcode`,
            source: sql`excluded.source`,
            sourceRef: sql`excluded.source_ref`,
            isVerified: sql`excluded.is_verified`,
            updatedAt: sql`case when (${foods.name}, ${foods.brand}, ${foods.barcode}, ${foods.source}, ${foods.sourceRef}, ${foods.isVerified}) is distinct from (excluded.name, excluded.brand, excluded.barcode, excluded.source, excluded.source_ref, excluded.is_verified) then now() else ${foods.updatedAt} end`,
          },
          // A custom food never has a seed slug; this keeps it that way.
          setWhere: sql`${foods.ownerUserId} IS NULL`,
        })
        .returning({ id: foods.id, slug: foods.slug });

      const idBySlug = new Map(upserted.map((r) => [r.slug, r.id]));
      if (idBySlug.size !== entries.length) throw new Error('a seed slug collides with a custom food');
      const ids = [...idBySlug.values()];

      await tx.delete(foodNutrition).where(inArray(foodNutrition.foodId, ids));
      await tx.delete(foodAliases).where(inArray(foodAliases.foodId, ids));

      const idOf = (slug: string): string => idBySlug.get(slug) as string;
      const nutritionRows = entries.flatMap((f) =>
        f.nutrition.map((n, position) => ({
          foodId: idOf(f.slug),
          position,
          basis: n.basis,
          servingLabel: n.servingLabel,
          servingGrams: numOrNull(n.servingGrams),
          kcalLow: num(n.kcalLow),
          kcalHigh: num(n.kcalHigh),
          proteinLow: num(n.proteinLow),
          proteinHigh: num(n.proteinHigh),
          carbLow: num(n.carbLow),
          carbHigh: num(n.carbHigh),
          fatLow: num(n.fatLow),
          fatHigh: num(n.fatHigh),
          fibreLow: numOrNull(n.fibreLow),
          fibreHigh: numOrNull(n.fibreHigh),
          confidence: n.confidence,
        })),
      );
      const aliasRows = entries.flatMap((f) => f.aliases.map((alias) => ({ foodId: idOf(f.slug), alias })));

      // Postgres caps bind parameters per statement; ~16 per nutrition row.
      for (let i = 0; i < nutritionRows.length; i += 500) {
        await tx.insert(foodNutrition).values(nutritionRows.slice(i, i + 500));
      }
      for (let i = 0; i < aliasRows.length; i += 1000) {
        await tx.insert(foodAliases).values(aliasRows.slice(i, i + 1000));
      }
      return { foods: upserted.length, nutritionRows: nutritionRows.length, aliases: aliasRows.length };
    });
  } finally {
    await client.end({ timeout: 5 });
  }
}
