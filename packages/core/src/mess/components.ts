/**
 * Meal components (Phase 10 Amendment A, ADR-016; owner C1–C6).
 *
 * FITOS recommends a MEAL, not the nutritionally cheapest dish. A plate is
 * judged first by its structure — a staple, a protein, a vegetable — and only
 * then by nutrition. This file says what part of a meal each dish is, which
 * parts each meal may use, and what structure a set of parts makes.
 *
 * Separate from the Phase 9 `role` on purpose: `role` drives the accepted
 * Phase 9 estimator and the `/mess/menu` contract and stays untouched.
 *
 * Classification is by ordered, word-boundary term rules on the dish name
 * plus its diet class — term FAMILIES ("… Sambar", "… Poriyal", "… Soup",
 * "… Juice"), no per-dish lists and no nutrition thresholds — so it
 * generalises to menus it has never seen. An unrecognised name is `other`
 * and never goes on a plate.
 */
import type { DietClass, MealSlot } from './types.js';

export const MEAL_COMPONENTS = [
  'staple', 'complete', 'protein', 'pulse-gravy', 'dairy', 'veg', 'soup', 'fruit',
  'snack', 'dessert', 'crisp', 'beverage', 'condiment', 'other',
] as const;
export type MealComponent = (typeof MEAL_COMPONENTS)[number];

function norm(name: string): string {
  return ` ${name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim()} `;
}
function has(n: string, terms: readonly string[]): boolean {
  return terms.some((t) => n.includes(` ${t} `));
}

/* ------------------------------------------------------------- terms -- */

const STAPLE = [
  'rice', 'roti', 'chapathi', 'chapati', 'phulka', 'pulka', 'poori', 'puri', 'paratha', 'parota', 'naan',
  'bhatura', 'dosa', 'dosai', 'idly', 'idli', 'uthappam', 'utappam', 'pongal', 'upma', 'semiya', 'vermicelli',
  'poha', 'kitchadi', 'kichidi', 'khichdi', 'bread', 'pav', 'paav', 'pulav', 'pulao', 'biryani', 'biriyani',
  'bath', 'pasta', 'noodles', 'chow mein', 'idiyappam', 'idiappam',
] as const;
/** Vegetarian protein anchors: pulses eaten as the protein dish, paneer, soya. */
const STRONG_PROTEIN = [
  'paneer', 'panneer', 'tofu', 'soya', 'meal maker', 'dal', 'dhal', 'channa', 'chana', 'chenna', 'chole',
  'rajma', 'chickpea', 'sprouts', 'sprout', 'sprouted', 'green gram', 'moong', 'masoor', 'toor', 'urad',
  'sundal', 'lentil', 'cowpea', 'cow peas', 'payaru',
] as const;
/** A staple dish that also carries its protein. */
const COMPLETE_VEG = ['chole', 'meal maker'] as const;
const DESSERT = [
  'gulab jamun', 'jamun', 'jamoon', 'jalebi', 'halwa', 'laddu', 'ladoo', 'kheer', 'payasam', 'rasgulla',
  'rasagulla', 'rasamalai', 'peda', 'mysore pak', 'mysorepaku', 'badusha', 'badhusa', 'cake', 'brownie',
  'donut', 'ice cream', 'pudding', 'custard', 'shahi tukra', 'suzhiyam', 'suryakala', 'chocos', 'corn flakes',
] as const;
const DAIRY = ['curd', 'dahi', 'raitha', 'raita', 'butter milk', 'buttermilk', 'lassi'] as const;
const BEVERAGE = [
  'juice', 'tea', 'coffee', 'milk', 'milkshake', 'milk shake', 'sarbat', 'nimbu', 'mint lemon', 'lemonade',
] as const;
const SOUP = ['rasam', 'soup'] as const;
const CONDIMENT = ['chutney', 'pickle', 'sauce', 'jam', 'butter', 'thokku', 'podi'] as const;
const PULSE_GRAVY = ['sambar', 'sambhar', 'kootu', 'kuttu', 'kadhi', 'kadi'] as const;
const CRISP = ['appalam', 'papad', 'fryums', 'chips'] as const;
const SNACK = [
  'samosa', 'puff', 'puffs', 'cutlet', 'bonda', 'bajji', 'vada', 'vadai', 'sandwich', 'chaat', 'chat', 'fries',
  'roll', 'pizza', 'peanuts', 'corn', 'pakora', 'pakoda',
] as const;
const FRUIT = ['banana', 'papaya', 'watermelon', 'water melon', 'musk melon', 'grapes', 'fruit', 'fruits'] as const;
const VEG = [
  'poriyal', 'sabji', 'subji', 'sabzi', 'subzi', 'kurma', 'korma', 'manchurian', 'jalfrezi', 'jal frezi',
  'kulambu', 'kozhambu', 'kuzhambu', 'gravy', 'fry', 'masala', 'salad', 'kofta', 'podimas', 'foogath', 'aloo',
  'gobi', 'bhindi', 'bindi', 'brinjal', 'peas', 'stew', 'salna', 'kolhapuri', 'kholapuri', 'pyaza', 'capsicum',
  'cabbage', 'carrot', 'beetroot', 'keerai', '65', 'mushroom',
] as const;

