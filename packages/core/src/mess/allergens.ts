/**
 * Allergen status of a mess dish, from its name (Phase 10, owner D1/D2;
 * ADR-015). SAFETY-CRITICAL — read before editing.
 *
 * A dish is allowed for an allergy only when it is CONFIRMED FREE of that
 * allergen. `contains`, `likely` and `unknown` are all excluded, and severity
 * never relaxes this. Mess menus publish names, not ingredients, so "free"
 * is a positive, curated statement about a dish's usual recipe:
 *
 *   1. `contains` — a CONTAINS term appears (whole words);
 *   2. `likely`   — a LIKELY term appears (whole words);
 *   3. `free`     — the normalised name is EXACTLY one of FREE[allergen]
 *                   (never a word inside a longer name: "rice" does not vouch
 *                   for "egg fried rice"); for fish and shellfish, the dish is
 *                   classified `veg` or `egg`;
 *   4. `unknown`  — anything else.
 *
 * CONTAINS and LIKELY only choose the explanation; safety rests on FREE.
 *
 * Cooking fat: FITOS does not know a mess's cooking oil or fat (groundnut,
 * gingelly/sesame, soybean oil, ghee, butter) or tempering (mustard seed), so
 * for peanut, sesame, soy, mustard and milk, FREE lists only dishes made
 * without added fat or tempering. No list can rule out cross-contact in a
 * shared kitchen; the app says so.
 */
import type { DietClass } from './types.js';

/** Mirrors `@fitos/contracts` ALLERGENS (an API test keeps them equal). */
export const ALLERGENS = [
  'peanut', 'tree-nut', 'milk', 'egg', 'soy', 'wheat', 'fish', 'shellfish', 'sesame', 'mustard',
] as const;
export type Allergen = (typeof ALLERGENS)[number];

export type AllergenStatus = 'contains' | 'likely' | 'free' | 'unknown';

/** Lower case, "(2 Nos)" dropped, anything but a–z / 0–9 becomes one space. */
export function normaliseDishName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\([^)]*\)/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function hasTerm(normalised: string, terms: readonly string[]): boolean {
  const haystack = ` ${normalised} `;
  return terms.some((t) => haystack.includes(` ${t} `));
}

// ---------------------------------------------------------------- FREE --

const PLAIN_RICE = ['white rice', 'steamed rice', 'plain rice'];
const STEAMED = ['idly', 'idli'];
const FRUIT = ['seasonal fruit', 'fruit', 'fruits', 'banana', 'papaya', 'watermelon', 'water melon', 'musk melon', 'grapes'];
const EGG_PLAIN = ['boiled egg', 'boiled eggs'];
const DAIRY_PLAIN = ['curd', 'cup curd', 'loose curd', 'dahi', 'milk', 'cold milk'];
const HOT_DRINKS = ['tea', 'coffee'];
const DRY_BREAD = ['phulka', 'pulka'];
const FLATBREAD = ['phulka', 'pulka', 'roti', 'chapathi', 'chapati'];
const DALS = [
  'dal', 'dhal', 'toor dal', 'toor dhal', 'dal tadka', 'dhal tadka', 'dal fry', 'dhal fry',
  'yellow dhal', 'mix dhal', 'sambar', 'rasam',
];
const NO_FAT = [...PLAIN_RICE, ...STEAMED, ...FRUIT, ...EGG_PLAIN];
const FAT_FREE_EVERYDAY = [...NO_FAT, ...DAIRY_PLAIN, ...HOT_DRINKS, ...DRY_BREAD];

/** Exact normalised names confirmed free. Fish and shellfish use the diet rule instead. */
export const FREE: Readonly<Record<Exclude<Allergen, 'fish' | 'shellfish'>, ReadonlySet<string>>> = {
  peanut: new Set(FAT_FREE_EVERYDAY),
  sesame: new Set(FAT_FREE_EVERYDAY),
  soy: new Set(FAT_FREE_EVERYDAY),
  mustard: new Set(FAT_FREE_EVERYDAY),
  milk: new Set(NO_FAT),
  'tree-nut': new Set([
    ...NO_FAT, ...DAIRY_PLAIN, ...HOT_DRINKS, ...FLATBREAD, ...DALS,
    'butter milk', 'dosa', 'plain dosa', 'set dosa', 'poriyal', 'omelette',
  ]),
  egg: new Set([
    ...PLAIN_RICE, ...STEAMED, ...FRUIT, ...DAIRY_PLAIN, ...HOT_DRINKS, ...FLATBREAD, ...DALS,
    'butter milk', 'dosa', 'plain dosa', 'set dosa', 'poriyal', 'curd rice',
  ]),
  // Sambar, rasam and dal are not free: compounded asafoetida often carries wheat flour.
  wheat: new Set([...PLAIN_RICE, ...STEAMED, ...FRUIT, ...EGG_PLAIN, ...DAIRY_PLAIN, ...HOT_DRINKS]),
};

// ------------------------------------------------- CONTAINS / LIKELY --

