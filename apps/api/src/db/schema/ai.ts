/**
 * AI usage (Phase 14, MASTER-SPEC §19.3; ADR-020 D3). One row per model call:
 * who, for what, which model, the tokens it cost, and how it ended. It is the
 * cost log §19.3 asks for ("log every call's token count") and the ledger
 * the hourly limits and the daily token budget are counted from — durable,
 * unlike an in-memory limiter. No prompt or answer text is stored.
 *
 * Kept with the user (cascade); `audit_logs` stays Phase 16's (admin actions).
 */
import { sql } from 'drizzle-orm';
import { check, index, integer, pgEnum, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const aiRouteEnum = pgEnum('ai_route', ['chat', 'parse', 'explain', 'guide']);
/** `discarded`: the model answered but a guard threw it away (§19.2). */
export const aiOutcomeEnum = pgEnum('ai_outcome', ['ok', 'discarded', 'failed']);

export const aiUsage = pgTable(
  'ai_usage',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    route: aiRouteEnum('route').notNull(),
    model: text('model').notNull(),
    inputTokens: integer('input_tokens').notNull().default(0),
    outputTokens: integer('output_tokens').notNull().default(0),
    outcome: aiOutcomeEnum('outcome').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('ai_usage_user_created_idx').on(t.userId, t.createdAt),
    check('ai_usage_tokens', sql`${t.inputTokens} >= 0 and ${t.outputTokens} >= 0`),
  ],
);

export type AiUsageRow = typeof aiUsage.$inferSelect;
