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
 *
 * Beta 5.5 (owner): the same from a PHOTO. The photo goes to the model with
 * the dish names of the person's mess menu for that meal (when they have a
 * mess); a dish it picks from the menu comes back as a mess dish at the mess
 * table's numbers. The photo is held for this one call and never stored.
 */
import { z } from 'zod';

import {
  DRAFT_MESS_SERVINGS_MAX,
  PHOTO_MAX_BYTES,
  type DraftItem,
  type Food,
  type MealSlot,
  type ParseFoodPhotoRequest,
  type ParseFoodPhotoResponse,
  type ParseFoodResponse,
} from '@fitos/contracts';
import { checkEstimate, draftOf, lowestConfidence, type AiConfidence } from '@fitos/core/ai/guard';
import { choosePortion } from '@fitos/core/ai/portion';
import { snapshotNutrition } from '@fitos/core/nutrition/log';
import type { FoodNutritionRange } from '@fitos/core/nutrition/food';

import { AppError } from '../../lib/errors.js';
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
/** Beta 5.5: a photo's item may name a dish on the menu it was given (1-based); anything else is no dish. */
const photoItemSchema = modelItemSchema.extend({ menuDish: z.coerce.number().int().positive().nullable().optional().catch(null) });
const photoAnswerSchema = z.object({ items: z.array(photoItemSchema).max(PARSE_MAX_ITEMS) });
type PhotoItem = z.infer<typeof photoItemSchema>;

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

/** Beta 5.5: at most this many menu dishes go with a photo. */
export const PHOTO_MENU_MAX = 25;

export const PHOTO_SYSTEM = [
  'You look at a photo of a meal (often Indian food, often a hostel mess plate or a thali) and list the foods you can see.',
  'Answer with JSON only, exactly this shape:',
  '{"items":[{"phrase":"what you see, in a few words","name":"the food\'s common English name (Indian dishes in their usual spelling, e.g. chapati, dal tadka, idli, poha)","quantity":2,"unit":"piece | katori | bowl | cup | glass | plate | tbsp | tsp | slice | serving | g | ml","grams":80,"kcal":240,"proteinG":7,"carbG":44,"fatG":4,"confidence":"high | medium | low","menuDish":null}]}',
  'Rules:',
  '- One item per food you can see. At most 8 items. Never list a food you cannot see; the plate, cutlery and packaging are not food.',
  '- quantity and unit: your best estimate of the amount in the photo, in everyday units.',
  '- grams is your estimate of the whole portion\'s weight, or null when you cannot tell.',
  '- kcal, proteinG, carbG and fatG are your estimate for the whole portion.',
  '- confidence is how sure you are about the food and the amount; an amount seen in a photo is rarely certain.',
  '- When the message lists a menu: if a food is one of those dishes, set menuDish to its number, name to that dish\'s name exactly, unit to "serving" and quantity to the number of that dish\'s servings you see (1.5 is one and a half). Otherwise menuDish is null.',
  '- If the photo shows no food, answer {"items":[]}.',
].join('\n');

/** Beta 5.5: the person's mess menu for the meal in the photo; dishes with the mess table's numbers only. */
export interface PhotoMenu {
  readonly code: string;
  readonly menuDate: string;
  readonly dishes: readonly {
    readonly slug: string;
    readonly name: string;
    readonly servingLabel: string;
    readonly servingGrams: number | null;
    readonly macros: FoodNutritionRange['macros'];
  }[];
}

/** Where the photo's menu comes from (the routes wire the mess services in). */
export interface PhotoMenuSource {
  menuFor(userId: string, slot: MealSlot, date: string | undefined): Promise<PhotoMenu | null>;
}

