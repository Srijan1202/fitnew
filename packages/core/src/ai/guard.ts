/**
 * Phase 14 — the deterministic guards around AI output (MASTER-SPEC §19.1,
 * §19.2; ADR-020). Pure: no model, no I/O. Every AI result passes through
 * one of these before a user sees it, and nothing AI-derived is stored
 * without the user's confirmation (the draft contract).
 */

/** §19.2: every AI call returns a DRAFT, never a committed value. */
export interface AiDraft<T> {
  readonly data: T;
  readonly confidence: AiConfidence;
  readonly source: 'ai-draft';
  /** Literal `true`: a draft can never skip confirmation. */
  readonly requiresConfirmation: true;
}

export const AI_CONFIDENCE = ['high', 'medium', 'low'] as const;
export type AiConfidence = (typeof AI_CONFIDENCE)[number];

export function draftOf<T>(data: T, confidence: AiConfidence): AiDraft<T> {
  return { data, confidence, source: 'ai-draft', requiresConfirmation: true };
}

/** The lowest of several confidences (a draft is only as sure as its weakest part). */
export function lowestConfidence(levels: readonly AiConfidence[]): AiConfidence {
  if (levels.includes('low')) return 'low';
  if (levels.includes('medium')) return 'medium';
  return 'high';
}

/* ----------------------------------------------------------- numbers -- */

const WORD_NUMBERS: Readonly<Record<string, number>> = {
  zero: 0, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
  eleven: 11, twelve: 12, thirteen: 13, fourteen: 14, fifteen: 15, sixteen: 16, seventeen: 17, eighteen: 18,
  nineteen: 19, twenty: 20, thirty: 30, forty: 40, fifty: 50, sixty: 60, seventy: 70, eighty: 80, ninety: 90,
  hundred: 100, thousand: 1000, half: 0.5, quarter: 0.25, dozen: 12, once: 1, twice: 2, double: 2, triple: 3,
};

/** A number written as text, normalised so "1,200", "1200" and "1200.0" compare equal. */
function canonical(n: number): string {
  return String(Math.round(n * 1000) / 1000);
}

/**
 * Every number a text states: digits ("1,250", "0.5", "−130", "2.5x"),
 * fractions ("1/2"), and number words ("three", "half", "twice") — so a
 * model cannot slip a figure past the check by spelling it out.
 */
export function numbersIn(text: string): Set<string> {
  const out = new Set<string>();
  const lower = text.toLowerCase();
  for (const m of lower.matchAll(/(\d+)\s*\/\s*(\d+)/g)) {
    const d = Number(m[2]);
    if (d !== 0) out.add(canonical(Number(m[1]) / d));
  }
  for (const m of lower.matchAll(/\d[\d,]*(?:\.\d+)?/g)) {
    const n = Number(m[0].replace(/,/g, ''));
    if (Number.isFinite(n)) out.add(canonical(n));
  }
  for (const m of lower.matchAll(/[a-z]+/g)) {
    const w = WORD_NUMBERS[m[0]];
    if (w !== undefined) out.add(canonical(w));
  }
  return out;
}

/** Every number in a payload: strings, numbers and nested values, recursively. */
export function numbersInPayload(payload: unknown): Set<string> {
  const out = new Set<string>();
  const walk = (v: unknown): void => {
    if (typeof v === 'number' && Number.isFinite(v)) {
      out.add(canonical(v));
      // A signed engine value may be phrased without its sign ("down by 130").
      out.add(canonical(Math.abs(v)));
    } else if (typeof v === 'string') {
      for (const n of numbersIn(v)) out.add(n);
    } else if (Array.isArray(v)) {
      for (const x of v) walk(x);
    } else if (v !== null && typeof v === 'object') {
      for (const x of Object.values(v)) walk(x);
    }
  };
  walk(payload);
  return out;
}

export type ExplanationCheck =
  | { readonly ok: true }
  | { readonly ok: false; readonly reason: 'empty' | 'too-long' | 'new-number'; readonly numbers?: readonly string[] };

