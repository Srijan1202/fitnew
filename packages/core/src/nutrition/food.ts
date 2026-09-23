/**
 * The food library's domain (Phase 7): sources, ranges, validation, search
 * normalisation and the deterministic composition of FITOS estimates.
 *
 * Every number is a range. A measured value (a USDA record, a packaged label)
 * is a range whose ends are equal; an estimate is a range that is honestly
 * wide. Fibre is the one value a source may simply not report: it is `null`
 * then — unknown — and is never turned into 0.
 *
 * Arithmetic on the macro ranges goes through the existing mess helpers
 * (`scaleMacros`, `addMacros`); this module only adds fibre and the rules
 * around them, so there is one nutrition arithmetic in the codebase.
 */

import { addMacros, scaleMacros } from '../mess/nutrition.js';
import type { Confidence, MacroRange, NutritionSource } from '../mess/types.js';

// ---------------------------------------------------------------- sources --

/** Where a food's numbers came from (API / database vocabulary). */
export const FOOD_SOURCES = ['estimated', 'usda', 'ifct', 'indb', 'user', 'user-corrected'] as const;
export type FoodSource = (typeof FOOD_SOURCES)[number];

export const CONFIDENCE_LEVELS = ['high', 'medium', 'low'] as const satisfies readonly Confidence[];

/**
 * The mess module's `NutritionSource` in the food vocabulary. Its types stay
 * as they are; this is the one place they are translated.
 */
export function foodSourceFromNutritionSource(source: NutritionSource): FoodSource {
  switch (source) {
    case 'estimated-table':
      return 'estimated';
    case 'ifct-mapped':
      return 'ifct';
    case 'user-corrected':
      return 'user-corrected';
  }
}

/**
 * MASTER-SPEC §13.3: user-corrected → ifct / indb → usda → estimated. A
 * user's own custom food (a label they typed) is unverified: it ranks below
 * USDA's measured data and above FITOS estimates.
 */
const SOURCE_RANK: Readonly<Record<FoodSource, number>> = {
  'user-corrected': 0,
  ifct: 1,
  indb: 1,
  usda: 2,
  user: 3,
  estimated: 4,
};

export function sourceRank(source: FoodSource): number {
  return SOURCE_RANK[source];
}

/** Negative when `a` is preferred over `b`. */
export function compareSources(a: FoodSource, b: FoodSource): number {
  return SOURCE_RANK[a] - SOURCE_RANK[b];
}

/** The most trusted item; ties keep their original order. */
export function preferredBySource<T extends { readonly source: FoodSource }>(items: readonly T[]): T | undefined {
  let best: T | undefined;
  for (const item of items) {
    if (best === undefined || compareSources(item.source, best.source) < 0) best = item;
  }
  return best;
}

// ----------------------------------------------------------------- ranges --

/** Fibre in grams as a range; `null` means the source does not report it. */
export interface FibreRange {
  readonly low: number;
  readonly high: number;
}

export interface FoodNutritionRange {
  readonly macros: MacroRange;
  readonly fibre: FibreRange | null;
}

export interface ExactValues {
  readonly kcal: number;
  readonly protein: number;
  readonly carb: number;
  readonly fat: number;
  /** `null` when not reported — never 0 by default. */
  readonly fibre: number | null;
}

/** A measured value: every range collapses to a point (`low == high`). */
export function exactFoodNutrition(v: ExactValues): FoodNutritionRange {
  return {
    macros: {
      kcalLow: v.kcal, kcalHigh: v.kcal,
      proteinLow: v.protein, proteinHigh: v.protein,
      carbLow: v.carb, carbHigh: v.carb,
      fatLow: v.fat, fatHigh: v.fat,
    },
    fibre: v.fibre === null ? null : { low: v.fibre, high: v.fibre },
  };
}

export function scaleFoodNutrition(n: FoodNutritionRange, factor: number): FoodNutritionRange {
  return {
    macros: scaleMacros(n.macros, factor),
    fibre: n.fibre === null ? null : { low: n.fibre.low * factor, high: n.fibre.high * factor },
  };
}

/** Sum of two foods. Unknown fibre in either makes the total's fibre unknown. */
export function addFoodNutrition(a: FoodNutritionRange, b: FoodNutritionRange): FoodNutritionRange {
  return {
    macros: addMacros(a.macros, b.macros),
    fibre: a.fibre === null || b.fibre === null ? null : { low: a.fibre.low + b.fibre.low, high: a.fibre.high + b.fibre.high },
  };
}

