/**
 * Exercise substitution (§12.6; owner decision 12.6). Deterministic triggers
 * only: the user no longer has the equipment, a limitation on file now
 * contraindicates the lift, or the user rejected it twice. The substitute is
 * the first alternative with the same movement pattern and the same first
 * primary muscle that the user can perform; when the library has none, that
 * is said plainly. A substitute starts at `establish-baseline` — load never
 * carries over between different exercises.
 */
import { isContraindicated, isPerformable, type BodyPart, type CatalogueExercise, type Equipment } from './generator.js';

export const REJECTIONS_TO_SUBSTITUTE = 2;

export type SubstitutionTrigger = 'equipment' | 'limitation' | 'rejected';

export interface SubstitutionNeed {
  readonly trigger: SubstitutionTrigger;
  readonly reason: string;
}

export interface Substitution {
  readonly trigger: SubstitutionTrigger;
  /** The alternative to swap to, or null when the library has none the user can perform. */
  readonly alternative: CatalogueExercise | null;
  readonly reason: string;
}

/** Why an exercise should be swapped, or null when it should stay. */
export function needsSubstitution(
  exercise: CatalogueExercise,
  kit: readonly Equipment[],
  limitations: readonly BodyPart[],
  rejections: number,
): SubstitutionNeed | null {
  if (!isPerformable(exercise, kit)) {
    const missing = exercise.equipment.filter((q) => q !== 'bodyweight' && !kit.includes(q));
    return { trigger: 'equipment', reason: `${exercise.name} needs ${missing.join(' and ')}, which is not in your equipment any more.` };
  }
  if (isContraindicated(exercise, limitations)) {
    const parts = exercise.contraindications.filter((p) => limitations.includes(p));
    return { trigger: 'limitation', reason: `${exercise.name} is contraindicated by your ${parts.join(', ')} limitation.` };
  }
  if (rejections >= REJECTIONS_TO_SUBSTITUTE) {
    return { trigger: 'rejected', reason: `You have skipped ${exercise.name} ${rejections} times; here is a swap that trains the same thing.` };
  }
  return null;
}

/**
 * The first alternative (in the order the library lists them) with the same
 * pattern and first primary muscle that the user can perform and that is not
 * itself contraindicated.
 */
export function pickAlternative(
  exercise: CatalogueExercise,
  alternatives: readonly CatalogueExercise[],
  kit: readonly Equipment[],
  limitations: readonly BodyPart[],
): CatalogueExercise | null {
  for (const alt of alternatives) {
    if (alt.id === exercise.id) continue;
    if (alt.movementPattern !== exercise.movementPattern) continue;
    if (alt.primaryMuscles[0] !== exercise.primaryMuscles[0]) continue;
    if (!isPerformable(alt, kit) || isContraindicated(alt, limitations)) continue;
    return alt;
  }
  return null;
}

export function substitute(
  exercise: CatalogueExercise,
  alternatives: readonly CatalogueExercise[],
  kit: readonly Equipment[],
  limitations: readonly BodyPart[],
  rejections: number,
): Substitution | null {
  const need = needsSubstitution(exercise, kit, limitations, rejections);
  if (need === null) return null;
  const alternative = pickAlternative(exercise, alternatives, kit, limitations);
  return {
    trigger: need.trigger,
    alternative,
    reason:
      alternative === null
        ? `${need.reason} No alternative in the library trains ${exercise.primaryMuscles[0] ?? 'the same muscle'} with the same movement and your equipment; keep it, skip it, or pick something yourself.`
        : `${need.reason} ${alternative.name} trains the same muscle with the same movement; it starts from a fresh baseline — load does not carry over.`,
  };
}
