/**
 * Progress (Phase 12, MASTER-SPEC §17, §13.2; ADR-018). Pure and
 * deterministic: everything here is computed on read from source rows and
 * never stored (§9.4). It reuses the existing engines — the EWMA trend and
 * its reliability gate (`nutrition/trend.ts`), Epley (`training/progression.ts`)
 * and ISO weeks (`training/mesocycle.ts`) — and adds only the window maths.
 *
 * Anti-obsession rules (§17) are data rules here too: there is no
 * day-over-day figure; every change is over a window of at least 7 days.
 */
import { addDays } from '../nutrition/log.js';
import { computeTrend, summariseTrend, type TrendPoint, type WeightEntry } from '../nutrition/trend.js';
import { isoWeekKey } from '../training/mesocycle.js';
import { estimate1RM } from '../training/progression.js';

/** The summary windows (owner D8). */
export const PROGRESS_WINDOWS = ['30d', '90d'] as const;
export type ProgressWindow = (typeof PROGRESS_WINDOWS)[number];
export const WINDOW_DAYS: Readonly<Record<ProgressWindow, number>> = { '30d': 30, '90d': 90 };

/** §17 rule 2: a change is reported only over at least this many days. */
export const MIN_CHANGE_DAYS = 7;

/** Owner D6: calories are "on target" when the day's range overlaps target ± 10 %. */
export const CALORIE_TOLERANCE = 0.1;

/** The first local date of a window ending (inclusive) on `today`. */
export function windowStart(today: string, window: ProgressWindow): string {
  return addDays(today, -(WINDOW_DAYS[window] - 1));
}

/** Whole days from `a` to `b` (yyyy-mm-dd). */
export function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
}

const round1 = (v: number): number => Math.round(v * 10) / 10;
const pct = (n: number, of: number): number | null => (of === 0 ? null : Math.round((n / of) * 100));

/* ------------------------------------------------------------ weight -- */

export interface WeightProgress {
  /** Raw readings and the trend at each, inside the window, oldest first. */
  readonly points: readonly TrendPoint[];
  readonly currentTrendKg: number | null;
  /** kg/week from the trend; null before the 10-day reliability gate (§13.2). */
  readonly weeklyChangeKg: number | null;
  readonly daysOfData: number;
  readonly isReliable: boolean;
  /**
   * The trend's change across the window's readings (last − first), only
   * when they are at least 7 days apart; otherwise null (§17 rule 2).
   */
  readonly windowChangeKg: number | null;
  /** The span that change covers, in days; null with it. */
  readonly windowChangeDays: number | null;
}

/**
 * The trend is smoothed over the WHOLE history up to `today` (so a window
 * does not restart the EWMA), then cut to the window. Readings after
 * `today` are ignored.
 */
export function weightProgress(entries: readonly WeightEntry[], today: string, window: ProgressWindow): WeightProgress {
  const upToToday = entries.filter((e) => e.date <= today);
  const all = computeTrend(upToToday);
  const summary = summariseTrend(upToToday);
  const from = windowStart(today, window);
  const points = all.filter((p) => p.date >= from);
  const first = points[0];
  const last = points[points.length - 1];
  let windowChangeKg: number | null = null;
  let windowChangeDays: number | null = null;
  if (first !== undefined && last !== undefined) {
    const span = daysBetween(first.date, last.date);
    if (span >= MIN_CHANGE_DAYS) {
      windowChangeKg = Number((last.trendKg - first.trendKg).toFixed(2));
      windowChangeDays = span;
    }
  }
  return {
    points,
    currentTrendKg: summary.currentTrendKg,
    weeklyChangeKg: summary.weeklyChangeKg,
    daysOfData: summary.daysOfData,
    isReliable: summary.isReliable,
    windowChangeKg,
    windowChangeDays,
  };
}

/* ------------------------------------------------------ measurements -- */

export const MEASUREMENT_SITES = ['waist', 'chest', 'arm', 'thigh', 'hip'] as const;
export type MeasurementSite = (typeof MEASUREMENT_SITES)[number];

export interface MeasurementReading {
  readonly date: string;
  readonly site: MeasurementSite;
  readonly valueCm: number;
}

