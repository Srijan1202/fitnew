/**
 * Nutrition enrichment for mess dishes.
 *
 * HONEST SOURCING NOTE — read before trusting any number in this file.
 * The MessIT endpoints publish dish NAMES ONLY. They contain no calories, no
 * macros, no serving sizes and no ids. Every number below is therefore an
 * ESTIMATE produced by us, tagged `source: 'estimated-table'`, and expressed as
 * a range rather than a point value.
 *
 * These ranges are calibrated to typical Indian hostel-mess serving sizes. They
 * are NOT lookups against IFCT 2017 / INDB. Wiring a real composition database
 * is tracked as a pre-production requirement; when that lands, entries move to
 * `source: 'ifct-mapped'` and confidence rises. Until then the UI must render
 * these as estimates, and it does — see `formatEstimate`.
 *
 * Mess cooking adds uncounted oil and varies serving-to-serving, which is the
 * dominant error term. Ranges are widened accordingly rather than pretending to
 * a precision we do not have.
 */

import type { Confidence, DishNutrition, DishRole, MacroRange, MessDish } from './types.js';

interface TableEntry {
  readonly terms: readonly string[];
  readonly servingLabel: string;
  readonly servingGrams: number | null;
  readonly kcal: readonly [number, number];
  readonly protein: readonly [number, number];
  readonly carb: readonly [number, number];
  readonly fat: readonly [number, number];
  readonly confidence: Confidence;
}

function has(name: string, terms: readonly string[]): boolean {
  const haystack = ` ${name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ')} `;
  return terms.some((t) => haystack.includes(` ${t} `));
}

/**
 * Ordered most-specific first. "Chicken Biryani" must match before "Biryani",
 * and "Paneer Butter Masala" before "Paneer".
 */
