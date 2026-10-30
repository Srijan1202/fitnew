/**
 * Beta 3.7 (owner 2026-10-25, ADR-036): the rules that turn the measured
 * Indian and UK sources into seed foods. Pure; build.ts places the foods.
 *
 *   IFCT 2017   raw foods per 100 g, each value +- the SD IFCT reports across
 *               its six regions, kept within 3-10 % of the value; verified.
 *   INDB 2024   recipes per piece / bowl as INDB serves them, +-10 %. Its
 *               deep-fried recipes count the whole pan of oil (a poori at
 *               ~920 kcal). From beta 3.9 the pan is taken out and the fat
 *               kept is what CoFID measured in fried food of the same kind
 *               (FRIED_KINDS), +-15 %; a kind CoFID cannot check within
 *               +-15 % (samosa, vada, cutlet) stays out, not guessed. So do
 *               whole dishes (a cake, a jar) and portions outside 5-900 kcal
 *               (a wrong unit). Never verified.
 *   CoFID 2021  measured as eaten, per 100 g: plain foods +-3 %, dishes +-8 %;
 *               verified.
 *
 * Both Indian sources have rows whose energy their own macros cannot give
 * (INDB's soups list ~13 g protein and ~13 g fat per 100 g at 27 kcal; IFCT's
 * skinless chicken leg twice the thigh's energy). A food whose energy and
 * 4/4/9 kcal from its macros differ by more than 25 % is left out, not guessed.
 */
import type { FoodNutrition } from '@fitos/contracts';

import type { CofidFood, IfctFood, IndbRecipe } from './format.js';

export const IFCT_SPREAD = { min: 0.03, max: 0.1 } as const;
export const INDB_SPREAD = 0.1;
/** A fried INDB recipe's spread: the owner's +-15 % check against CoFID (beta 3.9). */
export const INDB_FRIED_SPREAD = 0.15;
export const INDB_PIECE_KCAL = { min: 5, max: 900 } as const;
/** INDB units that are a whole dish, not something one person eats. */
export const INDB_WHOLE_UNITS = new Set(['cake', 'pie', 'jar', 'box', 'souffle dish', 'dish', 'chicken', 'loaf', 'tin', 'bottle', 'tray', 'pan']);
/**
 * Beta 4.9 (ADR-049): a whole dish one person eats a share of is served as
 * that share — a slice of cake an eighth, of pie a sixth, a portion of a
 * dish (lasagne, souffle) a quarter. A jar, box, tin or bottle (pickles,
 * chutneys) stays out: its serving is a spoonful nobody can weigh from it.
 */
export const INDB_WHOLE_PORTIONS: ReadonlyMap<string, { readonly share: number; readonly label: string }> = new Map([
  ['cake', { share: 8, label: 'slice (1/8 cake)' }],
  ['pie', { share: 6, label: 'slice (1/6 pie)' }],
  ['dish', { share: 4, label: 'portion (1/4 dish)' }],
  ['souffle dish', { share: 4, label: 'portion (1/4 dish)' }],
]);
/** A whole of less energy than this is one person's, served whole (beta 4.9). */
export const INDB_WHOLE_ONE_KCAL = 600;
export const COFID_SPREAD = { food: 0.03, dish: 0.08 } as const;
/** How far energy and 4/4/9 from the macros may differ (share of the energy; at least 10 kcal). */
export const ENERGY_AGREEMENT = 0.25;

/** Why a food's energy cannot be its macros' (4/4/9 kcal), or null when they agree. */
export function energyDisagreement(kcal: number, protein: number, carb: number, fat: number): string | null {
  const fromMacros = 4 * protein + 4 * carb + 9 * fat;
  if (Math.abs(fromMacros - kcal) <= Math.max(10, ENERGY_AGREEMENT * kcal)) return null;
  return `energy ${Math.round(kcal)} kcal but its macros give ${Math.round(fromMacros)}`;
}

const down = (v: number, d: number): number => Math.max(0, Math.floor(v * 10 ** d + 1e-9) / 10 ** d);
// `|| 0`: never -0 (the seed is JSON, which has no -0).
const up = (v: number, d: number): number => Math.ceil(v * 10 ** d - 1e-9) / 10 ** d || 0;

/** v +- spread, rounded outward (kcal whole, grams to 0.1). */
function around(v: number, spread: number, d: number): [number, number] {
  return [down(v * (1 - spread), d), up(v * (1 + spread), d)];
}

