/**
 * Food library (Phase 7, §9.2). Global foods (USDA records, FITOS estimates)
 * have no owner; a custom food belongs to one user and is visible only to
 * them. Every nutrition value is a range; fibre may be unknown (both NULL).
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  numeric,
  pgTable,
  primaryKey,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { foodSourceEnum, nutritionBasisEnum, nutritionConfidenceEnum } from './enums.js';
import { users } from './users.js';

export const foods = pgTable(
  'foods',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    /** Global foods: the seed's stable key. Custom foods: `custom-<clientFoodId>`. */
    slug: text('slug').notNull().unique(),
    name: text('name').notNull(),
    /**
     * `name` normalised the way core `normaliseFoodText` does (lower case,
     * anything but a-z / 0-9 becomes one space) — what exact and prefix
     * search compare against.
     */
    searchName: text('search_name')
      .notNull()
      .generatedAlwaysAs(sql`btrim(regexp_replace(lower(name), '[^a-z0-9]+', ' ', 'g'))`),
    brand: text('brand'),
    /** Stored when known; no lookup in Phase 7 (barcode is V1.5). */
    barcode: text('barcode'),
    source: foodSourceEnum('source').notNull(),
    /** Provenance, e.g. "USDA FoodData Central · SR Legacy (April 2018) · FDC 169757". */
    sourceRef: text('source_ref'),
    isVerified: boolean('is_verified').notNull().default(false),
    ownerUserId: uuid('owner_user_id').references(() => users.id, { onDelete: 'cascade' }),
    /** The app's idempotency key for a custom food (retry-safe creation). */
    clientFoodId: uuid('client_food_id'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('foods_search_name_trgm_idx').using('gin', sql`${t.searchName} gin_trgm_ops`),
    index('foods_owner_idx').on(t.ownerUserId).where(sql`${t.ownerUserId} IS NOT NULL`),
    uniqueIndex('foods_owner_client_idx').on(t.ownerUserId, t.clientFoodId).where(sql`${t.clientFoodId} IS NOT NULL`),
    check('foods_name_nonempty', sql`length(btrim(${t.name})) > 0`),
    // Global ⇔ not user-authored: a user / user-corrected food always has an owner, nothing else does.
    check('foods_owner_matches_source', sql`(${t.ownerUserId} IS NOT NULL) = (${t.source} IN ('user', 'user-corrected'))`),
    // Estimates and user-entered values are never verified.
    check('foods_unverified_sources', sql`NOT (${t.isVerified} AND ${t.source} IN ('estimated', 'user', 'user-corrected'))`),
    // A custom food is created with its idempotency key; a global food has none.
    check('foods_client_id_custom_only', sql`(${t.source} = 'user') = (${t.clientFoodId} IS NOT NULL)`),
  ],
);

export const foodNutrition = pgTable(
  'food_nutrition',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    foodId: uuid('food_id')
      .notNull()
      .references(() => foods.id, { onDelete: 'cascade' }),
    /** Display order within a food: per 100 g first, then servings. */
    position: smallint('position').notNull(),
    basis: nutritionBasisEnum('basis').notNull(),
    servingLabel: text('serving_label').notNull(),
    servingGrams: numeric('serving_grams', { precision: 8, scale: 2 }),
    kcalLow: numeric('kcal_low', { precision: 8, scale: 2 }).notNull(),
    kcalHigh: numeric('kcal_high', { precision: 8, scale: 2 }).notNull(),
    proteinLow: numeric('protein_low', { precision: 8, scale: 2 }).notNull(),
    proteinHigh: numeric('protein_high', { precision: 8, scale: 2 }).notNull(),
    carbLow: numeric('carb_low', { precision: 8, scale: 2 }).notNull(),
    carbHigh: numeric('carb_high', { precision: 8, scale: 2 }).notNull(),
    fatLow: numeric('fat_low', { precision: 8, scale: 2 }).notNull(),
    fatHigh: numeric('fat_high', { precision: 8, scale: 2 }).notNull(),
    /** Both NULL = the source does not report fibre. Never stored as 0 for unknown. */
    fibreLow: numeric('fibre_low', { precision: 8, scale: 2 }),
    fibreHigh: numeric('fibre_high', { precision: 8, scale: 2 }),
    confidence: nutritionConfidenceEnum('confidence').notNull(),
  },
  (t) => [
    uniqueIndex('food_nutrition_food_position_idx').on(t.foodId, t.position),
    uniqueIndex('food_nutrition_food_serving_idx').on(t.foodId, t.basis, t.servingLabel),
    check('food_nutrition_serving_grams_positive', sql`${t.servingGrams} IS NULL OR ${t.servingGrams} > 0`),
    check('food_nutrition_label_nonempty', sql`length(btrim(${t.servingLabel})) > 0`),
    check('food_nutrition_nonnegative', sql`${t.kcalLow} >= 0 AND ${t.proteinLow} >= 0 AND ${t.carbLow} >= 0 AND ${t.fatLow} >= 0`),
    check('food_nutrition_kcal_range', sql`${t.kcalLow} <= ${t.kcalHigh}`),
    check('food_nutrition_protein_range', sql`${t.proteinLow} <= ${t.proteinHigh}`),
    check('food_nutrition_carb_range', sql`${t.carbLow} <= ${t.carbHigh}`),
    check('food_nutrition_fat_range', sql`${t.fatLow} <= ${t.fatHigh}`),
    check(
      'food_nutrition_fibre_range',
      // Both-or-neither must be explicit: with one end NULL a comparison is NULL, and CHECK passes NULL.
      sql`(${t.fibreLow} IS NULL AND ${t.fibreHigh} IS NULL) OR (${t.fibreLow} IS NOT NULL AND ${t.fibreHigh} IS NOT NULL AND ${t.fibreLow} >= 0 AND ${t.fibreLow} <= ${t.fibreHigh})`,
    ),
  ],
);

export const foodAliases = pgTable(
  'food_aliases',
  {
    foodId: uuid('food_id')
      .notNull()
      .references(() => foods.id, { onDelete: 'cascade' }),
    /** Stored normalised (core `normaliseFoodText`): "dhal", "panneer 65". */
    alias: text('alias').notNull(),
  },
  (t) => [
    primaryKey({ columns: [t.foodId, t.alias] }),
    index('food_aliases_alias_trgm_idx').using('gin', sql`${t.alias} gin_trgm_ops`),
    check('food_aliases_normalised', sql`${t.alias} ~ '^[a-z0-9]+( [a-z0-9]+)*$'`),
  ],
);

export type FoodRow = typeof foods.$inferSelect;
export type FoodNutritionRow = typeof foodNutrition.$inferSelect;
export type FoodAliasRow = typeof foodAliases.$inferSelect;
