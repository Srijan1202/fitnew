/**
 * Feedback (Phase 19, ADR-026): a tester's message from the app, read in the
 * admin panel. Owned by the user (CASCADE): exported with their data and
 * deleted with their account (Phase 17).
 */
import { sql } from 'drizzle-orm';
import { check, customType, index, integer, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const feedback = pgTable(
  'feedback',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
    category: text('category').notNull(),
    message: text('message').notNull(),
    appVersion: text('app_version').notNull(),
    status: text('status').notNull().default('new'),
    /** The owner's triage tag: red first, then yellow, then green; null = not tagged yet. */
    priority: text('priority'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    /** Beta 3.6: the phone, when the sender left it in (all three or none). */
    deviceModel: text('device_model'),
    deviceOs: text('device_os'),
    /** The screen it was sent from; may be null with a device. */
    screen: text('screen'),
  },
  (t) => [
    index('feedback_status_created_idx').on(t.status, t.createdAt),
    index('feedback_user_idx').on(t.userId),
    check('feedback_category', sql`${t.category} in ('bug', 'idea', 'food', 'training', 'other')`),
    check('feedback_status', sql`${t.status} in ('new', 'read', 'done')`),
    check('feedback_priority', sql`${t.priority} is null or ${t.priority} in ('red', 'yellow', 'green')`),
    check('feedback_message', sql`length(btrim(${t.message})) between 1 and 2000`),
    check('feedback_app_version', sql`length(btrim(${t.appVersion})) between 1 and 40`),
  ],
);

const bytea = customType<{ data: Buffer; driverData: Buffer }>({ dataType: () => 'bytea' });

/**
 * Beta 3.6: up to three pictures per message, resized on the phone. Kept in
 * the database (in its backups, and it moves with it if hosting changes,
 * ADR-025); deleted with the message or the account, and after six months.
 */
export const feedbackPictures = pgTable(
  'feedback_pictures',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    feedbackId: uuid('feedback_id').notNull().references(() => feedback.id, { onDelete: 'cascade' }),
    /** The order they were sent in (0–2). */
    position: integer('position').notNull().default(0),
    contentType: text('content_type').notNull(),
    bytes: integer('bytes').notNull(),
    data: bytea('data').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('feedback_pictures_feedback_idx').on(t.feedbackId),
    index('feedback_pictures_created_idx').on(t.createdAt),
    check('feedback_pictures_type', sql`${t.contentType} in ('image/jpeg', 'image/png', 'image/webp')`),
    check('feedback_pictures_bytes', sql`${t.bytes} between 1 and 1000000`),
    check('feedback_pictures_position', sql`${t.position} between 0 and 2`),
  ],
);

/** Beta 3.6: a reply from the FITOS team; the sender reads it in the app. */
export const feedbackReplies = pgTable(
  'feedback_replies',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    feedbackId: uuid('feedback_id').notNull().references(() => feedback.id, { onDelete: 'cascade' }),
    /** The admin who replied; kept as null if their account goes. */
    adminUserId: uuid('admin_user_id').references(() => users.id, { onDelete: 'set null' }),
    message: text('message').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    readAt: timestamp('read_at', { withTimezone: true }),
  },
  (t) => [
    index('feedback_replies_feedback_idx').on(t.feedbackId),
    check('feedback_replies_message', sql`length(btrim(${t.message})) between 1 and 2000`),
  ],
);
