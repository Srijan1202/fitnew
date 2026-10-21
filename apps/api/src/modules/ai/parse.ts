/**
 * Phase 14 — natural-language food parsing (MASTER-SPEC §19, §13.4; ADR-020).
 *
 *   text ──model──▶ phrases + quantities (JSON, Zod-checked)
 *        ──FITOS──▶ each phrase matched to a food (the Phase 7 search) and a
 *                   portion of that food's own rows (core `choosePortion`):
 *                   the numbers are the database's, never the model's
 *        ──▶ a food the database lacks: the model's estimate, kept only when
 *            §19.2's bounds hold (core `checkEstimate`)
 *        ──▶ an AiDraft — returned, NEVER stored. The phone logs what the
 *            user confirms through the ordinary food-log routes.
 *
 * Only the meal text reaches the model: no profile, no history, no targets.
 */
import { z } from 'zod';

import type { DraftItem, Food, ParseFoodResponse } from '@fitos/contracts';
import { checkEstimate, draftOf, lowestConfidence, type AiConfidence } from '@fitos/core/ai/guard';
import { choosePortion } from '@fitos/core/ai/portion';
import { snapshotNutrition } from '@fitos/core/nutrition/log';
import type { FoodNutritionRange } from '@fitos/core/nutrition/food';

import type { AiConfig } from '../../plugins/ai.js';
import type { FoodService } from '../nutrition/service.js';
import { AiProviderError, type AiProvider } from './provider.js';
import { AiService } from './service.js';
import type { AiBudget } from './usage.js';

/** At most this many foods from one description. */
export const PARSE_MAX_ITEMS = 8;

const n = z.coerce.number().finite();
/** What the model must return; anything else is a malformed answer. */
const modelItemSchema = z.object({
  phrase: z.string().trim().min(1).max(120),
  name: z.string().trim().min(1).max(60),
  quantity: n.positive().max(5000),
  unit: z.string().trim().min(1).max(30),
  grams: n.positive().max(5000).nullable().optional(),
  kcal: n.nonnegative(),
  proteinG: n.nonnegative(),
  carbG: n.nonnegative(),
  fatG: n.nonnegative(),
  confidence: z.enum(['high', 'medium', 'low']).catch('low'),
});
const modelAnswerSchema = z.object({ items: z.array(modelItemSchema).max(PARSE_MAX_ITEMS) });

export const PARSE_SYSTEM = [
  'You read a short description of what someone ate (often Indian food, often a hostel mess) and list the foods in it.',
  'Answer with JSON only, exactly this shape:',
  '{"items":[{"phrase":"the words for this food as written","name":"the food\'s common English name (Indian dishes in their usual spelling, e.g. chapati, dal tadka, idli, poha)","quantity":2,"unit":"piece | katori | bowl | cup | glass | plate | tbsp | tsp | slice | serving | g | ml","grams":80,"kcal":240,"proteinG":7,"carbG":44,"fatG":4,"confidence":"high | medium | low"}]}',
  'Rules:',
  '- One item per food. At most 8 items. Never invent a food that is not mentioned.',
  '- quantity and unit as the person said them; when no amount is given, 1 serving.',
  '- grams is your estimate of the whole portion\'s weight, or null when you cannot tell.',
  '- kcal, proteinG, carbG and fatG are your estimate for the whole portion.',
  '- confidence is how sure you are about the food and the amount.',
  '- If nothing edible is described, answer {"items":[]}.',
].join('\n');

function rangeOf(row: Food['nutrition'][number]): FoodNutritionRange {
  return {
    macros: {
      kcalLow: row.kcalLow, kcalHigh: row.kcalHigh,
      proteinLow: row.proteinLow, proteinHigh: row.proteinHigh,
      carbLow: row.carbLow, carbHigh: row.carbHigh,
      fatLow: row.fatLow, fatHigh: row.fatHigh,
    },
    fibre: row.fibreLow === null || row.fibreHigh === null ? null : { low: row.fibreLow, high: row.fibreHigh },
  };
}

const CONFIDENCE_ORDER: Readonly<Record<AiConfidence, number>> = { high: 2, medium: 1, low: 0 };
const atMost = (a: AiConfidence, cap: AiConfidence): AiConfidence => (CONFIDENCE_ORDER[a] <= CONFIDENCE_ORDER[cap] ? a : cap);