type Row = Omit<FoodNutrition, 'basis' | 'servingLabel' | 'servingGrams' | 'confidence'>;

/** Per 100 g nothing weighs more than 100 g or holds more than 900 kcal (a pure oil +- 3 % would). */
function physical(r: Row): Row {
  const g = (v: number) => Math.min(100, v);
  return {
    ...r,
    kcalHigh: Math.min(900, r.kcalHigh),
    kcalLow: Math.min(900, r.kcalLow),
    proteinHigh: g(r.proteinHigh), carbHigh: g(r.carbHigh), fatHigh: g(r.fatHigh),
    proteinLow: g(r.proteinLow), carbLow: g(r.carbLow), fatLow: g(r.fatLow),
    fibreHigh: r.fibreHigh === null ? null : g(r.fibreHigh),
    fibreLow: r.fibreLow === null ? null : g(r.fibreLow),
  };
}

function rowOf(kcal: [number, number], protein: [number, number], carb: [number, number], fat: [number, number], fibre: [number, number] | null): Row {
  return {
    kcalLow: kcal[0], kcalHigh: kcal[1],
    proteinLow: protein[0], proteinHigh: protein[1],
    carbLow: carb[0], carbHigh: carb[1],
    fatLow: fat[0], fatHigh: fat[1],
    fibreLow: fibre === null ? null : fibre[0], fibreHigh: fibre === null ? null : fibre[1],
  };
}

/* ------------------------------------------------------------------ IFCT -- */

/** The share IFCT's SD is of its value, kept within 3-10 %. */
export function ifctSpread(value: number, sd: number | null): number {
  if (value <= 0 || sd === null) return IFCT_SPREAD.min;
  return Math.min(IFCT_SPREAD.max, Math.max(IFCT_SPREAD.min, sd / value));
}

export type SourceResult = { readonly nutrition: FoodNutrition } | { readonly skip: string };

/** IFCT 2017's own energy factors, kJ per gram (its `energies` table). */
export const IFCT_KJ_PER_G = { protein: 17, fat: 37, carb: 17, fibre: 8 } as const;

/**
 * IFCT's energy in kJ. Its data lists 0 kJ for the oils and ghee (100 g fat):
 * a gap, not a measurement, so a food at 0 kJ with macros gets IFCT's own
 * factors (an oil: 3700 kJ, 884 kcal).
 */
export function ifctEnergyKj(f: IfctFood): number | null {
  if (f.energyKj !== 0 || f.protein === null || f.fat === null || f.carb === null) return f.energyKj;
  const kj = IFCT_KJ_PER_G.protein * f.protein + IFCT_KJ_PER_G.fat * f.fat + IFCT_KJ_PER_G.carb * f.carb + IFCT_KJ_PER_G.fibre * (f.fibre ?? 0);
  return kj > 0 ? kj : 0;
}

/** An IFCT food per 100 g; or why it is left out (a missing value, energy its macros cannot give). */
export function ifctNutrition(f: IfctFood): SourceResult {
  const kj = ifctEnergyKj(f);
  if (kj === null || f.protein === null || f.fat === null || f.carb === null) return { skip: 'IFCT lacks its energy or a macro' };
  const kcal = kj / 4.184;
  const disagreement = energyDisagreement(kcal, f.protein, f.carb, f.fat);
  if (disagreement !== null) return { skip: disagreement };
  const band = (v: number, sd: number | null, d: number) => around(v, ifctSpread(v, sd), d);
  return { nutrition: {
    basis: 'per_100g',
    servingLabel: '100 g',
    servingGrams: 100,
    ...physical(
      rowOf(
        band(kcal, f.energyKjSd === null ? null : f.energyKjSd / 4.184, 0),
        band(f.protein, f.proteinSd, 1),
        band(f.carb, f.carbSd, 1),
        band(f.fat, f.fatSd, 1),
        f.fibre === null ? null : band(f.fibre, f.fibreSd, 1),
      ),
    ),
    confidence: 'high',
  } };
}

/** The names a local-language list adds for search (no name repeated). */
export function ifctAliases(f: IfctFood): string[] {
  return [...new Set(f.localNames.map((n) => n.trim()).filter((n) => n.length >= 2))];
}

/* ------------------------------------------------------------------ INDB -- */

