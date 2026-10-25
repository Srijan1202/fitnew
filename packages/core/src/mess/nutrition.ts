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
 *
 * Beta 3.7 (owner 2026-10-25, ADR-036):
 * - Where a dish matches one measured as eaten in the UK's Composition of
 *   Foods Integrated Dataset 2021 (CoFID, Open Government Licence v3.0), the
 *   entry is that measurement x the mess serving, +-8 % (`measured`). The
 *   source stays `estimated-table`: the serving is still an unweighed mess
 *   portion.
 * - Every other entry's ranges are at most +-20 % around their middle (they
 *   were up to +-35 %). The role fallback for an unrecognised dish stays wide.
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
  /** Beta 3.7: the CoFID 2021 food the numbers come from. */
  readonly measured?: MessMeasurement;
}

/** A CoFID 2021 food measured as eaten: per 100 g kcal, protein, carb, fat. */
export interface MessMeasurement {
  readonly code: string;
  readonly name: string;
  readonly per100g: readonly [number, number, number, number];
}

/** How far a measured dish may differ at a mess (+-8 %). */
export const MEASURED_SPREAD = 0.08;
/** The widest an estimate may be around its middle (+-20 %). */
export const ESTIMATE_SPREAD = 0.2;

const down = (v: number, d: number): number => Math.floor(v * 10 ** d) / 10 ** d;
const up = (v: number, d: number): number => Math.ceil(v * 10 ** d) / 10 ** d;

/** A table entry from a CoFID measurement at the mess serving, +-MEASURED_SPREAD, rounded outward. */
function measured(
  terms: readonly string[],
  servingLabel: string,
  servingGrams: number,
  confidence: Confidence,
  m: MessMeasurement,
): TableEntry {
  const at = (i: number, d: number): [number, number] => {
    const v = (m.per100g[i]! * servingGrams) / 100;
    return [down(v * (1 - MEASURED_SPREAD), d), up(v * (1 + MEASURED_SPREAD), d)];
  };
  return { terms, servingLabel, servingGrams, kcal: at(0, 0), protein: at(1, 1), carb: at(2, 1), fat: at(3, 1), confidence, measured: m };
}

/** A range at most +-ESTIMATE_SPREAD around its middle (kcal whole, grams to 0.1). */
export function capSpread(range: readonly [number, number], decimals: number): [number, number] {
  const [low, high] = range;
  const mid = (low + high) / 2;
  if (mid <= 0 || (high - low) / 2 <= mid * ESTIMATE_SPREAD) return [low, high];
  const f = 10 ** decimals;
  return [Math.round(mid * (1 - ESTIMATE_SPREAD) * f) / f, Math.round(mid * (1 + ESTIMATE_SPREAD) * f) / f];
}

/** An estimate entry with every range capped (a measured one is already narrow). */
function capped(e: TableEntry): TableEntry {
  if (e.measured !== undefined) return e;
  return { ...e, kcal: capSpread(e.kcal, 0), protein: capSpread(e.protein, 1), carb: capSpread(e.carb, 1), fat: capSpread(e.fat, 1) };
}

function has(name: string, terms: readonly string[]): boolean {
  const haystack = ` ${name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ')} `;
  return terms.some((t) => haystack.includes(` ${t} `));
}

/**
 * Ordered most-specific first. "Chicken Biryani" must match before "Biryani",
 * and "Paneer Butter Masala" before "Paneer".
 */
