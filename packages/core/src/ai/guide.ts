/**
 * Beta 3.6 (owner, F15) — the AI food guide's rules, pure. "What should I
 * eat?" from what the person has with them and today's mess menu.
 *
 *   candidates ──▶ only what may be suggested: a mess dish passes the
 *                  Phase 10 hard rules (diet, allergens confirmed free); a
 *                  food the person has is refused only when its name says it
 *                  breaks their diet or contains (or likely contains) one of
 *                  their allergens — an unknown one gets a "check" line
 *              ──model──▶ options as candidate ids and servings (JSON)
 *              ──here──▶ checked: known ids only, servings in quarter steps
 *                  within bounds, at most 3 options of 5 items
 *              ──▶ the numbers are the candidates' own (the database's and
 *                  the mess table's), times the servings; never the model's.
 */
import { allergenFailures, allergenStatus, type Allergen } from '../mess/allergens.js';
import { classifyDiet } from '../mess/classify.js';
import { isDietAllowed, type DietPreference } from '../mess/recommend.js';
import type { DietClass, MacroRange } from '../mess/types.js';

export const GUIDE_MAX_OPTIONS = 3;
export const GUIDE_MAX_ITEMS = 5;
/** Things the person may say they have. */
export const GUIDE_MAX_HAVE = 20;
export const GUIDE_MIN_SERVINGS = 0.25;
export const GUIDE_MAX_SERVINGS = 4;

export type GuideSource = 'mess' | 'have';

/** Something the guide may put on a plate, with its numbers for one serving. */
export interface GuideCandidate {
  /** "M1", "H2": what the model refers to. */
  readonly id: string;
  readonly source: GuideSource;
  readonly name: string;
  readonly servingLabel: string;
  readonly macros: MacroRange;
  /** Allergens the name cannot rule out (things the person has only). */
  readonly caution: readonly Allergen[];
}

/** A mess dish the guide may suggest: the same hard rules as Phase 10. */
export function messDishAllowed(name: string, dishDiet: DietClass, diet: DietPreference, allergies: readonly Allergen[]): boolean {
  return isDietAllowed(dishDiet, diet) && allergenFailures(name, dishDiet, allergies).length === 0;
}

/**
 * Something the person has: refused only when its name says so (meat for a
 * vegetarian, egg for a vegetarian, an allergen it contains or likely
 * contains). The rest is theirs to eat; an allergen the name cannot rule
 * out is returned as a caution.
 */
export function haveAllowed(name: string, diet: DietPreference, allergies: readonly Allergen[]): { readonly ok: boolean; readonly caution: readonly Allergen[] } {
  const cls = classifyDiet(name);
  if (cls === 'nonveg' && diet !== 'non-vegetarian') return { ok: false, caution: [] };
  if (cls === 'egg' && diet === 'vegetarian') return { ok: false, caution: [] };
  const caution: Allergen[] = [];
  for (const a of [...new Set(allergies)].sort()) {
    const s = allergenStatus(name, a, cls);
    if (s === 'contains' || s === 'likely') return { ok: false, caution: [] };
    if (s === 'unknown') caution.push(a);
  }
  return { ok: true, caution };
}

export interface GuideOptionPick {
  readonly title: string;
  readonly why: string;
  readonly items: readonly { readonly id: string; readonly servings: number }[];
}

/** Servings to the nearest quarter, within the bounds. */
export function roundServings(s: number): number {
  const q = Math.round(s * 4) / 4;
  return Math.min(GUIDE_MAX_SERVINGS, Math.max(GUIDE_MIN_SERVINGS, q));
}

const text = (v: unknown, max: number): string | null => (typeof v === 'string' && v.trim() !== '' ? v.trim().slice(0, max) : null);

/**
 * The model's options, checked against the candidates: unknown ids and
 * non-numbers dropped, an id once per option, servings rounded, empty
 * options dropped, at most GUIDE_MAX_OPTIONS of GUIDE_MAX_ITEMS. Null when
 * the answer is not the agreed shape at all.
 */
export function readGuideAnswer(json: unknown, candidates: readonly GuideCandidate[]): GuideOptionPick[] | null {
  if (typeof json !== 'object' || json === null || !Array.isArray((json as { options?: unknown }).options)) return null;
  const known = new Set(candidates.map((c) => c.id));
  const out: GuideOptionPick[] = [];
  for (const raw of (json as { options: unknown[] }).options) {
    if (out.length === GUIDE_MAX_OPTIONS) break;
    if (typeof raw !== 'object' || raw === null) continue;
    const o = raw as { title?: unknown; why?: unknown; items?: unknown };
    const items: { id: string; servings: number }[] = [];
    for (const it of Array.isArray(o.items) ? o.items : []) {
      if (items.length === GUIDE_MAX_ITEMS) break;
      const i = it as { id?: unknown; servings?: unknown } | null;
      const id = typeof i?.id === 'string' ? i.id.trim() : '';
      const servings = Number(i?.servings);
      if (!known.has(id) || !Number.isFinite(servings) || servings <= 0 || items.some((x) => x.id === id)) continue;
      items.push({ id, servings: roundServings(servings) });
    }
    if (items.length === 0) continue;
    out.push({ title: text(o.title, 60) ?? 'A plate', why: text(o.why, 200) ?? '', items });
  }
  return out;
}

