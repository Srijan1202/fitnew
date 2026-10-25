/**
 * Beta 3.6 (owner, F15) — the AI food guide: "What should I eat?" for one
 * meal of today, from what the person has with them and/or their mess's
 * menu (ADR-020 amendment).
 *
 *   what they have ──FITOS──▶ each matched to a database food (the Phase 7
 *       search, no fuzzy hits); unknown ones are said so, never guessed;
 *       ones whose name breaks their diet or holds their allergen are left
 *       out (core `haveAllowed`)
 *   the mess menu ──FITOS──▶ the dishes that pass Phase 10's hard rules,
 *       with their stored estimates
 *   ──model──▶ up to 3 plates as candidate ids and servings (JSON only)
 *   ──FITOS──▶ checked (core `readGuideAnswer`); every number is the
 *       database's or the mess table's, times the servings
 *
 * The model sees the meal, the candidates' names, servings and rough
 * numbers, what is left of today's calories and protein, and what they feel
 * like — never their name, weight or history. Nothing is stored; the app
 * logs a plate through the ordinary food-log routes.
 */
import type { Allergen } from '@fitos/core/mess/allergens';
import {
  GUIDE_MAX_HAVE,
  guidePrompt,
  haveAllowed,
  messDishAllowed,
  readGuideAnswer,
  remainingOf,
  scaleMacros,
  sumMacros,
  type GuideCandidate,
} from '@fitos/core/ai/guide';
import { localDateOf } from '@fitos/core/nutrition/log';
import { snapshotNutrition } from '@fitos/core/nutrition/log';
import type { DietPreference } from '@fitos/core/mess/recommend';
import type { MacroRange } from '@fitos/core/mess/types';
import type { Food, FoodGuideRequest, FoodGuideResponse, GuideItem } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { AiConfig } from '../../plugins/ai.js';
import type { MessRecommendService } from '../mess/recommend-service.js';
import type { MessService } from '../mess/service.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { FoodService } from '../nutrition/service.js';
import type { UserRepository } from '../user/repository.js';
import { rangeOf } from './parse.js';
import { AiProviderError, type AiProvider } from './provider.js';
import { AiService } from './service.js';
import type { AiBudget } from './usage.js';

type FoodHit = Awaited<ReturnType<FoodService['search']>>['items'][number];

const APPLE = "Apples, raw, with skin (Includes foods for USDA's Food Distribution Program)";
const WHEY = 'Beverages, Protein powder whey based';
const MILK = 'Milk, whole, pasteurised (3.6% fat)';
/**
 * Things a student often has, pinned to the plain food in the seed: the
 * search's first hit is often a dish or a product ("banana" → "Banana shake",
 * "milk" → condensed milk), so the app's common items never go through it.
 * A test checks that every name here is still in the seed.
 */
export const GUIDE_STAPLES: Readonly<Record<string, string>> = {
  bread: 'Bread, whole-wheat, commercially prepared',
  egg: 'Boiled eggs',
  eggs: 'Boiled eggs',
  curd: 'Curd',
  dahi: 'Curd',
  'peanut butter': 'Peanut butter, smooth style, without salt',
  oats: 'Oats, whole grain, rolled, old fashioned',
  banana: 'Bananas, raw',
  bananas: 'Bananas, raw',
  apple: APPLE,
  apples: APPLE,
  'whey protein': WHEY,
  whey: WHEY,
  'protein powder': WHEY,
  'roasted chana': 'Roasted chana',
  almond: 'Nuts, almonds, whole, raw',
  almonds: 'Nuts, almonds, whole, raw',
  sprouts: 'Green gram sprouts',
  'instant noodles': 'Instant noodles (masala)',
  maggi: 'Instant noodles (masala)',
  // Beta 3.7 (backlog E24): plain ones exist now. Milk is CoFID's whole milk
  // (its alias is "toned milk", and it has a glass); paneer is IFCT's.
  milk: MILK,
  paneer: 'Paneer',
};

/** "2 eggs", "1 cup curd": the food without the amount, for the search. */
export function foodWords(said: string): string {
  return said
    .replace(/^\s*\d+(?:[.,]\d+)?\s*(?:x|×|pcs?|pieces?|nos?|g|gm|grams?|ml|cups?|slices?|bowls?|katoris?|tbsp|tsp|scoops?|glass(?:es)?)?\b\.?\s*/i, '')
    .trim();
}

