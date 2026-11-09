/**
 * Beta 6.1: the monthly report (premium), a calendar month on two or three
 * pages of PDF made on the phone. The weekly report's rules hold: data
 * FITOS already has, plain sentences, no shaming, and an unlogged day is
 * unknown, never a miss (Phase 12, owner D6).
 */
import type { TrendPoint } from '../nutrition/trend.js';
import { CALORIE_TOLERANCE, targetOn, type NutritionDayRange, type TargetRow } from './summary.js';
import { isoWeekKey } from '../training/mesocycle.js';
import { STEADY_KG } from './weekly.js';

/** The month's muscles listed by hard sets. */
export const MONTHLY_TOP_MUSCLES = 5;

export interface MonthlyReportInput {
  /** yyyy-mm. */
  readonly month: string;
  /** The month's first and last local dates. */
  readonly from: string;
  readonly to: string;
  readonly today: string;
  readonly sessionsCompleted: number;
  /** Sessions the programme plans per week; null without a programme. */
  readonly sessionsPlannedPerWeek: number | null;
  /** Hard sets and tonnage per muscle over the month's ISO weeks (a week is the month's when its Thursday is). */
  readonly muscles: readonly { readonly muscle: string; readonly hardSets: number; readonly tonnageKg: number }[];
  readonly prs: readonly { readonly exerciseName: string }[];
  readonly runs: readonly { readonly distanceM: number }[];
  readonly days: readonly NutritionDayRange[];
  readonly targets: readonly TargetRow[];
  readonly water: readonly { readonly date: string; readonly ml: number }[];
  /** The day target from the latest weigh-in (beta 6.0). */
  readonly waterTargetMl: number;
  readonly checkIns: readonly { readonly date: string; readonly sleepHours: number | null }[];
  /** The whole trend, oldest first. */
  readonly trend: readonly TrendPoint[];
}

export interface MonthlyReport {
  readonly month: string;
  readonly from: string;
  readonly to: string;
  /** False while the month is still running. */
  readonly complete: boolean;
  readonly training: {
    readonly completed: number;
    /** Planned for the days of the month so far (all of it once complete); null without a programme. */
    readonly planned: number | null;
    readonly percent: number | null;
    readonly hardSets: number;
    readonly tonnageKg: number;
    readonly topMuscles: readonly { readonly muscle: string; readonly hardSets: number }[];
  };
  readonly prs: { readonly count: number; readonly lifts: readonly string[] };
  readonly running: { readonly runs: number; readonly km: number };
  readonly nutrition: {
    readonly loggedDays: number;
    readonly judgedDays: number;
    readonly proteinMet: number;
    readonly caloriesOn: number;
    /** The middle of each logged day's range, averaged; null with none. */
    readonly averageKcal: number | null;
  };
  readonly water: { readonly loggedDays: number; readonly daysAtTarget: number; readonly targetMl: number };
  readonly recovery: { readonly checkIns: number; readonly averageSleepHours: number | null };
  readonly weight: { readonly startKg: number; readonly endKg: number; readonly changeKg: number } | null;
  readonly highlights: readonly string[];
}

const round1 = (x: number): number => Math.round(x * 10) / 10;
const plural = (n: number, word: string): string => `${n} ${word}${n === 1 ? '' : 's'}`;

/** Days from `a` to `b` inclusive. */
const spanDays = (a: string, b: string): number => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000) + 1;

