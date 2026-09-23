import 'package:freezed_annotation/freezed_annotation.dart';

part 'food.freezed.dart';
part 'food.g.dart';

/// Wire shapes and closed vocabularies of `@fitos/contracts` food.ts
/// (Phase 7). Every number here is the server's: a USDA record as USDA
/// publishes it, a FITOS estimate as a range, or the user's own label. The
/// client formats; it never computes, rounds toward, or invents a value —
/// an unknown fibre stays unknown (null), never 0.

/// Where a food's numbers come from (§13.3). The label is what the app
/// says about it, the short badge what a result row shows.
enum FoodSource {
  @JsonValue('estimated')
  estimated('estimated', 'FITOS estimate', 'Estimate'),
  @JsonValue('usda')
  usda('usda', 'USDA FoodData Central', 'USDA'),
  @JsonValue('ifct')
  ifct('ifct', 'IFCT 2017', 'IFCT'),
  @JsonValue('indb')
  indb('indb', 'Indian Nutrient Databank', 'INDB'),
  @JsonValue('user')
  user('user', 'Your food, from a label', 'Yours'),
  @JsonValue('user-corrected')
  userCorrected('user-corrected', 'Your correction', 'Corrected');

  const FoodSource(this.wire, this.label, this.badge);
  final String wire;
  final String label;
  final String badge;
}

enum NutritionBasis {
  @JsonValue('per_100g')
  per100g('per_100g', 'Per 100 g'),
  @JsonValue('per_serving')
  perServing('per_serving', 'Per serving');

  const NutritionBasis(this.wire, this.label);
  final String wire;
  final String label;
}

enum NutritionConfidence {
  @JsonValue('high')
  high('high', 'High confidence'),
  @JsonValue('medium')
  medium('medium', 'Medium confidence'),
  @JsonValue('low')
  low('low', 'Low confidence');

  const NutritionConfidence(this.wire, this.label);
  final String wire;
  final String label;
}

/// How a search result matched the query, best first.
enum FoodMatchKind {
  @JsonValue('exact')
  exact('exact'),
  @JsonValue('alias')
  alias('alias'),
  @JsonValue('prefix')
  prefix('prefix'),
  @JsonValue('fuzzy')
  fuzzy('fuzzy');

  const FoodMatchKind(this.wire);
  final String wire;
}

/// One nutrition row: per 100 g or per a named serving. `low == high` is an
/// exact value (a USDA record, a label); otherwise it is an estimate's range.
@freezed
abstract class FoodNutrition with _$FoodNutrition {
  const FoodNutrition._();

  const factory FoodNutrition({
    required NutritionBasis basis,
    required String servingLabel,
    required double? servingGrams,
    required double kcalLow,
    required double kcalHigh,
    required double proteinLow,
    required double proteinHigh,
    required double carbLow,
    required double carbHigh,
    required double fatLow,
    required double fatHigh,
    required double? fibreLow,
    required double? fibreHigh,
    required NutritionConfidence confidence,
  }) = _FoodNutrition;

  factory FoodNutrition.fromJson(Map<String, dynamic> json) =>
      _$FoodNutritionFromJson(json);

  bool get isExact =>
      kcalLow == kcalHigh &&
      proteinLow == proteinHigh &&
      carbLow == carbHigh &&
      fatLow == fatHigh &&
      fibreLow == fibreHigh;

  bool get fibreKnown => fibreLow != null && fibreHigh != null;
}

@freezed
abstract class Food with _$Food {
  const Food._();

  const factory Food({
    required String id,
    required String slug,
    required String name,
    required String? brand,
    required String? barcode,
    required FoodSource source,
    required String? sourceRef,
    required bool isVerified,
    required bool isCustom,
    required List<String> aliases,
    required List<FoodNutrition> nutrition,
  }) = _Food;

  factory Food.fromJson(Map<String, dynamic> json) => _$FoodFromJson(json);

  /// The row a list shows: the first named serving when there is one (what
  /// people eat), else per 100 g.
  FoodNutrition get headline => nutrition.firstWhere(
        (n) => n.basis == NutritionBasis.perServing,
        orElse: () => nutrition.first,
      );

  bool get isEstimate => source == FoodSource.estimated;
}

/// A search hit: the food plus how it matched. The server sends one flat
/// object (`Food` + `match`), so this is written by hand around [Food].
class FoodSearchResult {
  const FoodSearchResult({required this.food, required this.match});

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) =>
      FoodSearchResult(
        food: Food.fromJson(json),
        match: FoodMatchKind.values.firstWhere(
          (m) => m.wire == json['match'],
          orElse: () => FoodMatchKind.fuzzy,
        ),
      );

  final Food food;
  final FoodMatchKind match;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...food.toJson(),
        'match': match.wire,
      };
}

@freezed
abstract class FoodSearchResponse with _$FoodSearchResponse {
  const factory FoodSearchResponse({
    @JsonKey(fromJson: _resultsFromJson, toJson: _resultsToJson)
    required List<FoodSearchResult> items,
  }) = _FoodSearchResponse;

  factory FoodSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodSearchResponseFromJson(json);
}

List<FoodSearchResult> _resultsFromJson(List<dynamic> json) => json
    .map((e) => FoodSearchResult.fromJson(e as Map<String, dynamic>))
    .toList();

List<Map<String, dynamic>> _resultsToJson(List<FoodSearchResult> items) =>
    items.map((r) => r.toJson()).toList();

/// `POST /nutrition/foods`: a custom food from a label. `clientFoodId` is
/// minted once per form, so a resend after a lost reply is the same food.
/// Written by hand: `servingLabel` is omitted (not null) for a per-100 g
/// label, exactly as the contract accepts it.
class CreateFoodRequest {
  const CreateFoodRequest({
    required this.clientFoodId,
    required this.name,
    required this.brand,
    required this.basis,
    required this.servingLabel,
    required this.servingGrams,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.fibreG,
  });

  final String clientFoodId;
  final String name;
  final String? brand;
  final NutritionBasis basis;
  final String? servingLabel;
  final double? servingGrams;
  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  /// Null when the label does not state fibre — never sent as 0.
  final double? fibreG;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientFoodId': clientFoodId,
        'name': name,
        'brand': brand,
        'basis': basis.wire,
        if (servingLabel != null) 'servingLabel': servingLabel,
        'servingGrams': servingGrams,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbG': carbG,
        'fatG': fatG,
        'fibreG': fibreG,
      };
}
