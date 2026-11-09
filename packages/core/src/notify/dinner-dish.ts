/**
 * Beta 6.1 (E17): the protein nudge names a dish from tonight's mess dinner.
 *
 * The dish is the one with the most protein a serving among those the mess
 * recommender would let on this user's plate at dinner — the same hard
 * filters (diet, allergens, dishes they dislike, a FITOS estimate), never
 * looser. Under DISH_PROTEIN_MIN_G a serving it is not worth naming, and
 * the nudge keeps its ordinary words. The caller passes only a published
 * menu: an inferred one may not be what is served.
 */
import type { Allergen } from '../mess/allergens.js';
import { dishVerdicts, type DietPreference } from '../mess/recommend.js';
import type { MessMeal } from '../mess/types.js';

export const DISH_PROTEIN_MIN_G = 10;

export interface DinnerDish {
  readonly name: string;
  /** Grams a serving, the middle of FITOS's range, rounded. */
  readonly proteinG: number;
}

export function proteinDishOf(
  dinner: MessMeal | undefined,
  filters: { readonly diet: DietPreference; readonly allergies: readonly Allergen[]; readonly excludedDishIds: readonly string[] },
): DinnerDish | null {
  if (dinner === undefined) return null;
  let best: DinnerDish | null = null;
  const verdicts = dishVerdicts({
    meal: dinner,
    remainingKcal: 0,
    remainingProtein: 0,
    diet: filters.diet,
    goal: 'general',
    allergies: filters.allergies,
    excludedDishIds: filters.excludedDishIds,
  });
  for (const v of verdicts) {
    // Eligible dishes always carry an estimate (dishVerdicts refuses one without).
    if (!v.eligible) continue;
    const m = v.dish.nutrition!.macros;
    const proteinG = Math.round((m.proteinLow + m.proteinHigh) / 2);
    if (best === null || proteinG > best.proteinG || (proteinG === best.proteinG && v.dish.name < best.name)) {
      best = { name: v.dish.name, proteinG };
    }
  }
  return best !== null && best.proteinG >= DISH_PROTEIN_MIN_G ? best : null;
}
