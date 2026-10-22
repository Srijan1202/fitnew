/**
 * Premium requests (Phase 19, ADR-027): a user asks, the owner approves or
 * denies in the admin panel. One pending request per user at a time. Owned
 * by the user (CASCADE): exported and deleted with the account.
 */
import { sql } from 'drizzle-orm';
import { check, index, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const premiumRequests = pgTable(
  'premium_requests',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
    message: text('message'),
    status: text('status').notNull().default('pending'),
    note: text('note'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    decidedAt: timestamp('decided_at', { withTimezone: true }),
    decidedBy: uuid('decided_by').references(() => users.id, { onDelete: 'set null' }),
  },
  (t) => [
    uniqueIndex('premium_requests_one_pending').on(t.userId).where(sql`${t.status} = 'pending'`),
    index('premium_requests_status_created_idx').on(t.status, t.createdAt),
    check('premium_requests_status', sql`${t.status} in ('pending', 'approved', 'denied')`),
    check('premium_requests_message', sql`${t.message} is null or length(${t.message}) <= 500`),
    check('premium_requests_note', sql`${t.note} is null or length(${t.note}) <= 300`),
  ],
);
