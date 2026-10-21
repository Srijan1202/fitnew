/**
 * Admin (Phase 16, MASTER-SPEC §9.2, §20; ADR-022).
 *
 * `audit_logs`: one row per admin action, written in the same transaction
 * as the change (§20: "every admin action writes to audit_logs").
 * `feature_flags`: global switches served to the app by GET /meta/config.
 * `mess_dish_overrides`: a reviewed diet class for a dish slug, applied to
 * every menu that serves that slug (§20: corrections apply by slug).
 */
import { sql } from 'drizzle-orm';
import { boolean, check, index, jsonb, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.js';

export const auditLogs = pgTable(
  'audit_logs',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    // Kept when the actor's account goes (who did it stays answerable by id in metadata).
    actorUserId: uuid('actor_user_id').references(() => users.id, { onDelete: 'set null' }),
    action: text('action').notNull(),
    entity: text('entity').notNull(),
    entityId: text('entity_id'),
    metadata: jsonb('metadata').notNull().default(sql`'{}'::jsonb`),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('audit_logs_occurred_idx').on(t.occurredAt),
    index('audit_logs_entity_idx').on(t.entity, t.entityId),
    check('audit_logs_action', sql`length(btrim(${t.action})) > 0`),
  ],
);

export const featureFlags = pgTable(
  'feature_flags',
  {
    key: text('key').primaryKey(),
    enabled: boolean('enabled').notNull().default(false),
    description: text('description').notNull().default(''),
    updatedBy: uuid('updated_by').references(() => users.id, { onDelete: 'set null' }),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [check('feature_flags_key', sql`${t.key} ~ '^[a-z][a-z0-9-]{1,48}$'`)],
);

export const messDishOverrides = pgTable(
  'mess_dish_overrides',
  {
    dishSlug: text('dish_slug').primaryKey(),
    diet: text('diet').notNull(),
    reason: text('reason').notNull(),
    updatedBy: uuid('updated_by').references(() => users.id, { onDelete: 'set null' }),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('mess_dish_overrides_diet', sql`${t.diet} in ('veg', 'egg', 'nonveg')`),
    check('mess_dish_overrides_reason', sql`length(btrim(${t.reason})) > 0`),
  ],
);

export type AuditLogRow = typeof auditLogs.$inferSelect;
export type FeatureFlagRow = typeof featureFlags.$inferSelect;