/**
 * Beta 3.9 (owner 2026-10-26, ADR-036 amendment): the fat a deep-fried food
 * of each kind holds, as a share of its protein + carbohydrate (grams of fat
 * per gram), from CoFID's dishes measured as eaten (`references`, codes in
 * cofid-picks.json). Fat over protein + carbohydrate does not depend on the
 * water or the portion, so INDB's own per-piece protein and carbohydrate give
 * the fat. A kind is here only when one share puts every reference's energy
 * within +-15 % (the owner's check; food-seed.test.ts). Pakoras split by what
 * is fried: cauliflower and aubergine soak up nearly twice the oil. Left out,
 * because CoFID's own measurements of them differ by more than that: samosa
 * (0.26-1.26), vada and cutlet (0.25-0.95), and the pakoras of paneer, egg,
 * bread, chicken and fish (no reference). Gulab jamun is left out too: INDB
 * also counts the whole pan of syrup.
 */
export const FRIED_KINDS: readonly { readonly kind: string; readonly pattern: RegExp; readonly share: number; readonly references: readonly string[] }[] = [
  { kind: 'poori, bhatura, kachori, mathri', pattern: /\b(poori|bhatura|kachori|mathri)\b/i, share: 0.51, references: ['11-911'] },
  { kind: 'cauliflower pakora', pattern: /\b(cauliflower|phoolgobhi)\b.*\bpakora\b|^gobi 65\b/i, share: 0.88, references: ['15-620', '15-826', '15-827'] },
  {
    kind: 'potato, onion or leafy pakora',
    pattern: /\b(potato|onion|spinach|methi|mixed vegetable)\b.*\bpakora\b|^potato bonda\b/i,
    share: 0.47,
    references: ['15-653', '15-828', '15-830', '15-831', '15-832'],
  },
  { kind: 'fried fish', pattern: /^(fried fish \(indian style\)|fish finger\b|fish orly\b)/i, share: 0.47, references: ['16-426', '16-444'] },
  { kind: 'sev, namak para, murukku, papdi', pattern: /^(sev|rice murukku|papdi)\b|\bnamak paras\b/i, share: 0.48, references: ['17-782', '17-836'] },
  { kind: 'kofta', pattern: /\bkofta\b/i, share: 0.53, references: ['15-774', '19-594'] },
  { kind: 'spring roll', pattern: /^spring roll\b/i, share: 0.66, references: ['19-327'] },
  { kind: 'scotch egg', pattern: /\bscotch egg\b/i, share: 0.64, references: ['19-518'] },
];

/** The kind of fried food an INDB recipe is, or null when no checked kind covers it. */
export function friedKindOf(name: string): (typeof FRIED_KINDS)[number] | null {
  return FRIED_KINDS.find((k) => k.pattern.test(name)) ?? null;
}

type IndbUnit = NonNullable<IndbRecipe['perUnit']>;

/**
 * A deep-fried recipe's piece with the pan taken out: the fat is the kind's
 * share of its protein + carbohydrate, never less than the fat INDB has
 * without the pan (a gravy's own oil); the energy moves with the fat.
 */
export function withAbsorbedOil(u: IndbUnit, panOilGrams: number, share: number): IndbUnit {
  const own = Math.max(0, u.fat - panOilGrams / u.unitsInRecipe);
  const fat = Math.max(own, share * (u.protein + u.carb));
  return { ...u, fat, kcal: u.kcal - 9 * (u.fat - fat) };
}

