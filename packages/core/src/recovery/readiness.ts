/**
 * Readiness (MASTER-SPEC §18; Phase 13, ADR-019). Deterministic, 0–100,
 * computed on read from the user's own records and never stored:
 *
 *   readiness = 100
 *             − sleepDebtPenalty       (max 25; vs 7.5 h, the last 7 days)
 *             − sorenessPenalty        (max 20)
 *             − energyPenalty          (max 20)
 *             − performanceDropPenalty (max 25; RIR drift + rep decline)
 *             − adherenceGapPenalty    (max 10)
 *
 * Only available inputs count (§31): readiness exists for a day with a
 * check-in, and a component without its input adds no penalty and says so.
 * Sleep quality and stress are logged but have no term in the formula.
 *
 * Readiness is advice. Nothing here — or anywhere downstream — changes the
 * plan on its own (§18 `DECISION`): the bands only choose what to suggest.
 */
import { addDays } from '../nutrition/log.js';
import { adherence, type NutritionDayRange, type TargetRow } from '../progress/summary.js';
import { meanRir, workingReps, workingWeight, type SessionLog } from '../training/progression.js';

/** §18: the nightly sleep baseline. */
export const SLEEP_BASELINE_HOURS = 7.5;
/** §18: sleep debt is judged over the last seven local days (the day included). */
export const SLEEP_WINDOW_DAYS = 7;
/** Performance is judged on lifts trained in the seven local days up to the day. */
export const PERFORMANCE_WINDOW_DAYS = 7;
/** Nutrition adherence is judged over the seven local days before the day. */
export const ADHERENCE_WINDOW_DAYS = 7;

/** §18's caps. Beta 4.1 (ADR-039, owner): running load, the sixth. */
export const PENALTY_MAX = {
  sleep: 25,
  soreness: 20,
  energy: 20,
  performance: 25,
  adherence: 10,
  running: 10,
} as const;
export type ReadinessComponentKey = keyof typeof PENALTY_MAX;
export const READINESS_COMPONENTS = ['sleep', 'soreness', 'energy', 'performance', 'adherence', 'running'] as const satisfies readonly ReadinessComponentKey[];

/**
 * Beta 4.1 (ADR-039): running load is effort-weighted minutes, compared the
 * standard way — the last 7 days (acute) against the average week of the
 * last 28 (chronic). No penalty up to a ratio of 1.3; it rises evenly to its
 * cap at 1.8. Judged only with at least 3 runs in the 28 days.
 */
export const RUNNING_LOAD = { acuteDays: 7, chronicDays: 28, minRuns: 3, from: 1.3, to: 1.8 } as const;

/** §18's bands: ≥ 75 no change; 55–74 advisory; 35–54 fewer accessory sets; < 35 rest. */
export const READINESS_BANDS = ['ready', 'advisory', 'reduce', 'rest'] as const;
export type ReadinessBand = (typeof READINESS_BANDS)[number];
export const BAND_FLOOR = { ready: 75, advisory: 55, reduce: 35 } as const;

/** §18: readiness under 35 for this many days running escalates to a deload check. */
export const LOW_READINESS_ESCALATION_DAYS = 3;
/** How far back a low-readiness run is counted. */
export const LOW_READINESS_RUN_MAX = 7;

/** One day's check-in (the §18 card). Every value is optional. */
export interface RecoveryCheckIn {
  /** yyyy-mm-dd, the user's local date. */
  readonly date: string;
  readonly sleepHours: number | null;
  /** 1 poor – 5 great. Logged, not scored. */
  readonly sleepQuality: number | null;
  /** 1 none – 5 very sore. */
  readonly soreness: number | null;
  /** 1 drained – 5 great. */
  readonly energy: number | null;
  /** 1 calm – 5 very stressed. Logged, not scored. */
  readonly stress: number | null;
}

export interface ReadinessComponent {
  readonly key: ReadinessComponentKey;
  readonly penalty: number;
  readonly max: number;
  /** False when its input is missing: the penalty is then 0 and not guessed. */
  readonly available: boolean;
}

export interface Readiness {
  readonly date: string;
  readonly score: number;
  readonly band: ReadinessBand;
  readonly components: readonly ReadinessComponent[];
  /** Deterministic English for the band (§18's effect, never a diagnosis). */
  readonly advice: string;
}

export interface ReadinessInput {
  /** The local date readiness is for. */
  readonly day: string;
  /** Check-ins on any dates; only the day's and the sleep window's are read. */
  readonly checkIns: readonly RecoveryCheckIn[];
  /** Per lift, its completed sessions (oldest first, deload-week sessions already left out). */
  readonly lifts: readonly (readonly SessionLog[])[];
  /** Nutrition day ranges and the target history (Phase 12 shapes). */
  readonly nutritionDays: readonly NutritionDayRange[];
  readonly targets: readonly TargetRow[];
  /**
   * Beta 4.1: the runs of the last 28 days. Absent, readiness has the five
   * Phase 13 parts only (callers that predate running).
   */
  readonly runs?: readonly RunLoad[];
}

