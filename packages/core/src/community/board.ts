/**
 * Beta 6.2 (C11, C12): the Community boards' rules — what each metric ranks
 * by, the plan kept, the days planned, and places moved. Pure: the API
 * counts from the synced records and ranks with these.
 */
import { dayNumberOn, plusDays, type Schedule } from '../training/schedule.js';

export type BoardMetricKey = 'sessions' | 'distance' | 'streak' | 'active-days' | 'plan';

/** The counts a board row is ranked on. */
export interface BoardCounts {
  readonly sessions: number;
  readonly runM: number;
  readonly streak: number;
  readonly activeDays: number;
  readonly keptPct: number | null;
}

/**
 * The sort key, best first: the metric, then the next most telling counts.
 * The plan board breaks ties by sessions, so 3 of 3 beats 2 of 2.
 */
export function boardKey(metric: BoardMetricKey, r: BoardCounts): number[] {
  switch (metric) {
    case 'sessions':
      return [r.sessions, r.runM, r.streak];
    case 'distance':
      return [r.runM, r.sessions, r.streak];
    case 'streak':
      return [r.streak, r.sessions, r.runM];
    case 'active-days':
      return [r.activeDays, r.sessions, r.runM];
    case 'plan':
      return [r.keptPct ?? -1, r.sessions, r.streak];
  }
}

/** Whether a row belongs on a board: the plan board needs a plan; the others take everyone. */
export const onBoard = (metric: BoardMetricKey, r: BoardCounts): boolean => metric !== 'plan' || r.keptPct !== null;

/** Sessions done of those planned, in per cent (at most 100); null with nothing planned. */
export function keptPlanPct(sessions: number, planned: number): number | null {
  if (planned <= 0) return null;
  return Math.round((100 * Math.min(Math.max(0, sessions), planned)) / planned);
}

/**
 * Training days of a programme from `from` to `to` (local dates, inclusive):
 * weekdays for a week programme, cycle days for a cycle. `training` holds the
 * programme day numbers that are not rest.
 */
export function plannedBetween(schedule: Schedule, training: ReadonlySet<number>, from: string, to: string): number {
  let n = 0;
  for (let d = from; d <= to; d = plusDays(d, 1)) if (training.has(dayNumberOn(schedule, d))) n += 1;
  return n;
}

/** Places gained from one week's rank to the next; null when either is missing. */
export const placesMoved = (before: number | null, after: number | null): number | null =>
  before === null || after === null ? null : before - after;

/** Ranks with ties sharing a place (1, 2, 2, 4), best first by [boardKey]. */
export function rankBy<T extends BoardCounts & { readonly handle: string }>(rows: readonly T[], metric: BoardMetricKey): (T & { rank: number })[] {
  const sorted = rows.filter((r) => onBoard(metric, r)).sort((a, b) => {
    const ka = boardKey(metric, a);
    const kb = boardKey(metric, b);
    for (let i = 0; i < ka.length; i++) if (ka[i] !== kb[i]) return kb[i]! - ka[i]!;
    return a.handle.localeCompare(b.handle);
  });
  const out: (T & { rank: number })[] = [];
  sorted.forEach((r, i) => {
    const prev = out[i - 1];
    const tied = prev !== undefined && boardKey(metric, prev).every((v, j) => v === boardKey(metric, r)[j]);
    out.push({ ...r, rank: tied ? prev.rank : i + 1 });
  });
  return out;
}
