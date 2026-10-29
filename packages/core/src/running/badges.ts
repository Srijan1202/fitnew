/**
 * Beta 4.5 (owner 2026-10-30): more running badges, beside the distance
 * firsts (efforts.ts). Each is dated by the run that earned it; past runs
 * count; once earned, a badge is kept (the caller stores it once).
 *
 *  - Speed: the best effort at a distance under a time ("under" is
 *    strictly less), so it needs a run with a route.
 *  - Lifetime: every run's distance added up, in the order they were run;
 *    the run that takes the total past the mark earns it.
 *  - Consistency: a run in each of 4 ISO weeks in a row (Monday to
 *    Sunday, the user's local dates); 3 runs in one week; a running plan
 *    finished (its race run done).
 *
 * Two unlock a reward (owner): 1,000 km the Mileage theme, a 5K under
 * 20 minutes the Bolt app icon.
 */
import { isoWeekKey } from '../training/mesocycle.js';
import type { EffortKey } from './efforts.js';

export const SPEED_BADGES = [
  { id: 'speed-5k-30', key: '5k', seconds: 1800, name: '5K under 30 min', reward: null },
  { id: 'speed-5k-25', key: '5k', seconds: 1500, name: '5K under 25 min', reward: null },
  { id: 'speed-5k-20', key: '5k', seconds: 1200, name: '5K under 20 min', reward: 'Bolt app icon' },
  { id: 'speed-10k-60', key: '10k', seconds: 3600, name: '10K under 60 min', reward: null },
  { id: 'speed-10k-50', key: '10k', seconds: 3000, name: '10K under 50 min', reward: null },
  { id: 'speed-half-2h', key: 'half', seconds: 7200, name: 'Half marathon under 2 h', reward: null },
  { id: 'speed-marathon-4h', key: 'marathon', seconds: 14_400, name: 'Marathon under 4 h', reward: null },
] as const satisfies readonly { id: string; key: EffortKey; seconds: number; name: string; reward: string | null }[];

export const LIFETIME_BADGES = [
  { id: 'total-50k', metres: 50_000, name: '50 km run', reward: null },
  { id: 'total-100k', metres: 100_000, name: '100 km run', reward: null },
  { id: 'total-250k', metres: 250_000, name: '250 km run', reward: null },
  { id: 'total-500k', metres: 500_000, name: '500 km run', reward: null },
  { id: 'total-1000k', metres: 1_000_000, name: '1,000 km run', reward: 'Mileage theme' },
] as const;

export const CONSISTENCY_BADGES = [
  { id: 'weeks-4', name: 'Four weeks in a row', reward: null },
  { id: 'three-in-a-week', name: 'Three runs in a week', reward: null },
  { id: 'plan-finished', name: 'Plan finished', reward: null },
] as const;

export type SpeedBadgeId = (typeof SPEED_BADGES)[number]['id'];
export type LifetimeBadgeId = (typeof LIFETIME_BADGES)[number]['id'];
export type ConsistencyBadgeId = (typeof CONSISTENCY_BADGES)[number]['id'];
export type MoreBadgeId = SpeedBadgeId | LifetimeBadgeId | ConsistencyBadgeId;

/** One run as the badges see it. */
export interface BadgeRun {
  readonly startedAt: Date;
  /** The user's local date of the start (yyyy-mm-dd). */
  readonly localDate: string;
  readonly distanceM: number;
}

/** One best effort of one run. */
export interface BadgeEffort {
  readonly key: EffortKey;
  readonly seconds: number;
  readonly startedAt: Date;
}

const byTime = <T extends { startedAt: Date }>(xs: readonly T[]): T[] =>
  [...xs].sort((a, b) => a.startedAt.getTime() - b.startedAt.getTime());

/** Speed badges earned, each dated by the first run under its time. */
export function speedBadges(efforts: readonly BadgeEffort[]): Map<SpeedBadgeId, Date> {
  const out = new Map<SpeedBadgeId, Date>();
  for (const e of byTime(efforts)) {
    for (const b of SPEED_BADGES) {
      if (!out.has(b.id) && e.key === b.key && e.seconds < b.seconds) out.set(b.id, e.startedAt);
    }
  }
  return out;
}

/** Lifetime badges earned, each dated by the run that took the total past it. */
export function lifetimeBadges(runs: readonly BadgeRun[]): Map<LifetimeBadgeId, Date> {
  const out = new Map<LifetimeBadgeId, Date>();
  let total = 0;
  for (const r of byTime(runs)) {
    total += r.distanceM;
    for (const b of LIFETIME_BADGES) {
      if (!out.has(b.id) && total >= b.metres) out.set(b.id, r.startedAt);
    }
  }
  return out;
}

/** "2026-W44" → the next ISO week's key. */
function nextWeek(key: string): string {
  const [y, w] = key.split('-W').map(Number) as [number, number];
  // The Thursday of the week, plus 7 days, names the next week.
  const jan4 = Date.UTC(y, 0, 4);
  const jan4Day = new Date(jan4).getUTCDay() || 7;
  const thursday = jan4 + ((w - 1) * 7 + (4 - jan4Day)) * 86_400_000;
  return isoWeekKey(new Date(thursday + 7 * 86_400_000).toISOString().slice(0, 10));
}

/**
 * Consistency badges earned: a run in 4 ISO weeks in a row (dated by the
 * first run of the fourth week), 3 runs in one week (the third run), and a
 * finished plan ([planFinishedAt], null for none).
 */
export function consistencyBadges(runs: readonly BadgeRun[], planFinishedAt: Date | null): Map<ConsistencyBadgeId, Date> {
  const out = new Map<ConsistencyBadgeId, Date>();
  const perWeek = new Map<string, BadgeRun[]>();
  for (const r of byTime(runs)) {
    const k = isoWeekKey(r.localDate);
    perWeek.set(k, [...(perWeek.get(k) ?? []), r]);
    if (!out.has('three-in-a-week') && perWeek.get(k)!.length === 3) out.set('three-in-a-week', r.startedAt);
  }
  const weeks = [...perWeek.keys()].sort();
  let run = 0;
  let prev: string | null = null;
  for (const w of weeks) {
    run = prev !== null && nextWeek(prev) === w ? run + 1 : 1;
    prev = w;
    if (run === 4) {
      out.set('weeks-4', perWeek.get(w)![0]!.startedAt);
      break;
    }
  }
  if (planFinishedAt !== null) out.set('plan-finished', planFinishedAt);
  return out;
}
