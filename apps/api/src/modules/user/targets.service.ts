/**
 * The bridge between stored profile data and packages/core's target engine.
 *
 * This is the ONLY place `computeTargets` is called (§7.3, §30). Everything
 * that reaches the engine is validated at the boundary; everything that comes
 * back is persisted as a new history row and returned unchanged.
 */
import { computeTargets, type TargetInput } from '@fitos/core/nutrition/targets';
import type { NutritionTargets } from '@fitos/contracts';

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

export type TargetsReason = 'onboarding' | 'goal-change' | 'profile-change';

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
}