/** The low ends of `low` and the high ends of `high` — e.g. least and most oil. */
export function spanFoodNutrition(low: FoodNutritionRange, high: FoodNutritionRange): FoodNutritionRange {
  return {
    macros: {
      kcalLow: low.macros.kcalLow, kcalHigh: high.macros.kcalHigh,
      proteinLow: low.macros.proteinLow, proteinHigh: high.macros.proteinHigh,
      carbLow: low.macros.carbLow, carbHigh: high.macros.carbHigh,
      fatLow: low.macros.fatLow, fatHigh: high.macros.fatHigh,
    },
    fibre: low.fibre === null || high.fibre === null ? null : { low: low.fibre.low, high: high.fibre.high },
  };
}

/** Widen every range by `fraction` on each side: low × (1 − f), high × (1 + f). */
export function widenFoodNutrition(n: FoodNutritionRange, fraction: number): FoodNutritionRange {
  if (!(fraction >= 0 && fraction < 1)) throw new RangeError(`widening fraction must be in [0, 1): ${fraction}`);
  const lo = 1 - fraction;
  const hi = 1 + fraction;
  const m = n.macros;
  return {
    macros: {
      kcalLow: m.kcalLow * lo, kcalHigh: m.kcalHigh * hi,
      proteinLow: m.proteinLow * lo, proteinHigh: m.proteinHigh * hi,
      carbLow: m.carbLow * lo, carbHigh: m.carbHigh * hi,
      fatLow: m.fatLow * lo, fatHigh: m.fatHigh * hi,
    },
    fibre: n.fibre === null ? null : { low: n.fibre.low * lo, high: n.fibre.high * hi },
  };
}

/** Stored precision: energy in whole kcal, grams to one decimal. */
function roundTo(value: number, decimals: number, mode: 'nearest' | 'down' | 'up'): number {
  const f = 10 ** decimals;
  // The epsilon absorbs binary-float noise (0.1 + 0.2) before floor / ceil.
  const scaled = value * f;
  const r = mode === 'nearest' ? Math.round(scaled) : mode === 'down' ? Math.floor(scaled + 1e-9) : Math.ceil(scaled - 1e-9);
  return r / f + 0; // + 0 turns -0 into 0
}

/**
 * `nearest` for measured values (both ends round the same way, so an exact
 * value stays exact); `outward` for estimates (lows down, highs up — rounding
 * never narrows an honest range).
 */
export function roundFoodNutrition(n: FoodNutritionRange, mode: 'nearest' | 'outward'): FoodNutritionRange {
  const lo = mode === 'nearest' ? 'nearest' : 'down';
  const hi = mode === 'nearest' ? 'nearest' : 'up';
  const m = n.macros;
  return {
    macros: {
      kcalLow: roundTo(m.kcalLow, 0, lo), kcalHigh: roundTo(m.kcalHigh, 0, hi),
      proteinLow: roundTo(m.proteinLow, 1, lo), proteinHigh: roundTo(m.proteinHigh, 1, hi),
      carbLow: roundTo(m.carbLow, 1, lo), carbHigh: roundTo(m.carbHigh, 1, hi),
      fatLow: roundTo(m.fatLow, 1, lo), fatHigh: roundTo(m.fatHigh, 1, hi),
    },
    fibre: n.fibre === null ? null : { low: roundTo(n.fibre.low, 1, lo), high: roundTo(n.fibre.high, 1, hi) },
  };
}

/** True when every known range is a point — a measured value. */
export function isExactNutrition(n: FoodNutritionRange): boolean {
  const m = n.macros;
  return (
    m.kcalLow === m.kcalHigh && m.proteinLow === m.proteinHigh && m.carbLow === m.carbHigh && m.fatLow === m.fatHigh &&
    (n.fibre === null || n.fibre.low === n.fibre.high)
  );
}

// ------------------------------------------------------------- validation --

export interface NutritionIssue {
  readonly field: string;
  readonly problem: string;
}

type Basis = 'per_100g' | 'per_serving';

function checkPair(issues: NutritionIssue[], field: string, low: number, high: number): void {
  if (!Number.isFinite(low) || !Number.isFinite(high)) issues.push({ field, problem: 'not a number' });
  else if (low < 0 || high < 0) issues.push({ field, problem: 'negative' });
  else if (low > high) issues.push({ field, problem: 'low is greater than high' });
}

/**
 * Every pair finite, non-negative and `low <= high`; fibre either unknown or a
 * valid pair. Per 100 g, nothing can exceed 100 g of a macro, and energy is
 * bounded by pure fat (~9 kcal/g, 900 kcal).
 */
