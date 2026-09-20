/**
 * Consent evidence, nutrition targets, body readings.
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
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

import { consentTypeEnum, weightSourceEnum } from './enums.js';
import { users } from './users.js';

const userRef = () =>
  uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' });

/**
 * DPDP evidence (§23). APPEND-ONLY: nothing updates or deletes a row while
 * the user exists. Revocation is a new row with `granted = false`. The
 * `ip_hash` is a salted SHA-256 — enough to show a request came from
 * somewhere, never enough to recover the address.
 */
export const consentRecords = pgTable(
  'consent_records',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    consentType: consentTypeEnum('consent_type').notNull(),
    granted: boolean('granted').notNull(),
    policyVersion: text('policy_version').notNull(),
    grantedAt: timestamp('granted_at', { withTimezone: true }).notNull().defaultNow(),
    ipHash: text('ip_hash'),
  },
  (t) => [index('consent_records_user_type_idx').on(t.userId, t.consentType, t.grantedAt)],
);

/**
 * Target history (§9.2). A new row per change; a past row is never mutated,
 * so "what was I told to eat on the 3rd" is always answerable. The engine's
 * rationale is persisted with the numbers it explains — the explanation shown
 * later is the one that was true at the time, not a recomputation.
 *
 * Energy and macros are integers: packages/core rounds them, and an integer
 * is exact (§9.1 forbids float, not integer).
 */
export const nutritionTargets = pgTable(
  'nutrition_targets',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    effectiveFrom: text('effective_from').notNull(), // yyyy-mm-dd in the user's zone
    kcal: integer('kcal').notNull(),
    proteinG: integer('protein_g').notNull(),
    carbG: integer('carb_g').notNull(),
    fatG: integer('fat_g').notNull(),
    fiberG: integer('fiber_g').notNull(),
    bmr: integer('bmr').notNull(),
    tdeeEstimate: integer('tdee_estimate').notNull(),
    rationale: jsonb('rationale').notNull().$type<string[]>(),
    reason: text('reason').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('nutrition_targets_user_effective_idx').on(t.userId, t.effectiveFrom, t.createdAt)],
);

/**
 * Body readings (§9.2 "Body & progress"). Pulled forward from Phase 12
 * because the onboarding weight has to live somewhere the trend engine will
 * later read. One reading per user per day; trend is DERIVED, never stored.
 */
export const bodyMetrics = pgTable(
  'body_metrics',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    measuredOn: text('measured_on').notNull(), // yyyy-mm-dd in the user's zone
    weightKg: numeric('weight_kg', { precision: 5, scale: 2 }).notNull(),
    source: weightSourceEnum('source').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [uniqueIndex('body_metrics_user_day').on(t.userId, t.measuredOn)],
);

export type NutritionTargetsRow = typeof nutritionTargets.$inferSelect;
export type BodyMetricRow = typeof bodyMetrics.$inferSelect;
