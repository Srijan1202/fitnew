/**
 * Progress (Phase 12, MASTER-SPEC §9.2 "Body & progress", §17; ADR-018).
 *
 * `body_measurements`: one tape reading per user, local date and site
 * (waist/chest/arm/thigh/hip, centimetres). Source rows — nothing derived
 * is stored (§9.4): changes over a window are computed on read. A second
 * reading for the same date and site replaces the first (upsert), and a
 * soft-deleted row comes back on the next write, as `body_metrics` does.
 *
 * `progress_photos` is not built: photos are deferred (owner D3, ADR-018)
 * because they need the private Cloud Storage bucket and signed URLs.
 */
import { sql } from 'drizzle-orm';
import { check, numeric, pgEnum, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const measurementSiteEnum = pgEnum('measurement_site', ['waist', 'chest', 'arm', 'thigh', 'hip']);

export const bodyMeasurements = pgTable(
  'body_measurements',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** yyyy-mm-dd in the user's zone, fixed at write (like `body_metrics.measured_on`). */
    measuredOn: text('measured_on').notNull(),
    site: measurementSiteEnum('site').notNull(),
    valueCm: numeric('value_cm', { precision: 5, scale: 1 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('body_measurements_user_day_site').on(t.userId, t.measuredOn, t.site),
    check('body_measurements_date', sql`${t.measuredOn} ~ '^\\d{4}-\\d{2}-\\d{2}$'`),
    check('body_measurements_value', sql`${t.valueCm} between 10 and 250`),
  ],
);

export type BodyMeasurementRow = typeof bodyMeasurements.$inferSelect;
