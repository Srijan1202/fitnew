/**
 * The MessIT mirror (Phase 9, §14.6, owner D1). Fetches all six endpoints,
 * validates each payload (core `isMessItResponse`), stores it deduplicated by
 * hash, records per-endpoint status, and writes an estimate for every dish
 * slug seen for the first time.
 *
 * Runs as a job (`node dist/jobs/mirror-mess.js`, or `pnpm mess:mirror`) —
 * the shape Cloud Scheduler will trigger later — and, for local development
 * only, on an in-process timer (server.ts). Cloud Scheduler itself is NOT set
 * up: it is a deferred deployment dependency while GCP work is paused.
 *
 * Nothing about any user is sent to MessIT: a plain GET with a fixed
 * User-Agent, no cookies, no identifiers. The app never calls MessIT; it
 * reads what this job stored.
 */
import { createHash } from 'node:crypto';

import { capMessConfidence } from '@fitos/core/mess/nutrition';
import { buildDay, isMessItResponse } from '@fitos/core/mess/providers/vit/provider';
import type { MessItResponse } from '@fitos/core/mess/types';

import type { DatabaseHandle } from '../../db/client.js';
import type { MessRow } from '../../db/schema.js';
import { MessRepository, type NewDishNutrition } from './repository.js';

export const MIRROR_USER_AGENT = 'FITOS-mess-mirror/1.0';
export const MIRROR_TIMEOUT_MS = 10_000;
/** Session-level advisory lock key: one mirror run at a time across processes. */
export const MIRROR_LOCK_KEY = 0x6d657373; // "mess"

/** What a fetch produced: the body text, or why there is none. */
export type FetchOutcome = { ok: true; body: string } | { ok: false };

/** The network seam. Tests pass a scripted one; nothing in tests reaches MessIT. */
export type MirrorFetcher = (url: string) => Promise<FetchOutcome>;

export const httpFetcher: MirrorFetcher = async (url) => {
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: { 'user-agent': MIRROR_USER_AGENT, accept: 'application/json' },
      credentials: 'omit',
      redirect: 'follow',
      signal: AbortSignal.timeout(MIRROR_TIMEOUT_MS),
    });
    if (!response.ok) return { ok: false };
    return { ok: true, body: await response.text() };
  } catch {
    return { ok: false };
  }
};

export type MessOutcome = 'new' | 'unchanged' | 'unreachable' | 'malformed';

export interface MirrorReport {
  readonly ranAt: string;
  /** False when another run held the lock; nothing was fetched. */
  readonly ran: boolean;
  readonly messes: readonly {
    readonly code: string;
    readonly outcome: MessOutcome;
    readonly dates: number;
    readonly dishesAdded: number;
  }[];
}

/** sha256 of the payload as parsed, re-serialised (stable across whitespace). */
export function payloadHash(payload: MessItResponse): string {
  return createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

/**
 * Parses a body. Malformed = not JSON, not the MessIT shape (every entry
 * checked, owner D23), or a payload for a different hostel/mess than the
 * endpoint it came from.
 */
export function parsePayload(body: string, endpoint: { hostel: number; mess: number }): MessItResponse | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (!isMessItResponse(parsed)) return null;
  if (parsed.hostel !== endpoint.hostel || parsed.mess !== endpoint.mess) return null;
  return parsed;
}

/**
 * Estimates for every dish the payload serves, keyed by slug. Classified by
 * keyword alone (servesNonVeg = true) so a slug's estimate does not depend on
 * which mess happened to be mirrored first. Dishes with no estimate get none.
 */
export function estimatesOf(payload: MessItResponse): NewDishNutrition[] {
  const bySlug = new Map<string, NewDishNutrition>();
  for (const day of payload.menu) {
    for (const meal of buildDay(payload, day.date, true).meals) {
      for (const dish of meal.dishes) {
        if (bySlug.has(dish.id) || dish.nutrition === null || dish.id === '') continue;
        const n = dish.nutrition;
        bySlug.set(dish.id, {
          dishSlug: dish.id,
          name: dish.name,
          servingLabel: n.servingLabel,
          servingGrams: n.servingGrams === null ? null : String(n.servingGrams),
          kcalLow: String(n.macros.kcalLow),
          kcalHigh: String(n.macros.kcalHigh),
          proteinLow: String(n.macros.proteinLow),
          proteinHigh: String(n.macros.proteinHigh),
          carbLow: String(n.macros.carbLow),
          carbHigh: String(n.macros.carbHigh),
          fatLow: String(n.macros.fatLow),
          fatHigh: String(n.macros.fatHigh),
          fibreLow: null,
          fibreHigh: null,
          confidence: capMessConfidence(n.confidence),
        });
      }
    }
  }
  return [...bySlug.values()];
}

/** The upstream ids each seeded mess expects, from its URL (`hostel-<h>-mess-<m>.json`). */
export function endpointIds(mess: Pick<MessRow, 'sourceUrl'>): { hostel: number; mess: number } | null {
  const m = /hostel-(\d+)-mess-(\d+)\.json$/.exec(mess.sourceUrl);
  if (m === null) return null;
  return { hostel: Number(m[1]), mess: Number(m[2]) };
}

async function mirrorOne(repo: MessRepository, mess: MessRow, fetcher: MirrorFetcher, now: () => Date): Promise<MirrorReport['messes'][number]> {
  const ids = endpointIds(mess);
  const result = await fetcher(mess.sourceUrl);
  if (!result.ok) {
    await repo.recordFailure(mess.id, 'unreachable', now());
    return { code: mess.code, outcome: 'unreachable', dates: 0, dishesAdded: 0 };
  }
  const payload = ids === null ? null : parsePayload(result.body, ids);
  if (payload === null) {
    // Fail safe: the previous good copy stays; only the status records the reject.
    await repo.recordFailure(mess.id, 'malformed', now());
    return { code: mess.code, outcome: 'malformed', dates: 0, dishesAdded: 0 };
  }
  const { isNew } = await repo.recordSuccess(mess.id, payload, payloadHash(payload), now());
  // Every successful fetch, new or not: a dish that gained an estimate in a
  // later release (D9) gets its row on the next run. Existing rows never change.
  const dishesAdded = await repo.insertNutritionIfAbsent(estimatesOf(payload));
  return { code: mess.code, outcome: isNew ? 'new' : 'unchanged', dates: payload.menu.length, dishesAdded };
}

/**
 * One mirror run over every seeded mess. Endpoints are independent: one
 * failing never stops the others. Holds a session advisory lock so two runs
 * (a timer and a manual job) never overlap; the loser reports `ran: false`.
 */
export async function runMirror(
  handle: DatabaseHandle,
  options: { fetcher?: MirrorFetcher; now?: () => Date } = {},
): Promise<MirrorReport> {
  const fetcher = options.fetcher ?? httpFetcher;
  const now = options.now ?? (() => new Date());
  const ranAt = now().toISOString();
  const reserved = await handle.client.reserve();
  try {
    const [lock] = await reserved<{ locked: boolean }[]>`select pg_try_advisory_lock(${MIRROR_LOCK_KEY}) as locked`;
    if (lock?.locked !== true) return { ranAt, ran: false, messes: [] };
    try {
      const repo = new MessRepository(handle.db);
      const messes = await repo.allMesses();
      const report: MirrorReport['messes'][number][] = [];
      for (const mess of messes) report.push(await mirrorOne(repo, mess, fetcher, now));
      return { ranAt, ran: true, messes: report };
    } finally {
      await reserved`select pg_advisory_unlock(${MIRROR_LOCK_KEY})`;
    }
  } finally {
    reserved.release();
  }
}
