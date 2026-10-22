/**
 * The weekly progress report (Phase 19, ADR-027: premium). One ISO week, from
 * data FITOS already holds: sessions done against the plan, hard sets per
 * muscle against the §12.3 landmarks, personal records, protein and calorie
 * days, and the trend weight. Plain sentences, no streaks and no shaming: an
 * unlogged day is unknown, never a miss (Phase 12, owner D6).
 */
import type { TrendPoint } from '../nutrition/trend.js';
import { CALORIE_TOLERANCE, targetOn, type NutritionDayRange, type TargetRow } from './summary.js';

/** The volume module's landmark statuses (contracts LANDMARK_STATUSES). */
export type LandmarkStatus = 'none' | 'below-mv' | 'below-mev' | 'mev-to-mav' | 'above-mav' | 'at-mrv';

export interface WeeklyReportInput {
  readonly isoWeek: string;
  /** Monday and Sunday of the week, local dates. */
  readonly from: string;
  readonly to: string;
  readonly today: string;
  readonly sessionsCompleted: number;
  /** Sessions the programme plans per week; null without a programme. */
  readonly sessionsPlanned: number | null;
  /** The week's hard sets per muscle the programme trains (`owned`). */
  readonly volume: readonly { readonly muscle: string; readonly hardSets: number; readonly status: LandmarkStatus }[];
  readonly prs: readonly { readonly exerciseName: string }[];
  readonly days: readonly NutritionDayRange[];
  readonly targets: readonly TargetRow[];
  /** The whole trend, oldest first (it is smoothed over all history). */
  readonly trend: readonly TrendPoint[];
}

export interface WeeklyReport {
  readonly isoWeek: string;
  readonly from: string;
  readonly to: string;
  /** False while the week is still running (today ≤ Sunday). */
  readonly complete: boolean;
  readonly training: { readonly completed: number; readonly planned: number | null; readonly percent: number | null };
  readonly volume: {
    readonly totalHardSets: number;
    readonly productive: readonly string[];
    readonly below: readonly string[];
    readonly above: readonly string[];
  };
  readonly prs: { readonly count: number; readonly lifts: readonly string[] };
  readonly nutrition: { readonly loggedDays: number; readonly judgedDays: number; readonly proteinMet: number; readonly caloriesOn: number };
  /** Trend weight at the first and last reading of the week; null with fewer than two. */
  readonly weight: { readonly startKg: number; readonly endKg: number; readonly changeKg: number } | null;
  readonly highlights: readonly string[];
}

/** A change smaller than this is "steady" (the trend's own noise). */
export const STEADY_KG = 0.1;

const round1 = (x: number): number => Math.round(x * 10) / 10;

const list = (xs: readonly string[]): string => (xs.length <= 2 ? xs.join(' and ') : `${xs.slice(0, -1).join(', ')} and ${xs.at(-1)!}`);

const cap = (s: string): string => s.charAt(0).toUpperCase() + s.slice(1);

export function weeklyReport(input: WeeklyReportInput): WeeklyReport {
  // Training.
  const planned = input.sessionsPlanned;
  const percent = planned !== null && planned > 0 ? Math.round((Math.min(input.sessionsCompleted, planned) / planned) * 100) : null;

  // Volume: only what the programme trains, by band.
  const trained = input.volume.filter((v) => v.status !== 'none');
  const productive = trained.filter((v) => v.status === 'mev-to-mav').map((v) => v.muscle);
  const below = trained.filter((v) => v.status === 'below-mv' || v.status === 'below-mev').map((v) => v.muscle);
  const above = trained.filter((v) => v.status === 'above-mav' || v.status === 'at-mrv').map((v) => v.muscle);
  const totalHardSets = round1(input.volume.reduce((a, v) => a + v.hardSets, 0));

  // Personal records: the lifts, once each, in the order they came.
  const lifts = [...new Set(input.prs.map((p) => p.exerciseName))];

  // Nutrition: logged days in the week, each against the target in effect.
  let loggedDays = 0;
  let judgedDays = 0;
  let proteinMet = 0;
  let caloriesOn = 0;
  for (const d of input.days) {
    if (d.date < input.from || d.date > input.to || d.itemCount <= 0) continue;
    loggedDays += 1;
    const t = targetOn(input.targets, d.date);
    if (t === null) continue;
    judgedDays += 1;
    if (d.proteinHigh >= t.proteinG) proteinMet += 1;
    if (d.kcalHigh >= t.kcal * (1 - CALORIE_TOLERANCE) && d.kcalLow <= t.kcal * (1 + CALORIE_TOLERANCE)) caloriesOn += 1;
  }

  // Weight: the trend across the week's readings.
  const inWeek = input.trend.filter((p) => p.date >= input.from && p.date <= input.to);
  const weight =
    inWeek.length >= 2
      ? { startKg: round1(inWeek[0]!.trendKg), endKg: round1(inWeek.at(-1)!.trendKg), changeKg: round1(inWeek.at(-1)!.trendKg - inWeek[0]!.trendKg) }
      : null;

  // The sentences.
  const highlights: string[] = [];
  if (input.sessionsCompleted === 0) highlights.push('No sessions logged this week.');
  else if (planned !== null && planned > 0) highlights.push(`${input.sessionsCompleted} of ${planned} planned sessions.`);
  else highlights.push(`${input.sessionsCompleted} session${input.sessionsCompleted === 1 ? '' : 's'}.`);
  if (productive.length > 0) highlights.push(`${cap(list(productive))} in the productive range (MEV to MAV).`);
  if (below.length > 0) highlights.push(`Below MEV: ${list(below)}.`);
  if (above.length > 0) highlights.push(`Above MAV: ${list(above)}. Watch recovery.`);
  if (lifts.length > 0) highlights.push(`${input.prs.length} personal record${input.prs.length === 1 ? '' : 's'}: ${list(lifts)}.`);
  if (loggedDays === 0) highlights.push('No food logged this week.');
  else if (judgedDays > 0) highlights.push(`Protein target reached on ${proteinMet} of ${judgedDays} logged day${judgedDays === 1 ? '' : 's'}.`);
  if (weight !== null) {
    if (Math.abs(weight.changeKg) < STEADY_KG) highlights.push('Trend weight steady.');
    else highlights.push(`Trend weight ${weight.changeKg < 0 ? 'down' : 'up'} ${Math.abs(weight.changeKg).toFixed(1)} kg.`);
  }

  return {
    isoWeek: input.isoWeek,
    from: input.from,
    to: input.to,
    complete: input.today > input.to,
    training: { completed: input.sessionsCompleted, planned, percent },
    volume: { totalHardSets, productive, below, above },
    prs: { count: input.prs.length, lifts },
    nutrition: { loggedDays, judgedDays, proteinMet, caloriesOn },
    weight,
    highlights,
  };
}
