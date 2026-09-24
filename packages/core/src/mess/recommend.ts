/**
 * "What should I eat at this meal?" (§15.1; Phase 10, ADR-015)
 *
 * Deterministic bounded search over serving combinations of the dishes actually
 * on the menu. No LLM chooses a plate or computes any number here, and none
 * rephrases the result (reasons are codes; the app words them).
 *
 *   diet + allergy hard filter (primary AND every alternative)
 *     → top 9 by protein density (slug breaks ties)
 *     → bounded search over whole servings (role caps, ≤ 8 servings, kcal pruning)
 *     → score → dedupe → top 3 with reasons and confidence
 *
 * Item numbers are Phase 8 snapshots (`snapshotNutrition`) of the dish's
 * estimate, so a plate's preview equals what logging it stores. The meal
 * target is the caller's (see recommendation.ts for the meal share).
 */

import { defaultMealSlot } from '../nutrition/log.js';
import { snapshotNutrition } from '../nutrition/log.js';
import { allergenFailures, type Allergen } from './allergens.js';
import type { DietClass, DishRole, MacroRange, MealSlot, MessDish, MessMeal } from './types.js';
import { ZERO_MACROS, addMacros, midpoint } from './nutrition.js';

/** What the user will and won't eat. */
export type DietPreference = 'vegetarian' | 'eggetarian' | 'non-vegetarian';

/** The six goals (§12.1). */
export type PlateGoal = 'muscle-gain' | 'fat-loss' | 'recomposition' | 'strength' | 'general' | 'maintenance';

export interface PlateItem {
  readonly dishId: string;
  readonly name: string;
  readonly servings: number;
  readonly servingLabel: string;
  readonly servingGrams: number | null;
  /** The Phase 8 snapshot of this dish × servings. */
  readonly macros: MacroRange;
  readonly confidence: 'high' | 'medium' | 'low';
}

/** A structured, deterministic reason. No prose: the app words each code. */
export type PlateReason =
  | { readonly code: 'protein-covers'; readonly target: number; readonly low: number }
  | { readonly code: 'protein-may-fall-short'; readonly target: number; readonly low: number; readonly high: number }
  | { readonly code: 'protein-short'; readonly target: number; readonly high: number }
  | { readonly code: 'kcal-within'; readonly target: number; readonly high: number }
  | { readonly code: 'kcal-may-exceed'; readonly target: number; readonly low: number; readonly high: number }
  | { readonly code: 'kcal-over'; readonly target: number; readonly low: number }
  | { readonly code: 'carb-within'; readonly target: number; readonly high: number }
  | { readonly code: 'carb-over'; readonly target: number; readonly low: number; readonly high: number }
  | { readonly code: 'fat-within'; readonly target: number; readonly high: number }
  | { readonly code: 'fat-over'; readonly target: number; readonly low: number; readonly high: number }
  | { readonly code: 'goal-weighting'; readonly goal: PlateGoal }
  | { readonly code: 'top-protein-dish'; readonly dishSlug: string }
  | { readonly code: 'post-workout-carbs'; readonly target: number; readonly low: number; readonly high: number }
  | { readonly code: 'repeat'; readonly dishSlug: string; readonly days: number }
  | { readonly code: 'low-confidence-dish'; readonly dishSlug: string }
  | { readonly code: 'inferred-menu'; readonly sourceDate: string };

export interface PlateSuggestion {
  readonly items: readonly PlateItem[];
  readonly macros: MacroRange;
  readonly reasons: readonly PlateReason[];
  /** Lowest confidence among constituent dishes — the plate is only as good as its worst estimate. */
  readonly confidence: 'high' | 'medium' | 'low';
  /** For ordering only; never shown. */
  readonly score: number;
}