export const CONTAINS: Readonly<Record<Allergen, readonly string[]>> = {
  peanut: ['peanut', 'peanuts', 'groundnut', 'groundnuts', 'chikki'],
  'tree-nut': ['cashew', 'cashews', 'kaju', 'almond', 'almonds', 'badam', 'pista', 'pistachio', 'walnut', 'dry fruit'],
  milk: [
    'milk', 'curd', 'dahi', 'butter', 'ghee', 'paneer', 'panneer', 'cheese', 'cream', 'lassi', 'raitha', 'raita',
    'kheer', 'payasam', 'custard', 'ice cream', 'milk shake', 'milkshake', 'tea', 'coffee', 'kadhi', 'kadi', 'moore',
    'rasgulla', 'rasagulla', 'rasamalai', 'peda', 'kova', 'malai', 'makhani', 'makani', 'butter milk', 'buttermilk',
  ],
  egg: ['egg', 'eggs', 'omelette', 'omlette', 'bhurji', 'burji', 'french toast', 'anda'],
  wheat: [
    'roti', 'chapathi', 'chapati', 'phulka', 'pulka', 'paratha', 'parota', 'poori', 'puri', 'naan', 'bhatura', 'bread',
    'pav', 'paav', 'bun', 'samosa', 'puff', 'puffs', 'pasta', 'noodles', 'semiya', 'vermicelli', 'upma', 'rava', 'suji',
    'sooji', 'kesari', 'cake', 'brownie', 'donut', 'biscuit', 'cutlet', 'french toast', 'jalebi', 'badusha',
  ],
  soy: ['soy', 'soya', 'meal maker', 'tofu'],
  fish: ['fish', 'anchovy', 'tuna'],
  shellfish: ['prawn', 'prawns', 'shrimp', 'crab', 'lobster', 'squid', 'clam', 'mussel', 'oyster'],
  sesame: ['sesame', 'til', 'gingelly', 'ellu'],
  mustard: ['mustard', 'kasundi'],
};

export const LIKELY: Readonly<Record<Allergen, readonly string[]>> = {
  peanut: [
    'chutney', 'podi', 'poha', 'chaat', 'chat', 'sundal', 'fry', 'fried', 'vada', 'vadai', 'bajji', 'bonda', 'pakoda',
    'pakora', 'samosa', 'puff', 'puffs', 'cutlet', 'chips', 'fryums', 'appalam', 'papad', 'mixture',
  ],
  'tree-nut': [
    'biryani', 'biriyani', 'pulao', 'pulav', 'ghee rice', 'kurma', 'korma', 'shahi', 'makhani', 'makani',
    'butter masala', 'kofta', 'payasam', 'kheer', 'halwa', 'laddu', 'ladoo', 'kesari', 'custard', 'pudding',
    'ice cream', 'milk shake', 'milkshake', 'mysore pak', 'mysorepaku', 'badusha', 'jamun', 'cake',
  ],
  milk: [
    'halwa', 'laddu', 'ladoo', 'mysore pak', 'mysorepaku', 'badusha', 'jamun', 'jamoon', 'jalebi', 'kesari', 'biryani',
    'biriyani', 'pulao', 'pulav', 'ghee rice', 'paratha', 'parota', 'naan', 'pongal', 'kurma', 'korma', 'shahi', 'cake',
    'brownie', 'pudding', 'bread',
  ],
  egg: ['cake', 'brownie', 'donut', 'puff', 'puffs', 'cutlet', 'pudding', 'custard', 'fried rice', 'noodles'],
  wheat: [
    'sambar', 'rasam', 'dal', 'dhal', 'kurma', 'korma', 'gravy', 'manchurian', 'chilli', '65', 'bajji', 'pakoda',
    'pakora', 'halwa', 'jamun',
  ],
  soy: ['manchurian', 'noodles', 'fried rice', 'chilli'],
  fish: ['thai'],
  shellfish: [],
  sesame: ['podi', 'chutney', 'puliyogare', 'tamarind rice', 'kulambu', 'kuzhambu', 'kozhambu'],
  mustard: [
    'sambar', 'rasam', 'poriyal', 'chutney', 'kootu', 'kulambu', 'kuzhambu', 'kozhambu', 'lemon rice', 'tamarind rice',
    'curd rice', 'upma', 'pongal', 'poha', 'kitchadi', 'butter milk', 'pickle', 'thokku', 'sundal',
  ],
};

/**
 * The status of one dish name for one allergen. `diet` is the dish's diet
 * class (used for fish and shellfish only).
 */
export function allergenStatus(name: string, allergen: Allergen, diet: DietClass): AllergenStatus {
  const n = normaliseDishName(name);
  if (n === '') return 'unknown';
  if (hasTerm(n, CONTAINS[allergen])) return 'contains';
  if (hasTerm(n, LIKELY[allergen])) return 'likely';
  if (allergen === 'fish' || allergen === 'shellfish') {
    return diet === 'veg' || diet === 'egg' ? 'free' : 'unknown';
  }
  return FREE[allergen].has(n) ? 'free' : 'unknown';
}

/** Every allergen of `allergies` that is NOT confirmed free, with its status. */
export function allergenFailures(
  name: string,
  diet: DietClass,
  allergies: readonly Allergen[],
): { allergen: Allergen; status: Exclude<AllergenStatus, 'free'> }[] {
  const out: { allergen: Allergen; status: Exclude<AllergenStatus, 'free'> }[] = [];
  for (const a of [...new Set(allergies)].sort()) {
    const s = allergenStatus(name, a, diet);
    if (s !== 'free') out.push({ allergen: a, status: s });
  }
  return out;
}