/**
 * Compound names whose parts would mislead the families below. Checked
 * first: "Curd Rice" is rice, not curd; "Vada Curry" is a gravy, not a snack.
 */
const COMPOUNDS: readonly (readonly [MealComponent, readonly string[]])[] = [
  ['staple', ['curd rice', 'podi dosa', 'podi idly', 'podi rice']],
  ['veg', ['vada curry', 'raw banana fry', 'baby corn']],
  ['snack', ['spring roll', 'pani puri']],
];

/**
 * The meal component of a dish. Order matters and is fixed (tests pin it):
 * compounds → complete (a staple with meat/egg or with chole / meal maker) →
 * dessert → dairy → beverage → soup → meat/egg protein → pulse/paneer protein
 * → condiment → pulse gravy → crisp → staple → snack → fruit → veg → other.
 */
export function classifyComponent(name: string, diet: DietClass): MealComponent {
  const n = norm(name);
  for (const [component, terms] of COMPOUNDS) if (has(n, terms)) return component;
  const animal = diet === 'nonveg' || diet === 'egg';
  if (has(n, STAPLE) && (animal || has(n, COMPLETE_VEG))) return 'complete';
  if (has(n, DESSERT)) return 'dessert';
  if (has(n, DAIRY)) return 'dairy';
  if (has(n, BEVERAGE)) return 'beverage';
  if (has(n, SOUP)) return 'soup';
  if (animal) return 'protein';
  if (has(n, STRONG_PROTEIN)) return 'protein';
  if (has(n, CONDIMENT)) return 'condiment';
  if (has(n, PULSE_GRAVY)) return 'pulse-gravy';
  if (has(n, CRISP)) return 'crisp';
  if (has(n, STAPLE)) return 'staple';
  if (has(n, SNACK)) return 'snack';
  if (has(n, FRUIT)) return 'fruit';
  if (has(n, VEG)) return 'veg';
  return 'other';
}

/* ---------------------------------------------------- what may go where -- */

/** Owner C5 (no drinks anywhere) and C6 (no dessert or crisp at lunch/dinner). Pinned by tests. */
export const PLATE_COMPONENTS: Readonly<Record<MealSlot, ReadonlySet<MealComponent>>> = {
  breakfast: new Set<MealComponent>(['staple', 'complete', 'protein', 'pulse-gravy', 'dairy', 'veg', 'fruit', 'snack']),
  lunch: new Set<MealComponent>(['staple', 'complete', 'protein', 'pulse-gravy', 'dairy', 'veg', 'soup', 'fruit']),
  snacks: new Set<MealComponent>(['snack', 'dessert', 'fruit', 'dairy', 'protein', 'staple', 'complete', 'crisp']),
  dinner: new Set<MealComponent>(['staple', 'complete', 'protein', 'pulse-gravy', 'dairy', 'veg', 'soup', 'fruit']),
};

/** Per-component candidates, each group by protein density (slug breaks ties). A staple is always a candidate. */
export const COMPONENT_CANDIDATES: Readonly<Record<MealComponent, number>> = {
  staple: 3, complete: 2, protein: 3, 'pulse-gravy': 2, veg: 2, dairy: 1, soup: 1, fruit: 1,
  snack: 2, dessert: 2, crisp: 1, beverage: 0, condiment: 0, other: 0,
};

const MAIN_MEAL_CAPS: Readonly<Partial<Record<MealComponent, number>>> = {
  staple: 2, complete: 1, protein: 2, 'pulse-gravy': 1, dairy: 1, veg: 2, soup: 1, fruit: 1,
};
/** Distinct dishes of each component on one plate. */
export const PLATE_DISH_CAPS: Readonly<Record<MealSlot, Readonly<Partial<Record<MealComponent, number>>>>> = {
  breakfast: { staple: 2, complete: 1, protein: 2, 'pulse-gravy': 1, dairy: 1, veg: 1, fruit: 1, snack: 1 },
  lunch: MAIN_MEAL_CAPS,
  snacks: { snack: 2, dessert: 1, fruit: 1, dairy: 1, protein: 1, staple: 1, complete: 1, crisp: 1 },
  dinner: MAIN_MEAL_CAPS,
};
/** Distinct dishes on one plate. */
export const PLATE_MAX_DISHES: Readonly<Record<MealSlot, number>> = { breakfast: 4, lunch: 5, snacks: 2, dinner: 5 };

const ONE_POT = [
  'rice', 'pulao', 'pulav', 'biryani', 'biriyani', 'bath', 'pongal', 'upma', 'poha', 'kitchadi', 'kichidi',
  'khichdi', 'pasta', 'noodles', 'chow mein', 'semiya', 'vermicelli',
] as const;