export interface PlateRequest {
  readonly meal: MessMeal;
  /** The meal's kcal target (Tk). */
  readonly remainingKcal: number;
  /** The meal's protein target (Tp). */
  readonly remainingProtein: number;
  /** Phase 10: the meal's carb and fat targets (Tc, Tf). Omitted → no carb/fat terms. */
  readonly remainingCarb?: number;
  readonly remainingFat?: number;
  readonly diet: DietPreference;
  readonly goal: PlateGoal;
  /** Dish ids the user has told us they dislike. Hard exclusion. */
  readonly excludedDishIds?: readonly string[];
  /** Phase 10: a hard filter — only dishes confirmed free of every one pass. */
  readonly allergies?: readonly Allergen[];
  /** Phase 10: a workout completed in the last 3 hours (carb reward). */
  readonly postWorkout?: boolean;
  /** Phase 10: slug → distinct days (0–3) it was logged in the 3 days before the menu date. */
  readonly varietyDays?: Readonly<Record<string, number>>;
}

/* ----------------------------------------------------------- constants -- */

/** ADR-015 §9 — fixed; tests pin every value. Changing one needs the owner. */
export const SCORING = {
  proteinCap: 1.25,
  proteinPoints: 100,
  carbWeight: 40,
  carbWeightPostWorkout: 20,
  fatWeight: 50,
  carbReward: 20,
  shapeTargetItems: 4,
  shapePerItem: 4,
  shapeServingsFree: 7,
  shapePerServing: 6,
  varietyPerDay: 6,
  varietyMaxDays: 3,
  maxCandidates: 9,
  maxServings: 8,
  kcalCeilingFactor: 1.5,
  kcalCeilingFloor: 400,
} as const;

export const GOAL_WEIGHTS: Readonly<Record<PlateGoal, { readonly over: number; readonly under: number }>> = {
  'muscle-gain': { over: 110, under: 55 },
  'fat-loss': { over: 180, under: 35 },
  // Owner D19 / R4: recomposition takes the fat-loss calorie weights; §15.1
  // has no goal-specific protein weight, so nothing else changes.
  recomposition: { over: 180, under: 35 },
  strength: { over: 110, under: 35 },
  general: { over: 110, under: 35 },
  maintenance: { over: 110, under: 35 },
};

/** §15.1 as written: everything but ambient items and condiments may go on a plate (owner R1). */
const PLATE_ROLES: ReadonlySet<DishRole> = new Set<DishRole>([
  'staple', 'protein', 'legume', 'dairy', 'vegetable', 'fruit', 'fried', 'sweet', 'beverage', 'other',
]);

/* -------------------------------------------------------------- diet -- */

/**
 * Diet gate. `unknown` is excluded for vegetarians and eggetarians by design:
 * in a mess that serves meat, an unrecognised dish name is not proof of
 * vegetarianism, and the cost of being wrong is asymmetric.
 */
export function isDietAllowed(diet: DietClass, preference: DietPreference): boolean {
  switch (preference) {
    case 'non-vegetarian':
      return true;
    case 'eggetarian':
      return diet === 'veg' || diet === 'egg';
    case 'vegetarian':
      return diet === 'veg';
  }
}

/** Max servings we'll ever suggest of one dish, by role. Keeps plates realistic. */
export function maxServings(dish: Pick<MessDish, 'role' | 'name'>): number {
  switch (dish.role) {
    case 'staple':
      return dish.name.toLowerCase().includes('rice') ? 2 : 3; // 3 rotis is normal, 3 plates of rice is not
    case 'protein':
    case 'legume':
    case 'dairy':
      return 2;
    default:
      return 1; // vegetable, fruit, fried, sweet, beverage, other
  }
}

function proteinDensity(dish: MessDish): number {
  const n = dish.nutrition;
  if (n === null) return 0;
  const kcal = midpoint(n.macros.kcalLow, n.macros.kcalHigh);
  if (kcal <= 0) return 0;
  return midpoint(n.macros.proteinLow, n.macros.proteinHigh) / kcal;
}

/* ------------------------------------------------------ dish verdicts -- */

