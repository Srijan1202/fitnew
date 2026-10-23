/**
 * The bridge between stored profile data and packages/core's target engine.
 *
 * This is the ONLY place `computeTargets` is called (§7.3, §30). Everything
 * that reaches the engine is validated at the boundary; everything that comes
 * back is persisted as a new history row and returned unchanged.
 */
import { CUSTOM_TARGET_LIMITS, customTargets, proteinRangeG } from '@fitos/core/nutrition/custom-targets';
import { computeTargets, type MacroTargets, type TargetInput } from '@fitos/core/nutrition/targets';
import type { CustomTargetsResponse, NutritionTargets, TargetsView } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { NutritionTargetsRow } from '../../db/schema.js';
import type { ProfileBundle, UserRepository } from './repository.js';

/** yyyy-mm-dd for "now" in the user's zone. "Today" is never the server's (§9.1). */
export function todayIn(timeZone: string, now: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const get = (type: string): string => parts.find((p) => p.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

/** Whole years between an ISO birth date and an ISO "today". */
export function ageYears(birthDate: string, today: string): number {
  const [by, bm, bd] = birthDate.split('-').map(Number) as [number, number, number];
  const [ty, tm, td] = today.split('-').map(Number) as [number, number, number];
  let age = ty - by;
  if (tm < bm || (tm === bm && td < bd)) age -= 1;
  return age;
}

export type TargetsReason = 'onboarding' | 'goal-change' | 'profile-change' | 'weight-change' | 'reset-to-fitos';

/**
 * Assembles the engine input from what is stored. Returns null with the
 * missing field named when the profile is not yet complete enough to
 * compute — the caller decides whether that is a 409 or "not yet".
 */
export function targetInputFrom(
  bundle: ProfileBundle,
): { input: TargetInput } | { missing: string } {
  const p = bundle.profile;
  const g = bundle.goal;
  const w = bundle.latestWeight;
  if (p === null) return { missing: 'profile' };
  if (g === null) return { missing: 'goal' };
  if (w === null) return { missing: 'weight' };
  if (p.sex === null) return { missing: 'sex' };
  if (p.birthDate === null) return { missing: 'birthDate' };
  if (p.heightCm === null) return { missing: 'heightCm' };
  if (p.activityLevel === null) return { missing: 'activityLevel' };
  if (p.trainingDaysPerWeek === null) return { missing: 'trainingDaysPerWeek' };

  return {
    input: {
      sex: p.sex,
      ageYears: ageYears(p.birthDate, todayIn(bundle.user.timezone)),
      heightCm: Number(p.heightCm),
      weightKg: Number(w.weightKg),
      activity: p.activityLevel,
      goal: g.goalType,
      trainingDaysPerWeek: p.trainingDaysPerWeek,
    },
  };
}

export function toContract(row: NutritionTargetsRow): NutritionTargets {
  return {
    effectiveFrom: row.effectiveFrom,
    kcal: row.kcal,
    proteinG: row.proteinG,
    carbG: row.carbG,
    fatG: row.fatG,
    fiberG: row.fiberG,
    bmr: row.bmr,
    tdeeEstimate: row.tdeeEstimate,
    rationale: row.rationale,
    reason: row.reason,
    source: row.source === 'custom' ? 'custom' : 'fitos',
  };
}

export class TargetsService {
  constructor(private readonly repo: UserRepository) {}

  /**
   * Compute from the current bundle and persist as a new history row.
   * Throws CONFLICT if the profile cannot support a computation yet.
   */
  async recompute(userId: string, bundle: ProfileBundle, reason: TargetsReason): Promise<NutritionTargets> {
    const assembled = targetInputFrom(bundle);
    if ('missing' in assembled) {
      throw new AppError('CONFLICT', `Cannot compute targets yet: ${assembled.missing} is not set.`);
    }
    const t = computeTargets(assembled.input);
    const row = await this.repo.insertTargets({
      source: 'fitos',
      userId,
      effectiveFrom: todayIn(bundle.user.timezone),
      kcal: t.kcal,
      proteinG: t.proteinG,
      carbG: t.carbG,
      fatG: t.fatG,
      fiberG: t.fiberG,
      bmr: t.bmr,
      tdeeEstimate: t.tdee,
      rationale: [...t.rationale],
      reason,
    });
    return toContract(row);
  }

  /** FITOS's own suggestion from the profile and goal, or null before they are complete. */
  static suggestion(bundle: ProfileBundle): MacroTargets | null {
    const assembled = targetInputFrom(bundle);
    return 'missing' in assembled ? null : computeTargets(assembled.input);
  }

  /** GET /user/targets: the targets in effect, FITOS's suggestion and the editor's limits. */
  view(bundle: ProfileBundle): TargetsView {
    const s = TargetsService.suggestion(bundle);
    const weight = bundle.latestWeight === null ? null : Number(bundle.latestWeight.weightKg);
    const protein = weight === null ? { min: CUSTOM_TARGET_LIMITS.proteinMinG, max: CUSTOM_TARGET_LIMITS.proteinMaxG } : proteinRangeG(weight);
    return {
      current: bundle.targets === null ? null : toContract(bundle.targets),
      suggestion: s === null ? null : { kcal: s.kcal, proteinG: s.proteinG, carbG: s.carbG, fatG: s.fatG, fiberG: s.fiberG },
      limits: { kcalMin: CUSTOM_TARGET_LIMITS.kcalMin, kcalMax: CUSTOM_TARGET_LIMITS.kcalMax, proteinMinG: protein.min, proteinMaxG: protein.max },
    };
  }

  /**
   * Beta 3.2 (ADR-031): the user's own calories and protein, a new history
   * row with `source: custom`. Fat and carbs follow FITOS's split; the limits
   * are core's (422 with the field); warnings are returned, not enforced.
   */
  async setCustom(userId: string, bundle: ProfileBundle, kcal: number, proteinG: number): Promise<CustomTargetsResponse> {
    const assembled = targetInputFrom(bundle);
    if ('missing' in assembled) {
      throw new AppError('CONFLICT', `Cannot set targets yet: ${assembled.missing} is not set.`);
    }
    const s = computeTargets(assembled.input);
    const check = customTargets({ kcal, proteinG, weightKg: assembled.input.weightKg, suggestion: s });
    if (!check.ok) {
      throw new AppError('VALIDATION_FAILED', check.problem, [{ path: check.field, issue: 'out-of-range' }]);
    }
    const t = check.targets;
    const row = await this.repo.insertTargets({
      userId,
      effectiveFrom: todayIn(bundle.user.timezone),
      kcal: t.kcal,
      proteinG: t.proteinG,
      carbG: t.carbG,
      fatG: t.fatG,
      fiberG: t.fiberG,
      bmr: s.bmr,
      tdeeEstimate: s.tdee,
      rationale: [
        `Your own target: ${t.kcal} kcal and ${t.proteinG} g protein.`,
        `Fat ${t.fatG} g (at least 0.8 g per kg or 22 % of calories) and carbs ${t.carbG} g fill the rest, as FITOS splits them.`,
        `FITOS would suggest ${s.kcal} kcal and ${s.proteinG} g protein.`,
      ],
      reason: 'custom',
      source: 'custom',
    });
    return { targets: toContract(row), warnings: [...check.warnings] };
  }
}