/** An explanation is a short rephrasing, not an essay. */
export const EXPLANATION_MAX_CHARS = 600;

/**
 * §19.2: an explanation may only rephrase the reason it was given. If it
 * states any number that is not in that input, it is discarded and the
 * engine's own words are shown instead.
 */
export function checkExplanation(explanation: string, input: unknown): ExplanationCheck {
  const text = explanation.trim();
  if (text.length === 0) return { ok: false, reason: 'empty' };
  if (text.length > EXPLANATION_MAX_CHARS) return { ok: false, reason: 'too-long' };
  const allowed = numbersInPayload(input);
  const extra = [...numbersIn(text)].filter((n) => !allowed.has(n));
  return extra.length === 0 ? { ok: true } : { ok: false, reason: 'new-number', numbers: extra };
}

/* --------------------------------------------------------- estimates -- */

/** §19.2: per 100 g, nothing above 900 kcal or 90 g protein (fat and carbs ≤ 100 g). */
export const PLAUSIBLE_PER_100G = { kcal: 900, protein: 90, carb: 100, fat: 100 } as const;
/** One food in one sitting: bounds that catch a model's slip without second-guessing a big plate. */
export const PLAUSIBLE_PORTION = { kcal: 3000, grams: 2000 } as const;

export interface AiFoodEstimate {
  readonly grams: number | null;
  readonly kcal: number;
  readonly proteinG: number;
  readonly carbG: number;
  readonly fatG: number;
}

export type EstimateCheck = { readonly ok: true } | { readonly ok: false; readonly problem: string };

/**
 * An AI estimate for a food the database does not have. Rejected when any
 * value is not a finite non-negative number, the portion is out of bounds,
 * or — with a weight — its density breaks §19.2's per-100 g limits.
 */
export function checkEstimate(e: AiFoodEstimate): EstimateCheck {
  const values = [e.kcal, e.proteinG, e.carbG, e.fatG];
  if (values.some((v) => !Number.isFinite(v) || v < 0)) return { ok: false, problem: 'not a number' };
  if (e.kcal > PLAUSIBLE_PORTION.kcal) return { ok: false, problem: `more than ${PLAUSIBLE_PORTION.kcal} kcal` };
  if (e.grams !== null) {
    if (!Number.isFinite(e.grams) || e.grams <= 0 || e.grams > PLAUSIBLE_PORTION.grams) return { ok: false, problem: 'impossible weight' };
    const per = 100 / e.grams;
    if (e.kcal * per > PLAUSIBLE_PER_100G.kcal) return { ok: false, problem: `more than ${PLAUSIBLE_PER_100G.kcal} kcal per 100 g` };
    if (e.proteinG * per > PLAUSIBLE_PER_100G.protein) return { ok: false, problem: `more than ${PLAUSIBLE_PER_100G.protein} g protein per 100 g` };
    if (e.carbG * per > PLAUSIBLE_PER_100G.carb) return { ok: false, problem: `more than ${PLAUSIBLE_PER_100G.carb} g carbs per 100 g` };
    if (e.fatG * per > PLAUSIBLE_PER_100G.fat) return { ok: false, problem: `more than ${PLAUSIBLE_PER_100G.fat} g fat per 100 g` };
  }
  // Macros cannot hold more energy than they carry (fat 9, protein and carbs 4 kcal/g),
  // nor far less: a figure off by more than half its macros' energy is a slip.
  const fromMacros = 4 * e.proteinG + 4 * e.carbG + 9 * e.fatG;
  if (e.kcal > 0 && fromMacros > 0 && (e.kcal > fromMacros * 1.5 + 30 || e.kcal < fromMacros * 0.5 - 30)) {
    return { ok: false, problem: "calories don't add up to the macros" };
  }
  return { ok: true };
}

/* ------------------------------------------------------------ limits -- */

/** §19.3 cost control: per user per hour, by route (owner D4). */
export const AI_ROUTES = ['chat', 'parse', 'explain'] as const;
export type AiRoute = (typeof AI_ROUTES)[number];