/** One run, as running load reads it. */
export interface RunLoad {
  /** The user's local date of the run. */
  readonly date: string;
  readonly minutes: number;
  /** 1–10 as the runner felt it; null counts as 5 (moderate). */
  readonly effort: number | null;
}

const clamp = (v: number, lo: number, hi: number): number => Math.min(hi, Math.max(lo, v));
/** Integer penalties; the tiny epsilon keeps 12.5 from rounding down on float noise. */
const whole = (v: number): number => Math.round(v + 1e-9);

/** 10 × the mean nightly shortfall below 7.5 h over the window's logged nights, max 25. */
export function sleepDebtPenalty(checkIns: readonly RecoveryCheckIn[], day: string): ReadinessComponent {
  const from = addDays(day, -(SLEEP_WINDOW_DAYS - 1));
  const nights = checkIns.filter((c) => c.date >= from && c.date <= day && c.sleepHours !== null);
  if (nights.length === 0) return { key: 'sleep', penalty: 0, max: PENALTY_MAX.sleep, available: false };
  const shortfall = nights.reduce((sum, c) => sum + Math.max(0, SLEEP_BASELINE_HOURS - c.sleepHours!), 0) / nights.length;
  return { key: 'sleep', penalty: clamp(whole(shortfall * 10), 0, PENALTY_MAX.sleep), max: PENALTY_MAX.sleep, available: true };
}

/** 5 per point above "none" (1–5), max 20. */
export function sorenessPenalty(soreness: number | null): ReadinessComponent {
  if (soreness === null) return { key: 'soreness', penalty: 0, max: PENALTY_MAX.soreness, available: false };
  return { key: 'soreness', penalty: clamp((soreness - 1) * 5, 0, PENALTY_MAX.soreness), max: PENALTY_MAX.soreness, available: true };
}

/** 5 per point below "great" (1–5), max 20. */
export function energyPenalty(energy: number | null): ReadinessComponent {
  if (energy === null) return { key: 'energy', penalty: 0, max: PENALTY_MAX.energy, available: false };
  return { key: 'energy', penalty: clamp((5 - energy) * 5, 0, PENALTY_MAX.energy), max: PENALTY_MAX.energy, available: true };
}

/** One lift's Phase 6 signals over its last three sessions up to the day, or null when it cannot be judged. */
export function liftSignals(sessions: readonly SessionLog[], day: string): { repDecline: boolean; rirDrift: boolean } | null {
  const upTo = [...sessions].filter((s) => s.date <= day).sort((a, b) => a.date.localeCompare(b.date)).slice(-3);
  const [beforeThat, previous, last] = upTo;
  if (beforeThat === undefined || previous === undefined || last === undefined) return null;
  if (last.date < addDays(day, -(PERFORMANCE_WINDOW_DAYS - 1))) return null;
  const load = workingWeight(last);
  // Comparable only at the same working load (the Phase 6 rule); bodyweight lifts are not judged.
  if (load === null || workingWeight(previous) !== load || workingWeight(beforeThat) !== load) return null;
  const repDecline = workingReps(last) < workingReps(previous) && workingReps(previous) <= workingReps(beforeThat);
  const lastRir = meanRir(last);
  const olderRir = meanRir(beforeThat);
  const rirDrift = lastRir !== null && olderRir !== null && lastRir < olderRir;
  return { repDecline, rirDrift };
}

/** 25 × the share of possible signals (rep decline, RIR drift) across the lifts that can be judged. */
export function performanceDropPenalty(lifts: readonly (readonly SessionLog[])[], day: string): ReadinessComponent {
  const judged = lifts.map((l) => liftSignals(l, day)).filter((s): s is NonNullable<typeof s> => s !== null);
  if (judged.length === 0) return { key: 'performance', penalty: 0, max: PENALTY_MAX.performance, available: false };
  const points = judged.reduce((n, s) => n + (s.repDecline ? 1 : 0) + (s.rirDrift ? 1 : 0), 0);
  return {
    key: 'performance',
    penalty: clamp(whole((PENALTY_MAX.performance * points) / (2 * judged.length)), 0, PENALTY_MAX.performance),
    max: PENALTY_MAX.performance,
    available: true,
  };
}

/**
 * 10 × the share of missed nutrition marks over the logged days of the seven
 * days before the day, by the Phase 12 adherence rules (reused, not copied).
 */
