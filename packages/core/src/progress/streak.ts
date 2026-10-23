/**
 * Beta 3.3 (owner 2026-10-23, ADR-018 amendment): the streak and the weekly
 * goal ring on Home. Pure: the caller passes LOCAL dates (yyyy-mm-dd) in the
 * user's calendar.
 *
 * Rules the owner chose:
 *  - a day COUNTS when a workout was completed or any food was logged;
 *  - a planned rest day and the day used by Skip today are EXCUSED: they
 *    neither break nor add to the run;
 *  - any other day without a log ends the run;
 *  - today not logged yet does not break it (there is still time).
 */
import { addDays } from '../nutrition/log.js';
import { isoWeekKey } from '../training/mesocycle.js';

/** How far back a streak is looked for (the best run is within it). */
export const STREAK_LOOKBACK_DAYS = 400;

export interface StreakInput {
  /** The user's local today. */
  readonly today: string;
  /** Days with a completed workout or any food logged. */
  readonly activeDays: ReadonlySet<string>;
  /** Rest days of the active programme, 1 = Monday … 7 = Sunday. */
  readonly restWeekdays: ReadonlySet<number>;
  /** Days used by Skip today. */
  readonly skippedDays: ReadonlySet<string>;
  /** The first day to look at (the account's first day); null looks back the full window. */
  readonly firstDay: string | null;
}

export interface Streak {
  /** Counted days in the run that is still going. */
  readonly current: number;
  /** The longest run in the window (at least `current`). */
  readonly best: number;
  /** Whether today already counts. */
  readonly todayCounted: boolean;
}

/** 1 = Monday … 7 = Sunday for a yyyy-mm-dd date. */
export function isoWeekday(date: string): number {
  const [y, m, d] = date.split('-').map(Number) as [number, number, number];
  const day = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return day === 0 ? 7 : day;
}

export function streak(input: StreakInput): Streak {
  const windowStart = addDays(input.today, -STREAK_LOOKBACK_DAYS);
  const start = input.firstDay !== null && input.firstDay > windowStart ? input.firstDay : windowStart;
  const excused = (d: string): boolean => input.restWeekdays.has(isoWeekday(d)) || input.skippedDays.has(d);
  let run = 0;
  let best = 0;
  for (let d = start; d <= input.today; d = addDays(d, 1)) {
    if (input.activeDays.has(d)) {
      run += 1;
      best = Math.max(best, run);
    } else if (d !== input.today && !excused(d)) {
      run = 0;
    }
  }
  return { current: run, best, todayCounted: input.activeDays.has(input.today) };
}

export interface WeekGoal {
  /** Workouts completed this ISO week (Monday to Sunday). */
  readonly done: number;
  /** Training days the programme plans per week. */
  readonly planned: number;
}

/**
 * The goal ring: workouts done this week against the programme's training
 * days. Null without a programme (nothing planned), and then the ring hides.
 */
export function weekGoal(today: string, completedOn: readonly string[], plannedPerWeek: number): WeekGoal | null {
  if (plannedPerWeek <= 0) return null;
  const week = isoWeekKey(today);
  return { done: completedOn.filter((d) => isoWeekKey(d) === week).length, planned: plannedPerWeek };
}