const MAGIC: Readonly<Record<ParseFoodPhotoRequest['mimeType'], (b: Buffer) => boolean>> = {
  'image/jpeg': (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,
  'image/png': (b) => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
  'image/webp': (b) => b.subarray(0, 4).toString('latin1') === 'RIFF' && b.subarray(8, 12).toString('latin1') === 'WEBP',
};

/** The photo's bytes, when they are within the size and really are the type they claim. */
export function photoBytes(body: Pick<ParseFoodPhotoRequest, 'image' | 'mimeType'>): Buffer {
  const bytes = Buffer.from(body.image, 'base64');
  if (bytes.length === 0 || bytes.length > PHOTO_MAX_BYTES || !MAGIC[body.mimeType](bytes)) {
    throw new AppError('VALIDATION_FAILED', 'That photo could not be read. Take it again.', [
      { path: 'image', issue: bytes.length > PHOTO_MAX_BYTES ? 'larger than 1.5 MB' : `not a ${body.mimeType} image` },
    ]);
  }
  return bytes;
}

/** The menu as the model sees it: numbered names and servings only. */
export function photoMenuText(slot: MealSlot, menu: PhotoMenu | null): string {
  if (menu === null || menu.dishes.length === 0) return `A photo of a ${slot}.`;
  const lines = menu.dishes.map((d, i) => `${i + 1}. ${d.name} (a serving is ${d.servingLabel})`);
  return [`A photo of a ${slot}. This ${slot} menu is at the person's mess that day:`, ...lines].join('\n');
}

/** Servings of a menu dish from the model's amount: in quarters, 0.25–10. */
export function messServings(item: Pick<PhotoItem, 'quantity' | 'unit'>, servingGrams: number | null): number {
  const raw = item.unit === 'g' && servingGrams !== null && servingGrams > 0 ? item.quantity / servingGrams : item.quantity;
  return Math.min(DRAFT_MESS_SERVINGS_MAX, Math.max(0.25, Math.round(raw * 4) / 4));
}

export function rangeOf(row: Food['nutrition'][number]): FoodNutritionRange {
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
    /** Beta 5.5: the mess menu a photo is read against; absent → none. */
    private readonly menus?: PhotoMenuSource,
  ) {}

  private get model(): string {
    return this.config.models.parse ?? this.provider.model;
  }

  async parse(userId: string, text: string, premium = false): Promise<ParseFoodResponse> {
    await this.budget.check(userId, 'parse', premium);
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

  /**
   * Beta 5.5: a meal photo → a draft. Checked before anything is spent; the
   * photo goes to the model with the menu's dish names and is then dropped.
   */
  async parsePhoto(userId: string, body: ParseFoodPhotoRequest, premium = false): Promise<ParseFoodPhotoResponse> {
    photoBytes(body);
    await this.budget.check(userId, 'photo', premium);
    if (this.provider.name === 'none') throw AiService.toAppError(new AiProviderError('not_configured', 'no provider'));
    const found = (await this.menus?.menuFor(userId, body.slot, body.date)) ?? null;
    const menu = found === null || found.dishes.length === 0 ? null : { ...found, dishes: found.dishes.slice(0, PHOTO_MENU_MAX) };

    let answer: z.infer<typeof photoAnswerSchema>;
    let usage: { inputTokens: number; outputTokens: number } | undefined;
    let model = this.model;
    try {
      const response = await this.provider.generate({
        system: PHOTO_SYSTEM,
        messages: [{ role: 'user', content: photoMenuText(body.slot, menu), images: [{ mimeType: body.mimeType, data: body.image }] }],
        jsonMode: true,
        temperature: 0,
        ...(this.config.models.parse !== null ? { model: this.config.models.parse } : {}),
      });
      usage = response.usage;
      model = response.model ?? model;
      answer = FoodParseService.read(response.text, photoAnswerSchema);
    } catch (e) {
      if (e instanceof AiProviderError) {
        this.log?.warn({ kind: e.kind, upstreamStatus: e.status ?? null, model }, 'ai photo: provider failure');
      }
      await this.budget.record(userId, 'photo', model, usage, 'failed');
      throw AiService.toAppError(e);
    }

    const items: DraftItem[] = [];
    const dishLines = new Map<string, number>();
    for (const item of answer.items) {
      const dish = menu !== null && item.menuDish !== null && item.menuDish !== undefined ? menu.dishes[item.menuDish - 1] : undefined;
      if (dish === undefined) {
        // Portions from a photo are never certain.
        const resolved = await this.resolve(userId, item);
        items.push({ ...resolved, confidence: atMost(resolved.confidence, 'medium') });
        continue;
      }
      // The same dish twice (two rotis seen apart) is one line.
      const at = dishLines.get(dish.slug);
      const earlier = at === undefined ? undefined : items[at];
      const servings = Math.min(DRAFT_MESS_SERVINGS_MAX, messServings(item, dish.servingGrams) + (earlier?.messDish?.servings ?? 0));
      const line: DraftItem = {
        phrase: earlier?.phrase ?? item.phrase,
        quantity: servings,
        unit: 'serving',
        confidence: atMost(item.confidence, 'medium'),
        match: null,
        messDish: {
          dishSlug: dish.slug,
          name: dish.name,
          servingLabel: dish.servingLabel,
          servings,
          perServing: { ...dish.macros },
          snapshot: { ...snapshotNutrition({ macros: dish.macros, fibre: null }, servings).macros },
        },
        estimate: null,
        problem: null,
      };
      if (at !== undefined) {
        items[at] = line;
      } else {
        dishLines.set(dish.slug, items.length);
        items.push(line);
      }
    }
    await this.budget.record(userId, 'photo', model, usage, items.length === 0 ? 'discarded' : 'ok');
    const draft = draftOf({ items }, items.length === 0 ? 'low' : lowestConfidence(items.map((i) => i.confidence)));
    return {
      draft: { ...draft, data: { items: [...draft.data.items] } },
      mess: menu === null ? null : { code: menu.code, menuDate: menu.menuDate },
      model,
    };
  }

  /** The model's JSON, checked; a code fence around it is tolerated. */
  static read(raw: string): z.infer<typeof modelAnswerSchema>;
  static read<S extends z.ZodTypeAny>(raw: string, schema: S): z.infer<S>;
  static read(raw: string, schema: z.ZodTypeAny = modelAnswerSchema): unknown {
    const text = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    let json: unknown;
    try {
      json = JSON.parse(text);
    } catch {
      throw new AiProviderError('malformed', 'The model did not answer with JSON.');
    }
    const parsed = schema.safeParse(json);
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
          messDish: null,
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
      return { ...base, confidence: 'low', match: null, messDish: null, estimate: null, problem: `Not in FITOS, and the estimate was not believable (${check.problem}). Enter it yourself.` };
    }
    return {
      ...base,
      confidence: 'low',
      match: null,
      messDish: null,
      estimate: { name: item.name.slice(0, 60), ...estimate },
      problem: null,
    };
  }
}
