import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/repositories/food_repository.dart';

/// A FITOS estimate: a range per serving, fibre not known.
const dalTadka = Food(
  id: '31111111-1111-4111-8111-111111111111',
  slug: 'dal-tadka',
  name: 'Dal tadka',
  brand: null,
  barcode: null,
  source: FoodSource.estimated,
  sourceRef:
      'FITOS estimate · core estimate table (packages/core mess/nutrition.ts) · "dal tadka"',
  isVerified: false,
  isCustom: false,
  aliases: ['dal', 'dhal', 'daal'],
  nutrition: [
    FoodNutrition(
      basis: NutritionBasis.perServing,
      servingLabel: '1 katori',
      servingGrams: 150,
      kcalLow: 120,
      kcalHigh: 185,
      proteinLow: 6,
      proteinHigh: 9,
      carbLow: 16,
      carbHigh: 23,
      fatLow: 3,
      fatHigh: 7.5,
      fibreLow: null,
      fibreHigh: null,
      confidence: NutritionConfidence.medium,
    ),
  ],
);

/// A verified USDA record: exact values, per 100 g and a USDA portion.
const honey = Food(
  id: '32222222-2222-4222-8222-222222222222',
  slug: 'honey',
  name: 'Honey',
  brand: null,
  barcode: null,
  source: FoodSource.usda,
  sourceRef: 'USDA FoodData Central · SR Legacy (April 2018) · FDC 169640',
  isVerified: true,
  isCustom: false,
  aliases: ['shahad'],
  nutrition: [
    FoodNutrition(
      basis: NutritionBasis.per100g,
      servingLabel: '100 g',
      servingGrams: 100,
      kcalLow: 304,
      kcalHigh: 304,
      proteinLow: 0.3,
      proteinHigh: 0.3,
      carbLow: 82.4,
      carbHigh: 82.4,
      fatLow: 0,
      fatHigh: 0,
      fibreLow: 0.2,
      fibreHigh: 0.2,
      confidence: NutritionConfidence.high,
    ),
    FoodNutrition(
      basis: NutritionBasis.perServing,
      servingLabel: '1 tbsp',
      servingGrams: 21,
      kcalLow: 64,
      kcalHigh: 64,
      proteinLow: 0.1,
      proteinHigh: 0.1,
      carbLow: 17.3,
      carbHigh: 17.3,
      fatLow: 0,
      fatHigh: 0,
      fibreLow: 0,
      fibreHigh: 0,
      confidence: NutritionConfidence.high,
    ),
  ],
);

/// The user's own food, from a label.
const lassi = Food(
  id: '33333333-3333-4333-8333-333333333333',
  slug: 'custom-33333333-3333-4333-8333-333333333333',
  name: 'Protein Lassi',
  brand: 'Amul',
  barcode: null,
  source: FoodSource.user,
  sourceRef: 'Custom food · entered from a label',
  isVerified: false,
  isCustom: true,
  aliases: [],
  nutrition: [
    FoodNutrition(
      basis: NutritionBasis.perServing,
      servingLabel: '1 bottle (200 ml)',
      servingGrams: 200,
      kcalLow: 160,
      kcalHigh: 160,
      proteinLow: 15,
      proteinHigh: 15,
      carbLow: 20,
      carbHigh: 20,
      fatLow: 2,
      fatHigh: 2,
      fibreLow: null,
      fibreHigh: null,
      confidence: NutritionConfidence.medium,
    ),
  ],
);

/// Scripted server. `results` answers every search unless `searchFailure`
/// is set; `createResults` answers creates in order (then echoes [lassi]).
class FakeFoodRepository implements FoodRepository {
  FakeFoodRepository({List<FoodSearchResult>? results})
      : results = results ??
            const <FoodSearchResult>[
              FoodSearchResult(food: dalTadka, match: FoodMatchKind.alias),
              FoodSearchResult(food: honey, match: FoodMatchKind.prefix),
            ];

  List<FoodSearchResult> results;
  Failure? searchFailure;
  final List<String> queries = <String>[];
  final List<CreateFoodRequest> created = <CreateFoodRequest>[];
  final List<Result<Food>> createResults = <Result<Food>>[];

  @override
  Future<Result<List<FoodSearchResult>>> search(
    String q, {
    int limit = 20,
  }) async {
    queries.add(q);
    final failure = searchFailure;
    if (failure != null) return Err(failure);
    return Ok(results);
  }

  @override
  Future<Result<Food>> create(CreateFoodRequest request) async {
    created.add(request);
    if (createResults.isNotEmpty) return createResults.removeAt(0);
    return const Ok(lassi);
  }
}