const TABLE: readonly TableEntry[] = [
  // ---- animal protein -----------------------------------------------------
  { terms: ['chicken biryani', 'chicken dum biriyani', 'chicken biriyani', 'chicken hyderabadi biryani', 'chicken malliga biryani'], servingLabel: '1 plate', servingGrams: 300, kcal: [450, 650], protein: [22, 30], carb: [55, 75], fat: [14, 24], confidence: 'low' },
  { terms: ['butter chicken', 'chicken tikka masala', 'chicken rogan josh', 'chicken tikka lababdar'], servingLabel: '1 serving', servingGrams: 130, kcal: [270, 370], protein: [19, 26], carb: [5, 11], fat: [18, 27], confidence: 'medium' },
  { terms: ['tandoori chicken', 'chicken 65', 'chicken hariyali', 'dragon chicken', 'kadai chicken', 'pepper chicken gravy', 'chilli chicken'], servingLabel: '1 serving', servingGrams: 120, kcal: [200, 300], protein: [20, 28], carb: [3, 9], fat: [10, 18], confidence: 'medium' },
  { terms: ['chicken gravy', 'chicken'], servingLabel: '1 serving', servingGrams: 120, kcal: [180, 270], protein: [18, 25], carb: [4, 9], fat: [9, 17], confidence: 'medium' },
  { terms: ['fish fry', 'masala fried fish', 'fish'], servingLabel: '1 piece', servingGrams: 100, kcal: [170, 260], protein: [17, 24], carb: [3, 9], fat: [8, 16], confidence: 'medium' },
  { terms: ['egg fried rice', 'egg rice', 'egg chow mein'], servingLabel: '1 plate', servingGrams: 250, kcal: [300, 420], protein: [9, 15], carb: [45, 60], fat: [8, 16], confidence: 'low' },
  { terms: ['egg manchurian', 'egg puffs', 'egg puff'], servingLabel: '1 serving', servingGrams: 110, kcal: [200, 300], protein: [7, 12], carb: [18, 28], fat: [10, 18], confidence: 'low' },
  { terms: ['omelette', 'omlette', 'masala omelette', 'cheese omelette'], servingLabel: '2 eggs', servingGrams: 120, kcal: [180, 250], protein: [11, 15], carb: [1, 4], fat: [13, 19], confidence: 'medium' },
  { terms: ['egg burji', 'egg bhurji', 'scrambled egg', 'boiled egg masala', 'fried egg masala'], servingLabel: '2 eggs', servingGrams: 120, kcal: [160, 230], protein: [11, 14], carb: [2, 5], fat: [11, 17], confidence: 'medium' },
  { terms: ['boiled egg', 'boiled eggs', 'fried egg', 'fried eggs', 'boiled fried eggs', 'egg'], servingLabel: '2 eggs', servingGrams: 110, kcal: [140, 190], protein: [12, 14], carb: [1, 2], fat: [10, 14], confidence: 'high' },
  { terms: ['french toast'], servingLabel: '2 slices', servingGrams: 100, kcal: [180, 260], protein: [7, 10], carb: [22, 30], fat: [7, 12], confidence: 'low' },

  // ---- vegetarian protein -------------------------------------------------
  { terms: ['paneer butter masala', 'kadai paneer', 'shahi paneer', 'paneer amritsari', 'capsicum paneer masala', 'hariyali paneer', 'dragon paneer', 'paneer tikka'], servingLabel: '1 katori', servingGrams: 120, kcal: [230, 330], protein: [10, 15], carb: [8, 15], fat: [16, 25], confidence: 'medium' },
  { terms: ['paneer 65', 'panneer 65', 'paneer'], servingLabel: '1 serving', servingGrams: 110, kcal: [220, 310], protein: [12, 17], carb: [7, 14], fat: [14, 22], confidence: 'medium' },
  { terms: ['green gram sprouts', 'moong dal sprout', 'sprouted channa black', 'black channa sprout', 'sprouts', 'sprout'], servingLabel: '1 katori', servingGrams: 100, kcal: [90, 140], protein: [6, 9], carb: [14, 20], fat: [0.5, 2], confidence: 'medium' },
  { terms: ['channa masala', 'chenna masala', 'chole', 'chickpea masala', 'rajma masala', 'dal rajma', 'rajma', 'tendli channa'], servingLabel: '1 katori', servingGrams: 150, kcal: [150, 230], protein: [7, 11], carb: [20, 28], fat: [4, 9], confidence: 'medium' },

  // ---- legumes ------------------------------------------------------------
  { terms: ['dal makhani', 'dhal makani', 'dhal makhani', 'dal maharani'], servingLabel: '1 katori', servingGrams: 150, kcal: [180, 260], protein: [7, 10], carb: [18, 25], fat: [8, 15], confidence: 'medium' },
  { terms: ['dal tadka', 'dhal tadka', 'dal fry', 'dhal fry', 'toor dal', 'toor dhal', 'yellow dhal', 'mix dhal', 'masoor dhal', 'urad dhal', 'green gram dhal', 'dal', 'dhal'], servingLabel: '1 katori', servingGrams: 150, kcal: [120, 185], protein: [6, 9], carb: [16, 23], fat: [3, 7], confidence: 'medium' },
  { terms: ['sambar', 'sambhar'], servingLabel: '1 katori', servingGrams: 150, kcal: [85, 145], protein: [3.5, 6], carb: [12, 19], fat: [2, 5], confidence: 'medium' },
  { terms: ['rasam'], servingLabel: '1 katori', servingGrams: 150, kcal: [30, 65], protein: [1, 2.5], carb: [4, 9], fat: [1, 2.5], confidence: 'medium' },
  { terms: ['kootu', 'kuttu', 'kadhi pakoda', 'kadi pakora'], servingLabel: '1 katori', servingGrams: 130, kcal: [90, 150], protein: [3, 5.5], carb: [11, 18], fat: [3, 7], confidence: 'low' },

  // ---- dairy --------------------------------------------------------------
  { terms: ['cup curd', 'loose curd', 'curd', 'dahi'], servingLabel: '1 cup', servingGrams: 120, kcal: [65, 105], protein: [4, 7], carb: [5, 8], fat: [3, 5.5], confidence: 'high' },
  { terms: ['butter milk', 'buttermilk', 'sweet lassi', 'lassi'], servingLabel: '1 glass', servingGrams: 200, kcal: [45, 90], protein: [2, 4], carb: [5, 10], fat: [1, 3], confidence: 'medium' },
  { terms: ['onion raitha', 'cucumber raitha', 'raitha', 'raita'], servingLabel: '1 katori', servingGrams: 100, kcal: [50, 90], protein: [2.5, 4.5], carb: [4, 8], fat: [2, 4.5], confidence: 'medium' },

  // ---- staples ------------------------------------------------------------
  { terms: ['curd rice'], servingLabel: '1 katori', servingGrams: 180, kcal: [180, 260], protein: [5, 8], carb: [30, 40], fat: [4, 8], confidence: 'medium' },
  { terms: ['veg biryani', 'vegetable dum biriyani', 'chettinad veg biriyani', 'malliga veg biryani', 'veg hyderabadi biryani', 'biryani', 'biriyani'], servingLabel: '1 plate', servingGrams: 280, kcal: [380, 520], protein: [8, 13], carb: [60, 80], fat: [10, 18], confidence: 'low' },
  { terms: ['veg fried rice', 'fried rice', 'thai fried rice', 'peas pulao', 'peas pulav', 'jeera rice', 'ghee rice', 'tomato rice', 'lemon rice', 'coconut rice', 'tamarind rice', 'carrot rice', 'mint pulav', 'veg pulao', 'pulav', 'pulao', 'bisibela bath', 'bisi bele bath', 'vangi bath', 'mushroom rice'], servingLabel: '1 plate', servingGrams: 220, kcal: [260, 380], protein: [5, 9], carb: [45, 62], fat: [6, 13], confidence: 'low' },
  { terms: ['white rice', 'rice'], servingLabel: '1 katori', servingGrams: 150, kcal: [175, 215], protein: [3.2, 4.5], carb: [38, 48], fat: [0.3, 1.2], confidence: 'high' },
  { terms: ['phulka', 'pulka', 'roti', 'chapathi', 'chapati', 'methi chapathi', 'diamond chapathi', 'methi roti', 'triangle chapathi'], servingLabel: '1 piece', servingGrams: 40, kcal: [85, 120], protein: [2.5, 3.6], carb: [16, 22], fat: [0.8, 3], confidence: 'high' },
  { terms: ['lachha parota', 'parota', 'paratha', 'chole bhatura', 'bhatura'], servingLabel: '1 piece', servingGrams: 90, kcal: [220, 320], protein: [5, 8], carb: [30, 42], fat: [8, 16], confidence: 'low' },
  { terms: ['poori', 'puri'], servingLabel: '2 pieces', servingGrams: 80, kcal: [230, 320], protein: [4, 6.5], carb: [28, 38], fat: [11, 18], confidence: 'low' },
  { terms: ['masala dosai', 'masala dosa', 'podi dosa', 'set dosai', 'set dosa', 'plain dosa', 'thin dosa', 'kal dosa', 'dosa', 'dosai'], servingLabel: '1 piece', servingGrams: 110, kcal: [150, 260], protein: [3, 6], carb: [25, 40], fat: [4, 10], confidence: 'low' },
  { terms: ['podi idly', 'idly', 'idli'], servingLabel: '2 pieces', servingGrams: 110, kcal: [120, 165], protein: [3.5, 5.5], carb: [24, 33], fat: [0.5, 3], confidence: 'high' },
  { terms: ['onion uthappam', 'masala uthappam', 'uthappam'], servingLabel: '1 piece', servingGrams: 120, kcal: [160, 240], protein: [4, 6.5], carb: [28, 38], fat: [3, 8], confidence: 'low' },
  { terms: ['pongal', 'upma', 'semiya', 'poha namkeen', 'poha', 'kitchadi', 'kichidi', 'rava kitchadi'], servingLabel: '1 katori', servingGrams: 180, kcal: [190, 280], protein: [4, 7], carb: [30, 42], fat: [5, 11], confidence: 'low' },
  { terms: ['vada pav', 'vada paav', 'paav bhaji', 'pav bhaji'], servingLabel: '1 serving', servingGrams: 160, kcal: [250, 360], protein: [6, 10], carb: [35, 48], fat: [9, 17], confidence: 'low' },

  // ---- vegetables ---------------------------------------------------------
  { terms: ['poriyal', 'sabji', 'subji', 'sabzi', 'foogath', 'podimas', 'thokku'], servingLabel: '1 katori', servingGrams: 100, kcal: [55, 115], protein: [1.5, 3], carb: [7, 13], fat: [2, 6], confidence: 'medium' },
  { terms: ['manchurian', 'jalfrezi', 'jal frezi', 'kurma', 'korma', 'kofta', 'kolhapuri', 'kholapuri', 'mixed veg gravy', 'veg gravy', 'masala', 'gravy', 'fry'], servingLabel: '1 katori', servingGrams: 120, kcal: [110, 200], protein: [2.5, 5], carb: [12, 20], fat: [5, 12], confidence: 'low' },
  { terms: ['soup'], servingLabel: '1 bowl', servingGrams: 200, kcal: [55, 110], protein: [1.5, 4], carb: [7, 14], fat: [1.5, 4.5], confidence: 'low' },
  { terms: ['salad'], servingLabel: '1 katori', servingGrams: 80, kcal: [25, 70], protein: [1, 4], carb: [4, 10], fat: [0.3, 2], confidence: 'medium' },

  // ---- fried / snacks -----------------------------------------------------
  { terms: ['samosa', 'aloo samosa', 'onion samosa', 'veg samosa', 'samosa chat'], servingLabel: '1 piece', servingGrams: 65, kcal: [170, 250], protein: [3, 5], carb: [20, 28], fat: [9, 15], confidence: 'low' },
  { terms: ['vada', 'vadai', 'masala vada', 'mysore bonda', 'bonda', 'bajji', 'pakoda', 'pakora'], servingLabel: '1 piece', servingGrams: 55, kcal: [120, 190], protein: [3, 5.5], carb: [13, 20], fat: [6, 12], confidence: 'low' },
  { terms: ['puff', 'puffs', 'cutlet', 'spring roll', 'veg roll', 'roll', 'sandwich', 'pizza', 'french fries', 'donut'], servingLabel: '1 piece', servingGrams: 80, kcal: [180, 290], protein: [3, 7], carb: [22, 34], fat: [8, 16], confidence: 'low' },
  { terms: ['potato chips', 'wheel chips', 'chips', 'fryums', 'appalam', 'papad', 'rice papad', 'masala papad'], servingLabel: '1 small portion', servingGrams: 25, kcal: [95, 155], protein: [1, 2.5], carb: [11, 17], fat: [5, 10], confidence: 'low' },
  { terms: ['sundal', 'masala peanuts', 'peanuts', 'channa chat', 'sweet corn chat', 'chat'], servingLabel: '1 katori', servingGrams: 90, kcal: [130, 220], protein: [4, 8], carb: [15, 24], fat: [4, 10], confidence: 'low' },

  // ---- sweets & fruit -----------------------------------------------------
  { terms: ['gulab jamun', 'jamun', 'jalebi', 'laddu', 'ladoo', 'badhusa', 'mysore pak', 'peda', 'rasgulla', 'rasamalai', 'suryakala', 'suzhiyam'], servingLabel: '1 piece', servingGrams: 50, kcal: [140, 230], protein: [1.5, 3.5], carb: [22, 34], fat: [5, 11], confidence: 'low' },
  { terms: ['ice cream', 'brownie cake', 'cake', 'halwa', 'kheer', 'payasam', 'custard', 'shahi tukra'], servingLabel: '1 serving', servingGrams: 90, kcal: [150, 260], protein: [2.5, 5], carb: [22, 36], fat: [5, 12], confidence: 'low' },
  { terms: ['banana'], servingLabel: '1 medium', servingGrams: 100, kcal: [85, 115], protein: [1, 1.5], carb: [20, 27], fat: [0.2, 0.5], confidence: 'high' },
  { terms: ['water melon', 'watermelon', 'musk melon', 'papaya', 'grapes', 'cut fruits', 'seasonal fruit', 'fresh fruits', 'fruit salad', 'fruit'], servingLabel: '1 bowl', servingGrams: 150, kcal: [45, 90], protein: [0.5, 1.5], carb: [10, 20], fat: [0.1, 0.6], confidence: 'medium' },

  // ---- beverages & condiments --------------------------------------------
  { terms: ['banana milk shake', 'dates milk shake', 'date milk shake', 'milk shake', 'cold badam milk', 'rose milk', 'badam milk'], servingLabel: '1 glass', servingGrams: 200, kcal: [150, 240], protein: [4, 7], carb: [24, 36], fat: [3, 7], confidence: 'low' },
  { terms: ['cold milk', 'milk'], servingLabel: '1 glass', servingGrams: 200, kcal: [100, 150], protein: [6, 8], carb: [9, 13], fat: [4, 8], confidence: 'medium' },
  { terms: ['tea', 'coffee'], servingLabel: '1 cup', servingGrams: 120, kcal: [55, 100], protein: [1.5, 3], carb: [8, 14], fat: [1.5, 3.5], confidence: 'medium' },
  { terms: ['fresh juice', 'juice', 'nimbu sarbat', 'sarbat', 'ice lemon tea'], servingLabel: '1 glass', servingGrams: 200, kcal: [70, 130], protein: [0.3, 1.5], carb: [16, 30], fat: [0, 0.5], confidence: 'low' },
  { terms: ['chutney', 'sauce', 'pickle', 'podi'], servingLabel: '1 tbsp', servingGrams: 20, kcal: [20, 60], protein: [0.4, 1.5], carb: [1.5, 5], fat: [1, 4.5], confidence: 'low' },
  { terms: ['butter', 'jam', 'bread'], servingLabel: '1 serving', servingGrams: 40, kcal: [80, 150], protein: [1.5, 4], carb: [12, 22], fat: [1.5, 6], confidence: 'low' },
  { terms: ['corn flakes', 'chocos'], servingLabel: '1 bowl', servingGrams: 40, kcal: [140, 190], protein: [2.5, 4.5], carb: [30, 40], fat: [0.5, 2], confidence: 'medium' },
];

