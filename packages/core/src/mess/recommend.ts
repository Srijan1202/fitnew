/**
 * "What should I eat at this meal?" (§15.1; Phase 10, ADR-015 and ADR-016)
 *
 * FITOS recommends a MEAL, not the nutritionally cheapest dish (owner). A
 * deterministic bounded search over serving combinations of the dishes
 * actually on the menu, where STRUCTURE is a constraint and nutrition ranks
 * within it. No LLM chooses a plate or computes any number here, and none
 * rephrases the result (reasons are codes; the app words them).
 *
 *   diet + allergy hard filter (primary AND every alternative)
 *     → meal component per dish (components.ts; drinks never, desserts and
 *       crisps only at snacks — owner C5, C6)
 *     → per-component candidates, anchors first (a staple always survives)
 *     → bounded search over whole servings (component caps, ≤ 8 servings,
 *       a kcal ceiling that always admits the smallest valid meal)
 *     → structure tier per plate → only the best achievable tier
 *     → score within it (protein, kcal, carb/fat with F1, shape, variety,
 *       post-workout) → up to 3 plates that differ in a meal anchor (C3)
 *
 * Item numbers are Phase 8 snapshots (`snapshotNutrition`) of the dish's
 * estimate, so a plate's preview equals what logging it stores. The meal
 * target is the caller's (see recommendation.ts for the meal share).
 */

import { defaultMealSlot, snapshotNutrition } from '../nutrition/log.js';
import { allergenFailures, type Allergen } from './allergens.js';
import {
  COMPONENT_CANDIDATES, MEAL_COMPONENTS, PLATE_COMPONENTS, PLATE_DISH_CAPS, PLATE_MAX_DISHES,
  classifyComponent, isAnchor, lastTier, partsOf, servingCap, structureOf, tierNeeds,
  type MealComponent, type MissingPart, type Parts, type Structure, type StructureKind,
} from './components.js';
import type { DietClass, MacroRange, MealSlot, MessDish, MessMeal } from './types.js';
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
  /** What part of the meal this dish is (ADR-016). */
  readonly component: MealComponent;
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
  | { readonly code: 'meal-structure'; readonly kind: StructureKind }
  | { readonly code: 'staple-anchor'; readonly dishSlug: string }
  | { readonly code: 'protein-anchor'; readonly dishSlug: string; readonly strength: 'strong' | 'weak' }
  | { readonly code: 'vegetable-component'; readonly dishSlug: string }
  | { readonly code: 'supporting-side'; readonly dishSlug: string }
  | { readonly code: 'limited-menu'; readonly missing: readonly MissingPart[] }
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
  /** The meal it makes (tier is internal; kind and missing are shown). */
  readonly structure: Structure;
  /** For ordering only; never shown. */
  readonly score: number;
}

