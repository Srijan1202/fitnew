/**
 * Food logging's domain (Phase 8): portions, the snapshot a log keeps, the
 * day's totals and what remains against the target. Pure and deterministic;
 * the API calls it, nothing else computes these numbers.
 *
 * A log item is a SNAPSHOT: the food's nutrition row, scaled to the portion
 * and rounded, copied at log time. History never re-reads the food table, so
 * correcting a food later cannot change what a past day says was eaten.
 *
 * Every total is a range (a day with one estimate in it is an estimate).
 * Unknown fibre is never 0: a day reports the fibre it knows plus how many
 * items did not say.
 */

import type { MacroRange } from '../mess/types.js';
import { isExactNutrition, roundFoodNutrition, scaleFoodNutrition, type FoodNutritionRange } from './food.js';

// ------------------------------------------------------------ vocabulary --

/** The mess vocabulary (`mess/types.ts` MealSlot), so Phase 9 logs share it. */
export const MEAL_SLOTS = ['breakfast', 'lunch', 'snacks', 'dinner'] as const;
export type MealSlot = (typeof MEAL_SLOTS)[number];

/** How a log was made. Phase 9 added `mess`; Phase 14 an AI draft, confirmed. */
export const ENTRY_METHODS = ['search', 'quick-add', 'saved-meal', 'mess'] as const;
export type EntryMethod = (typeof ENTRY_METHODS)[number];

/** Owner J19: a portion is 0.1–20 servings in 0.01 steps, or up to 5000 g. */
export const SERVINGS_MIN = 0.1;
export const SERVINGS_MAX = 20;
export const GRAMS_MAX = 5000;

/** Owner J4: today and up to 30 days back; never a future day. */
export const LOG_DAYS_BACK = 30;

/**
 * Local breakfast / lunch / snacks / dinner by the hour, for the default slot
 * only — the user can always pick another.
 */
export function defaultMealSlot(hourOfDay: number): MealSlot {
  if (hourOfDay < 11) return 'breakfast';
  if (hourOfDay < 16) return 'lunch';
  if (hourOfDay < 19) return 'snacks';
  return 'dinner';
}

// --------------------------------------------------------------- portions --

/** The nutrition row a portion is measured against. */
export interface PortionRow {
  readonly basis: 'per_100g' | 'per_serving';
  /** Grams in one serving of this row; `null` when the serving has no known weight. */
  readonly servingGrams: number | null;
}

export type PortionInput = { readonly servings: number } | { readonly grams: number };

export interface Portion {
  /** Multiplier on the row. Exact (grams ÷ serving grams when entered in grams). */
  readonly servings: number;
  /** The portion's weight when it is known; `null` for a serving without grams. */
  readonly grams: number | null;
}

export type PortionResult = { readonly ok: true; readonly portion: Portion } | { readonly ok: false; readonly problem: string };

function gramsPerServing(row: PortionRow): number | null {
  return row.basis === 'per_100g' ? 100 : row.servingGrams;
}

/** Hundredths, tolerant of binary-float noise (1.15 × 100 = 114.999…). */
function isHundredths(v: number): boolean {
  return Math.abs(v * 100 - Math.round(v * 100)) < 1e-6;
}

const round = (v: number, decimals: number): number => {
  const f = 10 ** decimals;
  return Math.round(v * f) / f + 0;
};

/**
 * A portion as servings of the row, or as grams where the row has a weight.
 * Servings are bounded (0.1–20, hundredths); grams are bounded (≤ 5000) and
 * converted exactly — a per-100 g row takes grams ÷ 100, a weighed serving
 * grams ÷ its weight. A serving with no weight cannot take grams.
 */
export function resolvePortion(row: PortionRow, input: PortionInput): PortionResult {
  const per = gramsPerServing(row);
  if ('servings' in input) {
    const s = input.servings;
    if (!Number.isFinite(s) || s < SERVINGS_MIN - 1e-9 || s > SERVINGS_MAX + 1e-9) {
      return { ok: false, problem: `servings must be between ${SERVINGS_MIN} and ${SERVINGS_MAX}` };
    }
    if (!isHundredths(s)) return { ok: false, problem: 'servings are in steps of 0.01' };
    const servings = round(s, 2);
    return { ok: true, portion: { servings, grams: per === null ? null : round(servings * per, 1) } };
  }
  const g = input.grams;
  if (!Number.isFinite(g) || g <= 0 || g > GRAMS_MAX) return { ok: false, problem: `grams must be more than 0 and at most ${GRAMS_MAX}` };
  if (per === null || per <= 0) return { ok: false, problem: 'this serving has no weight; enter servings instead' };
  return { ok: true, portion: { servings: g / per, grams: round(g, 1) } };
}

// --------------------------------------------------------------- snapshot --

/**
 * What a log item keeps: the row scaled by the portion, rounded to stored
 * precision. An exact row (a USDA record, a label) stays exact — rounded to
 * nearest; an estimate rounds outward so a range is never narrowed (J20).
 */
export function snapshotNutrition(row: FoodNutritionRange, servings: number): FoodNutritionRange {
  return roundFoodNutrition(scaleFoodNutrition(row, servings), isExactNutrition(row) ? 'nearest' : 'outward');
}

// ----------------------------------------------------------------- rollup --

