/**
 * Recommendation events (MASTER-SPEC §16.3, §9.2; Phase 11, ADR-017 §5).
 *
 * Product records of how the user responded to a TODAY action — not
 * analytics (D15). These are the pure rules; the API applies them and adds
 * the checks that need the database (ownership, completion evidence).
 */

import { addDays, localDateOf, localHourOf } from '../nutrition/log.js';
import type { ActionKind } from './engine.js';

/** §9.2's five events (D7). */
export const TODAY_EVENTS = ['shown', 'opened', 'accepted', 'dismissed', 'completed'] as const;
export type TodayEvent = (typeof TODAY_EVENTS)[number];

/**
 * What proves a `completed` event (D7, P2), checked by the server against its
 * own records on the recommendation's local date. `null`: informational —
 * the action can be accepted or dismissed but never completed (P4).
 */
export type CompletionEvidence =
  | 'deload-accepted'
  | 'session-completed'
  | 'session-with-exercise'
  | 'session-with-muscle'
  | 'food-logged-in-slot'
  | 'weight-logged';

export const COMPLETION_EVIDENCE: Readonly<Record<ActionKind, CompletionEvidence | null>> = {
  deload: 'deload-accepted',
  'injured-limitation': null,
  'start-workout': 'session-completed',
  'eat-protein': 'food-logged-in-slot',
  'eat-meal': 'food-logged-in-slot',
  'progress-load': 'session-with-exercise',
  'muscle-neglected': 'session-with-muscle',
  'rest-day': null,
  'celebrate-pr': null,
  'log-weight': 'weight-logged',
};

export function isCompletable(kind: ActionKind): boolean {
  return COMPLETION_EVIDENCE[kind] !== null;
}

export type TransitionRejection =
  | 'not-shown' // any event before `shown`
  | 'not-completable' // `completed` on an informational action (P4)
  | 'not-accepted' // `completed` without the explicit primary action first (owner Q2)
  | 'accepted-and-dismissed' // the two exclude each other
  | 'after-dismissed' // opened / completed once dismissed
  | 'after-completed'; // dismissed once completed

export type TransitionResult =
  | { readonly outcome: 'record' }
  /** Already recorded for this recommendation: nothing new is stored (each event at most once). */
  | { readonly outcome: 'duplicate' }
  | { readonly outcome: 'reject'; readonly code: TransitionRejection };

/**
 * Whether `next` may be recorded for an action of `kind` that already has
 * `recorded` events. Impossible transitions are rejected, never absorbed (P4).
 */
export function checkTransition(kind: ActionKind, recorded: readonly TodayEvent[], next: TodayEvent): TransitionResult {
  const has = (e: TodayEvent): boolean => recorded.includes(e);
  if (has(next)) return { outcome: 'duplicate' };
  if (next !== 'shown' && !has('shown')) return { outcome: 'reject', code: 'not-shown' };
  if (next === 'completed' && !isCompletable(kind)) return { outcome: 'reject', code: 'not-completable' };
  if ((next === 'accepted' && has('dismissed')) || (next === 'dismissed' && has('accepted'))) {
    return { outcome: 'reject', code: 'accepted-and-dismissed' };
  }
  if ((next === 'opened' || next === 'completed') && has('dismissed')) return { outcome: 'reject', code: 'after-dismissed' };
  if (next === 'dismissed' && has('completed')) return { outcome: 'reject', code: 'after-completed' };
  // Owner Q2: the downstream flow starts from the primary action, so `completed`
  // needs `accepted` first; `opened` is never required.
  if (next === 'completed' && !has('accepted')) return { outcome: 'reject', code: 'not-accepted' };
  return { outcome: 'record' };
}

/** P3: an event may belong to the recommendation's local day through 03:00 of the next local day. */
export const LATE_NIGHT_GRACE_HOUR = 3;
/** P3: offline catch-up is accepted up to 7 days after the event happened. */
export const DELIVERY_WINDOW_MS = 7 * 24 * 3_600_000;
/** Clock skew tolerated between the phone and the server. */
export const CLOCK_SKEW_MS = 5 * 60_000;

export type TimingRejection =
  | 'before-recommendation' // earlier than the action existed
  | 'outside-day' // not on the recommendation's local day or before 03:00 the next
  | 'in-future' // after the server received it
  | 'delivered-too-late'; // more than 7 days after it happened

/**
 * P3 timing, in the user's zone (never UTC). `occurredAt` is when it happened
 * on the phone; `receivedAt` when the server got it. A late offline event is
 * still an event about its own recommendation and day: nothing here moves
 * it to today.
 */
export function checkEventTiming(params: {
  readonly generatedFor: string;
  readonly timeZone: string;
  readonly createdAt: Date;
  readonly occurredAt: Date;
  readonly receivedAt: Date;
}): { readonly ok: true } | { readonly ok: false; readonly code: TimingRejection } {
  const { generatedFor, timeZone, createdAt, occurredAt, receivedAt } = params;
  if (occurredAt.getTime() < createdAt.getTime() - CLOCK_SKEW_MS) return { ok: false, code: 'before-recommendation' };
  if (occurredAt.getTime() > receivedAt.getTime() + CLOCK_SKEW_MS) return { ok: false, code: 'in-future' };
  const day = localDateOf(occurredAt, timeZone);
  const onDay = day === generatedFor;
  const lateNight = day === addDays(generatedFor, 1) && localHourOf(occurredAt, timeZone) < LATE_NIGHT_GRACE_HOUR;
  if (!onDay && !lateNight) return { ok: false, code: 'outside-day' };
  if (receivedAt.getTime() - occurredAt.getTime() > DELIVERY_WINDOW_MS) return { ok: false, code: 'delivered-too-late' };
  return { ok: true };
}