export interface PlateRequest {
  /** The meal on the menu; its slot decides the structure rules. */
  readonly meal: MessMeal;
  /** The meal's kcal target (Tk). */
  readonly remainingKcal: number;
  /** The meal's protein target (Tp). */
  readonly remainingProtein: number;
  /** Phase 10: the meal's carb and fat targets (Tc, Tf). Omitted → no carb/fat terms. */
  readonly remainingCarb?: number;
  readonly remainingFat?: number;
  /**
   * F1 (owner C2): a normal-sized meal — the day target × the meal weight.
   * Over-penalties divide by max(target, normal), so an empty remainder can
   * never make every real meal cost hundreds of points. Omitted → max(target, 1).
   */
  readonly normalKcal?: number;
  readonly normalCarb?: number;
  readonly normalFat?: number;
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
  | { readonly code: 'not-a-meal-component'; readonly component: MealComponent }
  | { readonly code: 'disliked' }
  | { readonly code: 'not-top-candidate' }
  | { readonly code: 'not-chosen' };

/** Hard-filter reasons: a dish failing one of these is not safe for this user. */
export const UNSAFE_REASONS: ReadonlySet<DishReason['code']> = new Set(['diet', 'diet-alternative', 'allergen', 'allergen-alternative']);

export interface DishVerdict {
  readonly dish: MessDish;
  readonly component: MealComponent;
  /** Passed every filter and may go on a plate at this meal (may still be outside the candidates). */
  readonly eligible: boolean;
  readonly reasons: readonly DishReason[];
}

/**
 * Why each dish can or cannot go on a plate, checked in the plan's order;
 * the first failing step is the reason (every failing allergen is listed).
 * The hard filters run before anything about meal structure.
 */
export function dishVerdicts(request: PlateRequest): DishVerdict[] {
  const excluded = new Set(request.excludedDishIds ?? []);
  const allergies = request.allergies ?? [];
  const allowed = PLATE_COMPONENTS[request.meal.slot];
  return request.meal.dishes.map((dish): DishVerdict => {
    const component = classifyComponent(dish.name, dish.diet);
    const fail = (reasons: DishReason[]): DishVerdict => ({ dish, component, eligible: false, reasons });

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
    if (!allowed.has(component)) return fail([{ code: 'not-a-meal-component', component }]);
    if (excluded.has(dish.id)) return fail([{ code: 'disliked' }]);
    return { dish, component, eligible: true, reasons: [] };
  });
}

function byDensityThenSlug(a: MessDish, b: MessDish): number {
  const d = proteinDensity(b) - proteinDensity(a);
  if (d !== 0) return d;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

export interface Candidate {
  readonly dish: MessDish;
  readonly component: MealComponent;
}

/** Search order: anchors first, then the meal's other parts; a fixed component order. */
const COMPONENT_ORDER: readonly MealComponent[] = [
  'staple', 'complete', 'protein', 'pulse-gravy', 'dairy', 'veg', 'soup', 'fruit', 'snack', 'dessert', 'crisp',
];

/**
 * Per-component candidates (ADR-016 §5): the top N of each component by
 * protein density, slug breaking ties. A global ranking could drop every
 * staple; this cannot.
 */
export function selectCandidates(request: PlateRequest): Candidate[] {
  const groups = new Map<MealComponent, MessDish[]>();
  for (const v of dishVerdicts(request)) {
    if (!v.eligible) continue;
    groups.set(v.component, [...(groups.get(v.component) ?? []), v.dish]);
  }
  const out: Candidate[] = [];
  for (const component of COMPONENT_ORDER) {
    const list = [...(groups.get(component) ?? [])].sort(byDensityThenSlug).slice(0, COMPONENT_CANDIDATES[component]);
    for (const dish of list) out.push({ dish, component });
  }
  return out;
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

/**
 * Targets and the F1 denominators (owner C2). Over-terms measure the excess
 * over the real target (never below 0) against max(target, a normal-sized
 * meal) — so a spent fat budget costs a meal tens of points, not hundreds.
 * Without a normal meal (the pre-F1 request) the floor stays 1.
 */
function denominators(request: PlateRequest): { Tk: number; Tc: number; Tf: number; rc: number; rf: number; dk: number; dc: number; df: number } {
  const Tk = Math.max(request.remainingKcal, 1);
  const rc = Math.max(request.remainingCarb ?? 0, 0);
  const rf = Math.max(request.remainingFat ?? 0, 0);
  const Tc = Math.max(rc, 1);
  const Tf = Math.max(rf, 1);
  const f1 = request.normalFat !== undefined || request.normalCarb !== undefined || request.normalKcal !== undefined;
  return {
    Tk, Tc, Tf,
    // Pre-F1 requests keep ADR-015's exact terms (target floored at 1 throughout).
    rc: f1 ? rc : Tc,
    rf: f1 ? rf : Tf,
    dk: Math.max(Tk, request.normalKcal ?? 1),
    dc: Math.max(Tc, request.normalCarb ?? 1),
    df: Math.max(Tf, request.normalFat ?? 1),
  };
}

/** Every term of ADR-015 §9 (with ADR-016 F1), exposed so tests pin each one. Higher is better. */
export function scoreTerms(input: ScoreInput): ScoreTerms {
  const { macros, itemCount, totalServings, request } = input;
  const S = SCORING;
  const k = midpoint(macros.kcalLow, macros.kcalHigh);
  const p = midpoint(macros.proteinLow, macros.proteinHigh);
  const c = midpoint(macros.carbLow, macros.carbHigh);
  const f = midpoint(macros.fatLow, macros.fatHigh);
  const { Tk, Tc, rc, rf, dk, dc, df } = denominators(request);

  const Tp = Math.max(request.remainingProtein, 1);
  const proteinScore = S.proteinPoints * Math.min(p / Tp, S.proteinCap);

  const w = GOAL_WEIGHTS[request.goal];
  const kcalPenalty = w.over * (Math.max(0, k - Tk) / dk) + w.under * (Math.max(0, Tk - k) / Tk);

  const post = request.postWorkout === true;
  let carbPenalty = 0;
  let carbReward = 0;
  if (request.remainingCarb !== undefined) {
    carbPenalty = (post ? S.carbWeightPostWorkout : S.carbWeight) * (Math.max(0, c - rc) / dc);
    if (post) carbReward = S.carbReward * Math.min(c / Tc, 1);
  }
  let fatPenalty = 0;
  if (request.remainingFat !== undefined) {
    fatPenalty = S.fatWeight * (Math.max(0, f - rf) / df);
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

/* ----------------------------------------------------------- reasons -- */

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

/** What the filtered menu can provide, for `limited-menu` (the plate lacks it because the menu does). */
function menuProvides(part: MissingPart, menu: Parts): boolean {
  switch (part) {
    case 'staple': return menu.staple;
    case 'protein': return menu.strong || menu.weak;
    case 'strong-protein': return menu.strong;
    case 'vegetable': return menu.veg;
  }
}

/** The structure reasons, in a fixed order (ADR-016 §9). */
export function structureReasons(slot: MealSlot, structure: Structure, items: readonly PlateItem[], menu: Parts): PlateReason[] {
  const r: PlateReason[] = [{ code: 'meal-structure', kind: structure.kind }];
  if (slot !== 'snacks') {
    for (const it of items) {
      switch (it.component) {
        case 'staple':
          r.push({ code: 'staple-anchor', dishSlug: it.dishId });
          break;
        case 'complete':
          r.push({ code: 'staple-anchor', dishSlug: it.dishId }, { code: 'protein-anchor', dishSlug: it.dishId, strength: 'strong' });
          break;
        case 'protein':
          r.push({ code: 'protein-anchor', dishSlug: it.dishId, strength: 'strong' });
          break;
        case 'pulse-gravy':
        case 'dairy':
          r.push({ code: 'protein-anchor', dishSlug: it.dishId, strength: 'weak' });
          break;
        case 'veg':
          r.push({ code: 'vegetable-component', dishSlug: it.dishId });
          break;
        default:
          r.push({ code: 'supporting-side', dishSlug: it.dishId });
      }
    }
  }
  const lacking = structure.missing.filter((m) => !menuProvides(m, menu));
  if (lacking.length > 0) r.push({ code: 'limited-menu', missing: lacking });
  return r;
}

/** The plate's nutrition reasons, in a fixed order (ADR-015 §13). */
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
  return r;
}

function tailReasons(chosen: readonly MessDish[], macros: MacroRange, request: PlateRequest): PlateReason[] {
  const r: PlateReason[] = [];
  const top = [...chosen].sort(byDensityThenSlug)[0];
  if (top !== undefined) r.push({ code: 'top-protein-dish', dishSlug: top.id });
  if (request.postWorkout === true && request.remainingCarb !== undefined) {
    r.push({ code: 'post-workout-carbs', target: request.remainingCarb, low: macros.carbLow, high: macros.carbHigh });
  }
  const bySlug = [...chosen].sort((a, b) => (a.id < b.id ? -1 : 1));
  for (const d of bySlug) {
    const days = Math.min(request.varietyDays?.[d.id] ?? 0, SCORING.varietyMaxDays);
    if (days > 0) r.push({ code: 'repeat', dishSlug: d.id, days });
  }
  for (const d of bySlug) {
    if ((d.nutrition?.confidence ?? 'low') === 'low') r.push({ code: 'low-confidence-dish', dishSlug: d.id });
  }
  return r;
}

/* ------------------------------------------------------------ search -- */

export interface PlateSearch {
  readonly plates: PlateSuggestion[];
  readonly candidates: readonly MessDish[];
  /** The highest optimistic protein and kcal any structurally valid plate reaches (for the shortfall). */
  readonly menuMax: { readonly proteinHigh: number; readonly kcalHigh: number };
  /** What the filtered menu can provide. */
  readonly menuParts: Parts;
  /** The low-end kcal of the smallest plate of the best tier (null: no valid meal). */
  readonly smallestMealKcal: number | null;
}

const COMPONENT_INDEX = new Map<MealComponent, number>(MEAL_COMPONENTS.map((c, i) => [c, i]));
const EPS = 1e-9;
const [KL, KH, PL, PH, CL, CH, FL, FH] = [0, 1, 2, 3, 4, 5, 6, 7] as const;

/** The kcal floor of the best tier the menu offers: its cheapest minimal plate (ADR-016 §5). */
function bestAvailable(slot: MealSlot, groups: Map<MealComponent, number>, menu: Parts): { tier: number; floor: number } | null {
  const min = (cs: MealComponent[]): number => Math.min(...cs.map((c) => groups.get(c) ?? Infinity));
  for (let tier = 1; tier <= lastTier(slot); tier += 1) {
    const need = tierNeeds(slot, tier);
    if ((need.staple && !menu.staple) || (need.strong && !menu.strong) || (need.weak && !menu.weak) || (need.veg && !menu.veg)) continue;
    if (slot === 'snacks') {
      if (!menu.any) return null;
      return { tier, floor: Math.min(...[...groups.values()]) };
    }
    const extra = (need.weak ? min(['pulse-gravy', 'dairy']) : 0) + (need.veg ? min(['veg']) : 0);
    const separate = (need.staple ? min(['staple']) : 0) + (need.strong ? min(['protein']) : 0);
    const oneDish = need.staple || need.strong ? min(['complete']) : Infinity;
    const floor = Math.min(separate, oneDish) + extra;
    if (Number.isFinite(floor)) return { tier, floor };
  }
  return null;
}

/**
 * Bounded depth-first enumeration over whole servings of the candidates.
 * Structure first: every leaf is placed in its tier, and only the best plate
 * per anchor set (owner C3) is kept, so memory stays tiny. Running sums per
 * depth, no allocation at the leaves — under 100 ms on the widest real menu.
 */
export function searchPlates(request: PlateRequest, maxResults = 3): PlateSearch {
  const slot = request.meal.slot;
  const picked = selectCandidates(request);
  const candidates = picked.map((c) => c.dish);
  const menuParts = partsOf(picked.map((c) => c.component));
  const none = { plates: [], candidates, menuMax: { proteinHigh: 0, kcalHigh: 0 }, menuParts, smallestMealKcal: null };
  if (picked.length === 0) return none;

  const cheapest = new Map<MealComponent, number>();
  for (const c of picked) {
    const k = c.dish.nutrition?.macros.kcalLow ?? 0;
    cheapest.set(c.component, Math.min(cheapest.get(c.component) ?? Infinity, k));
  }
  const best = bestAvailable(slot, cheapest, menuParts);
  if (best === null) return none;

  const n = picked.length;
  const caps = picked.map((c) => servingCap(c.dish.name, c.component));
  const snaps = picked.map((c, i) => {
    const out: MacroRange[] = [ZERO_MACROS];
    for (let s = 1; s <= caps[i]!; s += 1) out.push(snapshotOf(c.dish, s));
    return out;
  });
  const compIdx = picked.map((c) => COMPONENT_INDEX.get(c.component)!);
  const dishCaps = PLATE_DISH_CAPS[slot];
  const compCap = MEAL_COMPONENTS.map((c) => dishCaps[c] ?? 0);
  const maxDishes = PLATE_MAX_DISHES[slot];
  let anchorBits = 0;
  const bit = picked.map((c) => (isAnchor(slot, c.component) ? 1 << anchorBits++ : 0));
  const variety = picked.map((c) => SCORING.varietyPerDay * Math.min(Math.max(request.varietyDays?.[c.dish.id] ?? 0, 0), SCORING.varietyMaxDays));
  const ceiling = Math.max(request.remainingKcal * SCORING.kcalCeilingFactor, SCORING.kcalCeilingFloor, best.floor * SCORING.kcalCeilingFactor);

  // Structure for every combination of the four parts (+ any), computed once.
  const structures: (Structure | null)[] = [];
  for (let b = 0; b < 32; b += 1) {
    structures.push(structureOf(slot, { staple: (b & 1) > 0, strong: (b & 2) > 0, weak: (b & 4) > 0, veg: (b & 8) > 0, any: (b & 16) > 0 }));
  }
  const iStaple = COMPONENT_INDEX.get('staple')!, iComplete = COMPONENT_INDEX.get('complete')!, iProtein = COMPONENT_INDEX.get('protein')!;
  const iPulse = COMPONENT_INDEX.get('pulse-gravy')!, iDairy = COMPONENT_INDEX.get('dairy')!, iVeg = COMPONENT_INDEX.get('veg')!;

  const S = SCORING;
  const { Tk, Tc, rc, rf, dk, dc, df } = denominators(request);
  const Tp = Math.max(request.remainingProtein, 1);
  const w = GOAL_WEIGHTS[request.goal];
  const post = request.postWorkout === true;
  const hasCarb = request.remainingCarb !== undefined;
  const hasFat = request.remainingFat !== undefined;

  const acc = new Float64Array((n + 1) * 8);
  const counts = new Int8Array(n);
  const compCount = new Int8Array(MEAL_COMPONENTS.length);
  interface Kept { score: number; counts: Int8Array; kcalLow: number; key?: string }
  const kept = new Map<number, Map<number, Kept>>(); // tier → anchor bits → best plate
  const smallest = new Map<number, number>(); // tier → smallest low-end kcal
  let maxProtein = 0;
  let maxKcal = 0;

  const keyOf = (c: Int8Array): string => {
    const parts: string[] = [];
    for (let i = 0; i < n; i += 1) if (c[i]! > 0) parts.push(`${picked[i]!.dish.id}x${c[i]}`);
    return parts.sort().join('|');
  };

  const leaf = (dishes: number, servings: number, mask: number, varietySum: number): void => {
    const b =
      (compCount[iStaple]! + compCount[iComplete]! > 0 ? 1 : 0) |
      (compCount[iProtein]! + compCount[iComplete]! > 0 ? 2 : 0) |
      (compCount[iPulse]! + compCount[iDairy]! > 0 ? 4 : 0) |
      (compCount[iVeg]! > 0 ? 8 : 0) |
      16;
    const structure = structures[b];
    if (structure === null || structure === undefined) return;
    const o = n * 8;
    maxProtein = Math.max(maxProtein, acc[o + PH]!);
    maxKcal = Math.max(maxKcal, acc[o + KH]!);
    const kcalLow = acc[o + KL]!;
    smallest.set(structure.tier, Math.min(smallest.get(structure.tier) ?? Infinity, kcalLow));

    const k = (acc[o + KL]! + acc[o + KH]!) / 2;
    const p = (acc[o + PL]! + acc[o + PH]!) / 2;
    const c = (acc[o + CL]! + acc[o + CH]!) / 2;
    const f = (acc[o + FL]! + acc[o + FH]!) / 2;
    let score = S.proteinPoints * Math.min(p / Tp, S.proteinCap);
    score -= w.over * (Math.max(0, k - Tk) / dk) + w.under * (Math.max(0, Tk - k) / Tk);
    if (hasCarb) {
      score -= (post ? S.carbWeightPostWorkout : S.carbWeight) * (Math.max(0, c - rc) / dc);
      if (post) score += S.carbReward * Math.min(c / Tc, 1);
    }
    if (hasFat) score -= S.fatWeight * (Math.max(0, f - rf) / df);
    score -= Math.abs(dishes - S.shapeTargetItems) * S.shapePerItem + Math.max(0, servings - S.shapeServingsFree) * S.shapePerServing;
    score -= varietySum;

    let tierMap = kept.get(structure.tier);
    if (tierMap === undefined) kept.set(structure.tier, (tierMap = new Map()));
    const prev = tierMap.get(mask);
    if (prev === undefined || score > prev.score + EPS) {
      tierMap.set(mask, { score, counts: counts.slice(), kcalLow });
    } else if (Math.abs(score - prev.score) <= EPS) {
      const key = keyOf(counts);
      prev.key ??= keyOf(prev.counts);
      if (key < prev.key) tierMap.set(mask, { score, counts: counts.slice(), kcalLow, key });
    }
  };

  const walk = (i: number, dishes: number, servings: number, mask: number, varietySum: number): void => {
    if (i === n) {
      if (dishes > 0) leaf(dishes, servings, mask, varietySum);
      return;
    }
    const base = i * 8;
    const next = (i + 1) * 8;
    // 0 servings of this dish
    for (let j = 0; j < 8; j += 1) acc[next + j] = acc[base + j]!;
    walk(i + 1, dishes, servings, mask, varietySum);
    if (dishes >= maxDishes) return;
    const ci = compIdx[i]!;
    if (compCount[ci]! >= compCap[ci]!) return;
    compCount[ci]! += 1;
    for (let s = 1; s <= caps[i]!; s += 1) {
      if (servings + s > S.maxServings) break;
      const m = snaps[i]![s]!;
      if (acc[base + KL]! + m.kcalLow > ceiling) break;
      acc[next + KL] = acc[base + KL]! + m.kcalLow;
      acc[next + KH] = acc[base + KH]! + m.kcalHigh;
      acc[next + PL] = acc[base + PL]! + m.proteinLow;
      acc[next + PH] = acc[base + PH]! + m.proteinHigh;
      acc[next + CL] = acc[base + CL]! + m.carbLow;
      acc[next + CH] = acc[base + CH]! + m.carbHigh;
      acc[next + FL] = acc[base + FL]! + m.fatLow;
      acc[next + FH] = acc[base + FH]! + m.fatHigh;
      counts[i] = s;
      walk(i + 1, dishes + 1, servings + s, mask | bit[i]!, varietySum + variety[i]!);
    }
    counts[i] = 0;
    compCount[ci]! -= 1;
  };
  walk(0, 0, 0, 0, 0);

  const tiers = [...kept.keys()].sort((a, b) => a - b);
  const bestTier = tiers[0];
  if (bestTier === undefined) return none;

  // Best tier, score descending, plate key ascending; then owner C3.
  const ranked = [...kept.get(bestTier)!.entries()]
    .map(([mask, k]) => ({ mask, ...k, key: k.key ?? keyOf(k.counts) }))
    .sort((a, b) => (Math.abs(b.score - a.score) > EPS ? b.score - a.score : a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
  const chosen: typeof ranked = [];
  for (const plate of ranked) {
    if (chosen.length >= maxResults) break;
    // Meaningfully different: never the same anchors, never a subset or superset of a chosen plate's.
    if (chosen.some((c) => (plate.mask & c.mask) === plate.mask || (plate.mask & c.mask) === c.mask)) continue;
    chosen.push(plate);
  }

  const plates = chosen.map((plate): PlateSuggestion => {
    const items: PlateItem[] = [];
    const dishes: MessDish[] = [];
    const parts: MacroRange[] = [];
    for (let i = 0; i < n; i += 1) {
      const servings = plate.counts[i]!;
      const cand = picked[i]!;
      const nut = cand.dish.nutrition;
      if (servings === 0 || nut === null) continue;
      const m = snaps[i]![servings]!;
      parts.push(m);
      dishes.push(cand.dish);
      items.push({
        dishId: cand.dish.id,
        name: cand.dish.name,
        servings,
        servingLabel: nut.servingLabel,
        servingGrams: nut.servingGrams,
        macros: m,
        confidence: nut.confidence,
        component: cand.component,
      });
    }
    const macros = sumMacros(parts);
    const structure = structureOf(slot, partsOf(items.map((it) => it.component)))!;
    return {
      items,
      macros,
      structure,
      confidence: worstConfidence(dishes),
      score: plate.score,
      reasons: [
        ...plateReasons(macros, dishes, request),
        ...structureReasons(slot, structure, items, menuParts),
        ...tailReasons(dishes, macros, request),
      ],
    };
  });

  const smallestKcal = smallest.get(bestTier);
  return {
    plates,
    candidates,
    menuMax: { proteinHigh: round1(maxProtein), kcalHigh: Math.round(maxKcal) },
    menuParts,
    smallestMealKcal: smallestKcal === undefined ? null : Math.round(smallestKcal),
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