/** Whole servings of one dish on a plate. Realistic, never inflated. */
export function servingCap(name: string, component: MealComponent): number {
  switch (component) {
    case 'staple':
      return has(norm(name), ONE_POT) ? 2 : 3; // 3 rotis is normal; 3 plates of rice is not
    case 'protein':
    case 'pulse-gravy':
      return 2;
    default:
      return 1;
  }
}

/* ----------------------------------------------------------- structure -- */

export const STRUCTURE_KINDS = ['complete-meal', 'meal', 'meal-weak-protein', 'limited', 'limited-no-staple', 'snack'] as const;
export type StructureKind = (typeof STRUCTURE_KINDS)[number];
export const MISSING_PARTS = ['staple', 'protein', 'strong-protein', 'vegetable'] as const;
export type MissingPart = (typeof MISSING_PARTS)[number];

export interface Structure {
  /** 1 is best. Plates rank by tier before score. */
  readonly tier: number;
  readonly kind: StructureKind;
  /** What this plate lacks for a complete meal. */
  readonly missing: readonly MissingPart[];
}

/** What a set of components provides. */
export interface Parts {
  readonly staple: boolean; // staple or complete
  readonly strong: boolean; // protein or complete
  readonly weak: boolean; // pulse-gravy or dairy
  readonly veg: boolean;
  readonly any: boolean;
}

export function partsOf(components: Iterable<MealComponent>): Parts {
  let staple = false, strong = false, weak = false, veg = false, any = false;
  for (const c of components) {
    any = true;
    if (c === 'staple' || c === 'complete') staple = true;
    if (c === 'protein' || c === 'complete') strong = true;
    if (c === 'pulse-gravy' || c === 'dairy') weak = true;
    if (c === 'veg') veg = true;
  }
  return { staple, strong, weak, veg, any };
}

/**
 * The structure a plate's parts make at a meal, or null when they are not a
 * meal at all (never returned). Owner tiers, pinned by tests:
 *
 *   lunch / dinner  T1 staple+strong+veg  T2 staple+strong  T3 staple+weak
 *                   T4 staple only (limited)  T5 strong, no staple (limited)
 *   breakfast       T1 staple+strong  T2 staple+weak  T3 staple only (limited)
 *                   T4 strong, no staple (limited)
 *   snacks          T1 any substantive item — a snack, never called a meal
 */
export function structureOf(slot: MealSlot, p: Parts): Structure | null {
  const noVeg: MissingPart[] = p.veg ? [] : ['vegetable'];
  if (slot === 'snacks') return p.any ? { tier: 1, kind: 'snack', missing: [] } : null;
  if (slot === 'breakfast') {
    if (p.staple && p.strong) return { tier: 1, kind: 'complete-meal', missing: [] };
    if (p.staple && p.weak) return { tier: 2, kind: 'meal-weak-protein', missing: ['strong-protein'] };
    if (p.staple) return { tier: 3, kind: 'limited', missing: ['protein'] };
    if (p.strong) return { tier: 4, kind: 'limited-no-staple', missing: ['staple'] };
    return null;
  }
  if (p.staple && p.strong && p.veg) return { tier: 1, kind: 'complete-meal', missing: [] };
  if (p.staple && p.strong) return { tier: 2, kind: 'meal', missing: ['vegetable'] };
  if (p.staple && p.weak) return { tier: 3, kind: 'meal-weak-protein', missing: ['strong-protein', ...noVeg] };
  if (p.staple) return { tier: 4, kind: 'limited', missing: ['protein', ...noVeg] };
  if (p.strong) return { tier: 5, kind: 'limited-no-staple', missing: ['staple', ...noVeg] };
  return null;
}

/** The parts a tier needs, for the kcal floor (ADR-016 §5). */
export function tierNeeds(slot: MealSlot, tier: number): { staple: boolean; strong: boolean; weak: boolean; veg: boolean } {
  const n = (staple: boolean, strong: boolean, weak: boolean, veg: boolean) => ({ staple, strong, weak, veg });
  if (slot === 'snacks') return n(false, false, false, false);
  if (slot === 'breakfast') return [n(true, true, false, false), n(true, false, true, false), n(true, false, false, false), n(false, true, false, false)][tier - 1]!;
  return [n(true, true, false, true), n(true, true, false, false), n(true, false, true, false), n(true, false, false, false), n(false, true, false, false)][tier - 1]!;
}

/** The last tier of a meal. */
export function lastTier(slot: MealSlot): number {
  return slot === 'snacks' ? 1 : slot === 'breakfast' ? 4 : 5;
}

/** Anchors decide whether two plates are meaningfully different (owner C3). */
export function isAnchor(slot: MealSlot, component: MealComponent): boolean {
  if (slot === 'snacks') return true; // every snack item is the snack
  return component === 'staple' || component === 'complete' || component === 'protein';
}
