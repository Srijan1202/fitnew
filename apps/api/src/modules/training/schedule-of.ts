/**
 * Beta 6.1 (F2): a programme row's schedule for core `dayNumberOn` — the one
 * way the API turns a date into a programme day.
 */
import { dayNumberOn, type Schedule } from '@fitos/core/training/schedule';

export interface ScheduleColumns {
  readonly schedule: 'week' | 'cycle';
  readonly cycleStart: string | null;
  readonly cycleLength: number | null;
}

export function scheduleOf(p: ScheduleColumns): Schedule {
  // The database's check: a cycle always has both.
  return p.schedule === 'cycle' ? { kind: 'cycle', start: p.cycleStart!, length: p.cycleLength! } : { kind: 'week' };
}

/** The programme day number that falls on a local date. */
export const programDayOn = (p: ScheduleColumns, date: string): number => dayNumberOn(scheduleOf(p), date);