/**
 * Role-based fallback for a dish we cannot name-match. Always `low` confidence
 * and deliberately wide — an honest shrug beats a confident guess.
 */
const ROLE_FALLBACK: Partial<Record<DishRole, Omit<TableEntry, 'terms'>>> = {
  staple: { servingLabel: '1 serving', servingGrams: null, kcal: [150, 300], protein: [3, 7], carb: [28, 50], fat: [2, 10], confidence: 'low' },
  protein: { servingLabel: '1 serving', servingGrams: null, kcal: [180, 320], protein: [12, 24], carb: [4, 14], fat: [8, 20], confidence: 'low' },
  legume: { servingLabel: '1 katori', servingGrams: null, kcal: [100, 200], protein: [4, 9], carb: [14, 25], fat: [2, 8], confidence: 'low' },
  vegetable: { servingLabel: '1 katori', servingGrams: null, kcal: [60, 160], protein: [1.5, 4], carb: [8, 18], fat: [2, 9], confidence: 'low' },
  dairy: { servingLabel: '1 serving', servingGrams: null, kcal: [50, 120], protein: [2.5, 7], carb: [4, 10], fat: [2, 6], confidence: 'low' },
  fruit: { servingLabel: '1 serving', servingGrams: null, kcal: [45, 110], protein: [0.5, 1.5], carb: [10, 25], fat: [0.1, 0.6], confidence: 'low' },
  sweet: { servingLabel: '1 serving', servingGrams: null, kcal: [140, 260], protein: [1.5, 5], carb: [22, 36], fat: [4, 12], confidence: 'low' },
  fried: { servingLabel: '1 serving', servingGrams: null, kcal: [120, 260], protein: [2, 6], carb: [14, 30], fat: [6, 15], confidence: 'low' },
  beverage: { servingLabel: '1 glass', servingGrams: null, kcal: [50, 150], protein: [0.5, 7], carb: [8, 25], fat: [0, 7], confidence: 'low' },
  condiment: { servingLabel: '1 tbsp', servingGrams: null, kcal: [20, 60], protein: [0.4, 1.5], carb: [1.5, 5], fat: [1, 4.5], confidence: 'low' },
};