export interface SiteProgress {
  readonly site: MeasurementSite;
  readonly latest: { readonly date: string; readonly valueCm: number };
  /** latest − the earliest reading in the window, only when ≥ 7 days apart. */
  readonly changeCm: number | null;
  readonly changeDays: number | null;
}

/** The latest reading per site (any time up to `today`) and its change over the window. */
export function measurementProgress(
  readings: readonly MeasurementReading[],
  today: string,
  window: ProgressWindow,
): SiteProgress[] {
  const from = windowStart(today, window);
  const out: SiteProgress[] = [];
  for (const site of MEASUREMENT_SITES) {
    const mine = readings.filter((r) => r.site === site && r.date <= today).sort((a, b) => a.date.localeCompare(b.date));
    const latest = mine[mine.length - 1];
    if (latest === undefined) continue;
    const earliest = mine.find((r) => r.date >= from);
    let changeCm: number | null = null;
    let changeDays: number | null = null;
    if (earliest !== undefined && earliest !== latest) {
      const span = daysBetween(earliest.date, latest.date);
      if (span >= MIN_CHANGE_DAYS) {
        changeCm = round1(latest.valueCm - earliest.valueCm);
        changeDays = span;
      }
    }
    out.push({ site, latest: { date: latest.date, valueCm: latest.valueCm }, changeCm, changeDays });
  }
  return out;
}

/* --------------------------------------------------------- adherence -- */

export interface NutritionDayRange {
  readonly date: string;
  /** Items logged that day; a day with none is not a logged day. */
  readonly itemCount: number;
  readonly kcalLow: number;
  readonly kcalHigh: number;
  readonly proteinHigh: number;
}

export interface TargetRow {
  /** The first local date the row applies to. */
  readonly effectiveFrom: string;
  readonly kcal: number;
  readonly proteinG: number;
}

export interface AdherenceCount {
  readonly met: number;
  /** Logged days with a target in effect. */
  readonly of: number;
  /** Rounded %; null when `of` is 0. */
  readonly percent: number | null;
}

export interface Adherence {
  /** Owner D6: met when the day's protein HIGH end reaches the target. */
  readonly protein: AdherenceCount;
  /** Owner D6: on target when the day's kcal range overlaps target ± 10 %. */
  readonly calories: AdherenceCount;
  /** Days in the window with at least one log. */
  readonly loggedDays: number;
  /** Logged days with no target in effect yet (not counted either way). */
  readonly daysWithoutTarget: number;
}

/** The target row in effect on `date`: the latest with `effectiveFrom ≤ date`. */
export function targetOn(rows: readonly TargetRow[], date: string): TargetRow | null {
  let best: TargetRow | null = null;
  for (const r of rows) {
    if (r.effectiveFrom <= date && (best === null || r.effectiveFrom >= best.effectiveFrom)) best = r;
  }
  return best;
}

/**
 * Owner D6. Only days with at least one log count — an unlogged day is
 * unknown, never a miss (no streaks, no shaming). Each day is judged
 * against the target in effect that day, so a target change mid-window is
 * handled day by day. Ranges are compared as approved (owner D6): protein
 * is met when the day's HIGH end reaches the target; calories are on target
 * when the day's low–high range overlaps the target ± 10 %.
 */
export function adherence(
  days: readonly NutritionDayRange[],
  targets: readonly TargetRow[],
  today: string,
  window: ProgressWindow,
): Adherence {
  const from = windowStart(today, window);
  let loggedDays = 0;
  let without = 0;
  let proteinMet = 0;
  let caloriesOn = 0;
  let judged = 0;
  for (const d of days) {
    if (d.date < from || d.date > today || d.itemCount <= 0) continue;
    loggedDays += 1;
    const t = targetOn(targets, d.date);
    if (t === null) {
      without += 1;
      continue;
    }
    judged += 1;
    if (d.proteinHigh >= t.proteinG) proteinMet += 1;
    const lo = t.kcal * (1 - CALORIE_TOLERANCE);
    const hi = t.kcal * (1 + CALORIE_TOLERANCE);
    if (d.kcalHigh >= lo && d.kcalLow <= hi) caloriesOn += 1;
  }
  return {
    protein: { met: proteinMet, of: judged, percent: pct(proteinMet, judged) },
    calories: { met: caloriesOn, of: judged, percent: pct(caloriesOn, judged) },
    loggedDays,
    daysWithoutTarget: without,
  };
}

