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

/// Beta 5.5: a mess dish seen in a photo — Phulka at 2 servings, the mess
/// table's numbers per serving and at 2.
const phulkaDish = DraftMessDish(
  dishSlug: 'phulka',
  name: 'Phulka',
  servingLabel: '1 piece',
  servings: 2,
  perServing: {
    'kcalLow': 85,
    'kcalHigh': 120,
    'proteinLow': 2.5,
    'proteinHigh': 3.6,
    'carbLow': 16,
    'carbHigh': 22,
    'fatLow': 0.8,
    'fatHigh': 3,
  },
  snapshot: {
    'kcalLow': 170,
    'kcalHigh': 240,
    'proteinLow': 5,
    'proteinHigh': 7.2,
    'carbLow': 32,
    'carbHigh': 44,
    'fatLow': 1.6,
    'fatHigh': 6,
  },
);

/// Beta 5.5: the answer to a meal photo — a mess dish on the menu, a FITOS
/// food and an estimate, against today's lunch menu of mens-veg.
ParseFoodPhotoResponse photoDraft({String? messCode = 'mens-veg'}) =>
    ParseFoodPhotoResponse(
      model: 'fake-1',
      messCode: messCode,
      menuDate: messCode == null ? null : '2026-09-24',
      draft: FoodDraft(
        confidence: AiConfidence.medium,
        items: [
          const DraftItem(
            phrase: 'two phulka',
            quantity: 2,
            unit: 'serving',
            confidence: AiConfidence.medium,
            messDish: phulkaDish,
          ),
          DraftItem(
            phrase: 'a katori of dal',
            quantity: 1,
            unit: 'katori',
            confidence: AiConfidence.medium,
            match: dalMatch,
          ),
          const DraftItem(
            phrase: 'a zqxv bar',
            quantity: 1,
            unit: 'piece',
            confidence: AiConfidence.low,
            estimate: barEstimate,
          ),
        ],
      ),
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
