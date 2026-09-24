/**
 * Food logging (Phase 8, §9.2). A log is one act of logging — a meal slot, a
 * time, a method — holding one or more items. Each item is a SNAPSHOT of the
 * food's nutrition at log time: correcting or removing a food later never
 * changes a logged day. `daily_nutrition` is a derived cache of the live
 * items, kept in the same transaction and rebuildable (§9.4).
 */
import { sql } from 'drizzle-orm';
import {
  check,
  index,
  integer,
  jsonb,
  numeric,
  pgTable,
  primaryKey,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { foodEntryMethodEnum, foodSourceEnum, mealSlotEnum, nutritionBasisEnum, nutritionConfidenceEnum } from './enums.js';
import { foods } from './food.js';
import { messes } from './mess.js';
import { users } from './users.js';

const userRef = () =>
  uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' });

const range = (name: string) => numeric(name, { precision: 8, scale: 2 });
const total = (name: string) => numeric(name, { precision: 9, scale: 2 }).notNull().default('0');

/**
 * Owner J7: made from logged meals. `items` keeps each food and portion (a
 * re-log re-snapshots the food's current values) or a quick add's values.
 */
export const savedMeals = pgTable(
  'saved_meals',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    clientMealId: uuid('client_meal_id').notNull(),
    name: text('name').notNull(),
    items: jsonb('items').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('saved_meals_user_client_id').on(t.userId, t.clientMealId),
    index('saved_meals_user_created_idx').on(t.userId, t.createdAt),
    check('saved_meals_name_length', sql`length(btrim(${t.name})) between 1 and 60`),
    check('saved_meals_items_nonempty', sql`jsonb_typeof(${t.items}) = 'array' AND jsonb_array_length(${t.items}) > 0`),
  ],
);

