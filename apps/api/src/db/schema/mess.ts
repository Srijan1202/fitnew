/**
 * VIT mess (Phase 9, §9.2 / §14). The server mirrors MessIT and keeps every
 * distinct payload; menus are built from those snapshots on read with the
 * packages/core parser. There are deliberately no `mess_days`, `mess_meals`
 * or `mess_dishes` tables (owner D2, ADR-014): they would only be a cache of
 * the snapshots that has to be kept in step.
 *
 * A logged mess dish is a Phase 8 snapshot like any food; `food_log_items`
 * only records which dish it came from (`mess_dish_slug`, owner D10).
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  jsonb,
  numeric,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { foodSourceEnum, nutritionConfidenceEnum } from './enums.js';
import { foods } from './food.js';
import { users } from './users.js';

const SLUG = `'^[a-z0-9]+(-[a-z0-9]+)*$'`;

/** A menu provider (VIT Vellore's MessIT). Seeded from packages/core config. */
export const messProviders = pgTable(
  'mess_providers',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    slug: text('slug').notNull().unique(),
    displayName: text('display_name').notNull(),
    status: text('status').notNull().default('active'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [check('mess_providers_status', sql`${t.status} in ('active', 'disabled')`)],
);

/**
 * The six messes, one per MessIT endpoint, with that endpoint's own sync
 * status (owner D4 — freshness differs per endpoint, §14.2).
 */
export const messes = pgTable(
  'messes',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    providerId: uuid('provider_id')
      .notNull()
      .references(() => messProviders.id, { onDelete: 'restrict' }),
    /** Public code, e.g. `mens-veg` (core `messCode`). */
    code: text('code').notNull().unique(),
    hostelId: text('hostel_id').notNull(),
    hostelLabel: text('hostel_label').notNull(),
    messId: text('mess_id').notNull(),
    messLabel: text('mess_label').notNull(),
    servesNonVeg: boolean('serves_non_veg').notNull(),
    sourceUrl: text('source_url').notNull(),
    // --- mirror status, per endpoint ---
    lastAttemptAt: timestamp('last_attempt_at', { withTimezone: true }),
    lastSuccessAt: timestamp('last_success_at', { withTimezone: true }),
    /** When a fetch last returned a payload not seen before. */
    lastChangedAt: timestamp('last_changed_at', { withTimezone: true }),
    lastError: text('last_error'),
    consecutiveFailures: integer('consecutive_failures').notNull().default(0),
  },
  (t) => [
    uniqueIndex('messes_provider_hostel_mess').on(t.providerId, t.hostelId, t.messId),
    check('messes_code_format', sql.raw(`"code" ~ ${SLUG}`)),
    check('messes_last_error', sql`${t.lastError} is null or ${t.lastError} in ('unreachable', 'malformed')`),
    check('messes_failures_nonnegative', sql`${t.consecutiveFailures} >= 0`),
  ],
);

/**
 * Every distinct payload an endpoint has returned, verbatim (§14.6). A fetch
 * that returns a payload already stored only moves `last_seen_at` (dedupe by
 * `payload_hash`, owner D3). Never updated in content, never deleted: MessIT
 * keeps no history, so this is the only record of what it published.
 */
export const messMenuSnapshots = pgTable(
  'mess_menu_snapshots',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    messId: uuid('mess_id')
      .notNull()
      .references(() => messes.id, { onDelete: 'cascade' }),
    rawPayload: jsonb('raw_payload').notNull(),
    /** sha256 of the response body as received. */
    payloadHash: text('payload_hash').notNull(),
    /** The dates the payload publishes, for "which snapshot has this day". */
    dates: text('dates').array().notNull(),
    firstSeenAt: timestamp('first_seen_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('mess_menu_snapshots_mess_hash').on(t.messId, t.payloadHash),
    // Newest CONTENT first: a payload seen again (upstream reverted) is current again.
    index('mess_menu_snapshots_mess_recent_idx').on(t.messId, t.lastSeenAt.desc()),
    index('mess_menu_snapshots_dates_idx').using('gin', t.dates),
    check('mess_menu_snapshots_hash_format', sql`${t.payloadHash} ~ '^[0-9a-f]{64}$'`),
    check('mess_menu_snapshots_seen_order', sql`${t.firstSeenAt} <= ${t.lastSeenAt}`),
  ],
);

/**
 * The current estimate per dish slug (§9.2, owner D6), from the core table.
 * Written the first time a slug is seen and never overwritten by a re-run,
 * so enrichment is idempotent. Never `high` confidence (owner: structural
 * cap), always `estimated`; fibre is not estimated (NULL = unknown).
 * `food_id` is reserved for a later link to the food library (unused).
 */
