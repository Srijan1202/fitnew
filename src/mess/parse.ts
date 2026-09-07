/**
 * Parses MessIT's single comma-joined menu string into structured dishes.
 *
 * Every rule here exists because of a defect observed in a real response on
 * 2026-09-07. See test/fixtures/*.json `_capture.note`. Do not "simplify" this
 * file without re-running mess.parse.test.ts.
 */

import type { DietClass, DishRole, MessDish } from './types.js';
import { classifyDiet, classifyRole, isAmbient } from './classify.js';

/**
 * Label prefixes the mess uses to annotate an item, e.g. "Non Veg : Chicken gravy".
 * Spacing around the colon is inconsistent upstream ("Non Veg :", "Non Veg:",
 * "Sweet :  ", "Fruits:"), so the pattern is deliberately loose.
 */
const LABEL_PATTERN = /^\s*(non\s*veg|veg|sweet|fruits?|dessert|salad)\s*:\s*/i;

/**
 * Multi-word dish names that legitimately contain no comma but DO contain a
 * slash-separated choice, e.g. "Coconut Rice / Tamarind Rice".
 */
const ALTERNATIVE_SEPARATOR = /\s*\/\s*/;

/**
 * Known upstream corruption: a dish name that got comma-split mid-phrase.
 * Observed verbatim in hostel-1-mess-3 on 2026-08-01:
 *   "...Rajma Masala, White, Egg Fried Rice, White Rice, ..."
 * "White" is an orphaned fragment of "White Rice". We repair rather than emit
 * a nonsense dish called "White".
 */
const ORPHAN_FRAGMENTS = new Set(['white', 'cream of', 'mix', 'plain']);

function stripLabel(segment: string): { label: string | null; rest: string } {
  const match = LABEL_PATTERN.exec(segment);
  if (!match) return { label: null, rest: segment.trim() };
  const rawLabel = match[1];
  if (rawLabel === undefined) return { label: null, rest: segment.trim() };
  // Normalise "Non  Veg" -> "Non Veg"
  const label = rawLabel.replace(/\s+/g, ' ').trim();
  return { label, rest: segment.slice(match[0].length).trim() };
}

/** Collapse internal whitespace and strip stray punctuation, preserving parentheses. */
function normaliseName(value: string): string {
  return value
    .replace(/\s+/g, ' ')
    .replace(/^[,.\s]+|[,.\s]+$/g, '')
    .trim();
}

/** Title-case for display without destroying acronym-ish tokens like "65" or "(2 Nos)". */
function toDisplayName(value: string): string {
  return value
    .split(' ')
    .map((word) => {
      if (word.length === 0) return word;
      if (/^\(?\d/.test(word)) return word; // "65", "(2"
      const first = word[0];
      if (first === undefined) return word;
      return first.toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(' ');
}

export function slugifyDish(name: string): string {
  return name
    .toLowerCase()
    .replace(/\([^)]*\)/g, '') // drop "(2 Nos)" so counts don't fragment ids
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Splits the raw menu string into candidate segments, repairing orphaned
 * fragments produced by upstream comma errors.
 */
export function splitMenuString(raw: string): string[] {
  const segments = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0); // handles "Mix Dhal,," and "Butter milk,,"

  const repaired: string[] = [];
  for (const segment of segments) {
    const previousIndex = repaired.length - 1;
    const previous = repaired[previousIndex];
    if (
      previous !== undefined &&
      ORPHAN_FRAGMENTS.has(previous.toLowerCase()) &&
      // Only merge when the fragment alone is not a real dish we know about.
      previous.split(' ').length <= 2
    ) {
      repaired[previousIndex] = `${previous} ${segment}`;
      continue;
    }
    repaired.push(segment);
  }
  return repaired;
}

export interface ParseOptions {
  /**
   * Diet hint from the mess descriptor. A dish in a mess that serves no non-veg
   * is never upgraded to nonveg by keyword alone — but a dish in a non-veg mess
   * with an unrecognised name stays `unknown`, never silently `veg`.
   */
  readonly messServesNonVeg: boolean;
}

/**
 * Parse one meal's raw string into dishes.
 *
 * Dedupes by dish id, because the source repeats tokens within a single meal
 * (observed: "Masala Vada, Tea, Coffee, Milk, Tea").
 */
export function parseMenuString(raw: string, options: ParseOptions): MessDish[] {
  const segments = splitMenuString(raw);
  const seen = new Set<string>();
  const dishes: MessDish[] = [];

  for (const segment of segments) {
    const { label, rest } = stripLabel(segment);
    if (rest.length === 0) continue;

    const parts = rest.split(ALTERNATIVE_SEPARATOR).map(normaliseName).filter(Boolean);
    const primary = parts[0];
    if (primary === undefined || primary.length === 0) continue;

    const alternatives = parts.slice(1);
    const displayName = toDisplayName(primary);
    const id = slugifyDish(primary);
    if (id.length === 0 || seen.has(id)) continue;
    seen.add(id);

    const diet = resolveDiet(primary, label, options.messServesNonVeg);
    const role: DishRole = classifyRole(primary, diet);

    dishes.push({
      id,
      name: displayName,
      raw: segment,
      label,
      diet,
      role,
      alternatives: alternatives.map(toDisplayName),
      isAmbient: isAmbient(primary),
      nutrition: null, // filled by the enrichment layer, never by the parser
    });
  }

  return dishes;
}

/**
 * Diet resolution combines two independent signals:
 *
 *  1. The upstream label ("Non Veg : Chicken gravy") — present in the women's
 *     non-veg mess, ABSENT in the men's non-veg mess where chicken appears
 *     inline. So the label alone is not sufficient.
 *  2. Keyword classification of the dish name.
 *
 * Rule: either signal saying non-veg wins. This is intentionally asymmetric —
 * a false "non-veg" costs a vegetarian one hidden menu item; a false "veg"
 * costs them their dietary commitment.
 */
function resolveDiet(name: string, label: string | null, messServesNonVeg: boolean): DietClass {
  const byKeyword = classifyDiet(name);
  const labelSaysNonVeg = label !== null && /^non\s*veg$/i.test(label);

  if (labelSaysNonVeg) {
    // Trust the label's non-veg assertion, but let keywords refine egg vs meat.
    return byKeyword === 'egg' ? 'egg' : 'nonveg';
  }
  if (byKeyword === 'nonveg' || byKeyword === 'egg') return byKeyword;
  if (label !== null && /^veg$/i.test(label)) return 'veg';

  // In a veg-only mess an unrecognised dish is safely veg. In a mess that does
  // serve meat, an unrecognised dish stays `unknown` and is excluded from
  // vegetarian recommendations by the filter in recommend.ts.
  if (!messServesNonVeg) return 'veg';
  return byKeyword;
}