/** An INDB recipe per piece / bowl; or why it is left out. */
export function indbNutrition(r: IndbRecipe): SourceResult {
  let u = r.perUnit;
  if (u === null) return { skip: 'INDB gives no per-serving values' };
  let spread = INDB_SPREAD;
  if (r.deepFry !== null) {
    const kind = friedKindOf(r.name);
    if (kind === null) return { skip: 'deep-fried: INDB counts the whole pan of oil, and CoFID checks no rule for this kind' };
    u = withAbsorbedOil(u, r.deepFry.panOilGrams, kind.share);
    spread = INDB_FRIED_SPREAD;
  }
  const portion = INDB_WHOLE_PORTIONS.get(u.unit.toLowerCase());
  // Under INDB_WHOLE_ONE_KCAL the whole is one person's (a single fish pie,
  // a souffle made four at a time): served whole, as INDB gives it.
  if (portion !== undefined && u.kcal >= INDB_WHOLE_ONE_KCAL) {
    const of = (v: number) => v / portion.share;
    u = { ...u, unit: portion.label, kcal: of(u.kcal), protein: of(u.protein), carb: of(u.carb), fat: of(u.fat), fibre: u.fibre === null ? null : of(u.fibre) };
  } else if (portion === undefined && INDB_WHOLE_UNITS.has(u.unit.toLowerCase())) {
    return { skip: `a whole ${u.unit}, not a portion` };
  }
  if (u.kcal < INDB_PIECE_KCAL.min || u.kcal > INDB_PIECE_KCAL.max) return { skip: `${Math.round(u.kcal)} kcal a ${u.unit} is not plausible` };
  const disagreement = energyDisagreement(u.kcal, u.protein, u.carb, u.fat);
  if (disagreement !== null) return { skip: disagreement };
  return {
    nutrition: {
      basis: 'per_serving',
      servingLabel: `1 ${u.unit}`,
      servingGrams: null,
      ...rowOf(
        around(u.kcal, spread, 0),
        around(u.protein, spread, 1),
        around(u.carb, spread, 1),
        around(u.fat, spread, 1),
        u.fibre === null ? null : around(u.fibre, spread, 1),
      ),
      confidence: 'medium',
    },
  };
}

/**
 * "Plain urad dal vada (Uzunne vada/Minapa garelu/Medu vada)" → the name
 * "Plain urad dal vada" and the other names as aliases; "Chapati/Roti" →
 * "Chapati" and "Roti".
 *
 * Beta 3.9: a one-word spelling of the last word is that dish's other
 * spelling ("Potato pakora/pakoda" → the alias "Potato pakoda", not
 * "pakoda", which is another food); one word before a whole dish names the
 * dish's main ingredient ("Ghiya/Lauki Kofta Curry" → "Lauki Kofta Curry").
 * `slugName` is the first part, as before beta 3.9: a seeded food's slug
 * never changes (the seed is upserted by slug). `spellings` are kept apart:
 * they never make a recipe "one FITOS already has".
 */
export function indbNames(name: string): { name: string; slugName: string; aliases: string[]; spellings: string[] } {
  const inner = [...name.matchAll(/\(([^)]*)\)/g)].flatMap((m) => m[1]!.split(/[/,]/));
  const base = name.replace(/\([^)]*\)/g, ' ').replace(/\s+/g, ' ').trim();
  const [first = base, ...rest] = base.split('/').map((s) => s.trim()).filter((s) => s !== '');
  const words = (s: string) => s.split(' ');
  const last = rest.at(-1);
  const ingredientOnly = last !== undefined && words(first).length === 1 && words(last).length > 1;
  const spelling = (p: string) => words(p).length === 1 && words(first).length > 1;
  const others = (ingredientOnly ? rest.slice(0, -1) : rest).filter((p) => !spelling(p));
  const spellings = rest.filter(spelling).map((p) => [...words(first).slice(0, -1), p].join(' '));
  const fit = (s: string) => s.length >= 2 && s.length <= 60;
  const aliases = [...others, ...inner.map((s) => s.trim())].filter(fit);
  return { name: ingredientOnly ? last : first, slugName: first, aliases: [...new Set(aliases)], spellings: spellings.filter(fit) };
}

/* ----------------------------------------------------------------- CoFID -- */

/** A CoFID food at `grams` (100 = per 100 g), +- the spread for a plain food or a dish. */
export function cofidNutrition(f: CofidFood, grams: number, kind: 'food' | 'dish', servingLabel: string): FoodNutrition {
  const spread = COFID_SPREAD[kind];
  const at = (v: number, d: number) => around((v * grams) / 100, spread, d);
  const per100 = grams === 100 && servingLabel === '100 g';
  const row = rowOf(at(f.kcal, 0), at(f.protein, 1), at(f.carb, 1), at(f.fat, 1), f.fibre === null ? null : at(f.fibre, 1));
  return {
    basis: per100 ? 'per_100g' : 'per_serving',
    servingLabel,
    servingGrams: grams,
    ...(per100 ? physical(row) : row),
    confidence: kind === 'food' ? 'high' : 'medium',
  };
}

/* ----------------------------------------------------------------- names -- */

/** A slug from a name: lower case, letters and digits joined by hyphens, at most 60 characters. */
export function slugOf(name: string): string {
  return name
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
    .replace(/-+$/g, '');
}
