/**
 * Phase 14 — choosing a FITOS portion for a food the model read from a
 * meal description (ADR-020 D6). The model supplies only words and a
 * quantity; this deterministic rule picks one of the food's own rows and a
 * number of servings, so every number in the draft comes from the food
 * database (§19.1: the model never sets nutrition for a known food).
 */
import { SERVINGS_MAX, SERVINGS_MIN } from '../nutrition/log.js';

export interface DraftRow {
  readonly basis: 'per_100g' | 'per_serving';
  readonly servingLabel: string;
  readonly servingGrams: number | null;
}

export interface PortionAsked {
  readonly quantity: number;
  readonly unit: string;
  /** The model's guess at the portion's weight, when it gave one. */
  readonly grams: number | null;
}

export interface ChosenPortion {
  /** Index into the food's rows. */
  readonly row: number;
  /** Servings of that row, hundredths, within 0.1–20. */
  readonly servings: number;
  /** True when the unit or weight said exactly which row and how much. */
  readonly exact: boolean;
}

const SYNONYMS: Readonly<Record<string, string>> = {
  g: 'g', gm: 'g', gms: 'g', gram: 'g', grams: 'g', gr: 'g',
  ml: 'ml', millilitre: 'ml', milliliter: 'ml', millilitres: 'ml', milliliters: 'ml',
  pieces: 'piece', pc: 'piece', pcs: 'piece', nos: 'piece', no: 'piece',
  katoris: 'katori', bowls: 'bowl', cups: 'cup', glasses: 'glass', plates: 'plate', slices: 'slice',
  servings: 'serving', tablespoon: 'tbsp', tablespoons: 'tbsp', teaspoon: 'tsp', teaspoons: 'tsp',
};

/** "Katoris" → "katori", "grams" → "g". */
export function normaliseUnit(unit: string): string {
  const u = unit.trim().toLowerCase();
  return SYNONYMS[u] ?? u;
}

const round2 = (v: number): number => Math.round(v * 100) / 100;
const clampServings = (v: number): number => Math.min(SERVINGS_MAX, Math.max(SERVINGS_MIN, round2(v)));

function gramsPer(row: DraftRow): number | null {
  return row.basis === 'per_100g' ? 100 : row.servingGrams;
}

/** Words that measure an amount; any other noun in a label counts the food itself ("2 eggs", "1 samosa"). */
const MEASURES = new Set([
  'g', 'ml', 'katori', 'bowl', 'cup', 'glass', 'plate', 'tbsp', 'tsp', 'serving', 'scoop', 'ladle', 'packet', 'pack', 'bottle', 'can',
]);

/** "2 eggs" and "1 samosa" count the food; "1 katori" and "100 g" measure it. */
function isCountLabel(label: string): boolean {
  const m = /^\s*\d+(?:\.\d+)?\s*([a-z]+)/.exec(label.toLowerCase());
  return m !== null && !MEASURES.has(normaliseUnit(m[1]!).replace(/s$/, ''));
}

/** "2 pieces (80 g)" → 2; "1 katori" → 1; no leading number → 1. */
function labelCount(label: string): number {
  const m = /^\s*(\d+(?:\.\d+)?)/.exec(label);
  const n = m === null ? 1 : Number(m[1]);
  return n > 0 ? n : 1;
}

/**
 * The row and servings for what was asked:
 *   1. grams or ml → the weighed row (per 100 g first), by weight;
 *   2. a unit the food has a serving for ("katori", "piece", "glass") → that serving;
 *   2b. a count ("2 pieces") and a serving that counts the food ("2 eggs") → by count;
 *   3. the model's weight guess → a weighed row (not exact);
 *   4. the first serving row, quantity as servings (not exact);
 *   5. only a per-100 g row and no weight → 100 g (not exact).
 */
export function choosePortion(rows: readonly DraftRow[], asked: PortionAsked): ChosenPortion | null {
  if (rows.length === 0 || !Number.isFinite(asked.quantity) || asked.quantity <= 0) return null;
  const unit = normaliseUnit(asked.unit);
  const weighed = rows
    .map((r, i) => ({ i, per: gramsPer(r), basis: r.basis }))
    .filter((r): r is { i: number; per: number; basis: DraftRow['basis'] } => r.per !== null && r.per > 0)
    .sort((a, b) => (a.basis === b.basis ? 0 : a.basis === 'per_100g' ? -1 : 1));

  if ((unit === 'g' || unit === 'ml') && weighed.length > 0) {
    const w = weighed[0]!;
    return { row: w.i, servings: clampServings(asked.quantity / w.per), exact: true };
  }

  const wordMatch = rows.findIndex(
    (r) => r.basis === 'per_serving' && new RegExp(`\\b${unit.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}s?\\b`).test(r.servingLabel.toLowerCase()),
  );
  if (unit.length > 0 && unit !== 'g' && unit !== 'ml' && wordMatch >= 0) {
    return { row: wordMatch, servings: clampServings(asked.quantity / labelCount(rows[wordMatch]!.servingLabel)), exact: true };
  }

  if (unit === 'piece') {
    const counted = rows.findIndex((r) => r.basis === 'per_serving' && isCountLabel(r.servingLabel));
    if (counted >= 0) {
      return { row: counted, servings: clampServings(asked.quantity / labelCount(rows[counted]!.servingLabel)), exact: true };
    }
  }

  if (asked.grams !== null && Number.isFinite(asked.grams) && asked.grams > 0 && weighed.length > 0) {
    const w = weighed[0]!;
    return { row: w.i, servings: clampServings(asked.grams / w.per), exact: false };
  }

  const serving = rows.findIndex((r) => r.basis === 'per_serving');
  if (serving >= 0) return { row: serving, servings: clampServings(asked.quantity / labelCount(rows[serving]!.servingLabel)), exact: false };

  return { row: 0, servings: 1, exact: false };
}
