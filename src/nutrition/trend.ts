/**
 * Weight trend smoothing and adaptive expenditure.
 *
 * Daily scale weight is dominated by water, glycogen and gut content. Reacting
 * to it is the single most common way fitness apps make users miserable and
 * make bad calorie decisions. Everything user-facing reads `trendKg`, never
 * `rawKg`.
 *
 * Method: exponentially weighted moving average, alpha 0.1 (~19-day half-life),
 * the same family of smoothing used by trend-weight tools.
 */

export interface WeightEntry {
  readonly date: string; // ISO yyyy-mm-dd
  readonly kg: number;
}

export interface TrendPoint {
  readonly date: string;
  readonly rawKg: number;
  readonly trendKg: number;
}

export const DEFAULT_ALPHA = 0.1;

/**
 * Seeds the trend with the first observation, then smooths forward.
 * Input need not be sorted.
 */
export function computeTrend(entries: readonly WeightEntry[], alpha = DEFAULT_ALPHA): TrendPoint[] {
  const sorted = [...entries].sort((a, b) => a.date.localeCompare(b.date));
  const points: TrendPoint[] = [];
  let trend: number | null = null;

  for (const entry of sorted) {
    trend = trend === null ? entry.kg : trend + alpha * (entry.kg - trend);
    points.push({ date: entry.date, rawKg: entry.kg, trendKg: Number(trend.toFixed(3)) });
  }
  return points;
}

export interface TrendSummary {
  readonly currentTrendKg: number | null;
  /** Positive = gaining. kg per week, from the trend line, not raw endpoints. */
  readonly weeklyChangeKg: number | null;
  readonly daysOfData: number;
  /** False until we have enough data to say anything responsible. */
  readonly isReliable: boolean;
}

const MIN_DAYS_FOR_TREND = 10;

export function summariseTrend(entries: readonly WeightEntry[], alpha = DEFAULT_ALPHA): TrendSummary {
  const points = computeTrend(entries, alpha);
  const last = points[points.length - 1];
  if (last === undefined) {
    return { currentTrendKg: null, weeklyChangeKg: null, daysOfData: 0, isReliable: false };
  }

  const firstDate = points[0]?.date;
  const daysOfData =
    firstDate === undefined
      ? 0
      : Math.round(
          (Date.parse(`${last.date}T00:00:00Z`) - Date.parse(`${firstDate}T00:00:00Z`)) / 86_400_000,
        ) + 1;

  if (daysOfData < MIN_DAYS_FOR_TREND) {
    return {
      currentTrendKg: last.trendKg,
      weeklyChangeKg: null,
      daysOfData,
      isReliable: false,
    };
  }

  // Compare the trend now against the trend ~14 days ago, then normalise weekly.
  const targetDate = new Date(Date.parse(`${last.date}T00:00:00Z`) - 14 * 86_400_000)
    .toISOString()
    .slice(0, 10);
  let reference = points[0];
  for (const point of points) {
    if (point.date <= targetDate) reference = point;
  }
  if (reference === undefined) {
    return { currentTrendKg: last.trendKg, weeklyChangeKg: null, daysOfData, isReliable: false };
  }

  const spanDays = Math.max(
    1,
    Math.round(
      (Date.parse(`${last.date}T00:00:00Z`) - Date.parse(`${reference.date}T00:00:00Z`)) / 86_400_000,
    ),
  );
  const weeklyChangeKg = ((last.trendKg - reference.trendKg) / spanDays) * 7;

  return {
    currentTrendKg: last.trendKg,
    weeklyChangeKg: Number(weeklyChangeKg.toFixed(3)),
    daysOfData,
    isReliable: true,
  };
}

/**
 * Adaptive expenditure from observed intake and observed trend change.
 *
 * Energy balance: TDEE ≈ mean intake − (tissue energy change / days).
 * 7700 kcal per kg is the conventional mixed-tissue figure.
 *
 * Returns null when the data can't support an estimate — an honest null beats a
 * confident wrong number that then moves someone's calorie target.
 */
export interface AdaptiveTdeeInput {
  readonly entries: readonly WeightEntry[];
  /** Daily calorie intake logs, aligned by date. */
  readonly intake: readonly { readonly date: string; readonly kcal: number }[];
  readonly minDays?: number;
}

const KCAL_PER_KG = 7700;

export function estimateAdaptiveTdee(input: AdaptiveTdeeInput): number | null {
  const minDays = input.minDays ?? 14;
  const summary = summariseTrend(input.entries);
  if (!summary.isReliable || summary.weeklyChangeKg === null) return null;

  const sortedIntake = [...input.intake].sort((a, b) => a.date.localeCompare(b.date));
  const window = sortedIntake.slice(-minDays);
  if (window.length < minDays) return null;

  const meanIntake = window.reduce((sum, d) => sum + d.kcal, 0) / window.length;
  const dailyTissueKcal = (summary.weeklyChangeKg / 7) * KCAL_PER_KG;
  const tdee = meanIntake - dailyTissueKcal;

  // Guard against absurd outputs from sparse or noisy logs.
  if (!Number.isFinite(tdee) || tdee < 1000 || tdee > 6000) return null;
  return Math.round(tdee);
}

/**
 * Decides whether the calorie target should move, and by how much.
 * Deliberately conservative: adjusts at most once per week, in small steps.
 */
export interface CalorieAdjustment {
  readonly shouldAdjust: boolean;
  readonly deltaKcal: number;
  readonly reason: string;
}

export function recommendCalorieAdjustment(params: {
  readonly goal: 'muscle-gain' | 'fat-loss' | 'strength' | 'general';
  readonly weeklyChangeKg: number | null;
  readonly daysSinceLastAdjustment: number;
  readonly bodyweightKg: number;
}): CalorieAdjustment {
  const { goal, weeklyChangeKg, daysSinceLastAdjustment, bodyweightKg } = params;

  if (weeklyChangeKg === null) {
    return { shouldAdjust: false, deltaKcal: 0, reason: 'Not enough weight data yet to judge a trend.' };
  }
  if (daysSinceLastAdjustment < 7) {
    return { shouldAdjust: false, deltaKcal: 0, reason: 'Targets were adjusted less than a week ago.' };
  }

  // Target rates as a fraction of bodyweight per week.
  const targetRate =
    goal === 'muscle-gain' ? bodyweightKg * 0.0035
    : goal === 'fat-loss' ? -bodyweightKg * 0.007
    : 0;

  const tolerance = Math.max(0.1, Math.abs(targetRate) * 0.5);
  const error = weeklyChangeKg - targetRate;

  if (Math.abs(error) <= tolerance) {
    return { shouldAdjust: false, deltaKcal: 0, reason: 'Your trend is tracking where it should be.' };
  }

  // Step size capped at 150 kcal so no single adjustment is disruptive.
  const rawDelta = -(error / 7) * KCAL_PER_KG;
  const deltaKcal = Math.round(Math.max(-150, Math.min(150, rawDelta)) / 10) * 10;
  if (deltaKcal === 0) {
    return { shouldAdjust: false, deltaKcal: 0, reason: 'Your trend is close enough to target.' };
  }

  const direction = deltaKcal > 0 ? 'up' : 'down';
  return {
    shouldAdjust: true,
    deltaKcal,
    reason:
      goal === 'fat-loss' && deltaKcal < 0
        ? `Trend weight is falling slower than target, so calories move ${direction} by ${Math.abs(deltaKcal)}.`
        : `Trend weight is off target, so calories move ${direction} by ${Math.abs(deltaKcal)}.`,
  };
}
