/**
 * Beta 6.0 (F7, ADR-059): the day's water target, from body weight.
 *
 * 35 ml for each kg, rounded to the nearest glass (250 ml), and kept between
 * 1.5 L and 4 L, so a very light or very heavy reading never asks for too
 * little or too much. Without a weight it is 2.5 L. A guide, not a rule:
 * heat, sweat and the food eaten all change what a body needs.
 */
export const WATER_ML_PER_KG = 35;
export const WATER_GLASS_ML = 250;
export const WATER_MIN_TARGET_ML = 1500;
export const WATER_MAX_TARGET_ML = 4000;
export const WATER_DEFAULT_TARGET_ML = 2500;

export function waterTargetMl(weightKg: number | null): number {
  if (weightKg === null || !Number.isFinite(weightKg) || weightKg <= 0) return WATER_DEFAULT_TARGET_ML;
  const glasses = Math.round((weightKg * WATER_ML_PER_KG) / WATER_GLASS_ML);
  return Math.min(WATER_MAX_TARGET_ML, Math.max(WATER_MIN_TARGET_ML, glasses * WATER_GLASS_ML));
}
