/**
 * TODAY (Phase 11, ADR-017; MASTER-SPEC §9.2 as amended).
 *
 * `recommendations`: one IMMUTABLE row per action the engine put on a user's
 * surface, identified by (user, local day, kind, subject, content hash) — the
 * same content on a later GET reuses its id; changed content is a new row;
 * rows are never updated (D4). The whole `UserModel` is never stored, only
 * its digest (D16). Kept indefinitely; a deleted user takes them along (D10).
 *
 * `recommendation_events`: product records of how the user responded (§16.3)
 * — not analytics (D15). Idempotent per (user, client event id); each event
 * at most once per recommendation (D7).
 *
 * No foreign keys to food logs, menus, dishes or workouts: actions are
 * day-level decisions, not copies of those records.
 */
import { sql } from 'drizzle-orm';
import { check, date, index, jsonb, pgEnum, pgTable, smallint, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { programs } from './training.js';
import { users } from './users.js';

export const todayActionKindEnum = pgEnum('today_action_kind', [
  'deload',
  'injured-limitation',
  'start-workout',
  'eat-protein',
  'eat-meal',
  'progress-load',
  'muscle-neglected',
  'rest-day',
  'calorie-adjust', // Phase 12 (migration 0015)
  'celebrate-pr',
  'log-weight',
]);
export const actionBasisEnum = pgEnum('action_basis', ['logged', 'calculated', 'estimated']);
export const actionTargetEnum = pgEnum('action_target', ['train', 'eat', 'progress', 'today']);
export const recommendationEventEnum = pgEnum('recommendation_event', ['shown', 'opened', 'accepted', 'dismissed', 'completed']);

export const recommendations = pgTable(
  'recommendations',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** The user's local date the action was decided for. */
    generatedFor: date('generated_for', { mode: 'string' }).notNull(),
    kind: todayActionKindEnum('kind').notNull(),
    subjectKey: text('subject_key').notNull().default(''),
    /** The rank when this content was first generated (P5); the API returns the current rank. */
    rank: smallint('rank').notNull(),
    priority: smallint('priority').notNull(),
    basis: actionBasisEnum('basis').notNull(),
    target: actionTargetEnum('target').notNull(),
    /** `{ reason: {code, values}, engineVersion, inputDigest }`. */
    payload: jsonb('payload').notNull(),
    engineVersion: text('engine_version').notNull(),
    inputDigest: text('input_digest').notNull(),
    headline: text('headline').notNull(),
    detail: text('detail').notNull(),
    contentHash: text('content_hash').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('recommendations_identity').on(t.userId, t.generatedFor, t.kind, t.subjectKey, t.contentHash),
    index('recommendations_user_day_idx').on(t.userId, t.generatedFor),
    check('recommendations_rank', sql`${t.rank} between 1 and 4`),
    check('recommendations_priority', sql`${t.priority} between 0 and 100`),
    check('recommendations_content_hash', sql`${t.contentHash} ~ '^[0-9a-f]{64}$'`),
    check('recommendations_input_digest', sql`${t.inputDigest} ~ '^[0-9a-f]{64}$'`),
    check('recommendations_text', sql`length(${t.headline}) > 0 AND length(${t.detail}) > 0`),
  ],
);

export const recommendationEvents = pgTable(
  'recommendation_events',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    recommendationId: uuid('recommendation_id')
      .notNull()
      .references(() => recommendations.id, { onDelete: 'cascade' }),
    /** Denormalised for ownership checks and indexing. */
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    event: recommendationEventEnum('event').notNull(),
    clientEventId: uuid('client_event_id').notNull(),
    /** When it happened on the phone (P3). */
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    /** When the server received it — separate, so late offline events keep their own time. */
    receivedAt: timestamp('received_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('recommendation_events_client_id').on(t.userId, t.clientEventId),
    uniqueIndex('recommendation_events_once').on(t.recommendationId, t.event),
    index('recommendation_events_user_received_idx').on(t.userId, t.receivedAt),
  ],
);

/**
 * Every activation of a deload week, kept after the week closes (migration
 * 0014). Phase 6 stores only the CURRENT week in `programs.deload_started_at`
 * and clears it when the week ends, which would erase the evidence a delayed
 * TODAY `completed` event needs (P3: up to 7 days late). A trigger on
 * `programs` appends a row whenever `deload_started_at` is set, so the Phase 6
 * code and lifecycle are unchanged. Read only by TODAY's completion evidence.
 */
export const deloadActivations = pgTable(
  'deload_activations',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    programId: uuid('program_id')
      .notNull()
      .references(() => programs.id, { onDelete: 'cascade' }),
    /** The activation time Phase 6 wrote to `programs.deload_started_at` (server time). */
    startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('deload_activations_program_started').on(t.programId, t.startedAt),
    index('deload_activations_user_started_idx').on(t.userId, t.startedAt),
  ],
);

export type RecommendationRow = typeof recommendations.$inferSelect;
export type RecommendationEventRow = typeof recommendationEvents.$inferSelect;