/** The row a person's own food is suggested in: a serving if it has one, else 100 g. */
function rowOf(food: Food): Food['nutrition'][number] | null {
  return food.nutrition.find((r) => r.basis === 'per_serving') ?? food.nutrition[0] ?? null;
}

const macrosOf = (r: Food['nutrition'][number]): MacroRange => ({
  kcalLow: r.kcalLow,
  kcalHigh: r.kcalHigh,
  proteinLow: r.proteinLow,
  proteinHigh: r.proteinHigh,
  carbLow: r.carbLow,
  carbHigh: r.carbHigh,
  fatLow: r.fatLow,
  fatHigh: r.fatHigh,
});

export class FoodGuideService {
  constructor(
    private readonly provider: AiProvider,
    private readonly deps: {
      readonly foods: FoodService;
      readonly users: UserRepository;
      readonly logs: FoodLogRepository;
      readonly mess: MessService;
      readonly menus: MessRecommendService;
    },
    private readonly budget: AiBudget,
    private readonly config: AiConfig,
    private readonly log?: { warn: (obj: Record<string, unknown>, msg: string) => void },
    private readonly now: () => Date = () => new Date(),
  ) {}

  private get model(): string {
    return this.config.models.guide ?? this.provider.model;
  }

  async guide(userId: string, body: FoodGuideRequest, premium = false): Promise<FoodGuideResponse> {
    await this.budget.check(userId, 'guide', premium);
    if (this.provider.name === 'none') throw AiService.toAppError(new AiProviderError('not_configured', 'no provider'));

    const bundle = await this.deps.users.loadBundle(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'User not found.');
    const date = localDateOf(this.now(), bundle.user.timezone);
    // The most restrictive diet when none was chosen (as Phase 10).
    const diet: DietPreference = bundle.diet?.dietType ?? 'vegetarian';
    const allergies: Allergen[] = [...new Set(bundle.allergies.map((a) => a.allergen))].sort();
    const excluded = new Set(Array.isArray(bundle.diet?.excludedDishIds) ? (bundle.diet?.excludedDishIds as string[]) : []);

    const candidates: GuideCandidate[] = [];
    const foodsById = new Map<string, { hit: FoodHit; row: Food['nutrition'][number] }>();
    const dishesById = new Map<string, string>();
    const unknown: string[] = [];
    const refused: string[] = [];

    // What they have.
    const said = [...new Set(body.have.map((h) => h.trim()).filter((h) => h !== ''))].slice(0, GUIDE_MAX_HAVE);
    for (const s of said) {
      const words = foodWords(s);
      // A staple by its pinned name; anything else must match a food's own
      // name or alias: a loose prefix hit ("milk" → condensed milk) is worse
      // than saying FITOS does not know it.
      const q = GUIDE_STAPLES[words.toLowerCase()] ?? words;
      const hit = words === '' ? undefined : (await this.deps.foods.search(userId, { q, limit: 3 })).items.find((h) => h.match === 'exact' || h.match === 'alias');
      const row = hit === undefined ? null : rowOf(hit);
      if (hit === undefined || row === null) {
        unknown.push(s);
        continue;
      }
      const allowed = haveAllowed(hit.name, diet, allergies);
      if (!allowed.ok) {
        refused.push(s);
        continue;
      }
      if ([...foodsById.values()].some((f) => f.hit.id === hit.id)) continue;
      const id = `H${foodsById.size + 1}`;
      foodsById.set(id, { hit, row });
      candidates.push({
        id,
        source: 'have',
        name: hit.name,
        servingLabel: row.basis === 'per_100g' ? '100 g' : row.servingLabel,
        macros: macrosOf(row),
        caution: allowed.caution,
      });
    }

    // Today's mess menu, through Phase 10's hard rules.
    let mess: FoodGuideResponse['mess'] = null;
    let messNote: string | null = null;
    if (body.fromMess) {
      const row = await this.deps.mess.configuredMessRow(userId);
      if (row === null) {
        messNote = 'Choose your mess in Profile to use its menu.';
      } else {
        const menu = await this.deps.menus.storedMenu(row, date);
        const meal = menu.meals.find((m) => m.slot === body.slot);
        const allowed = (meal?.dishes ?? []).filter(
          (d) => d.nutrition !== null && !excluded.has(d.id) && messDishAllowed(d.name, d.diet, diet, allergies),
        );
        if (meal === undefined || meal.dishes.length === 0) messNote = `No ${body.slot} menu for today.`;
        else if (allowed.length === 0) messNote = `Nothing on today's ${body.slot} menu fits your diet and allergies.`;
        else mess = { code: row.code, menuDate: date };
        for (const d of allowed) {
          const id = `M${dishesById.size + 1}`;
          dishesById.set(id, d.id);
          candidates.push({ id, source: 'mess', name: d.name, servingLabel: d.nutrition!.servingLabel, macros: d.nutrition!.macros, caution: [] });
        }
      }
    }

    const [targets, totals] = await Promise.all([this.deps.logs.targetsOn(userId, date), this.deps.logs.dayTotals(userId, date)]);
    const remaining = remainingOf(
      targets === null ? null : { kcal: targets.kcal, proteinG: targets.proteinG },
      totals === null
        ? { kcalLow: 0, kcalHigh: 0, proteinLow: 0, proteinHigh: 0 }
        : { kcalLow: Number(totals.kcalLow), kcalHigh: Number(totals.kcalHigh), proteinLow: Number(totals.proteinLow), proteinHigh: Number(totals.proteinHigh) },
    );

    const base = { slot: body.slot, date, mess, remaining, unknown, refused, messNote, model: this.model };
    if (candidates.length === 0) return { ...base, options: [] };

    const prompt = guidePrompt({ slot: body.slot, candidates, remaining, feel: body.feel });
    let usage: { inputTokens: number; outputTokens: number } | undefined;
    let picks: NonNullable<ReturnType<typeof readGuideAnswer>>;
    try {
      const response = await this.provider.generate({
        system: prompt.system,
        messages: [{ role: 'user', content: prompt.user }],
        jsonMode: true,
        temperature: 0.4,
        ...(this.config.models.guide !== null ? { model: this.config.models.guide } : {}),
      });
      usage = response.usage;
      picks = FoodGuideService.read(response.text, candidates);
    } catch (e) {
      if (e instanceof AiProviderError) {
        this.log?.warn({ kind: e.kind, upstreamStatus: e.status ?? null, model: this.model }, 'ai guide: provider failure');
      }
      await this.budget.record(userId, 'guide', this.model, usage, 'failed');
      throw AiService.toAppError(e);
    }

    const byId = new Map(candidates.map((c) => [c.id, c]));
    const options = picks.map((p) => {
      const items: GuideItem[] = p.items.map(({ id, servings }) => {
        const c = byId.get(id)!;
        const food = foodsById.get(id);
        const macros = food === undefined ? scaleMacros(c.macros, servings) : snapshotNutrition(rangeOf(food.row), servings).macros;
        return {
          source: c.source,
          name: c.name,
          servings,
          servingLabel: c.servingLabel,
          macros: { ...macros },
          food:
            food === undefined
              ? null
              : {
                  foodId: food.hit.id,
                  name: food.hit.name,
                  matchKind: food.hit.match,
                  basis: food.row.basis,
                  servingLabel: food.row.servingLabel,
                  servings,
                  row: food.row,
                  snapshot: { ...macros },
                },
          dishSlug: dishesById.get(id) ?? null,
        };
      });
      const caution = [...new Set(p.items.flatMap(({ id }) => byId.get(id)!.caution))].sort();
      return { title: p.title, why: p.why, items, totals: sumMacros(items.map((i) => i.macros)), caution };
    });
    await this.budget.record(userId, 'guide', this.model, usage, options.length === 0 ? 'discarded' : 'ok');
    return { ...base, options };
  }

  /** The model's JSON, checked; a code fence around it is tolerated. */
  static read(raw: string, candidates: readonly GuideCandidate[]): NonNullable<ReturnType<typeof readGuideAnswer>> {
    const text = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    let json: unknown;
    try {
      json = JSON.parse(text);
    } catch {
      throw new AiProviderError('malformed', 'The model did not answer with JSON.');
    }
    const picks = readGuideAnswer(json, candidates);
    if (picks === null) throw new AiProviderError('malformed', 'The model answered in the wrong shape.');
    return picks;
  }
}