/* ------------------------------------------------------- consistency -- */

export interface WeekConsistency {
  readonly isoWeek: string;
  readonly completed: number;
  /** Planned programme training days of this week that fall inside the window up to today. */
  readonly planned: number;
}

export interface Consistency {
  readonly weeks: readonly WeekConsistency[];
  readonly completed: number;
  /** Null when there is no programme to plan from. */
  readonly planned: number | null;
  readonly percent: number | null;
}

/** ISO day of week, 1 = Monday. */
function isoDow(date: string): number {
  const d = new Date(`${date}T00:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
}

/**
 * Owner D7: completed sessions per ISO week against the programme's planned
 * training days, over the window, in the user's zone (the caller passes
 * local dates). A partial week at either end of the window plans only the
 * programme days that fall inside it (up to today), so the first and the
 * current week are never counted against days that have not happened or
 * lie outside the window. No streaks.
 *
 * `plannedDays`: ISO weekdays (1–7) of the programme's non-rest days; null
 * when the user has no programme.
 */
export function consistency(
  completedOn: readonly string[],
  plannedDays: readonly number[] | null,
  today: string,
  window: ProgressWindow,
): Consistency {
  const from = windowStart(today, window);
  const byWeek = new Map<string, WeekConsistency>();
  const planned = plannedDays === null ? null : new Set(plannedDays);
  for (let d = from; d <= today; d = addDays(d, 1)) {
    const key = isoWeekKey(d);
    const w = byWeek.get(key) ?? { isoWeek: key, completed: 0, planned: 0 };
    byWeek.set(key, { ...w, planned: w.planned + (planned?.has(isoDow(d)) === true ? 1 : 0) });
  }
  for (const date of completedOn) {
    if (date < from || date > today) continue;
    const key = isoWeekKey(date);
    const w = byWeek.get(key);
    if (w !== undefined) byWeek.set(key, { ...w, completed: w.completed + 1 });
  }
  const weeks = [...byWeek.values()];
  const completed = weeks.reduce((n, w) => n + w.completed, 0);
  const plannedTotal = planned === null ? null : weeks.reduce((n, w) => n + w.planned, 0);
  return {
    weeks,
    completed,
    planned: plannedTotal,
    // Not capped: more sessions than planned reads as over 100 % (owner D7's ratio as is).
    percent: plannedTotal === null ? null : pct(completed, plannedTotal),
  };
}

/* ----------------------------------------------------- strength / PR -- */

export interface WorkingSet {
  readonly exerciseId: string;
  readonly exerciseName: string;
  readonly date: string;
  readonly weightKg: number;
  readonly reps: number;
}

export interface BestLift {
  readonly exerciseId: string;
  readonly exerciseName: string;
  /** Epley (display only, never a prescription). */
  readonly estimated1RmKg: number;
  readonly weightKg: number;
  readonly reps: number;
  readonly date: string;
}

/**
 * The best estimated 1RM per lift across the given working sets (the
 * caller passes the window's completed working sets). Ties keep the
 * earliest set; lifts are ordered by name.
 */
export function bestLifts(sets: readonly WorkingSet[]): BestLift[] {
  const best = new Map<string, BestLift>();
  const ordered = [...sets].sort((a, b) => a.date.localeCompare(b.date));
  for (const s of ordered) {
    if (s.weightKg <= 0 || s.reps < 1) continue;
    const e = estimate1RM(s.weightKg, s.reps);
    const cur = best.get(s.exerciseId);
    if (cur === undefined || e > cur.estimated1RmKg) {
      best.set(s.exerciseId, { exerciseId: s.exerciseId, exerciseName: s.exerciseName, estimated1RmKg: e, weightKg: s.weightKg, reps: s.reps, date: s.date });
    }
  }
  return [...best.values()].sort((a, b) => a.exerciseName.localeCompare(b.exerciseName) || a.exerciseId.localeCompare(b.exerciseId));
}