const ZERO: MacroRange = { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0, carbLow: 0, carbHigh: 0, fatLow: 0, fatHigh: 0 };

/** One serving's numbers times the servings, rounded outward to whole units. */
export function scaleMacros(m: MacroRange, servings: number): MacroRange {
  return {
    kcalLow: Math.floor(m.kcalLow * servings),
    kcalHigh: Math.ceil(m.kcalHigh * servings),
    proteinLow: Math.floor(m.proteinLow * servings),
    proteinHigh: Math.ceil(m.proteinHigh * servings),
    carbLow: Math.floor(m.carbLow * servings),
    carbHigh: Math.ceil(m.carbHigh * servings),
    fatLow: Math.floor(m.fatLow * servings),
    fatHigh: Math.ceil(m.fatHigh * servings),
  };
}

export function sumMacros(items: readonly MacroRange[]): MacroRange {
  return items.reduce<MacroRange>(
    (a, b) => ({
      kcalLow: a.kcalLow + b.kcalLow,
      kcalHigh: a.kcalHigh + b.kcalHigh,
      proteinLow: a.proteinLow + b.proteinLow,
      proteinHigh: a.proteinHigh + b.proteinHigh,
      carbLow: a.carbLow + b.carbLow,
      carbHigh: a.carbHigh + b.carbHigh,
      fatLow: a.fatLow + b.fatLow,
      fatHigh: a.fatHigh + b.fatHigh,
    }),
    ZERO,
  );
}

/** What is left of today's targets, from the middle of what was eaten; never below 0. */
export function remainingOf(
  targets: { readonly kcal: number; readonly proteinG: number } | null,
  eaten: Pick<MacroRange, 'kcalLow' | 'kcalHigh' | 'proteinLow' | 'proteinHigh'>,
): { readonly kcal: number; readonly proteinG: number } | null {
  if (targets === null) return null;
  return {
    kcal: Math.max(0, Math.round(targets.kcal - (eaten.kcalLow + eaten.kcalHigh) / 2)),
    proteinG: Math.max(0, Math.round(targets.proteinG - (eaten.proteinLow + eaten.proteinHigh) / 2)),
  };
}

const mid = (low: number, high: number): number => Math.round((low + high) / 2);

/** The instructions and the candidates, for the model. */
export function guidePrompt(input: {
  readonly slot: string;
  readonly candidates: readonly GuideCandidate[];
  readonly remaining: { readonly kcal: number; readonly proteinG: number } | null;
  readonly feel: string | null;
}): { readonly system: string; readonly user: string } {
  const system = [
    'You help a student in India decide what to eat for one meal, from a fixed list of foods they can get right now.',
    'Answer with JSON only, exactly this shape:',
    '{"options":[{"title":"a short name for the plate","why":"one sentence on why it suits them","items":[{"id":"M1","servings":1}]}]}',
    'Rules:',
    `- Use only ids from the list. Never add a food that is not listed. At most ${GUIDE_MAX_OPTIONS} options, ${GUIDE_MAX_ITEMS} items each.`,
    `- servings is how many of that item's listed serving, in quarters, from ${GUIDE_MIN_SERVINGS} to ${GUIDE_MAX_SERVINGS}.`,
    '- Make each option a sensible meal for the time of day, and different from the others.',
    '- Fit what is left of their day: close to the calories left for this meal, and as much of the protein left as is reasonable.',
    '- Respect what they feel like when the list allows it. Do not mention calories in the title.',
    '- If nothing on the list makes a sensible meal, answer {"options":[]}.',
  ].join('\n');
  const lines = input.candidates.map(
    (c) =>
      `${c.id}: ${c.name} (${c.source === 'mess' ? 'from the mess' : 'they have it'}), 1 serving = ${c.servingLabel}, ` +
      `about ${mid(c.macros.kcalLow, c.macros.kcalHigh)} kcal and ${mid(c.macros.proteinLow, c.macros.proteinHigh)} g protein`,
  );
  const left =
    input.remaining === null
      ? 'They have no targets set.'
      : `Left for today: about ${input.remaining.kcal} kcal and ${input.remaining.proteinG} g protein.`;
  const user = [`Meal: ${input.slot}.`, left, input.feel === null ? 'No preference given.' : `They feel like: ${input.feel}`, 'Foods:', ...lines].join('\n');
  return { system, user };
}
