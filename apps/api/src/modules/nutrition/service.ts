/**
 * Food library service (Phase 7): search and custom foods. Nutrition numbers
 * are never computed here — they come from the seed (USDA records, FITOS
 * estimates) or from the user's label; this layer only maps and guards.
 */
import {
  exactFoodNutrition,
  normaliseFoodText,
  validateFoodNutrition,
  validateSourceClaims,
} from '@fitos/core/nutrition/food';
import type { CreateFoodRequest, Food, FoodMatchKind, FoodNutrition, FoodSearchQuery, FoodSearchResponse } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { FoodNutritionRow } from '../../db/schema.js';
import type { FoodDetailRows, FoodRepository, SearchTier } from './repository.js';

const MATCH_FOR_TIER: Readonly<Record<SearchTier, FoodMatchKind>> = {
  0: 'exact',
  1: 'alias',
  2: 'prefix',
  3: 'prefix',
  4: 'fuzzy',
};

const toNumber = (v: string): number => Number(v);
const toNumberOrNull = (v: string | null): number | null => (v === null ? null : Number(v));

function nutritionFrom(n: FoodNutritionRow): FoodNutrition {
  return {
    basis: n.basis,
    servingLabel: n.servingLabel,
    servingGrams: toNumberOrNull(n.servingGrams),
    kcalLow: toNumber(n.kcalLow),
    kcalHigh: toNumber(n.kcalHigh),
    proteinLow: toNumber(n.proteinLow),
    proteinHigh: toNumber(n.proteinHigh),
    carbLow: toNumber(n.carbLow),
    carbHigh: toNumber(n.carbHigh),
    fatLow: toNumber(n.fatLow),
    fatHigh: toNumber(n.fatHigh),
    fibreLow: toNumberOrNull(n.fibreLow),
    fibreHigh: toNumberOrNull(n.fibreHigh),
    confidence: n.confidence,
  };
}

export function foodFrom(d: FoodDetailRows, userId: string): Food {
  return {
    id: d.food.id,
    slug: d.food.slug,
    name: d.food.name,
    brand: d.food.brand,
    barcode: d.food.barcode,
    source: d.food.source,
    sourceRef: d.food.sourceRef,
    isVerified: d.food.isVerified,
    isCustom: d.food.ownerUserId !== null && d.food.ownerUserId === userId,
    aliases: [...d.aliases],
    nutrition: d.nutrition.map(nutritionFrom),
  };
}

export class FoodService {
  constructor(private readonly repo: FoodRepository) {}

  async search(userId: string, query: FoodSearchQuery): Promise<FoodSearchResponse> {
    const q = normaliseFoodText(query.q);
    if (q === '') return { items: [] };
    const hits = await this.repo.search(q, userId, query.limit);
    const details = await this.repo.details(
      hits.map((h) => h.id),
      userId,
    );
    const tierById = new Map(hits.map((h) => [h.id, h.tier]));
    return {
      items: details.map((d) => ({ ...foodFrom(d, userId), match: MATCH_FOR_TIER[tierById.get(d.food.id) as SearchTier] })),
    };
  }

  async create(userId: string, body: CreateFoodRequest): Promise<{ food: Food; created: boolean }> {
    const values = exactFoodNutrition({
      kcal: body.kcal,
      protein: body.proteinG,
      carb: body.carbG,
      fat: body.fatG,
      fibre: body.fibreG ?? null,
    });
    const perHundred = body.basis === 'per_100g';
    const issues = [
      ...validateFoodNutrition(values, body.basis),
      ...validateSourceClaims('user', false, 'medium'),
    ];
    if (issues.length > 0) {
      throw new AppError(
        'VALIDATION_FAILED',
        'Those values are not possible for a food.',
        issues.map((i) => ({ path: i.field, issue: i.problem })),
      );
    }
    const m = values.macros;
    const { id, created } = await this.repo.createCustom({
      ownerUserId: userId,
      clientFoodId: body.clientFoodId,
      name: body.name,
      brand: body.brand ?? null,
      nutrition: {
        basis: body.basis,
        servingLabel: perHundred ? '100 g' : (body.servingLabel as string),
        servingGrams: perHundred ? '100' : body.servingGrams === undefined || body.servingGrams === null ? null : String(body.servingGrams),
        kcalLow: String(m.kcalLow),
        kcalHigh: String(m.kcalHigh),
        proteinLow: String(m.proteinLow),
        proteinHigh: String(m.proteinHigh),
        carbLow: String(m.carbLow),
        carbHigh: String(m.carbHigh),
        fatLow: String(m.fatLow),
        fatHigh: String(m.fatHigh),
        fibreLow: values.fibre === null ? null : String(values.fibre.low),
        fibreHigh: values.fibre === null ? null : String(values.fibre.high),
        confidence: 'medium',
      },
    });
    const [detail] = await this.repo.details([id], userId);
    if (detail === undefined) throw new AppError('INTERNAL', 'The food was saved but could not be read back.');
    return { food: foodFrom(detail, userId), created };
  }
}