export function adherenceGapPenalty(
  days: readonly NutritionDayRange[],
  targets: readonly TargetRow[],
  day: string,
): ReadinessComponent {
  const from = addDays(day, -ADHERENCE_WINDOW_DAYS);
  const to = addDays(day, -1);
  // Only the window's days reach `adherence`, so its own (longer) window never widens it.
  const a = adherence(days.filter((d) => d.date >= from && d.date <= to), targets, to, '30d');
  const judged = a.protein.of;
  if (judged === 0) return { key: 'adherence', penalty: 0, max: PENALTY_MAX.adherence, available: false };
  const missed = 1 - (a.protein.met + a.calories.met) / (2 * judged);
  return { key: 'adherence', penalty: clamp(whole(PENALTY_MAX.adherence * missed), 0, PENALTY_MAX.adherence), max: PENALTY_MAX.adherence, available: true };
}

/** The acute:chronic ratio of effort-weighted running minutes, or null without a base. */
export function runningLoadRatio(runs: readonly RunLoad[], day: string): number | null {
  const chronicFrom = addDays(day, -(RUNNING_LOAD.chronicDays - 1));
  const acuteFrom = addDays(day, -(RUNNING_LOAD.acuteDays - 1));
  const inWindow = runs.filter((r) => r.date >= chronicFrom && r.date <= day);
  if (inWindow.length < RUNNING_LOAD.minRuns) return null;
  const load = (r: RunLoad) => r.minutes * ((r.effort ?? 5) / 5);
  const chronicWeekly = inWindow.reduce((n, r) => n + load(r), 0) / (RUNNING_LOAD.chronicDays / 7);
  // Three runs of some minutes always make a positive base.
  /* v8 ignore next -- @preserve: minutes are positive for any run with time */
  if (chronicWeekly <= 0) return null;
  const acute = inWindow.filter((r) => r.date >= acuteFrom).reduce((n, r) => n + load(r), 0);
  return acute / chronicWeekly;
}

/** 0 up to a ratio of 1.3, rising evenly to 10 at 1.8. */
export function runningLoadPenalty(runs: readonly RunLoad[], day: string): ReadinessComponent {
  const ratio = runningLoadRatio(runs, day);
  if (ratio === null) return { key: 'running', penalty: 0, max: PENALTY_MAX.running, available: false };
  const share = clamp((ratio - RUNNING_LOAD.from) / (RUNNING_LOAD.to - RUNNING_LOAD.from), 0, 1);
  return { key: 'running', penalty: whole(PENALTY_MAX.running * share), max: PENALTY_MAX.running, available: true };
}

/** Said after the band's advice when running load is the biggest part taken off. */
export const RUNNING_LOAD_ADVICE = 'Your running jumped this week; keep today easy.';

export function bandOf(score: number): ReadinessBand {
  if (score >= BAND_FLOOR.ready) return 'ready';
  if (score >= BAND_FLOOR.advisory) return 'advisory';
  if (score >= BAND_FLOOR.reduce) return 'reduce';
  return 'rest';
}

/** §18's effect for a band, in plain words. Advice only; never a diagnosis. */
export const BAND_ADVICE: Readonly<Record<ReadinessBand, string>> = {
  ready: 'Ready to train as planned.',
  advisory: 'A little under par. Train as planned and notice how the sets feel.',
  reduce: 'Consider one fewer set on your accessory lifts today. Your main lifts stay as planned.',
  rest: 'Consider resting today or keeping it easy. Nothing changes unless you choose to.',
};

/** Readiness for a day, or null when there is no check-in for it (nothing is guessed). */
export function readinessOn(input: ReadinessInput): Readiness | null {
  const today = input.checkIns.find((c) => c.date === input.day);
  if (today === undefined) return null;
  const components: ReadinessComponent[] = [
    sleepDebtPenalty(input.checkIns, input.day),
    sorenessPenalty(today.soreness),
    energyPenalty(today.energy),
    performanceDropPenalty(input.lifts, input.day),
    adherenceGapPenalty(input.nutritionDays, input.targets, input.day),
  ];
  if (input.runs !== undefined) components.push(runningLoadPenalty(input.runs, input.day));
  const score = clamp(100 - components.reduce((n, c) => n + c.penalty, 0), 0, 100);
  const band = bandOf(score);
  const running = components.find((c) => c.key === 'running');
  const biggest = Math.max(...components.map((c) => c.penalty));
  const advice =
    running !== undefined && running.penalty > 0 && running.penalty === biggest ? `${BAND_ADVICE[band]} ${RUNNING_LOAD_ADVICE}` : BAND_ADVICE[band];
  return { date: input.day, score, band, components, advice };
}

/**
 * How many local days running readiness has been under 35, ending today —
 * or yesterday while today has no check-in yet, so a morning without one
 * does not break the run. `scoreOn` returns null for a day without a check-in.
 */
export function lowReadinessRun(scoreOn: (date: string) => number | null, today: string): number {
  const start = scoreOn(today) === null ? addDays(today, -1) : today;
  let run = 0;
  for (let i = 0; i < LOW_READINESS_RUN_MAX; i++) {
    const s = scoreOn(addDays(start, -i));
    if (s === null || s >= BAND_FLOOR.reduce) break;
    run += 1;
  }
  return run;
}
