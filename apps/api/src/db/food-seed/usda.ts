/**
 * Reading USDA FoodData Central JSON downloads (Foundation Foods, SR Legacy)
 * for the food seed builder. Only the builder uses this — the raw files are
 * never committed (Phase 7, N5); CI verifies the derived seed instead.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { USDA_DATASETS, type Per100g, type UsdaDatasetKey } from './format.js';

interface RawNutrient {
  readonly amount?: number;
  readonly nutrient?: { readonly number?: string; readonly unitName?: string };
}
interface RawPortion {
  readonly amount?: number;
  readonly gramWeight?: number;
  readonly modifier?: string;
  readonly portionDescription?: string;
  readonly sequenceNumber?: number;
  readonly id?: number;
  readonly measureUnit?: { readonly name?: string };
}
interface RawFood {
  readonly fdcId: number;
  readonly description: string;
  readonly foodNutrients?: readonly RawNutrient[];
  readonly foodPortions?: readonly RawPortion[];
}

export interface UsdaPortion {
  readonly label: string;
  readonly grams: number;
}

export interface UsdaRecord {
  readonly fdcId: number;
  readonly dataset: UsdaDatasetKey;
  readonly description: string;
  /** Exactly as USDA reports it, per 100 g (not rounded). `null` → not reported. */
  readonly per100g: {
    readonly kcal: number | null;
    readonly protein: number | null;
    readonly carb: number | null;
    readonly fat: number | null;
    readonly fibre: number | null;
  };
  readonly energyNutrient: '208' | '958' | '957' | null;
  readonly portions: readonly UsdaPortion[];
}

/**
 * Energy: nutrient 208 (Energy, kcal) when present; Foundation Foods often
 * publish only the Atwater values, so 958 (specific factors), then 957
 * (general factors). Fat: 204 (total lipid), else 298 (total fat, NLEA).
 * Carbohydrate: 205 (by difference). Fibre: 291 (total dietary).
 */
function nutrientAmounts(food: RawFood): UsdaRecord['per100g'] & { energyNutrient: UsdaRecord['energyNutrient'] } {
  const byNumber = new Map<string, number>();
  for (const n of food.foodNutrients ?? []) {
    const num = n.nutrient?.number;
    if (num === undefined || n.amount === undefined) continue;
    if ((num === '208' || num === '957' || num === '958') && n.nutrient?.unitName !== 'kcal') continue;
    byNumber.set(num, n.amount);
  }
  const energyNutrient = (['208', '958', '957'] as const).find((k) => byNumber.has(k)) ?? null;
  return {
    kcal: energyNutrient === null ? null : (byNumber.get(energyNutrient) as number),
    protein: byNumber.get('203') ?? null,
    carb: byNumber.get('205') ?? null,
    fat: byNumber.get('204') ?? byNumber.get('298') ?? null,
    fibre: byNumber.get('291') ?? null,
    energyNutrient,
  };
}

function formatAmount(amount: number): string {
  return Number.isInteger(amount) ? String(amount) : String(Number(amount.toFixed(3)));
}

/**
 * USDA household portions, in USDA's own order (sequence number, then id):
 * SR Legacy spells the measure in `modifier` ("1 cup, chopped"), Foundation
 * in the measure unit plus modifier. FDA reference amounts (RACC), unnamed
 * measures, labels over 60 characters and portions over 1 kg ("1 waxgourd",
 * 5.7 kg — not a serving) are skipped; at most two are kept.
 */
function portionsOf(food: RawFood): UsdaPortion[] {
  const sorted = [...(food.foodPortions ?? [])].sort(
    (a, b) => (a.sequenceNumber ?? 0) - (b.sequenceNumber ?? 0) || (a.id ?? 0) - (b.id ?? 0),
  );
  const out: UsdaPortion[] = [];
  const seen = new Set<string>();
  for (const p of sorted) {
    if (!(typeof p.gramWeight === 'number' && p.gramWeight > 0 && p.gramWeight <= 1000)) continue;
    const unit = p.measureUnit?.name ?? '';
    if (unit === 'RACC') continue;
    const modifier = (p.modifier ?? p.portionDescription ?? '').trim();
    const amount = formatAmount(p.amount ?? 1);
    let label: string;
    if (unit === '' || unit === 'undetermined') {
      if (modifier === '') continue;
      label = `${amount} ${modifier}`;
    } else {
      label = modifier === '' ? `${amount} ${unit}` : `${amount} ${unit}, ${modifier}`;
    }
    label = label.replace(/\s+/g, ' ').trim();
    if (label.length > 60 || seen.has(label)) continue;
    seen.add(label);
    out.push({ label, grams: p.gramWeight });
    if (out.length === 2) break;
  }
  return out;
}

/** Load both permitted datasets from `dir` (the unzipped downloads). */
export function loadUsda(dir: string): Map<string, UsdaRecord> {
  const records = new Map<string, UsdaRecord>();
  for (const key of Object.keys(USDA_DATASETS) as UsdaDatasetKey[]) {
    const meta = USDA_DATASETS[key];
    const parsed = JSON.parse(readFileSync(join(dir, meta.json), 'utf8')) as Record<string, (RawFood | null)[]>;
    const foods = parsed[meta.rootKey];
    if (!Array.isArray(foods)) throw new Error(`${meta.json}: no ${meta.rootKey} array`);
    for (const food of foods) {
      if (food === null) continue;
      const { energyNutrient, ...per100g } = nutrientAmounts(food);
      records.set(usdaKey(key, food.fdcId), {
        fdcId: food.fdcId,
        dataset: key,
        description: food.description,
        per100g,
        energyNutrient,
        portions: portionsOf(food),
      });
    }
  }
  return records;
}

export function usdaKey(dataset: UsdaDatasetKey, fdcId: number): string {
  return `${dataset}:${fdcId}`;
}

/**
 * The values a food may be seeded from, or why not: every core value must be
 * reported and none may be negative (a by-difference carbohydrate can come out
 * below zero — such a record is not used rather than altered).
 */
export function usableValues(record: UsdaRecord): { ok: true; values: Per100g } | { ok: false; reason: string } {
  const { kcal, protein, carb, fat, fibre } = record.per100g;
  const missing = (
    [
      ['energy', kcal],
      ['protein', protein],
      ['carbohydrate', carb],
      ['fat', fat],
    ] as const
  )
    .filter(([, v]) => v === null)
    .map(([k]) => k);
  if (missing.length > 0) return { ok: false, reason: `not reported: ${missing.join(', ')}` };
  const values = { kcal: kcal as number, protein: protein as number, carb: carb as number, fat: fat as number, fibre };
  const negative = Object.entries(values).filter(([, v]) => v !== null && v < 0);
  if (negative.length > 0) return { ok: false, reason: `negative value: ${negative.map(([k]) => k).join(', ')}` };
  return { ok: true, values };
}
