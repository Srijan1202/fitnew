/**
 * Notifications (Phase 15, MASTER-SPEC §9.2 `notifications`, §21; ADR-021).
 *
 * `notifications` is the ledger of what was planned and what happened to
 * it on the phone: one row per (user, kind, local date), so a re-plan
 * updates the same row and the phone's outcome reports always find it.
 * The planner reads it for the cap (already sent today), back-off (ignored
 * in a row) and variety (words used recently, open rates).
 *
 * `push_tokens` holds FCM registrations (§31 Phase 15) for server push once
 * the API is hosted; nothing is pushed from the server yet (ADR-021 D2).
 */
import { sql } from 'drizzle-orm';
import { check, index, pgEnum, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const notifyKindEnum = pgEnum('notify_kind', [
  'workout-reminder',
  'missed-session',
  'protein-gap',
  'streak-at-risk',
  'weigh-in',
  'recovery-checkin',
  'weekly-recap',
  'comeback',
  'meal-breakfast',
  'meal-lunch',
  'meal-dinner',
]);
/** planned → delivered → opened, or planned → cancelled (its point was gone, on the phone). */
export const notifyStatusEnum = pgEnum('notify_status', ['planned', 'delivered', 'opened', 'cancelled']);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    kind: notifyKindEnum('kind').notNull(),
    /** yyyy-mm-dd in the user's zone. */
    localDate: text('local_date').notNull(),
    scheduledFor: timestamp('scheduled_for', { withTimezone: true }).notNull(),
    /** The template id (core notify/copy.ts). */
    variant: text('variant').notNull(),
    title: text('title').notNull(),
    body: text('body').notNull(),
    status: notifyStatusEnum('status').notNull().default('planned'),
    sentAt: timestamp('sent_at', { withTimezone: true }),
    openedAt: timestamp('opened_at', { withTimezone: true }),
    cancelledAt: timestamp('cancelled_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('notifications_user_kind_day').on(t.userId, t.kind, t.localDate),
    index('notifications_user_day_idx').on(t.userId, t.localDate),
    check('notifications_local_date_format', sql`${t.localDate} ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`),
  ],
);

export type NotificationRow = typeof notifications.$inferSelect;

export const pushTokens = pgTable(
  'push_tokens',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    token: text('token').notNull(),
    platform: text('platform').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // A device token belongs to whoever signed in on it last.
    uniqueIndex('push_tokens_token').on(t.token),
    index('push_tokens_user_idx').on(t.userId),
    check('push_tokens_platform', sql`${t.platform} in ('android')`),
  ],
);