export const foodLogs = pgTable(
  'food_logs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    /** The phone's idempotency key; unique per user (owner J12). */
    clientLogId: uuid('client_log_id').notNull(),
    /** When it was eaten. */
    loggedAt: timestamp('logged_at', { withTimezone: true }).notNull(),
    /** yyyy-mm-dd of `logged_at` in users.timezone, fixed at write (owner J3). */
    localDate: text('local_date').notNull(),
    mealSlot: mealSlotEnum('meal_slot').notNull(),
    entryMethod: foodEntryMethodEnum('entry_method').notNull(),
    savedMealId: uuid('saved_meal_id').references(() => savedMeals.id, { onDelete: 'set null' }),
    /** Phase 9: the mess a `mess` log came from (owner D10). */
    messId: uuid('mess_id').references(() => messes.id, { onDelete: 'set null' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    /** §9.1: user-authored content soft-deletes. */
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('food_logs_user_client_id').on(t.userId, t.clientLogId),
    index('food_logs_user_day_idx').on(t.userId, t.localDate).where(sql`${t.deletedAt} IS NULL`),
    // §9.3.
    index('food_logs_user_logged_at_idx').on(t.userId, t.loggedAt.desc()).where(sql`${t.deletedAt} IS NULL`),
    check('food_logs_local_date_format', sql`${t.localDate} ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`),
    check('food_logs_saved_meal_method', sql`${t.savedMealId} IS NULL OR ${t.entryMethod} = 'saved-meal'`),
    // ::text: the enum value is added in the same migration and cannot be used there as an enum.
    check('food_logs_mess_method', sql`${t.messId} IS NULL OR ${t.entryMethod}::text = 'mess'`),
  ],
);

export const foodLogItems = pgTable(
  'food_log_items',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    foodLogId: uuid('food_log_id')
      .notNull()
      .references(() => foodLogs.id, { onDelete: 'cascade' }),
    position: smallint('position').notNull(),
    /** The food it came from; NULL for quick add. The snapshot never depends on it. */
    foodId: uuid('food_id').references(() => foods.id, { onDelete: 'set null' }),
    /**
     * Phase 9 (owner D10): the mess dish it came from — provenance only. No
     * foreign key (dishes are parsed from snapshots, not stored); the numbers
     * are the snapshot below, as for any food.
     */
    messDishSlug: text('mess_dish_slug'),
    // --- snapshot of what was logged (owner J18) ---
    foodName: text('food_name').notNull(),
    foodSource: foodSourceEnum('food_source').notNull(),
    basis: nutritionBasisEnum('basis'),
    servingLabel: text('serving_label'),
    servingGrams: numeric('serving_grams', { precision: 7, scale: 2 }),
    /** Multiplier on the row (exact when entered as grams). */
    servings: numeric('servings', { precision: 10, scale: 4 }).notNull(),
    grams: numeric('grams', { precision: 7, scale: 1 }),
    kcalLow: range('kcal_low').notNull(),
    kcalHigh: range('kcal_high').notNull(),
    proteinLow: range('protein_low').notNull(),
    proteinHigh: range('protein_high').notNull(),
    carbLow: range('carb_low').notNull(),
    carbHigh: range('carb_high').notNull(),
    fatLow: range('fat_low').notNull(),
    fatHigh: range('fat_high').notNull(),
    /** NULL = unknown; both ends or neither. */
    fibreLow: range('fibre_low'),
    fibreHigh: range('fibre_high'),
    confidence: nutritionConfidenceEnum('confidence').notNull(),
  },
  (t) => [
    uniqueIndex('food_log_items_log_position').on(t.foodLogId, t.position),
    index('food_log_items_food_idx').on(t.foodId),
    check('food_log_items_mess_or_food', sql`${t.messDishSlug} IS NULL OR ${t.foodId} IS NULL`),
    check('food_log_items_name_nonempty', sql`length(btrim(${t.foodName})) > 0`),
    check('food_log_items_servings_positive', sql`${t.servings} > 0`),
    check('food_log_items_grams_positive', sql`${t.grams} IS NULL OR ${t.grams} > 0`),
    check('food_log_items_row_both_or_neither', sql`(${t.basis} IS NULL) = (${t.servingLabel} IS NULL)`),
    check('food_log_items_nonnegative', sql`${t.kcalLow} >= 0 AND ${t.proteinLow} >= 0 AND ${t.carbLow} >= 0 AND ${t.fatLow} >= 0`),
    check('food_log_items_kcal_range', sql`${t.kcalLow} <= ${t.kcalHigh}`),
    check('food_log_items_protein_range', sql`${t.proteinLow} <= ${t.proteinHigh}`),
    check('food_log_items_carb_range', sql`${t.carbLow} <= ${t.carbHigh}`),
    check('food_log_items_fat_range', sql`${t.fatLow} <= ${t.fatHigh}`),
    // Explicit on both ends: with one end NULL a comparison is NULL, and CHECK passes NULL (the Phase 7 lesson).
    check(
      'food_log_items_fibre_range',
      sql`(${t.fibreLow} IS NULL AND ${t.fibreHigh} IS NULL) OR (${t.fibreLow} IS NOT NULL AND ${t.fibreHigh} IS NOT NULL AND ${t.fibreLow} >= 0 AND ${t.fibreLow} <= ${t.fibreHigh})`,
    ),
  ],
);

/**
 * §9.4 derived cache: one row per user-day, the sum of that day's live item
 * snapshots. Updated in the same transaction as every log and delete;
 * `pnpm db:rebuild-nutrition` rebuilds it. Owner J2: no target columns — the
 * day's target is the `nutrition_targets` row in effect on that date.
 */
export const dailyNutrition = pgTable(
  'daily_nutrition',
  {
    userId: userRef(),
    localDate: text('local_date').notNull(),
    kcalLow: total('kcal_low'),
    kcalHigh: total('kcal_high'),
    proteinLow: total('protein_low'),
    proteinHigh: total('protein_high'),
    carbLow: total('carb_low'),
    carbHigh: total('carb_high'),
    fatLow: total('fat_low'),
    fatHigh: total('fat_high'),
    fibreKnownLow: total('fibre_known_low'),
    fibreKnownHigh: total('fibre_known_high'),
    fibreUnknownItems: integer('fibre_unknown_items').notNull().default(0),
    itemCount: integer('item_count').notNull().default(0),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.localDate] }),
    check('daily_nutrition_counts', sql`${t.fibreUnknownItems} >= 0 AND ${t.itemCount} >= 0 AND ${t.fibreUnknownItems} <= ${t.itemCount}`),
  ],
);

export type FoodLogRow = typeof foodLogs.$inferSelect;
export type FoodLogItemRow = typeof foodLogItems.$inferSelect;
export type DailyNutritionRow = typeof dailyNutrition.$inferSelect;
export type SavedMealRow = typeof savedMeals.$inferSelect;