export function validateFoodNutrition(n: FoodNutritionRange, basis: Basis): NutritionIssue[] {
  const issues: NutritionIssue[] = [];
  const m = n.macros;
  checkPair(issues, 'kcal', m.kcalLow, m.kcalHigh);
  checkPair(issues, 'protein', m.proteinLow, m.proteinHigh);
  checkPair(issues, 'carb', m.carbLow, m.carbHigh);
  checkPair(issues, 'fat', m.fatLow, m.fatHigh);
  if (n.fibre !== null) checkPair(issues, 'fibre', n.fibre.low, n.fibre.high);
  if (basis === 'per_100g') {
    if (m.kcalHigh > 900) issues.push({ field: 'kcal', problem: 'more than 900 kcal per 100 g' });
    for (const [field, high] of [['protein', m.proteinHigh], ['carb', m.carbHigh], ['fat', m.fatHigh]] as const) {
      if (high > 100) issues.push({ field, problem: 'more than 100 g per 100 g' });
    }
    if (n.fibre !== null && n.fibre.high > 100) issues.push({ field: 'fibre', problem: 'more than 100 g per 100 g' });
  }
  return issues;
}

/**
 * What a source may claim. Estimates are never verified and never `high`
 * confidence; a user's custom food is never verified; only USDA's own records
 * (and, later, licensed IFCT / INDB data) may be verified.
 */
export function validateSourceClaims(source: FoodSource, isVerified: boolean, confidence: Confidence): NutritionIssue[] {
  const issues: NutritionIssue[] = [];
  if (source === 'estimated' && isVerified) issues.push({ field: 'isVerified', problem: 'an estimate cannot be verified' });
  if (source === 'estimated' && confidence === 'high') issues.push({ field: 'confidence', problem: 'an estimate cannot have high confidence' });
  if ((source === 'user' || source === 'user-corrected') && isVerified) {
    issues.push({ field: 'isVerified', problem: 'user-entered values are not verified' });
  }
  return issues;
}

// ----------------------------------------------------------------- search --

/**
 * The single normalisation for food names, aliases and queries: accents
 * removed, lower case, anything that is not a letter or digit becomes a
 * space, spaces collapsed. "Dal (Tadka)!" and "dal  tadka" are one key.
 */
export function normaliseFoodText(text: string): string {
  return text
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** Search ranks, best first (the API orders by these, then by similarity). */
export const MATCH_KINDS = ['exact', 'alias', 'prefix', 'fuzzy'] as const;
export type MatchKind = (typeof MATCH_KINDS)[number];

/** Aliases for one food: normalised, de-duplicated, never the food's own name. */
export function normaliseAliases(name: string, aliases: readonly string[]): string[] {
  const own = normaliseFoodText(name);
  const seen = new Set<string>();
  const out: string[] = [];
  for (const alias of aliases) {
    const key = normaliseFoodText(alias);
    if (key === '' || key === own || seen.has(key)) continue;
    seen.add(key);
    out.push(key);
  }
  return out.sort();
}

// ------------------------------------------------------------ composition --

/** One ingredient of a declared recipe: a USDA record and its raw grams. */
export interface RecipeIngredient {
  readonly fdcId: number;
  readonly grams: number;
}

/**
 * How a FITOS estimate for a composite dish is computed: the ingredients of
 * ONE serving, the cooking fat as a range (the dominant uncertainty), and how
 * far to widen the result for recipe-to-recipe variation.
 */
export interface CompositeRecipe {
  readonly ingredients: readonly RecipeIngredient[];
  readonly oil: { readonly fdcId: number; readonly gramsLow: number; readonly gramsHigh: number } | null;
  readonly widening: number;
}

/**
 * Deterministic: the same recipe and the same per-100 g inputs always give the
 * same range. Ingredients are summed (scaled from per-100 g), the least and
 * the most oil give the two ends, the result is widened, then rounded outward.
 * Fibre is known only if every ingredient reports it.
 */
export function composeRecipe(
  recipe: CompositeRecipe,
  per100g: (fdcId: number) => FoodNutritionRange,
): FoodNutritionRange {
  if (recipe.ingredients.length === 0) throw new RangeError('a recipe needs at least one ingredient');
  let base: FoodNutritionRange | null = null;
  for (const ing of recipe.ingredients) {
    if (!(ing.grams > 0)) throw new RangeError(`ingredient ${ing.fdcId} must weigh more than 0 g`);
    const part = scaleFoodNutrition(per100g(ing.fdcId), ing.grams / 100);
    base = base === null ? part : addFoodNutrition(base, part);
  }
  let low = base as FoodNutritionRange;
  let high = base as FoodNutritionRange;
  if (recipe.oil !== null) {
    const { fdcId, gramsLow, gramsHigh } = recipe.oil;
    if (!(gramsLow >= 0 && gramsHigh >= gramsLow)) throw new RangeError('oil grams must satisfy 0 <= low <= high');
    const oil = per100g(fdcId);
    low = addFoodNutrition(low, scaleFoodNutrition(oil, gramsLow / 100));
    high = addFoodNutrition(high, scaleFoodNutrition(oil, gramsHigh / 100));
  }
  return roundFoodNutrition(widenFoodNutrition(spanFoodNutrition(low, high), recipe.widening), 'outward');
}
