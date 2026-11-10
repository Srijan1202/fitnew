/**
 * Beta 6.1 (F2): when a programme's days fall.
 *
 * A `week` programme is seven days on the weekdays (1 = Monday), as since
 * Phase 4. A `cycle` programme has N days (2–14) with no weekdays: day 1 on
 * its `start` date, day 2 the next, …, then day 1 again. The stored day
 * number (`program_days.day_of_week`) is the weekday for a week and the
 * place in the cycle for a cycle. Every reader asks `dayNumberOn`; nobody
 * works it out alone.
 *
 * Skip today (ADR-030) on a cycle moves `start` one day later, so today
 * becomes a rest-like gap and everything after moves a day.
 */

import { trainingDays } from './generator.js';

export const CYCLE_MIN_DAYS = 2;
export const CYCLE_MAX_DAYS = 14;

export type Schedule = { readonly kind: 'week' } | { readonly kind: 'cycle'; readonly start: string; readonly length: number };

const DAY_MS = 86_400_000;
const utc = (date: string): number => Date.parse(`${date}T00:00:00Z`);

/** ISO weekday of a local date: 1 = Monday … 7 = Sunday. */
export function weekdayOf(date: string): number {
  const d = new Date(utc(date)).getUTCDay();
  return d === 0 ? 7 : d;
}

/** The day number that falls on [date]. */
export function dayNumberOn(schedule: Schedule, date: string): number {
  if (schedule.kind === 'week') return weekdayOf(date);
  const n = schedule.length;
  const offset = Math.round((utc(date) - utc(schedule.start)) / DAY_MS);
  return (((offset % n) + n) % n) + 1;
}

/** yyyy-mm-dd, [n] days after [date]. */
export function plusDays(date: string, n: number): string {
  return new Date(utc(date) + n * DAY_MS).toISOString().slice(0, 10);
}

/** The next [count] dates from [from] with their day numbers. */
export function upcomingDays(schedule: Schedule, from: string, count: number): { date: string; day: number }[] {
  return Array.from({ length: count }, (_, i) => {
    const date = plusDays(from, i);
    return { date, day: dayNumberOn(schedule, date) };
  });
}

/**
 * A cycle made from a programme's training sessions, in order: [on]
 * sessions, then [off] rest days, repeated until every session is placed.
 * "4 on, 1 off" with four sessions is S1 S2 S3 S4 R; with five it is
 * S1 S2 S3 S4 R S5 R. Each entry is the session's index, or null for rest.
 * Null when the cycle would be shorter than CYCLE_MIN_DAYS or longer than
 * CYCLE_MAX_DAYS, or [on] is not at least 1.
 */
export function cycleLayout(sessions: number, on: number, off: number): (number | null)[] | null {
  if (sessions < 1 || on < 1 || off < 0) return null;
  const out: (number | null)[] = [];
  for (let s = 0; s < sessions; s += on) {
    for (let i = s; i < Math.min(s + on, sessions); i += 1) out.push(i);
    for (let r = 0; r < off; r += 1) out.push(null);
  }
  return out.length < CYCLE_MIN_DAYS || out.length > CYCLE_MAX_DAYS ? null : out;
}

/**
 * The weekdays [sessions] training sessions take on a week programme: the
 * generator's spread for 2–6, one on Monday, every day for 7. Null for more
 * than 7 (they do not fit in a week).
 */
export function weekdaysFor(sessions: number): number[] | null {
  if (sessions > 7) return null;
  if (sessions >= 2 && sessions <= 6) return [...trainingDays(sessions)];
  return [1, 2, 3, 4, 5, 6, 7].slice(0, Math.max(0, sessions));
}

/** Training sessions per seven days, for the reports and the ring. */
export function sessionsPerWeek(schedule: Schedule, sessions: number): number {
  if (schedule.kind === 'week') return sessions;
  return Math.round((sessions * 7) / schedule.length);
}