const RAW_BASE_TABLE: readonly TableEntry[] = [
  // ---- animal protein -----------------------------------------------------
  measured(['chicken biryani', 'chicken dum biriyani', 'chicken biriyani', 'chicken hyderabadi biryani', 'chicken malliga biryani'], '1 plate', 300, 'low', { code: '19-454', name: 'Biryani, chicken, takeaway', per100g: [163, 8.5, 16.6, 7.4] }),
  measured(['butter chicken', 'chicken tikka masala', 'chicken rogan josh', 'chicken tikka lababdar'], '1 serving', 130, 'medium', { code: '19-296', name: 'Curry, chicken tikka masala, retail, reheated', per100g: [156, 12.4, 4.9, 9.8] }),
  { terms: ['tandoori chicken', 'chicken 65', 'chicken hariyali', 'dragon chicken', 'kadai chicken', 'pepper chicken gravy', 'chilli chicken'], servingLabel: '1 serving', servingGrams: 120, kcal: [200, 300], protein: [20, 28], carb: [3, 9], fat: [10, 18], confidence: 'medium' },
  measured(['chicken gravy', 'chicken'], '1 serving', 120, 'medium', { code: '19-322', name: 'Curry, chicken, average, takeaway', per100g: [145, 11.7, 2.5, 9.8] }),
  { terms: ['fish fry', 'masala fried fish', 'fish'], servingLabel: '1 piece', servingGrams: 100, kcal: [170, 260], protein: [17, 24], carb: [3, 9], fat: [8, 16], confidence: 'medium' },
  measured(['egg fried rice', 'egg rice', 'egg chow mein'], '1 plate', 250, 'low', { code: '11-444', name: 'Rice, egg fried, takeaway', per100g: [186, 4.3, 33.3, 4.9] }),
  { terms: ['egg manchurian', 'egg puffs', 'egg puff'], servingLabel: '1 serving', servingGrams: 110, kcal: [200, 300], protein: [7, 12], carb: [18, 28], fat: [10, 18], confidence: 'low' },
  measured(['omelette', 'omlette', 'masala omelette', 'cheese omelette'], '2 eggs', 120, 'medium', { code: '12-946', name: 'Omelette, plain, homemade', per100g: [191, 10.9, 0, 16.4] }),
  { terms: ['egg burji', 'egg bhurji', 'scrambled egg', 'boiled egg masala', 'fried egg masala'], servingLabel: '2 eggs', servingGrams: 120, kcal: [160, 230], protein: [11, 14], carb: [2, 5], fat: [11, 17], confidence: 'medium' },
  measured(['boiled egg', 'boiled eggs', 'fried egg', 'fried eggs', 'boiled fried eggs', 'egg'], '2 eggs', 110, 'high', { code: '12-940', name: 'Eggs, chicken, whole, boiled', per100g: [143, 14.1, 0, 9.6] }),
  { terms: ['french toast'], servingLabel: '2 slices', servingGrams: 100, kcal: [180, 260], protein: [7, 10], carb: [22, 30], fat: [7, 12], confidence: 'low' },

  // ---- vegetarian protein -------------------------------------------------
  { terms: ['paneer butter masala', 'kadai paneer', 'shahi paneer', 'paneer amritsari', 'capsicum paneer masala', 'hariyali paneer', 'dragon paneer', 'paneer tikka'], servingLabel: '1 katori', servingGrams: 120, kcal: [230, 330], protein: [10, 15], carb: [8, 15], fat: [16, 25], confidence: 'medium' },
  { terms: ['paneer 65', 'panneer 65', 'paneer'], servingLabel: '1 serving', servingGrams: 110, kcal: [220, 310], protein: [12, 17], carb: [7, 14], fat: [14, 22], confidence: 'medium' },
  { terms: ['green gram sprouts', 'moong dal sprout', 'sprouted channa black', 'black channa sprout', 'sprouts', 'sprout'], servingLabel: '1 katori', servingGrams: 100, kcal: [90, 140], protein: [6, 9], carb: [14, 20], fat: [0.5, 2], confidence: 'medium' },
  { terms: ['channa masala', 'chenna masala', 'chole', 'chickpea masala', 'rajma masala', 'dal rajma', 'rajma', 'tendli channa'], servingLabel: '1 katori', servingGrams: 150, kcal: [150, 230], protein: [7, 11], carb: [20, 28], fat: [4, 9], confidence: 'medium' },

  // ---- legumes ------------------------------------------------------------
  { terms: ['dal makhani', 'dhal makani', 'dhal makhani', 'dal maharani'], servingLabel: '1 katori', servingGrams: 150, kcal: [180, 260], protein: [7, 10], carb: [18, 25], fat: [8, 15], confidence: 'medium' },
  measured(['dal tadka', 'dhal tadka', 'dal fry', 'dhal fry', 'toor dal', 'toor dhal', 'yellow dhal', 'mix dhal', 'masoor dhal', 'urad dhal', 'green gram dhal', 'dal', 'dhal'], '1 katori', 150, 'medium', { code: '15-780', name: 'Curry, pigeon pea dahl, with vegetable oil, homemade', per100g: [116, 4.6, 13.5, 5.5] }),
  measured(['sambar', 'sambhar'], '1 katori', 150, 'medium', { code: '12-467', name: 'Sambar, homemade', per100g: [49, 3.1, 7.7, 0.9] }),
  { terms: ['rasam'], servingLabel: '1 katori', servingGrams: 150, kcal: [30, 65], protein: [1, 2.5], carb: [4, 9], fat: [1, 2.5], confidence: 'medium' },
  { terms: ['kootu', 'kuttu', 'kadhi pakoda', 'kadi pakora'], servingLabel: '1 katori', servingGrams: 130, kcal: [90, 150], protein: [3, 5.5], carb: [11, 18], fat: [3, 7], confidence: 'low' },

  // ---- dairy --------------------------------------------------------------
  measured(['cup curd', 'loose curd', 'curd', 'dahi'], '1 cup', 120, 'high', { code: '12-184', name: 'Yogurt, whole milk, plain', per100g: [79, 5.7, 7.8, 3.0] }),
  // Beta 3.7: buttermilk (chaas) and sweet lassi were one entry at 45-90 kcal a glass; a sweet lassi is ~130.
  measured(['sweet lassi', 'lassi'], '1 glass', 200, 'medium', { code: '12-373', name: 'Lassi, sweetened', per100g: [65, 2.6, 12.3, 0.9] }),
  { terms: ['butter milk', 'buttermilk'], servingLabel: '1 glass', servingGrams: 200, kcal: [45, 90], protein: [2, 4], carb: [5, 10], fat: [1, 3], confidence: 'medium' },
  measured(['onion raitha', 'cucumber raitha', 'raitha', 'raita'], '1 katori', 100, 'medium', { code: '17-832', name: 'Raita, homemade', per100g: [57, 4.4, 5.8, 2.4] }),

  // ---- staples ------------------------------------------------------------
  { terms: ['curd rice'], servingLabel: '1 katori', servingGrams: 180, kcal: [180, 260], protein: [5, 8], carb: [30, 40], fat: [4, 8], confidence: 'medium' },
  { terms: ['veg biryani', 'vegetable dum biriyani', 'chettinad veg biriyani', 'malliga veg biryani', 'veg hyderabadi biryani', 'biryani', 'biriyani'], servingLabel: '1 plate', servingGrams: 280, kcal: [380, 520], protein: [8, 13], carb: [60, 80], fat: [10, 18], confidence: 'low' },
  { terms: ['veg fried rice', 'fried rice', 'thai fried rice', 'peas pulao', 'peas pulav', 'jeera rice', 'ghee rice', 'tomato rice', 'lemon rice', 'coconut rice', 'tamarind rice', 'carrot rice', 'mint pulav', 'veg pulao', 'pulav', 'pulao', 'bisibela bath', 'bisi bele bath', 'vangi bath', 'mushroom rice'], servingLabel: '1 plate', servingGrams: 220, kcal: [260, 380], protein: [5, 9], carb: [45, 62], fat: [6, 13], confidence: 'low' },
  measured(['white rice', 'rice'], '1 katori', 150, 'high', { code: '11-862', name: 'Rice, white, long grain, boiled in unsalted water', per100g: [131, 2.8, 31.1, 0.4] }),
  { terms: ['phulka', 'pulka', 'roti', 'chapathi', 'chapati', 'methi chapathi', 'diamond chapathi', 'methi roti', 'triangle chapathi'], servingLabel: '1 piece', servingGrams: 40, kcal: [85, 120], protein: [2.5, 3.6], carb: [16, 22], fat: [0.8, 3], confidence: 'high' },
  { terms: ['lachha parota', 'parota', 'paratha', 'chole bhatura', 'bhatura'], servingLabel: '1 piece', servingGrams: 90, kcal: [220, 320], protein: [5, 8], carb: [30, 42], fat: [8, 16], confidence: 'low' },
  measured(['poori', 'puri'], '2 pieces', 80, 'low', { code: '11-911', name: 'Puri, homemade', per100g: [366, 7.2, 36.5, 22.3] }),
  { terms: ['masala dosai', 'masala dosa', 'podi dosa', 'set dosai', 'set dosa', 'plain dosa', 'thin dosa', 'kal dosa', 'dosa', 'dosai'], servingLabel: '1 piece', servingGrams: 110, kcal: [150, 260], protein: [3, 6], carb: [25, 40], fat: [4, 10], confidence: 'low' },
  { terms: ['podi idly', 'idly', 'idli'], servingLabel: '2 pieces', servingGrams: 110, kcal: [120, 165], protein: [3.5, 5.5], carb: [24, 33], fat: [0.5, 3], confidence: 'high' },
  { terms: ['onion uthappam', 'masala uthappam', 'uthappam'], servingLabel: '1 piece', servingGrams: 120, kcal: [160, 240], protein: [4, 6.5], carb: [28, 38], fat: [3, 8], confidence: 'low' },
  { terms: ['pongal', 'upma', 'semiya', 'poha namkeen', 'poha', 'kitchadi', 'kichidi', 'rava kitchadi'], servingLabel: '1 katori', servingGrams: 180, kcal: [190, 280], protein: [4, 7], carb: [30, 42], fat: [5, 11], confidence: 'low' },
  { terms: ['vada pav', 'vada paav', 'paav bhaji', 'pav bhaji'], servingLabel: '1 serving', servingGrams: 160, kcal: [250, 360], protein: [6, 10], carb: [35, 48], fat: [9, 17], confidence: 'low' },

  // ---- vegetables ---------------------------------------------------------
  { terms: ['poriyal', 'sabji', 'subji', 'sabzi', 'foogath', 'podimas', 'thokku'], servingLabel: '1 katori', servingGrams: 100, kcal: [55, 115], protein: [1.5, 3], carb: [7, 13], fat: [2, 6], confidence: 'medium' },
  { terms: ['manchurian', 'jalfrezi', 'jal frezi', 'kurma', 'korma', 'kofta', 'kolhapuri', 'kholapuri', 'mixed veg gravy', 'veg gravy', 'masala', 'gravy', 'fry'], servingLabel: '1 katori', servingGrams: 120, kcal: [110, 200], protein: [2.5, 5], carb: [12, 20], fat: [5, 12], confidence: 'low' },
  measured(['soup'], '1 bowl', 200, 'low', { code: '17-684', name: 'Soup, vegetable, homemade', per100g: [55, 1.0, 3.7, 4.2] }),
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

const BASE_TABLE: readonly TableEntry[] = RAW_BASE_TABLE.map(capped);

/** The base entry that owns `term` — for spelling variants that share its estimate. */
function entryWithTerm(term: string): Omit<TableEntry, 'terms'> {
  const entry = BASE_TABLE.find((e) => e.terms.includes(term));
  // Runs at module load over a fixed table: a typo fails every test, never a user.
  /* v8 ignore next -- @preserve */
  if (entry === undefined) throw new Error(`no base estimate owns "${term}"`);
  const { terms: _terms, ...rest } = entry;
  return rest;
}

/**
 * Phase 9 (owner D9): entries for dishes the live menus actually served that
 * matched nothing above — observed in the 2026-09-24 capture of all six
 * endpoints (docs/phase-reports/phase-9-messit-capture-2026-09-24.md). No
 * padding, no target count.
 *
 * APPENDED LAST ON PURPOSE. First match wins, and the Phase 7 food seed
 * (apps/api/src/db/food-seed) reads this table through `estimateNutrition`;
 * an entry placed earlier could capture one of its terms and change a frozen
 * Phase 7 food. Terms here match nothing the base table already matches.
 */
const RAW_PHASE9_ADDITIONS: readonly TableEntry[] = [
  // Spelling variants of dishes already estimated above — the same estimate, not a new one.
  { terms: ['subzi', 'green veg subzi'], ...entryWithTerm('subji') }, // "Subzi" = sabji
  { terms: ['jamoon', 'dry jamoon'], ...entryWithTerm('jamun') }, // "Dry Jamoon" = (dry) gulab jamun
  { terms: ['mysorepaku', 'mysorepak', 'kova mysorepaku'], ...entryWithTerm('mysore pak') },
  { terms: ['rasagulla', 'rasagolla'], ...entryWithTerm('rasgulla') },
  { terms: ['badusha', 'badushah'], ...entryWithTerm('badhusa') },
  // MessIT re-spelt "Chat" as "Chaat" in September; without this the dishes fell to the role fallback.
  { terms: ['chaat', 'sweet corn chaat', 'aloo tikka chaat'], ...entryWithTerm('sweet corn chat') },
  { terms: ['mint lemon', 'lemonade'], ...entryWithTerm('nimbu sarbat') }, // a sweetened lemon drink
  { terms: ['pudding', 'pineapple pudding'], ...entryWithTerm('custard') }, // a milk-set dessert
  // Salna: the thin Tamil gravy served with parotta — the generic vegetable-gravy estimate.
  { terms: ['salna'], ...entryWithTerm('gravy') },
  // New dishes, estimated from their make-up; low confidence, ranges wide.
  // Idiyappam: steamed rice-flour noodles, ~45–50 g a piece, little or no fat.
  { terms: ['idiyappam', 'idiappam', 'string hoppers'], servingLabel: '2 pieces', servingGrams: 100, kcal: [140, 200], protein: [2, 4], carb: [30, 42], fat: [0.3, 2.5], confidence: 'low' },
  // Stew: the Kerala vegetable stew — potato and vegetables in coconut milk.
  { terms: ['stew', 'veg stew'], servingLabel: '1 katori', servingGrams: 150, kcal: [110, 200], protein: [2, 4.5], carb: [9, 18], fat: [6, 14], confidence: 'low' },
];

const PHASE9_ADDITIONS: readonly TableEntry[] = RAW_PHASE9_ADDITIONS.map(capped);

const TABLE: readonly TableEntry[] = [...BASE_TABLE, ...PHASE9_ADDITIONS];

/** Beta 3.7: the CoFID measurement a term's estimate is calibrated to, if any (the food seed cites it). */
export function measurementOf(term: string): MessMeasurement | null {
  return TABLE.find((e) => has(term, e.terms))?.measured ?? null;
}

/* ------------------------------------------- Phase 10 mess corrections -- */

const WORSE: Readonly<Record<Confidence, number>> = { high: 0, medium: 1, low: 2 };

/** Several table entries eaten together, as one serving (the parts' sums; the worst confidence). */
function together(servingLabel: string, parts: readonly (readonly [Omit<TableEntry, 'terms'>, number])[]): Omit<TableEntry, 'terms'> {
  const sum = (pick: (e: Omit<TableEntry, 'terms'>) => readonly [number, number]): [number, number] => [
    parts.reduce((a, [e, n]) => a + pick(e)[0] * n, 0),
    parts.reduce((a, [e, n]) => a + pick(e)[1] * n, 0),
  ];
  // Every part combined today is weighed; an unweighed one makes the whole unweighed.
  /* v8 ignore next -- @preserve */
  const grams = parts.every(([e]) => e.servingGrams !== null) ? parts.reduce((a, [e, n]) => a + e.servingGrams! * n, 0) : null;
  const confidence = parts.map(([e]) => e.confidence).reduce((a, b) => (WORSE[b] > WORSE[a] ? b : a));
  return {
    servingLabel, servingGrams: grams,
    kcal: sum((e) => e.kcal), protein: sum((e) => e.protein), carb: sum((e) => e.carb), fat: sum((e) => e.fat),
    confidence,
  };
}

/**
 * Phase 10 Amendment B (owner, 2026-09-24; ADR-016): four mess dishes whose
 * estimate was wrong because an earlier, shorter term won the table's first
 * match ("curd" before "curd rice", "rice" before "rice papad", "chole"
 * before "chole bhatura", "dahi" before "dahi vada"). Each correction is an
 * existing table entry or a sum of existing entries — no new numbers.
 *
 * MESS PATH ONLY (`estimateMessDish` / `enrichDish`). `estimateNutrition`
 * is deliberately unchanged: the frozen Phase 7 food seed reads it, and its
 * "Curd rice" food keeps the old values until the owner decides otherwise.
 * Existing stored rows are corrected by migration 0012, with provenance.
 */
export const MESS_ESTIMATE_CORRECTIONS: readonly TableEntry[] = [
  { terms: ['curd rice'], ...entryWithTerm('curd rice') },
  { terms: ['rice papad'], ...entryWithTerm('rice papad') },
  { terms: ['chole bhatura'], ...together('1 plate (2 bhatura + chole)', [[entryWithTerm('chole'), 1], [entryWithTerm('bhatura'), 2]]) },
  { terms: ['dahi vada'], ...together('2 pieces in curd', [[entryWithTerm('vada'), 2], [entryWithTerm('curd'), 1]]) },
];

/**
 * Owner (Phase 9): mess-dish nutrition is never `high` confidence. The upstream
 * publishes names only, so even the table's best-known dishes (rice, roti,
 * idli, curd, eggs, banana) are an estimate of an unweighed mess portion —
 * the same cap Phase 7 applies to the carried foods. Enforced here for every
 * mess estimate that is stored or logged, and again by a database CHECK.
 * The table's own labels stay unchanged (Phase 7 reads them).
 */
export type MessConfidence = Exclude<Confidence, 'high'>;

export function capMessConfidence(confidence: Confidence): MessConfidence {
  return confidence === 'high' ? 'medium' : confidence;
}

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

/** A mess dish's estimate: the Phase 10 corrections first, then the table (ADR-016). */
export function estimateMessDish(name: string, role: DishRole): DishNutrition | null {
  for (const entry of MESS_ESTIMATE_CORRECTIONS) {
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
  return estimateNutrition(name, role);
}

/** Attach estimates to parsed mess dishes. Pure; the parser stays nutrition-free. */
export function enrichDish(dish: MessDish): MessDish {
  if (dish.nutrition !== null) return dish;
  return { ...dish, nutrition: estimateMessDish(dish.name, dish.role) };
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