export class FoodParseService {
  constructor(
    private readonly provider: AiProvider,
    private readonly foods: FoodService,
    private readonly budget: AiBudget,
    private readonly config: AiConfig,
    /** Operator diagnostics: the failure kind and upstream status, never the text. */
    private readonly log?: { warn: (obj: Record<string, unknown>, msg: string) => void },
  ) {}

  private get model(): string {
    return this.config.models.parse ?? this.provider.model;
  }

  async parse(userId: string, text: string): Promise<ParseFoodResponse> {
    await this.budget.check(userId, 'parse');
    if (this.provider.name === 'none') throw AiService.toAppError(new AiProviderError('not_configured', 'no provider'));

    let answer: z.infer<typeof modelAnswerSchema>;
    let usage: { inputTokens: number; outputTokens: number } | undefined;
    try {
      const response = await this.provider.generate({
        system: PARSE_SYSTEM,
        messages: [{ role: 'user', content: text }],
        jsonMode: true,
        temperature: 0,
        ...(this.config.models.parse !== null ? { model: this.config.models.parse } : {}),
      });
      usage = response.usage;
      answer = FoodParseService.read(response.text);
    } catch (e) {
      if (e instanceof AiProviderError) {
        this.log?.warn({ kind: e.kind, upstreamStatus: e.status ?? null, model: this.model }, 'ai parse: provider failure');
      }
      await this.budget.record(userId, 'parse', this.model, usage, 'failed');
      throw AiService.toAppError(e);
    }

    const items: DraftItem[] = [];
    for (const item of answer.items) items.push(await this.resolve(userId, item));
    await this.budget.record(userId, 'parse', this.model, usage, items.length === 0 ? 'discarded' : 'ok');
    const draft = draftOf({ items }, items.length === 0 ? 'low' : lowestConfidence(items.map((i) => i.confidence)));
    return { draft: { ...draft, data: { items: [...draft.data.items] } }, model: this.model };
  }

  /** The model's JSON, checked; a code fence around it is tolerated. */
  static read(raw: string): z.infer<typeof modelAnswerSchema> {
    const text = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    let json: unknown;
    try {
      json = JSON.parse(text);
    } catch {
      throw new AiProviderError('malformed', 'The model did not answer with JSON.');
    }
    const parsed = modelAnswerSchema.safeParse(json);
    if (!parsed.success) throw new AiProviderError('malformed', 'The model answered in the wrong shape.');
    return parsed.data;
  }

  /** One phrase → a FITOS food at a portion, an estimate within bounds, or a problem. */
  private async resolve(userId: string, item: z.infer<typeof modelItemSchema>): Promise<DraftItem> {
    const base = { phrase: item.phrase, quantity: item.quantity, unit: item.unit };
    const hits = (await this.foods.search(userId, { q: item.name, limit: 1 })).items;
    // A fuzzy hit is a different food as often as a misspelling ("brown
    // bread" → "Sugars, brown" in the live smoke); the model already gives a
    // common name, so only exact, alias and prefix hits count as FITOS foods.
    const food = hits.find((h) => h.match !== 'fuzzy');
    if (food !== undefined) {
      const chosen = choosePortion(food.nutrition, { quantity: item.quantity, unit: item.unit, grams: item.grams ?? null });
      if (chosen !== null) {
        const row = food.nutrition[chosen.row]!;
        const snap = snapshotNutrition(rangeOf(row), chosen.servings).macros;
        // Confidence: never above the model's; a prefix match or a guessed amount lowers it.
        let confidence: AiConfidence = item.confidence;
        if (food.match === 'prefix') confidence = atMost(confidence, 'medium');
        if (!chosen.exact) confidence = atMost(confidence, 'medium');
        return {
          ...base,
          confidence,
          match: {
            foodId: food.id,
            name: food.name,
            matchKind: food.match,
            basis: row.basis,
            servingLabel: row.servingLabel,
            servings: chosen.servings,
            row,
            snapshot: { ...snap },
          },
          estimate: null,
          problem: null,
        };
      }
    }
    const estimate = { grams: item.grams ?? null, kcal: item.kcal, proteinG: item.proteinG, carbG: item.carbG, fatG: item.fatG };
    const check = checkEstimate(estimate);
    if (!check.ok) {
      return { ...base, confidence: 'low', match: null, estimate: null, problem: `Not in FITOS, and the estimate was not believable (${check.problem}). Enter it yourself.` };
    }
    return {
      ...base,
      confidence: 'low',
      match: null,
      estimate: { name: item.name.slice(0, 60), ...estimate },
      problem: null,
    };
  }
}
