import 'package:fitos/features/ai/domain/entities/ai_draft.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';

import 'fake_food_repository.dart';

/// Phase 14 fixtures: a FITOS AI meal draft as the server sends it — a
/// database food at 2 servings (unsure), one at 1, an estimate for a food
/// FITOS lacks, and one whose estimate was not believable.
const chapatiRow = FoodNutrition(
  basis: NutritionBasis.perServing,
  servingLabel: '1 piece',
  servingGrams: 40,
  kcalLow: 85,
  kcalHigh: 120,
  proteinLow: 2.5,
  proteinHigh: 4,
  carbLow: 15,
  carbHigh: 20,
  fatLow: 0.5,
  fatHigh: 3.5,
  fibreLow: null,
  fibreHigh: null,
  confidence: NutritionConfidence.medium,
);

const chapati = Food(
  id: '41111111-1111-4111-8111-111111111111',
  slug: 'chapati',
  name: 'Chapati',
  brand: null,
  barcode: null,
  source: FoodSource.estimated,
  sourceRef: 'FITOS estimate · "chapati"',
  isVerified: false,
  isCustom: false,
  aliases: ['roti', 'phulka'],
  nutrition: [chapatiRow],
);

const chapatiMatch = DraftMatch(
  foodId: '41111111-1111-4111-8111-111111111111',
  name: 'Chapati',
  matchKind: FoodMatchKind.exact,
  servings: 2,
  row: chapatiRow,
  snapshot: {
    'kcalLow': 170,
    'kcalHigh': 240,
    'proteinLow': 5,
    'proteinHigh': 8,
    'carbLow': 30,
    'carbHigh': 40,
    'fatLow': 1,
    'fatHigh': 7,
  },
);

final dalMatch = DraftMatch(
  foodId: dalTadka.id,
  name: dalTadka.name,
  matchKind: FoodMatchKind.alias,
  servings: 1,
  row: dalTadka.nutrition.single,
  snapshot: const {
    'kcalLow': 120,
    'kcalHigh': 185,
    'proteinLow': 6,
    'proteinHigh': 9,
    'carbLow': 16,
    'carbHigh': 23,
    'fatLow': 3,
    'fatHigh': 7.5,
  },
);

const barEstimate = DraftEstimate(
  name: 'Zqxv crunch bar',
  grams: 40,
  kcal: 180,
  proteinG: 8,
  carbG: 22,
  fatG: 7,
);

ParseFoodResponse mealDraft() => ParseFoodResponse(
      model: 'fake-1',
      draft: FoodDraft(
        confidence: AiConfidence.low,
        items: [
          const DraftItem(
            phrase: '2 chapati',
            quantity: 2,
            unit: 'piece',
            confidence: AiConfidence.medium,
            match: chapatiMatch,
          ),
          DraftItem(
            phrase: 'a katori of dal',
            quantity: 1,
            unit: 'katori',
            confidence: AiConfidence.high,
            match: dalMatch,
          ),
          const DraftItem(
            phrase: 'a zqxv bar',
            quantity: 1,
            unit: 'piece',
            confidence: AiConfidence.low,
            estimate: barEstimate,
          ),
          const DraftItem(
            phrase: 'mystery shake',
            quantity: 1,
            unit: 'glass',
            confidence: AiConfidence.low,
            problem:
                'Not in FITOS, and the estimate was not believable (kcal per 100 g). Enter it yourself.',
          ),
        ],
      ),
    );
