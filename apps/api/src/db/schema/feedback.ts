/**
 * Feedback (Phase 19, ADR-026): a tester's message from the app, read in the
 * admin panel. Owned by the user (CASCADE): exported with their data and
 * deleted with their account (Phase 17).
 */
import { sql } from 'drizzle-orm';
import { check, index, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

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
