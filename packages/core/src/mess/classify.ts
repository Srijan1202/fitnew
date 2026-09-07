/**
 * Dish classification: dietary class and plate role.
 *
 * Matching is word-boundary based, never substring, so "meal maker" does not
 * match "meat" and "eggless" would not match "egg".
 *
 * Rule order matters. The list is evaluated top-down and the first match wins;
 * more specific patterns are placed above more general ones ("butter milk"
 * before "milk", "paneer butter masala" before "masala").
 */

import type { DietClass, DishRole } from './types.js';

function has(name: string, terms: readonly string[]): boolean {
  const haystack = ` ${name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ')} `;
  return terms.some((term) => haystack.includes(` ${term} `));
}

/* ------------------------------------------------------------------ diet -- */

const MEAT_TERMS = [
  'chicken', 'mutton', 'fish', 'prawn', 'prawns', 'meat', 'keema', 'kheema',
  'lamb', 'beef', 'pork', 'crab', 'squid', 'tandoori chicken',
] as const;

const EGG_TERMS = [
  'egg', 'eggs', 'omelette', 'omlette', 'omelet', 'burji', 'bhurji',
  'french toast', 'half boil', 'anda',
] as const;

/**
 * Dishes whose names contain a meat-like token but are vegetarian.
 * "Meal Maker" is textured soya; "Mock" anything; "Veg Manchurian".
 * Kept explicit so the safe path is auditable rather than emergent.
 */
const VEG_FALSE_POSITIVES = ['meal maker', 'mock', 'soya chunks'] as const;

/**
 * Affirmatively vegetarian dishes.
 *
 * Without this list, a vegetarian in the non-veg or special mess gets an empty
 * recommendation: every unlabelled dish falls through to `unknown`, and
 * `unknown` is excluded from vegetarian plates by design. Recognising rice,
 * dal, curd and roti as vegetarian is what makes the fail-safe survivable.
 *
 * Order matters — this runs AFTER the meat and egg checks, so "Chicken Biryani"
 * and "Egg Fried Rice" are already classified before "rice" is ever consulted.
 * Genuinely ambiguous names (e.g. "Salna", which may be meat-based) are
 * deliberately absent and stay `unknown`.
 */
const KNOWN_VEG_TERMS = [
  // staples
  'rice', 'roti', 'chapathi', 'chapati', 'phulka', 'pulka', 'poori', 'puri', 'paratha',
  'parota', 'naan', 'bhatura', 'dosa', 'dosai', 'idly', 'idli', 'uthappam', 'pongal',
  'upma', 'semiya', 'poha', 'kitchadi', 'kichidi', 'pulav', 'pulao', 'bath', 'bread',
  'pav', 'paav',
  // legumes
  'dal', 'dhal', 'sambar', 'sambhar', 'rasam', 'channa', 'chana', 'chole', 'rajma',
  'kootu', 'kuttu', 'sprouts', 'sprout', 'moong', 'masoor', 'toor', 'urad', 'chickpea',
  'green gram', 'lentil', 'kadhi', 'kadi',
  // dairy
  'curd', 'dahi', 'butter milk', 'buttermilk', 'lassi', 'raitha', 'raita', 'paneer',
  'panneer', 'cheese', 'milk',
  // vegetables
  'poriyal', 'sabji', 'subji', 'sabzi', 'manchurian', 'jalfrezi', 'jal frezi', 'kurma',
  'korma', 'kofta', 'kolhapuri', 'kholapuri', 'aloo', 'potato', 'gobi', 'cabbage',
  'beetroot', 'beet root', 'carrot', 'keerai', 'capsicum', 'bhindi', 'bindi', 'brinjal',
  'baigan', 'peas', 'mutter', 'muttar', 'foogath', 'podimas', 'salad', 'kulambu',
  'kozhambu', 'kuzhambu',
  // fruit, sweets, snacks, drinks
  'banana', 'papaya', 'water melon', 'watermelon', 'musk melon', 'grapes', 'fruit',
  'fruits', 'jamun', 'jalebi', 'halwa', 'laddu', 'ladoo', 'kheer', 'payasam', 'rasgulla',
  'rasamalai', 'ice cream', 'vada', 'vadai', 'bonda', 'bajji', 'pakoda', 'pakora',
  'samosa', 'appalam', 'papad', 'fryums', 'chips', 'chutney', 'pickle', 'tea', 'coffee',
  'juice', 'sundal', 'peanuts',
] as const;

export function classifyDiet(name: string): DietClass {
  if (has(name, VEG_FALSE_POSITIVES)) return 'veg';
  if (has(name, MEAT_TERMS)) return 'nonveg';
  if (has(name, EGG_TERMS)) return 'egg';
  if (has(name, KNOWN_VEG_TERMS)) return 'veg';
  return 'unknown';
}

/* ------------------------------------------------------------------ role -- */

interface RoleRule {
  readonly role: DishRole;
  readonly terms: readonly string[];
}

