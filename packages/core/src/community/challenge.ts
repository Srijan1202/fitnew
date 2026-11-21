/**
 * Beta 6.5 (K2, C6): a club's challenge. The club's owner sets one goal for
 * a calendar month (owner Q2), and each member adds what they did in their
 * own month, in their own time zone. Pure: the API counts and stores.
 */
import { addDays } from '../nutrition/log.js';

export const CHALLENGE_METRICS = ['sessions', 'distance', 'active-days'] as const;
export type ChallengeMetric = (typeof CHALLENGE_METRICS)[number];

/** A target is a number of sessions, kilometres or active days. */
export const CHALLENGE_TARGET_MIN = 10;
export const CHALLENGE_TARGET_MAX = 100_000;

/** Finished challenges are kept a year; a club shows its last three. */
export const CHALLENGES_KEPT_MONTHS = 12;
export const CHALLENGE_HISTORY_SHOWN = 3;

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
] as const;

const UNIT: Record<ChallengeMetric, string> = { sessions: 'sessions', distance: 'km', 'active-days': 'active days' };

const daysFrom = (a: string, b: string): number => Math.round((Date.parse(b) - Date.parse(a)) / 86_400_000);

/** The month ("2026-12") a local date is in. */
export const monthOf = (date: string): string => date.slice(0, 7);

/** A month's first and last dates. */
export function monthRange(month: string): { from: string; to: string } {
  const y = Number(month.slice(0, 4));
  const m = Number(month.slice(5, 7));
  const next = m === 12 ? `${y + 1}-01-01` : `${y}-${String(m + 1).padStart(2, '0')}-01`;
  return { from: `${month}-01`, to: addDays(next, -1) };
}

/**
 * A count as it is shown, in the target's unit: distance is counted in
 * metres and shown in kilometres, rounded down to 0.1 km.
 */
export const inTargetUnit = (metric: ChallengeMetric, raw: number): number => (metric === 'distance' ? Math.floor(raw / 100) / 10 : raw);

/** Whether the club's count has reached the target. */
export const isReached = (metric: ChallengeMetric, raw: number, target: number): boolean => raw >= (metric === 'distance' ? target * 1000 : target);

/** The title made from the numbers, never typed: "200 sessions together in December". */
export const challengeTitle = (metric: ChallengeMetric, target: number, month: string): string =>
  `${target.toLocaleString('en-US')} ${UNIT[metric]} together in ${MONTH_NAMES[Number(month.slice(5, 7)) - 1]!}`;

/** Days left in the month, today included; 0 once it is over. */
export function daysLeft(month: string, today: string): number {
  const { to } = monthRange(month);
  return today > to ? 0 : daysFrom(today, to) + 1;
}

/**
 * Whether the month is over in every time zone (UTC+14 included) and every
 * member's count is final: two days after its last day, in UTC.
 */
export const monthOverEverywhere = (month: string, utcToday: string): boolean => utcToday >= addDays(monthRange(month).to, 2);

/**
 * The target the app suggests: the club's last 4 weeks scaled to the month,
 * plus 10%, rounded up to a multiple of 5, within the limits.
 */
export function suggestTarget(metric: ChallengeMetric, last4WeeksRaw: number, month: string): number {
  const { from, to } = monthRange(month);
  const perMonth = (metric === 'distance' ? last4WeeksRaw / 1000 : last4WeeksRaw) * ((daysFrom(from, to) + 1) / 28) * 1.1;
  // To the cent first, so 400 × 1.1 is 440, not 440.00000000000006 (→ 445).
  const nice = Math.ceil(Math.round(perMonth * 100) / 100 / 5) * 5;
  return Math.min(CHALLENGE_TARGET_MAX, Math.max(CHALLENGE_TARGET_MIN, nice));
}

/** The one push a reached challenge sends (owner Q4). */
export const challengeReachedLine = (club: string, title: string): { title: string; body: string } => ({
  title: `${club} reached its goal`,
  body: `${title}. Done together.`,
});