export type DishReason =
  | { readonly code: 'on-plate'; readonly ranks: readonly number[] }
  | { readonly code: 'diet'; readonly dietClass: DietClass }
  | { readonly code: 'diet-alternative'; readonly alternative: string; readonly dietClass: DietClass }
  | { readonly code: 'allergen'; readonly allergen: Allergen; readonly status: 'contains' | 'likely' | 'unknown' }
  | {
      readonly code: 'allergen-alternative';
      readonly alternative: string;
      readonly allergen: Allergen;
      readonly status: 'contains' | 'likely' | 'unknown';
    }
  | { readonly code: 'no-estimate' }
  | { readonly code: 'ambient' }
  | { readonly code: 'not-a-plate-dish'; readonly role: DishRole }
  | { readonly code: 'disliked' }
  | { readonly code: 'not-top-candidate' }
  | { readonly code: 'not-chosen' };

export interface DishVerdict {
  readonly dish: MessDish;
  /** Passed every filter (may still be outside the top candidates). */
  readonly eligible: boolean;
  readonly reasons: readonly DishReason[];
}

/**
 * Why each dish can or cannot go on a plate, checked in the plan's order;
 * the first failing step is the reason (every failing allergen is listed).
 */
export function dishVerdicts(request: PlateRequest): DishVerdict[] {
  const excluded = new Set(request.excludedDishIds ?? []);
  const allergies = request.allergies ?? [];
  return request.meal.dishes.map((dish): DishVerdict => {
    const fail = (reasons: DishReason[]): DishVerdict => ({ dish, eligible: false, reasons });

    if (!isDietAllowed(dish.diet, request.diet)) return fail([{ code: 'diet', dietClass: dish.diet }]);
    const altDiets = dish.alternativeDiets ?? [];
    for (let i = 0; i < dish.alternatives.length; i += 1) {
      const altDiet = altDiets[i] ?? 'unknown';
      if (!isDietAllowed(altDiet, request.diet)) {
        return fail([{ code: 'diet-alternative', alternative: dish.alternatives[i] as string, dietClass: altDiet }]);
      }
    }
    if (allergies.length > 0) {
      const primary = allergenFailures(dish.name, dish.diet, allergies);
      if (primary.length > 0) return fail(primary.map((f) => ({ code: 'allergen', ...f })));
      const alt: DishReason[] = [];
      dish.alternatives.forEach((a, i) => {
        for (const f of allergenFailures(a, altDiets[i] ?? 'unknown', allergies)) {
          alt.push({ code: 'allergen-alternative', alternative: a, ...f });
        }
      });
      if (alt.length > 0) return fail(alt);
    }
    if (dish.nutrition === null) return fail([{ code: 'no-estimate' }]);
    if (dish.isAmbient) return fail([{ code: 'ambient' }]);
    if (!PLATE_ROLES.has(dish.role)) return fail([{ code: 'not-a-plate-dish', role: dish.role }]);
    if (excluded.has(dish.id)) return fail([{ code: 'disliked' }]);
    return { dish, eligible: true, reasons: [] };
  });
}

