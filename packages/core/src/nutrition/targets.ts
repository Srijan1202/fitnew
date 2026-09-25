/**
 * Calorie and macro target computation. Pure arithmetic, no AI.
 *
 * Evidence anchors:
 *  - Resting energy: Mifflin-St Jeor (1990), the most accurate common predictive
 *    equation for non-obese adults.
 *  - Protein: Morton et al., Br J Sports Med 2018 — gains in fat-free mass
 *    plateaued beyond ~1.62 g/kg/day, with the authors noting ~2.2 g/kg/day as a
 *    prudent ceiling for those maximising. We default to 1.8 and raise toward
 *    2.2 in a deficit, where higher intakes help preserve lean mass.
 */

export type Sex = 'male' | 'female';
/**
 * Six goals per spec §12.1. `recomposition` and `maintenance` added in Phase 2
 * (scoped exception to the preserve-only rule, approved 2026-09-21).
 */
export type Goal =
  | 'muscle-gain'
  | 'fat-loss'
  | 'recomposition'
  | 'strength'
  | 'general'
  | 'maintenance';

export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'high';

export interface TargetInput {
  readonly sex: Sex;
  readonly ageYears: number;
  readonly heightCm: number;
  readonly weightKg: number;
  readonly activity: ActivityLevel;
  readonly goal: Goal;
  /** Sessions per week. Adds on top of non-training activity. */
  readonly trainingDaysPerWeek: number;
}

export interface MacroTargets {
  readonly kcal: number;
  readonly proteinG: number;
  readonly fatG: number;
  readonly carbG: number;
  readonly fiberG: number;
  readonly bmr: number;
  readonly tdee: number;
  /** Human-readable derivation, shown in-app so the numbers aren't a black box. */
  readonly rationale: readonly string[];
}

const ACTIVITY_MULTIPLIER: Readonly<Record<ActivityLevel, number>> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  high: 1.725,
};

/** Mifflin-St Jeor resting metabolic rate. */
export function mifflinStJeor(input: Pick<TargetInput, 'sex' | 'ageYears' | 'heightCm' | 'weightKg'>): number {
  const base = 10 * input.weightKg + 6.25 * input.heightCm - 5 * input.ageYears;
  return input.sex === 'male' ? base + 5 : base - 161;
}

export function estimateTdee(input: TargetInput): number {
  const bmr = mifflinStJeor(input);
  const base = ACTIVITY_MULTIPLIER[input.activity];
  // Resistance training adds roughly 4% per weekly session on top of baseline
  // activity, capped so 6 days/week doesn't produce an implausible multiplier.
  const trainingBump = Math.min(input.trainingDaysPerWeek, 6) * 0.04;
  return Math.round(bmr * (base + trainingBump));
}

/** Calorie offset from maintenance, as a fraction of TDEE. */
function goalOffset(goal: Goal): number {
  switch (goal) {
    case 'muscle-gain':
      return 0.1; // ~10% surplus: enough to build, slow enough to limit fat gain
    case 'fat-loss':
      return -0.2; // ~20% deficit: sustainable, protects training quality
    case 'recomposition':
      return -0.05; // slight deficit: lose fat while holding muscle (§12.1)
    case 'strength':
      return 0.05;
    case 'general':
      return 0;
    case 'maintenance':
      return 0;
  }
}

/** Protein in g/kg bodyweight. Higher in a deficit to protect lean mass. */
export function proteinPerKg(goal: Goal): number {
  switch (goal) {
    case 'muscle-gain':
      return 1.8;
    case 'fat-loss':
      return 2.2;
    case 'recomposition':
      return 2.2; // in a deficit, so the same ceiling as fat loss (§12.1)
    case 'strength':
      return 1.8;
    case 'general':
      return 1.6;
    case 'maintenance':
      return 1.6;
  }
}