export const messDishNutrition = pgTable(
  'mess_dish_nutrition',
  {
    dishSlug: text('dish_slug').primaryKey(),
    name: text('name').notNull(),
    servingLabel: text('serving_label').notNull(),
    servingGrams: numeric('serving_grams', { precision: 7, scale: 2 }),
    kcalLow: numeric('kcal_low', { precision: 8, scale: 2 }).notNull(),
    kcalHigh: numeric('kcal_high', { precision: 8, scale: 2 }).notNull(),
    proteinLow: numeric('protein_low', { precision: 8, scale: 2 }).notNull(),
    proteinHigh: numeric('protein_high', { precision: 8, scale: 2 }).notNull(),
    carbLow: numeric('carb_low', { precision: 8, scale: 2 }).notNull(),
    carbHigh: numeric('carb_high', { precision: 8, scale: 2 }).notNull(),
    fatLow: numeric('fat_low', { precision: 8, scale: 2 }).notNull(),
    fatHigh: numeric('fat_high', { precision: 8, scale: 2 }).notNull(),
    fibreLow: numeric('fibre_low', { precision: 8, scale: 2 }),
    fibreHigh: numeric('fibre_high', { precision: 8, scale: 2 }),
    confidence: nutritionConfidenceEnum('confidence').notNull(),
    source: foodSourceEnum('source').notNull().default('estimated'),
    foodId: uuid('food_id').references(() => foods.id, { onDelete: 'set null' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('mess_dish_nutrition_slug_format', sql.raw(`"dish_slug" ~ ${SLUG}`)),
    // Owner (Phase 9): the medium cap is structural, not a seed convention.
    check('mess_dish_nutrition_confidence_cap', sql`${t.confidence} <> 'high'`),
    check('mess_dish_nutrition_source', sql`${t.source} = 'estimated'`),
    check('mess_dish_nutrition_serving', sql`length(btrim(${t.servingLabel})) > 0 AND (${t.servingGrams} IS NULL OR ${t.servingGrams} > 0)`),
    check('mess_dish_nutrition_nonnegative', sql`${t.kcalLow} >= 0 AND ${t.proteinLow} >= 0 AND ${t.carbLow} >= 0 AND ${t.fatLow} >= 0`),
    check(
      'mess_dish_nutrition_ranges',
      sql`${t.kcalLow} <= ${t.kcalHigh} AND ${t.proteinLow} <= ${t.proteinHigh} AND ${t.carbLow} <= ${t.carbHigh} AND ${t.fatLow} <= ${t.fatHigh}`,
    ),
    check(
      'mess_dish_nutrition_fibre_range',
      sql`(${t.fibreLow} IS NULL AND ${t.fibreHigh} IS NULL) OR (${t.fibreLow} IS NOT NULL AND ${t.fibreHigh} IS NOT NULL AND ${t.fibreLow} >= 0 AND ${t.fibreLow} <= ${t.fibreHigh})`,
    ),
  ],
);

/**
 * A user's report that a dish's estimate is wrong (owner D17). Stored as
 * `pending`; it changes no estimate. Review (and `reviewed_by`) is Phase 16.
 * No foreign key to `mess_dish_nutrition`: a dish with no estimate can be
 * reported too.
 */
export const messDishCorrections = pgTable(
  'mess_dish_corrections',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    dishSlug: text('dish_slug').notNull(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    clientCorrectionId: uuid('client_correction_id').notNull(),
    field: text('field').notNull(),
    valueLow: numeric('value_low', { precision: 8, scale: 2 }),
    valueHigh: numeric('value_high', { precision: 8, scale: 2 }),
    dietValue: text('diet_value'),
    note: text('note'),
    status: text('status').notNull().default('pending'),
    reviewedBy: uuid('reviewed_by').references(() => users.id, { onDelete: 'set null' }),
    reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('mess_dish_corrections_user_client_id').on(t.userId, t.clientCorrectionId),
    index('mess_dish_corrections_slug_status_idx').on(t.dishSlug, t.status),
    check('mess_dish_corrections_slug_format', sql.raw(`"dish_slug" ~ ${SLUG}`)),
    check('mess_dish_corrections_status', sql`${t.status} in ('pending', 'accepted', 'rejected')`),
    check('mess_dish_corrections_field', sql`${t.field} in ('kcal', 'protein', 'carb', 'fat', 'diet', 'other')`),
    check(
      'mess_dish_corrections_value',
      sql`CASE
        WHEN ${t.field} in ('kcal', 'protein', 'carb', 'fat') THEN ${t.valueLow} IS NOT NULL AND ${t.valueHigh} IS NOT NULL AND ${t.valueLow} >= 0 AND ${t.valueLow} <= ${t.valueHigh} AND ${t.dietValue} IS NULL
        WHEN ${t.field} = 'diet' THEN ${t.dietValue} in ('veg', 'egg', 'nonveg') AND ${t.valueLow} IS NULL AND ${t.valueHigh} IS NULL
        ELSE ${t.note} IS NOT NULL AND ${t.valueLow} IS NULL AND ${t.valueHigh} IS NULL AND ${t.dietValue} IS NULL
      END`,
    ),
    check('mess_dish_corrections_note_length', sql`${t.note} IS NULL OR length(btrim(${t.note})) between 1 and 280`),
  ],
);

export type MessProviderRow = typeof messProviders.$inferSelect;
export type MessRow = typeof messes.$inferSelect;
export type MessMenuSnapshotRow = typeof messMenuSnapshots.$inferSelect;
export type MessDishNutritionRow = typeof messDishNutrition.$inferSelect;
export type MessDishCorrectionRow = typeof messDishCorrections.$inferSelect;

/**
 * Provenance for any change to a stored estimate (Phase 10 Amendment B,
 * ADR-016). Estimates are write-once from the mirror; when one is corrected
 * by a migration, the previous and the new values are kept here with the
 * reason. Logged snapshots never change. This holds data corrections, not
 * recommendations (nothing about recommendations is stored).
 */
export const messDishNutritionRevisions = pgTable(
  'mess_dish_nutrition_revisions',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    dishSlug: text('dish_slug')
      .notNull()
      .references(() => messDishNutrition.dishSlug, { onDelete: 'cascade' }),
    reason: text('reason').notNull(),
    previous: jsonb('previous').notNull(),
    current: jsonb('current').notNull(),
    revisedAt: timestamp('revised_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('mess_dish_nutrition_revisions_slug_idx').on(t.dishSlug, t.revisedAt),
    check('mess_dish_nutrition_revisions_reason', sql`length(btrim(${t.reason})) > 0`),
  ],
);
