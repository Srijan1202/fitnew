/**
 * Beta 3.2 (owner 2026-10-23, ADR-031): the user's own calorie and protein
 * targets. The user sets calories and protein; fat and carbs follow the same
 * §13.1 split FITOS uses (`adjustTargets`: the fat floor of max(0.8 g/kg,
 * 22 % of kcal), carbs take the rest), fibre at 14 g per 1000 kcal.
 *
 * Hard limits are refused (the caller answers 422); values far from FITOS's
 * suggestion are allowed with a plain warning. Nothing here stores or
 * decides anything else.
 */
import { adjustTargets, type MacroTargets } from './targets.js';

export const CUSTOM_TARGET_LIMITS = {
  kcalMin: 1200,
  kcalMax: 6000,
  proteinMinG: 30,
  proteinMaxG: 400,
  proteinMinPerKg: 0.6,
  proteinMaxPerKg: 3.3,
  /** Warn beyond this share away from FITOS's calories. */
  kcalWarnShare: 0.25,
  /** Warn outside this protein band (g per kg). */
  proteinWarnLowPerKg: 1.2,
  proteinWarnHighPerKg: 2.2,
} as const;

export interface CustomTargetInput {
  readonly kcal: number;
  readonly proteinG: number;
  /** The weight the split and the per-kg limits use (the latest weight). */
  readonly weightKg: number;
  /** FITOS's own suggestion, for the warnings. */
  readonly suggestion: Pick<MacroTargets, 'kcal' | 'proteinG'>;
}

export type CustomTargetResult =
  | {
      readonly ok: true;
      readonly targets: Pick<MacroTargets, 'kcal' | 'proteinG' | 'fatG' | 'carbG' | 'fiberG'>;
      readonly warnings: readonly string[];
    }
  | { readonly ok: false; readonly field: 'kcal' | 'proteinG'; readonly problem: string };

/** The protein range in grams for this weight: the per-kg limits inside the absolute ones. */
export function proteinRangeG(weightKg: number): { readonly min: number; readonly max: number } {
  const L = CUSTOM_TARGET_LIMITS;
  return {
    min: Math.max(L.proteinMinG, Math.ceil(weightKg * L.proteinMinPerKg)),
    max: Math.min(L.proteinMaxG, Math.floor(weightKg * L.proteinMaxPerKg)),
  };
}

export function customTargets(input: CustomTargetInput): CustomTargetResult {
  const L = CUSTOM_TARGET_LIMITS;
  const { kcal, proteinG, weightKg, suggestion } = input;

  if (!Number.isInteger(kcal) || kcal < L.kcalMin || kcal > L.kcalMax) {
    return { ok: false, field: 'kcal', problem: `Calories must be a whole number from ${L.kcalMin} to ${L.kcalMax}.` };
  }
  const range = proteinRangeG(weightKg);
  if (!Number.isInteger(proteinG) || proteinG < range.min || proteinG > range.max) {
    return {
      ok: false,
      field: 'proteinG',
      problem: `Protein must be a whole number from ${range.min} to ${range.max} g at your weight (${L.proteinMinPerKg}–${L.proteinMaxPerKg} g per kg).`,
    };
  }
  const split = adjustTargets({ proteinG }, kcal, weightKg);
  // Protein and the fat floor must fit inside the calories (carbs never below 0).
  if (proteinG * 4 + split.fatG * 9 > kcal) {
    const needed = proteinG * 4 + split.fatG * 9;
    return {
      ok: false,
      field: 'kcal',
      problem: `${proteinG} g protein and the minimum fat need ${needed} kcal: raise the calories or lower the protein.`,
    };
  }

  const warnings: string[] = [];
  const share = (kcal - suggestion.kcal) / suggestion.kcal;
  if (Math.abs(share) > L.kcalWarnShare) {
    const pct = Math.round(Math.abs(share) * 100);
    warnings.push(`${pct} % ${share < 0 ? 'below' : 'above'} FITOS's suggestion of ${suggestion.kcal} kcal.`);
  }
  const perKg = proteinG / weightKg;
  if (perKg < L.proteinWarnLowPerKg) {
    warnings.push(`${perKg.toFixed(1)} g protein per kg is below the ${L.proteinWarnLowPerKg}–${L.proteinWarnHighPerKg} g that supports training.`);
  } else if (perKg > L.proteinWarnHighPerKg) {
    warnings.push(`${perKg.toFixed(1)} g protein per kg is above the ${L.proteinWarnLowPerKg}–${L.proteinWarnHighPerKg} g that most people need.`);
  }
  return { ok: true, targets: split, warnings };
}