/**
 * One line explaining the calorie offset. Exhaustive so a new goal cannot
 * silently fall through to a wrong description — the previous ternary chain
 * would have called recomposition "at maintenance".
 */
function offsetRationale(goal: Goal): string {
  switch (goal) {
    case 'fat-loss':
      return 'Target set 20% below maintenance for steady fat loss.';
    case 'recomposition':
      return 'Target set 5% below maintenance to lose fat while keeping muscle.';
    case 'muscle-gain':
      return 'Target set 10% above maintenance to support muscle gain without excess fat.';
    case 'strength':
      return 'Target set slightly above maintenance to support strength work.';
    case 'general':
    case 'maintenance':
      return 'Target set at maintenance.';
  }
}

export function computeTargets(input: TargetInput): MacroTargets {
  const bmr = Math.round(mifflinStJeor(input));
  const tdee = estimateTdee(input);
  const kcal = Math.round(tdee * (1 + goalOffset(input.goal)));

  const gPerKg = proteinPerKg(input.goal);
  const proteinG = Math.round(input.weightKg * gPerKg);

  // Fat floor at 0.8 g/kg protects hormonal function; the rest goes to carbs to
  // fuel training, which matters more than a fashionable macro split.
  const fatG = Math.round(Math.max(input.weightKg * 0.8, (kcal * 0.22) / 9));
  const carbKcal = kcal - proteinG * 4 - fatG * 9;
  const carbG = Math.max(0, Math.round(carbKcal / 4));

  // 14 g fibre per 1000 kcal, the standard adequate-intake ratio.
  const fiberG = Math.round((kcal / 1000) * 14);

  const rationale = [
    `Resting metabolic rate ${bmr} kcal (Mifflin-St Jeor).`,
    `Maintenance ${tdee} kcal from ${input.activity} daily activity plus ${input.trainingDaysPerWeek} training days.`,
    offsetRationale(input.goal),
    `Protein at ${gPerKg} g/kg bodyweight.`,
  ];

  return { kcal, proteinG, fatG, carbG, fiberG, bmr, tdee, rationale };
}

/** Macros consumed so far today, against target. Used all over the TODAY screen. */
/**
 * Phase 12 (calorie-adjust): the targets after an accepted adjustment to
 * `kcal`, by the same §13.1 rules `computeTargets` uses — protein unchanged,
 * the fat floor `max(0.8 g/kg, 22 % kcal)`, carbs take the remainder, fibre
 * 14 g per 1000 kcal. `weightKg` is the trend weight the decision used.
 */
export function adjustTargets(
  current: Pick<MacroTargets, 'proteinG'>,
  kcal: number,
  weightKg: number,
): Pick<MacroTargets, 'kcal' | 'proteinG' | 'fatG' | 'carbG' | 'fiberG'> {
  const proteinG = current.proteinG;
  const fatG = Math.round(Math.max(weightKg * 0.8, (kcal * 0.22) / 9));
  const carbG = Math.max(0, Math.round((kcal - proteinG * 4 - fatG * 9) / 4));
  const fiberG = Math.round((kcal / 1000) * 14);
  return { kcal, proteinG, fatG, carbG, fiberG };
}

export interface DailyProgress {
  readonly kcalConsumed: number;
  readonly proteinConsumed: number;
  readonly targets: MacroTargets;
}

export interface RemainingMacros {
  readonly kcal: number;
  readonly protein: number;
  readonly kcalPercent: number;
  readonly proteinPercent: number;
}

export function remaining(progress: DailyProgress): RemainingMacros {
  const { targets } = progress;
  return {
    kcal: Math.max(0, targets.kcal - progress.kcalConsumed),
    protein: Math.max(0, targets.proteinG - progress.proteinConsumed),
    kcalPercent: targets.kcal > 0 ? progress.kcalConsumed / targets.kcal : 0,
    proteinPercent: targets.proteinG > 0 ? progress.proteinConsumed / targets.proteinG : 0,
  };
}