export interface DayTotals {
  readonly macros: MacroRange;
  /** Fibre summed over the items that report it. */
  readonly fibreKnown: { readonly low: number; readonly high: number };
  /** Items whose fibre is unknown — their fibre is not in `fibreKnown`, and is not 0. */
  readonly fibreUnknownItems: number;
  readonly itemCount: number;
}

export const EMPTY_DAY: DayTotals = {
  macros: { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0, carbLow: 0, carbHigh: 0, fatLow: 0, fatHigh: 0 },
  fibreKnown: { low: 0, high: 0 },
  fibreUnknownItems: 0,
  itemCount: 0,
};

/**
 * The day's totals from its (already rounded) item snapshots: lows summed,
 * highs summed. Sums are re-rounded to stored precision only to absorb
 * float noise — the inputs are already at that precision.
 */
export function rollupDay(items: readonly FoodNutritionRange[]): DayTotals {
  let t = EMPTY_DAY;
  for (const item of items) t = addToDay(t, item);
  return t;
}

export function addToDay(day: DayTotals, item: FoodNutritionRange): DayTotals {
  return adjustDay(day, item, 1);
}

export function removeFromDay(day: DayTotals, item: FoodNutritionRange): DayTotals {
  return adjustDay(day, item, -1);
}

function adjustDay(day: DayTotals, item: FoodNutritionRange, sign: 1 | -1): DayTotals {
  const d = day.macros;
  const m = item.macros;
  const kcal = (a: number, b: number): number => round(a + sign * b, 0);
  const g = (a: number, b: number): number => round(a + sign * b, 1);
  return {
    macros: {
      kcalLow: kcal(d.kcalLow, m.kcalLow), kcalHigh: kcal(d.kcalHigh, m.kcalHigh),
      proteinLow: g(d.proteinLow, m.proteinLow), proteinHigh: g(d.proteinHigh, m.proteinHigh),
      carbLow: g(d.carbLow, m.carbLow), carbHigh: g(d.carbHigh, m.carbHigh),
      fatLow: g(d.fatLow, m.fatLow), fatHigh: g(d.fatHigh, m.fatHigh),
    },
    fibreKnown:
      item.fibre === null
        ? day.fibreKnown
        : { low: g(day.fibreKnown.low, item.fibre.low), high: g(day.fibreKnown.high, item.fibre.high) },
    fibreUnknownItems: day.fibreUnknownItems + (item.fibre === null ? sign : 0),
    itemCount: day.itemCount + sign,
  };
}

// -------------------------------------------------------------- remaining --

/**
 * `under` — the target is not reached even at the high end of what was eaten;
 * `over` — it is exceeded even at the low end; `around` — the target lies
 * inside the range eaten, so whether it was passed is not known.
 */
export type RemainingState = 'under' | 'around' | 'over';

export interface RemainingRange {
  readonly target: number;
  /** target − consumed high. Negative means over. */
  readonly low: number;
  /** target − consumed low. Negative means over. */
  readonly high: number;
  readonly state: RemainingState;
}

export interface DayRemaining {
  readonly kcal: RemainingRange;
  readonly protein: RemainingRange;
  readonly carb: RemainingRange;
  readonly fat: RemainingRange;
}

export interface MacroTargetsLike {
  readonly kcal: number;
  readonly proteinG: number;
  readonly carbG: number;
  readonly fatG: number;
}

function remainingOf(target: number, consumedLow: number, consumedHigh: number, decimals: number): RemainingRange {
  const low = round(target - consumedHigh, decimals);
  const high = round(target - consumedLow, decimals);
  return { target, low, high, state: low >= 0 ? 'under' : high < 0 ? 'over' : 'around' };
}

/**
 * What is left against the target, as a range. Never clamped at zero: going
 * over is shown as over, not as "0 left".
 */
export function remainingForDay(day: DayTotals, targets: MacroTargetsLike): DayRemaining {
  const m = day.macros;
  return {
    kcal: remainingOf(targets.kcal, m.kcalLow, m.kcalHigh, 0),
    protein: remainingOf(targets.proteinG, m.proteinLow, m.proteinHigh, 1),
    carb: remainingOf(targets.carbG, m.carbLow, m.carbHigh, 1),
    fat: remainingOf(targets.fatG, m.fatLow, m.fatHigh, 1),
  };
}

// ------------------------------------------------------------------ dates --

/** yyyy-mm-dd of `instant` in `timeZone` (IANA). The day a log belongs to. */
export function localDateOf(instant: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(instant);
  const get = (type: string): string => parts.find((p) => p.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

/** Calendar arithmetic on yyyy-mm-dd, independent of any zone. */
export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split('-').map(Number) as [number, number, number];
  const t = new Date(Date.UTC(y, m - 1, d + days));
  return t.toISOString().slice(0, 10);
}

export type LogDateCheck = { readonly ok: true } | { readonly ok: false; readonly problem: 'future' | 'too-old' };

/** Owner J4: a log may land on today or up to 30 days back, never ahead. */
export function checkLogDate(localDate: string, today: string): LogDateCheck {
  if (localDate > today) return { ok: false, problem: 'future' };
  if (localDate < addDays(today, -LOG_DAYS_BACK)) return { ok: false, problem: 'too-old' };
  return { ok: true };
}
