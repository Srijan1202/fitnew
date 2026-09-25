import { describe, expect, it } from 'vitest';

import {
  TODAY_ACTION_KINDS,
  TODAY_EVENTS,
  TODAY_REASON_CODES,
  todayActionSchema,
  todayActionsResponseSchema,
  todayEventRequestSchema,
  todayEventResponseSchema,
  todayReasonSchema,
} from './today.js';

const ID = '11111111-1111-4111-8111-111111111111';
const action = {
  id: ID, kind: 'eat-protein', subjectKey: 'lunch', rank: 2, priority: 80, basis: 'calculated', target: 'eat',
  reason: { code: 'protein-behind', values: { slot: 'lunch', proteinTarget: 150, proteinLow: 30, proteinHigh: 42, kcalLeftLow: 1580, kcalLeftHigh: 1750 } },
  headline: '108–120 g protein to go', detail: 'Protein logged today is under three quarters of your 150 g target.',
};

describe('TODAY contracts (Phase 11)', () => {
  it('vocabularies: eleven kinds and codes (Phase 12 adds calorie-adjust), five events', () => {
    expect(TODAY_ACTION_KINDS).toHaveLength(11);
    expect(TODAY_REASON_CODES).toHaveLength(11);
    expect([...TODAY_EVENTS]).toEqual(['shown', 'opened', 'accepted', 'dismissed', 'completed']);
    for (const deferred of ['hydrate', 'add-steps', 'low-readiness']) {
      expect(TODAY_ACTION_KINDS as readonly string[]).not.toContain(deferred);
    }
  });

  it('an action: strict, ranked 1–4, reason values per code', () => {
    expect(todayActionSchema.safeParse(action).success).toBe(true);
    expect(todayActionSchema.safeParse({ ...action, rank: 5 }).success).toBe(false);
    expect(todayActionSchema.safeParse({ ...action, kind: 'hydrate' }).success).toBe(false);
    expect(todayActionSchema.safeParse({ ...action, extra: 1 }).success).toBe(false);
    expect(todayActionSchema.safeParse({ ...action, reason: { ...action.reason, values: { ...action.reason.values, note: 'x' } } }).success).toBe(false);
    expect(todayActionSchema.safeParse({ ...action, reason: { code: 'meal-remaining', values: action.reason.values } }).success).toBe(false);
  });

  it('reason schemas: the injured-limitation reason must name a swap', () => {
    const ok = { code: 'exercise-contraindicated', values: { exerciseId: ID, exerciseName: 'Squat', bodyParts: ['knee'], alternativeId: ID, alternativeName: 'Leg Press', affectedCount: 1 } };
    expect(todayReasonSchema.safeParse(ok).success).toBe(true);
    expect(todayReasonSchema.safeParse({ ...ok, values: { ...ok.values, alternativeId: null } }).success).toBe(false);
    expect(todayReasonSchema.safeParse({ code: 'looks-good', values: {} }).success).toBe(false);
  });

  it('the response: at most four actions', () => {
    const response = { date: '2026-09-24', generatedAt: '2026-09-24T07:30:00.000Z', engineVersion: 'today-1', actions: [action] };
    expect(todayActionsResponseSchema.safeParse(response).success).toBe(true);
    expect(todayActionsResponseSchema.safeParse({ ...response, actions: [action, action, action, action, action] }).success).toBe(false);
    expect(todayActionsResponseSchema.safeParse({ ...response, date: '24-09-2026' }).success).toBe(false);
  });

  it('the event request: strict, the five events, a UUID and an ISO time', () => {
    const body = { clientEventId: ID, event: 'shown', occurredAt: '2026-09-24T12:00:00+05:30' };
    expect(todayEventRequestSchema.safeParse(body).success).toBe(true);
    expect(todayEventRequestSchema.safeParse({ ...body, event: 'liked' }).success).toBe(false);
    expect(todayEventRequestSchema.safeParse({ ...body, clientEventId: 'abc' }).success).toBe(false);
    expect(todayEventRequestSchema.safeParse({ ...body, occurredAt: 'yesterday' }).success).toBe(false);
    expect(todayEventRequestSchema.safeParse({ ...body, analytics: true }).success).toBe(false);
    expect(todayEventResponseSchema.safeParse({ event: { id: ID, recommendationId: ID, event: 'shown', clientEventId: ID, occurredAt: body.occurredAt, receivedAt: '2026-09-24T06:31:00Z' } }).success).toBe(true);
  });
});