/** Evaluated in order; first match wins. */
const ROLE_RULES: readonly RoleRule[] = [
  // Dairy before beverage so "butter milk" beats "milk".
  { role: 'dairy', terms: ['curd', 'dahi', 'butter milk', 'buttermilk', 'raitha', 'raita', 'lassi', 'cheese', 'paneer tikka'] },

  // Explicit vegetarian protein mains.
  { role: 'protein', terms: ['paneer', 'tofu', 'meal maker', 'soya'] },

  // Sweets before fruit ("fruit custard" is a dessert) and before fried
  // ("bread halwa" is not fried food).
  { role: 'sweet', terms: [
    'gulab jamun', 'jamun', 'jalebi', 'ice cream', 'halwa', 'laddu', 'ladoo', 'kheer',
    'payasam', 'rasgulla', 'rasamalai', 'brownie', 'cake', 'donut', 'mysore pak',
    'badhusa', 'suryakala', 'peda', 'custard', 'shahi tukra', 'sweet', 'chocos',
    'corn flakes', 'suzhiyam',
  ] },

  { role: 'fruit', terms: [
    'banana', 'papaya', 'water melon', 'watermelon', 'musk melon', 'grapes',
    'seasonal fruit', 'cut fruits', 'fruit salad', 'fresh fruits', 'fruit', 'fruits',
  ] },

  { role: 'beverage', terms: [
    'tea', 'coffee', 'milk', 'cold milk', 'juice', 'milk shake', 'milkshake',
    'sarbat', 'rose milk', 'badam milk', 'nimbu', 'ice lemon tea',
  ] },

  { role: 'condiment', terms: [
    'chutney', 'pickle', 'sauce', 'jam', 'butter', 'podi', 'thokku', 'masala papad',
  ] },

  // Fried / crisp accompaniments before staples so "wheel chips" isn't a staple.
  { role: 'fried', terms: [
    'vada', 'vadai', 'bonda', 'bajji', 'pakoda', 'pakora', 'samosa', 'puff', 'puffs',
    'cutlet', 'chips', 'fryums', 'appalam', 'papad', 'french fries', 'spring roll',
    'roll', 'pizza', 'sandwich', 'pani puri', 'paani poori', 'chat', 'sundal', 'peanuts',
  ] },

  // Legumes: protein-bearing but carbohydrate-dominant.
  { role: 'legume', terms: [
    'dal', 'dhal', 'sambar', 'sambhar', 'rasam', 'channa', 'chana', 'chole', 'rajma',
    'kootu', 'kuttu', 'sprout', 'sprouts', 'moong', 'masoor', 'toor', 'urad',
    'green gram', 'chickpea', 'cow peas', 'black eye peas', 'lentil', 'kadhi', 'kadi',
  ] },

  { role: 'staple', terms: [
    'rice', 'roti', 'chapathi', 'chapati', 'phulka', 'pulka', 'poori', 'puri',
    'paratha', 'parota', 'naan', 'bhatura', 'dosa', 'dosai', 'idly', 'idli',
    'uthappam', 'utappam', 'pongal', 'upma', 'semiya', 'poha', 'kitchadi', 'kichidi',
    'khichdi', 'bread', 'pav', 'paav', 'pulav', 'pulao', 'biryani', 'biriyani',
    'bath', 'pasta', 'noodles', 'chow mein',
  ] },

  { role: 'vegetable', terms: [
    'poriyal', 'sabji', 'subji', 'sabzi', 'kurma', 'korma', 'manchurian', 'jalfrezi',
    'jal frezi', 'kulambu', 'kozhambu', 'kuzhambu', 'gravy', 'brinjal', 'baigan',
    'aloo', 'potato', 'gobi', 'cabbage', 'beetroot', 'beet root', 'carrot', 'keerai',
    'capsicum', 'bhindi', 'bindi', 'okra', 'mutter', 'muttar', 'peas', 'salad',
    'foogath', 'podimas', 'kofta', 'soup', 'fry', 'masala',
  ] },
];

export function classifyRole(name: string, diet: DietClass): DishRole {
  // Anything containing meat or egg is a protein source regardless of form.
  if (diet === 'nonveg' || diet === 'egg') return 'protein';
  for (const rule of ROLE_RULES) {
    if (has(name, rule.terms)) return rule.role;
  }
  return 'other';
}

/* --------------------------------------------------------------- ambient -- */

/**
 * Items printed against every single meal in the special and non-veg messes
 * (bread, butter, jam, tea, coffee, milk). They are real and loggable, but they
 * are not "what's for dinner" and must not dominate the menu UI.
 */
const AMBIENT_TERMS = [
  'bread', 'butter', 'jam', 'tea', 'coffee', 'milk', 'cold milk', 'corn flakes',
  'chocos', 'sauce', 'pickle',
] as const;

export function isAmbient(name: string): boolean {
  return has(name, AMBIENT_TERMS);
}