function toMacroRange(e: Omit<TableEntry, 'terms'>): MacroRange {
  return {
    kcalLow: e.kcal[0], kcalHigh: e.kcal[1],
    proteinLow: e.protein[0], proteinHigh: e.protein[1],
    carbLow: e.carb[0], carbHigh: e.carb[1],
    fatLow: e.fat[0], fatHigh: e.fat[1],
  };
}

/** Look up a nutrition estimate for one dish. Returns null only for `other`. */
export function estimateNutrition(name: string, role: DishRole): DishNutrition | null {
  for (const entry of TABLE) {
    if (has(name, entry.terms)) {
      return {
        servingLabel: entry.servingLabel,
        servingGrams: entry.servingGrams,
        macros: toMacroRange(entry),
        confidence: entry.confidence,
        source: 'estimated-table',
      };
    }
  }
  const fallback = ROLE_FALLBACK[role];
  if (fallback === undefined) return null;
  return {
    servingLabel: fallback.servingLabel,
    servingGrams: fallback.servingGrams,
    macros: toMacroRange(fallback),
    confidence: 'low',
    source: 'estimated-table',
  };
}

/** Attach estimates to parsed dishes. Pure; the parser stays nutrition-free. */
export function enrichDish(dish: MessDish): MessDish {
  if (dish.nutrition !== null) return dish;
  return { ...dish, nutrition: estimateNutrition(dish.name, dish.role) };
}