function byDensityThenSlug(a: MessDish, b: MessDish): number {
  const d = proteinDensity(b) - proteinDensity(a);
  if (d !== 0) return d;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

export function selectCandidates(request: PlateRequest, limit: number = SCORING.maxCandidates): MessDish[] {
  return dishVerdicts(request)
    .filter((v) => v.eligible)
    .map((v) => v.dish)
    .sort(byDensityThenSlug)
    .slice(0, limit);
}

/* ------------------------------------------------------------- score -- */

export interface ScoreInput {
  readonly macros: MacroRange;
  readonly itemCount: number;
  readonly totalServings: number;
  readonly request: PlateRequest;
  /** Slugs on the plate (for variety). */
  readonly dishIds?: readonly string[];
}

export interface ScoreTerms {
  readonly proteinScore: number;
  readonly carbReward: number;
  readonly kcalPenalty: number;
  readonly carbPenalty: number;
  readonly fatPenalty: number;
  readonly shapePenalty: number;
  readonly varietyPenalty: number;
  readonly score: number;
}

/** Every term of ADR-015 §9, exposed so tests pin each one. Higher is better. */
export function scoreTerms(input: ScoreInput): ScoreTerms {
  const { macros, itemCount, totalServings, request } = input;
  const S = SCORING;
  const k = midpoint(macros.kcalLow, macros.kcalHigh);
  const p = midpoint(macros.proteinLow, macros.proteinHigh);
  const c = midpoint(macros.carbLow, macros.carbHigh);
  const f = midpoint(macros.fatLow, macros.fatHigh);

  const Tk = Math.max(request.remainingKcal, 1);
  const Tp = Math.max(request.remainingProtein, 1);
  const proteinScore = S.proteinPoints * Math.min(p / Tp, S.proteinCap);

  const w = GOAL_WEIGHTS[request.goal];
  const kcalPenalty = w.over * (Math.max(0, k - Tk) / Tk) + w.under * (Math.max(0, Tk - k) / Tk);

  const post = request.postWorkout === true;
  let carbPenalty = 0;
  let carbReward = 0;
  if (request.remainingCarb !== undefined) {
    const Tc = Math.max(request.remainingCarb, 1);
    carbPenalty = (post ? S.carbWeightPostWorkout : S.carbWeight) * (Math.max(0, c - Tc) / Tc);
    if (post) carbReward = S.carbReward * Math.min(c / Tc, 1);
  }
  let fatPenalty = 0;
  if (request.remainingFat !== undefined) {
    const Tf = Math.max(request.remainingFat, 1);
    fatPenalty = S.fatWeight * (Math.max(0, f - Tf) / Tf);
  }

  const shapePenalty =
    Math.abs(itemCount - S.shapeTargetItems) * S.shapePerItem +
    Math.max(0, totalServings - S.shapeServingsFree) * S.shapePerServing;

  let varietyPenalty = 0;
  for (const id of input.dishIds ?? []) {
    const days = Math.min(Math.max(request.varietyDays?.[id] ?? 0, 0), S.varietyMaxDays);
    varietyPenalty += S.varietyPerDay * days;
  }

  const score = proteinScore + carbReward - kcalPenalty - carbPenalty - fatPenalty - shapePenalty - varietyPenalty;
  return { proteinScore, carbReward, kcalPenalty, carbPenalty, fatPenalty, shapePenalty, varietyPenalty, score };
}

export function scorePlate(input: ScoreInput): number {
  return scoreTerms(input).score;
}

/* ------------------------------------------------------------ search -- */

const round1 = (v: number): number => Math.round(v * 10) / 10;

function sumMacros(items: readonly MacroRange[]): MacroRange {
  const s = items.reduce(addMacros, ZERO_MACROS);
  return {
    kcalLow: Math.round(s.kcalLow), kcalHigh: Math.round(s.kcalHigh),
    proteinLow: round1(s.proteinLow), proteinHigh: round1(s.proteinHigh),
    carbLow: round1(s.carbLow), carbHigh: round1(s.carbHigh),
    fatLow: round1(s.fatLow), fatHigh: round1(s.fatHigh),
  };
}

/** The Phase 8 snapshot of `dish` × `servings`, as macros. */
function snapshotOf(dish: MessDish, servings: number): MacroRange {
  const n = dish.nutrition;
  if (n === null) return ZERO_MACROS;
  return snapshotNutrition({ macros: n.macros, fibre: null }, servings).macros;
}

function worstConfidence(items: readonly MessDish[]): 'high' | 'medium' | 'low' {
  let worst: 'high' | 'medium' | 'low' = 'high';
  for (const dish of items) {
    const c = dish.nutrition?.confidence ?? 'low';
    if (c === 'low') return 'low';
    if (c === 'medium') worst = 'medium';
  }
  return worst;
}

function level(target: number, low: number, high: number): 'covers' | 'maybe' | 'short' {
  if (low >= target) return 'covers';
  if (high >= target) return 'maybe';
  return 'short';
}

/** The plate's reasons, in a fixed order (ADR-015 §13). */
export function plateReasons(macros: MacroRange, chosen: readonly MessDish[], request: PlateRequest): PlateReason[] {
  const r: PlateReason[] = [];
  const Tp = request.remainingProtein;
  const Tk = request.remainingKcal;
  switch (level(Tp, macros.proteinLow, macros.proteinHigh)) {
    case 'covers':
      r.push({ code: 'protein-covers', target: Tp, low: macros.proteinLow });
      break;
    case 'maybe':
      r.push({ code: 'protein-may-fall-short', target: Tp, low: macros.proteinLow, high: macros.proteinHigh });
      break;
    case 'short':
      r.push({ code: 'protein-short', target: Tp, high: macros.proteinHigh });
  }
  if (macros.kcalHigh <= Tk) r.push({ code: 'kcal-within', target: Tk, high: macros.kcalHigh });
  else if (macros.kcalLow <= Tk) r.push({ code: 'kcal-may-exceed', target: Tk, low: macros.kcalLow, high: macros.kcalHigh });
  else r.push({ code: 'kcal-over', target: Tk, low: macros.kcalLow });
  if (request.remainingCarb !== undefined) {
    const Tc = request.remainingCarb;
    r.push(
      macros.carbHigh <= Tc
        ? { code: 'carb-within', target: Tc, high: macros.carbHigh }
        : { code: 'carb-over', target: Tc, low: macros.carbLow, high: macros.carbHigh },
    );
  }
  if (request.remainingFat !== undefined) {
    const Tf = request.remainingFat;
    r.push(
      macros.fatHigh <= Tf
        ? { code: 'fat-within', target: Tf, high: macros.fatHigh }
        : { code: 'fat-over', target: Tf, low: macros.fatLow, high: macros.fatHigh },
    );
  }
  r.push({ code: 'goal-weighting', goal: request.goal });
  const top = [...chosen].sort(byDensityThenSlug)[0];
  if (top !== undefined) r.push({ code: 'top-protein-dish', dishSlug: top.id });
  if (request.postWorkout === true && request.remainingCarb !== undefined) {
    r.push({ code: 'post-workout-carbs', target: request.remainingCarb, low: macros.carbLow, high: macros.carbHigh });
  }
  for (const d of [...chosen].sort((a, b) => (a.id < b.id ? -1 : 1))) {
    const days = Math.min(request.varietyDays?.[d.id] ?? 0, SCORING.varietyMaxDays);
    if (days > 0) r.push({ code: 'repeat', dishSlug: d.id, days });
  }
  for (const d of [...chosen].sort((a, b) => (a.id < b.id ? -1 : 1))) {
    if ((d.nutrition?.confidence ?? 'low') === 'low') r.push({ code: 'low-confidence-dish', dishSlug: d.id });
  }
  return r;
}

interface ScoredPlate {
  readonly items: readonly PlateItem[];
  readonly macros: MacroRange;
  readonly confidence: 'high' | 'medium' | 'low';
  readonly score: number;
  readonly chosen: readonly MessDish[];
  readonly key: string;
}

/** Identity of a plate: which dishes, at which serving counts. Order-independent. */
function plateKey(items: readonly PlateItem[]): string {
  return items
    .map((it) => `${it.dishId}x${it.servings}`)
    .sort()
    .join('|');
}

export interface PlateSearch {
  readonly plates: PlateSuggestion[];
  readonly candidates: readonly MessDish[];
  /** The highest optimistic protein and kcal any searched plate reaches (for the shortfall). */
  readonly menuMax: { readonly proteinHigh: number; readonly kcalHigh: number };
}

/**
 * Bounded depth-first enumeration. At most 9 candidates and 8 servings, so
 * the search space stays small and the result is deterministic for a given
 * menu and request.
 */
export function searchPlates(request: PlateRequest, maxResults = 3): PlateSearch {
  const candidates = selectCandidates(request);
  if (candidates.length === 0) return { plates: [], candidates, menuMax: { proteinHigh: 0, kcalHigh: 0 } };

  // Each dish's snapshot at each serving count, computed once.
  const snaps = candidates.map((d) => {
    const caps: MacroRange[] = [ZERO_MACROS];
    for (let s = 1; s <= maxServings(d); s += 1) caps.push(snapshotOf(d, s));
    return caps;
  });
  const kcalCeiling = Math.max(request.remainingKcal * SCORING.kcalCeilingFactor, SCORING.kcalCeilingFloor);

  const results: ScoredPlate[] = [];
  const counts = new Array<number>(candidates.length).fill(0);
  let maxProtein = 0;
  let maxKcal = 0;

  const walk = (index: number, totalServings: number, accKcalLow: number): void => {
    if (accKcalLow > kcalCeiling) return;
    if (index === candidates.length) {
      if (totalServings === 0) return;
      const chosen: MessDish[] = [];
      const items: PlateItem[] = [];
      const parts: MacroRange[] = [];
      for (let i = 0; i < candidates.length; i += 1) {
        const servings = counts[i] ?? 0;
        const dish = candidates[i];
        if (servings === 0 || dish === undefined || dish.nutrition === null) continue;
        const m = snaps[i]?.[servings] ?? ZERO_MACROS;
        parts.push(m);
        chosen.push(dish);
        items.push({
          dishId: dish.id,
          name: dish.name,
          servings,
          servingLabel: dish.nutrition.servingLabel,
          servingGrams: dish.nutrition.servingGrams,
          macros: m,
          confidence: dish.nutrition.confidence,
        });
      }
      if (items.length === 0) return;
      const macros = sumMacros(parts);
      maxProtein = Math.max(maxProtein, macros.proteinHigh);
      maxKcal = Math.max(maxKcal, macros.kcalHigh);
      const score = scorePlate({ macros, itemCount: items.length, totalServings, request, dishIds: items.map((i) => i.dishId) });
      results.push({ items, macros, confidence: worstConfidence(chosen), score, chosen, key: plateKey(items) });
      return;
    }
    const dish = candidates[index];
    if (dish === undefined) return;
    const cap = maxServings(dish);
    for (let servings = 0; servings <= cap; servings += 1) {
      if (totalServings + servings > SCORING.maxServings) break;
      const nextKcal = accKcalLow + (snaps[index]?.[servings]?.kcalLow ?? 0);
      if (nextKcal > kcalCeiling) break;
      counts[index] = servings;
      walk(index + 1, totalServings + servings, nextKcal);
    }
    counts[index] = 0;
  };

  walk(0, 0, 0);

  // Score descending; the plate key breaks ties, so the order never depends on the search path.
  results.sort((a, b) => (b.score !== a.score ? b.score - a.score : a.key < b.key ? -1 : a.key > b.key ? 1 : 0));

  const seen = new Set<string>();
  const survivors: ScoredPlate[] = [];
  for (const plate of results) {
    if (survivors.length >= maxResults) break;
    if (seen.has(plate.key)) continue;
    seen.add(plate.key);
    survivors.push(plate);
  }

  return {
    candidates,
    menuMax: { proteinHigh: maxProtein, kcalHigh: maxKcal },
    plates: survivors.map((plate) => ({
      items: plate.items,
      macros: plate.macros,
      reasons: plateReasons(plate.macros, plate.chosen, request),
      confidence: plate.confidence,
      score: plate.score,
    })),
  };
}

export function suggestPlates(request: PlateRequest, maxResults = 3): PlateSuggestion[] {
  return searchPlates(request, maxResults).plates;
}

/**
 * The meal a user is about to eat, given local time. Phase 10 (owner D21):
 * the same 11 / 16 / 19 boundaries as logging (`defaultMealSlot`).
 */
export function currentMealSlot(hour: number): MealSlot {
  return defaultMealSlot(hour);
}
