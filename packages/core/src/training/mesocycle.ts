/**
 * `programs.mesocycle_week` (Phase 5, owner decision 8.2): the week advances
 * on the first completed session of a new ISO week and is capped at 8.
 *
 * Stateless and rebuildable: the week is the number of distinct ISO weeks
 * (in the user's calendar, so callers pass LOCAL dates) in which a session
 * of this programme was completed, at least 1, at most 8. Phase 6's deload
 * resets the count by passing only the dates since the reset.
 */

export const MESOCYCLE_WEEK_CAP = 8;

/** ISO-8601 week key, e.g. "2026-W39", for a local calendar date "yyyy-mm-dd". */
export function isoWeekKey(localDate: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(localDate);
  if (m === null) throw new RangeError(`expected yyyy-mm-dd, got "${localDate}"`);
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  // ISO weeks start on Monday and week 1 contains the year's first Thursday.
  const day = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const isoYear = d.getUTCFullYear();
  const jan1 = Date.UTC(isoYear, 0, 1);
  const week = Math.ceil(((d.getTime() - jan1) / 86_400_000 + 1) / 7);
  return `${isoYear}-W${String(week).padStart(2, '0')}`;
}

/**
 * The mesocycle week for a programme given the LOCAL dates of its
 * completed sessions (order irrelevant, duplicates fine).
 */
export function mesocycleWeekFrom(completedLocalDates: readonly string[]): number {
  const weeks = new Set(completedLocalDates.map(isoWeekKey));
  return Math.max(1, Math.min(MESOCYCLE_WEEK_CAP, weeks.size));
}

/** True when completing on `localDate` would move the programme to a later week. */
export function advancesWeek(completedLocalDates: readonly string[], localDate: string): boolean {
  return mesocycleWeekFrom([...completedLocalDates, localDate]) > mesocycleWeekFrom(completedLocalDates);
}