/** Scale a range by a serving count. */
export function scaleMacros(macros: MacroRange, servings: number): MacroRange {
  return {
    kcalLow: macros.kcalLow * servings, kcalHigh: macros.kcalHigh * servings,
    proteinLow: macros.proteinLow * servings, proteinHigh: macros.proteinHigh * servings,
    carbLow: macros.carbLow * servings, carbHigh: macros.carbHigh * servings,
    fatLow: macros.fatLow * servings, fatHigh: macros.fatHigh * servings,
  };
}

export function addMacros(a: MacroRange, b: MacroRange): MacroRange {
  return {
    kcalLow: a.kcalLow + b.kcalLow, kcalHigh: a.kcalHigh + b.kcalHigh,
    proteinLow: a.proteinLow + b.proteinLow, proteinHigh: a.proteinHigh + b.proteinHigh,
    carbLow: a.carbLow + b.carbLow, carbHigh: a.carbHigh + b.carbHigh,
    fatLow: a.fatLow + b.fatLow, fatHigh: a.fatHigh + b.fatHigh,
  };
}

export const ZERO_MACROS: MacroRange = {
  kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0,
  carbLow: 0, carbHigh: 0, fatLow: 0, fatHigh: 0,
};

/** Midpoint, for ranking only. Never rendered as if it were a measured value. */
export function midpoint(low: number, high: number): number {
  return (low + high) / 2;
}

/**
 * UI-facing string. There is deliberately no `formatPoint` counterpart —
 * the type system should make it awkward to render fake precision.
 */
export function formatEstimate(low: number, high: number, unit: string): string {
  const l = Math.round(low);
  const h = Math.round(high);
  if (l === h) return `~${l}${unit}`;
  return `${l}–${h}${unit}`;
}
