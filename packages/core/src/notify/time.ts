/**
 * Phase 15 — local clock arithmetic for notifications (ADR-021). Times of
 * day are minutes after local midnight in the user's IANA zone; an instant
 * is built back from a local date and minute, honouring the zone's offset
 * on that day (DST-safe, though India has none).
 */

/** Minutes after local midnight (0–1439) of `instant` in `timeZone`. */
export function minuteOfDay(instant: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-GB', { timeZone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(instant);
  const get = (t: string): number => Number(parts.find((p) => p.type === t)?.value ?? '0');
  return (get('hour') % 24) * 60 + get('minute');
}

/** The zone's offset from UTC at `instant`, in minutes (IST → 330). */
function offsetMinutes(instant: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(instant);
  const get = (t: string): number => Number(parts.find((p) => p.type === t)?.value ?? '0');
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'));
  return Math.round((asUtc - Math.floor(instant.getTime() / 60_000) * 60_000) / 60_000);
}

/** The instant of `minute` after midnight on `localDate` (yyyy-mm-dd) in `timeZone`. */
export function instantAt(localDate: string, minute: number, timeZone: string): Date {
  const [y, m, d] = localDate.split('-').map(Number) as [number, number, number];
  const wall = Date.UTC(y, m - 1, d, Math.floor(minute / 60), minute % 60);
  let t = wall - offsetMinutes(new Date(wall), timeZone) * 60_000;
  // Once more at the guessed instant, in case the offset changes that day.
  t = wall - offsetMinutes(new Date(t), timeZone) * 60_000;
  return new Date(t);
}

/** "HH:MM" → minutes; null when malformed. */
export function parseClock(hhmm: string): number | null {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(hhmm);
  return m === null ? null : Number(m[1]) * 60 + Number(m[2]);
}

/** Minutes → "HH:MM". */
export function formatClock(minute: number): string {
  const v = ((Math.round(minute) % 1440) + 1440) % 1440;
  return `${String(Math.floor(v / 60)).padStart(2, '0')}:${String(v % 60).padStart(2, '0')}`;
}

/** A local day starts at 04:00 for habits: a 01:00 snack belongs to the evening before. */
const DAY_PIVOT = 240;

/**
 * The usual time of a habit: the median of its local times (with the day
 * pivoted at 04:00, so late-night times sort after the evening), rounded
 * to 5 minutes. Null below `minSamples` — a habit needs a few repeats.
 */
export function usualMinute(samples: readonly number[], minSamples = 3): number | null {
  if (samples.length < minSamples) return null;
  const shifted = samples.map((s) => (s - DAY_PIVOT + 1440) % 1440).sort((a, b) => a - b);
  const mid = shifted.length / 2;
  const median = shifted.length % 2 === 1 ? shifted[Math.floor(mid)]! : (shifted[mid - 1]! + shifted[mid]!) / 2;
  return (Math.round((median + DAY_PIVOT) / 5) * 5) % 1440;
}

/** Whole days from `from` to `to` (yyyy-mm-dd). */
export function daysBetween(from: string, to: string): number {
  const at = (s: string): number => {
    const [y, m, d] = s.split('-').map(Number) as [number, number, number];
    return Date.UTC(y, m - 1, d);
  };
  return Math.round((at(to) - at(from)) / 86_400_000);
}

/** ISO day of week (Mon 1 … Sun 7) of a yyyy-mm-dd. */
export function isoWeekday(localDate: string): number {
  const [y, m, d] = localDate.split('-').map(Number) as [number, number, number];
  const w = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return w === 0 ? 7 : w;
}

/** Inside a quiet window that may wrap midnight (22:30 → 07:30). */
export function inWindow(minute: number, start: number, end: number): boolean {
  return start <= end ? minute >= start && minute < end : minute >= start || minute < end;
}