export function monthlyReport(input: MonthlyReportInput): MonthlyReport {
  const inMonth = (d: string): boolean => d >= input.from && d <= input.to;
  const complete = input.today > input.to;
  const lastDay = complete ? input.to : input.today;

  // Training: planned for the days so far.
  const perWeek = input.sessionsPlannedPerWeek;
  const planned = perWeek === null ? null : Math.round((perWeek * spanDays(input.from, lastDay)) / 7);
  const percent = planned !== null && planned > 0 ? Math.round((Math.min(input.sessionsCompleted, planned) / planned) * 100) : null;
  const hardSets = round1(input.muscles.reduce((a, m) => a + m.hardSets, 0));
  const tonnageKg = Math.round(input.muscles.reduce((a, m) => a + m.tonnageKg, 0));
  const topMuscles = input.muscles
    .filter((m) => m.hardSets > 0)
    .sort((a, b) => b.hardSets - a.hardSets || a.muscle.localeCompare(b.muscle))
    .slice(0, MONTHLY_TOP_MUSCLES)
    .map((m) => ({ muscle: m.muscle, hardSets: round1(m.hardSets) }));
  const lifts = [...new Set(input.prs.map((p) => p.exerciseName))];
  const km = round1(input.runs.reduce((a, r) => a + r.distanceM, 0) / 1000);

  // Nutrition.
  let loggedDays = 0;
  let judgedDays = 0;
  let proteinMet = 0;
  let caloriesOn = 0;
  let kcalSum = 0;
  for (const d of input.days) {
    if (!inMonth(d.date) || d.itemCount <= 0) continue;
    loggedDays += 1;
    kcalSum += (d.kcalLow + d.kcalHigh) / 2;
    const t = targetOn(input.targets, d.date);
    if (t === null) continue;
    judgedDays += 1;
    if (d.proteinHigh >= t.proteinG) proteinMet += 1;
    if (d.kcalHigh >= t.kcal * (1 - CALORIE_TOLERANCE) && d.kcalLow <= t.kcal * (1 + CALORIE_TOLERANCE)) caloriesOn += 1;
  }
  const averageKcal = loggedDays === 0 ? null : Math.round(kcalSum / loggedDays);

  // Water and check-ins.
  const water = input.water.filter((w) => inMonth(w.date) && w.ml > 0);
  const daysAtTarget = water.filter((w) => w.ml >= input.waterTargetMl).length;
  const checkIns = input.checkIns.filter((c) => inMonth(c.date));
  const slept = checkIns.map((c) => c.sleepHours).filter((h): h is number => h !== null);
  const averageSleepHours = slept.length === 0 ? null : round1(slept.reduce((a, h) => a + h, 0) / slept.length);

  // Weight: the trend across the month's readings.
  const points = input.trend.filter((p) => inMonth(p.date));
  const weight =
    points.length >= 2
      ? { startKg: round1(points[0]!.trendKg), endKg: round1(points.at(-1)!.trendKg), changeKg: round1(points.at(-1)!.trendKg - points[0]!.trendKg) }
      : null;

  // The sentences.
  const highlights: string[] = [];
  if (input.sessionsCompleted === 0) highlights.push('No sessions logged this month.');
  else if (planned !== null && planned > 0) highlights.push(`${input.sessionsCompleted} of ${planned} planned sessions.`);
  else highlights.push(`${plural(input.sessionsCompleted, 'session')}.`);
  if (topMuscles.length > 0) highlights.push(`Most work: ${topMuscles.slice(0, 3).map((m) => m.muscle).join(', ')}.`);
  if (lifts.length > 0) highlights.push(`${plural(input.prs.length, 'personal record')}, on ${plural(lifts.length, 'lift')}.`);
  if (input.runs.length > 0) highlights.push(`${plural(input.runs.length, 'run')}, ${km.toFixed(1)} km.`);
  if (loggedDays === 0) highlights.push('No food logged this month.');
  else if (judgedDays > 0) highlights.push(`Protein target reached on ${proteinMet} of ${plural(judgedDays, 'logged day')}.`);
  if (water.length > 0) highlights.push(`Water target reached on ${daysAtTarget} of ${plural(water.length, 'day')} with water logged.`);
  if (weight !== null) {
    if (Math.abs(weight.changeKg) < STEADY_KG) highlights.push('Trend weight steady.');
    else highlights.push(`Trend weight ${weight.changeKg < 0 ? 'down' : 'up'} ${Math.abs(weight.changeKg).toFixed(1)} kg.`);
  }

  return {
    month: input.month,
    from: input.from,
    to: input.to,
    complete,
    training: { completed: input.sessionsCompleted, planned, percent, hardSets, tonnageKg, topMuscles },
    prs: { count: input.prs.length, lifts },
    running: { runs: input.runs.length, km },
    nutrition: { loggedDays, judgedDays, proteinMet, caloriesOn, averageKcal },
    water: { loggedDays: water.length, daysAtTarget, targetMl: input.waterTargetMl },
    recovery: { checkIns: checkIns.length, averageSleepHours },
    weight,
    highlights,
  };
}

/** The month's dates and the ISO weeks it owns (a week is the month's when its Thursday is in it). */
export function monthSpan(month: string): { from: string; to: string; isoWeeks: string[] } {
  const [y, m] = month.split('-').map(Number) as [number, number];
  const from = `${month}-01`;
  const to = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
  const isoWeeks: string[] = [];
  for (let t = Date.UTC(y, m - 1, 1); t <= Date.UTC(y, m, 0); t += 86_400_000) {
    const d = new Date(t);
    if (d.getUTCDay() === 4) isoWeeks.push(isoWeekKey(d.toISOString().slice(0, 10)));
  }
  return { from, to, isoWeeks };
}
