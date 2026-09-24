/**
 * TODAY (Phase 11, ADR-017): the ranked actions for the user's local day and
 * the events that record how the user responded. Actions are decided on the
 * server by the deterministic core engine; each carries a structured reason
 * (the source of truth) and deterministic English. Never an LLM (D3, D14).
 *
 * The vocabularies mirror `@fitos/core/recommend/*` exactly; the API suite
 * asserts they are identical.
 */
import { z } from 'zod';

import { isoDateSchema } from './profile.js';

export const TODAY_ACTION_KINDS = [
  'deload',
  'injured-limitation',
  'start-workout',
  'eat-protein',
  'eat-meal',
  'progress-load',
  'muscle-neglected',
  'rest-day',
  'celebrate-pr',
  'log-weight',
] as const;
export const todayActionKindSchema = z.enum(TODAY_ACTION_KINDS);
export type TodayActionKind = z.infer<typeof todayActionKindSchema>;

export const TODAY_REASON_CODES = [
  'deload-offered',
  'exercise-contraindicated',
  'session-scheduled',
  'protein-behind',
  'meal-remaining',
  'load-increase-due',
  'muscle-untrained',
  'rest-day',
  'pr-today',
  'weigh-in-due',
] as const;

export const ACTION_BASES = ['logged', 'calculated', 'estimated'] as const;
export const ACTION_TARGETS = ['train', 'eat', 'progress', 'today'] as const;
export const TODAY_EVENTS = ['shown', 'opened', 'accepted', 'dismissed', 'completed'] as const;
export const todayEventSchema = z.enum(TODAY_EVENTS);
export type TodayEventName = z.infer<typeof todayEventSchema>;

const slot = z.enum(['breakfast', 'lunch', 'snacks', 'dinner']);
const amount = z.number().finite().nonnegative();
const id = z.string().uuid();
const name = z.string().min(1).max(200);

/** One schema per reason code: exactly the values the engine emits, nothing else. */
export const todayReasonSchema = z.discriminatedUnion('code', [
  z.object({ code: z.literal('deload-offered'), values: z.object({ trigger: z.enum(['fatigue', 'mrv']).nullable() }).strict() }).strict(),
  z.object({
    code: z.literal('exercise-contraindicated'),
    values: z
      .object({
        exerciseId: id,
        exerciseName: name,
        bodyParts: z.array(z.string().min(1)).min(1),
        alternativeId: id,
        alternativeName: name,
        affectedCount: z.number().int().min(1),
      })
      .strict(),
  }).strict(),
  z.object({
    code: z.literal('session-scheduled'),
    values: z.object({ sessionName: name, exerciseCount: z.number().int().min(0), minutes: z.number().int().min(0) }).strict(),
  }).strict(),
  z.object({
    code: z.literal('protein-behind'),
    values: z
      .object({ slot, proteinTarget: amount, proteinLow: amount, proteinHigh: amount, kcalLeftLow: amount, kcalLeftHigh: amount })
      .strict(),
  }).strict(),
  z.object({
    code: z.literal('meal-remaining'),
    values: z
      .object({ slot, kcalLeftLow: amount, kcalLeftHigh: amount, proteinLeftLow: amount, proteinLeftHigh: amount })
      .strict(),
  }).strict(),
  z.object({
    code: z.literal('load-increase-due'),
    values: z.object({ exerciseId: id, exerciseName: name, weightKg: amount.nullable(), repTarget: z.string().min(1) }).strict(),
  }).strict(),
  z.object({
    code: z.literal('muscle-untrained'),
    values: z.object({ muscle: z.string().min(1), daysSince: z.number().int().min(0).nullable() }).strict(),
  }).strict(),
  z.object({
    code: z.literal('rest-day'),
    values: z
      .object({
        hasProgramme: z.boolean(),
        nextSessionName: name.nullable(),
        nextSessionDate: isoDateSchema.nullable(),
        kcalTarget: amount.nullable(),
        proteinTarget: amount.nullable(),
      })
      .strict(),
  }).strict(),
  z.object({
    code: z.literal('pr-today'),
    values: z
      .object({
        exerciseName: name,
        prType: z.enum(['1rm_est', 'weight', 'reps', 'volume']),
        value: z.number().finite(),
        previous: z.number().finite(),
        count: z.number().int().min(1),
      })
      .strict(),
  }).strict(),
  z.object({
    code: z.literal('weigh-in-due'),
    values: z.object({ daysSinceWeighIn: z.number().int().min(0).nullable() }).strict(),
  }).strict(),
]);
export type TodayReason = z.infer<typeof todayReasonSchema>;

export const todayActionSchema = z
  .object({
    /** The persisted recommendation's id — stable while the action's content is unchanged (D4). */
    id,
    kind: todayActionKindSchema,
    /** What the action is about within its kind ('' when there is only ever one). */
    subjectKey: z.string().max(200),
    /** The current rank on today's surface, 1–4 (the stored rank is the first one, P5). */
    rank: z.number().int().min(1).max(4),
    priority: z.number().int().min(0).max(100),
    basis: z.enum(ACTION_BASES),
    target: z.enum(ACTION_TARGETS),
    reason: todayReasonSchema,
    headline: z.string().min(1),
    detail: z.string().min(1),
  })
  .strict();
export type TodayAction = z.infer<typeof todayActionSchema>;

export const todayActionsResponseSchema = z
  .object({
    /** The user's local date the actions are for (stored timezone). */
    date: isoDateSchema,
    generatedAt: z.string().datetime({ offset: true }),
    engineVersion: z.string().min(1),
    /** At most four, ranked (§16.1). */
    actions: z.array(todayActionSchema).max(4),
  })
  .strict();
export type TodayActionsResponse = z.infer<typeof todayActionsResponseSchema>;

export const todayActionParamsSchema = z.object({ id }).strict();

export const todayEventRequestSchema = z
  .object({
    /** Minted on the phone; replaying it is safe (D7, D9). */
    clientEventId: id,
    event: todayEventSchema,
    /** When it happened on the phone (P3: the action's local day through 03:00 the next). */
    occurredAt: z.string().datetime({ offset: true }),
  })
  .strict();
export type TodayEventRequest = z.infer<typeof todayEventRequestSchema>;

export const todayEventRecordSchema = z
  .object({
    id,
    recommendationId: id,
    event: todayEventSchema,
    clientEventId: id,
    occurredAt: z.string().datetime({ offset: true }),
    receivedAt: z.string().datetime({ offset: true }),
  })
  .strict();
export type TodayEventRecord = z.infer<typeof todayEventRecordSchema>;

export const todayEventResponseSchema = z.object({ event: todayEventRecordSchema }).strict();
export type TodayEventResponse = z.infer<typeof todayEventResponseSchema>;
