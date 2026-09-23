// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FoodNutrition _$FoodNutritionFromJson(Map<String, dynamic> json) =>
    _FoodNutrition(
      basis: $enumDecode(_$NutritionBasisEnumMap, json['basis']),
      servingLabel: json['servingLabel'] as String,
      servingGrams: (json['servingGrams'] as num?)?.toDouble(),
      kcalLow: (json['kcalLow'] as num).toDouble(),
      kcalHigh: (json['kcalHigh'] as num).toDouble(),
      proteinLow: (json['proteinLow'] as num).toDouble(),
      proteinHigh: (json['proteinHigh'] as num).toDouble(),
      carbLow: (json['carbLow'] as num).toDouble(),
      carbHigh: (json['carbHigh'] as num).toDouble(),
      fatLow: (json['fatLow'] as num).toDouble(),
      fatHigh: (json['fatHigh'] as num).toDouble(),
      fibreLow: (json['fibreLow'] as num?)?.toDouble(),
      fibreHigh: (json['fibreHigh'] as num?)?.toDouble(),
      confidence: $enumDecode(_$NutritionConfidenceEnumMap, json['confidence']),
    );

Map<String, dynamic> _$FoodNutritionToJson(_FoodNutrition instance) =>
    <String, dynamic>{
      'basis': _$NutritionBasisEnumMap[instance.basis]!,
      'servingLabel': instance.servingLabel,
      'servingGrams': instance.servingGrams,
      'kcalLow': instance.kcalLow,
      'kcalHigh': instance.kcalHigh,
      'proteinLow': instance.proteinLow,
      'proteinHigh': instance.proteinHigh,
      'carbLow': instance.carbLow,
      'carbHigh': instance.carbHigh,
      'fatLow': instance.fatLow,
      'fatHigh': instance.fatHigh,
      'fibreLow': instance.fibreLow,
      'fibreHigh': instance.fibreHigh,
      'confidence': _$NutritionConfidenceEnumMap[instance.confidence]!,
    };

const _$NutritionBasisEnumMap = {
  NutritionBasis.per100g: 'per_100g',
  NutritionBasis.perServing: 'per_serving',
};

const _$NutritionConfidenceEnumMap = {
  NutritionConfidence.high: 'high',
  NutritionConfidence.medium: 'medium',
  NutritionConfidence.low: 'low',
};

_Food _$FoodFromJson(Map<String, dynamic> json) => _Food(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      source: $enumDecode(_$FoodSourceEnumMap, json['source']),
      sourceRef: json['sourceRef'] as String?,
      isVerified: json['isVerified'] as bool,
      isCustom: json['isCustom'] as bool,
      aliases:
          (json['aliases'] as List<dynamic>).map((e) => e as String).toList(),
      nutrition: (json['nutrition'] as List<dynamic>)
          .map((e) => FoodNutrition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FoodToJson(_Food instance) => <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'brand': instance.brand,
      'barcode': instance.barcode,
      'source': _$FoodSourceEnumMap[instance.source]!,
      'sourceRef': instance.sourceRef,
      'isVerified': instance.isVerified,
      'isCustom': instance.isCustom,
      'aliases': instance.aliases,
      'nutrition': instance.nutrition,
    };

const _$FoodSourceEnumMap = {
  FoodSource.estimated: 'estimated',
  FoodSource.usda: 'usda',
  FoodSource.ifct: 'ifct',
  FoodSource.indb: 'indb',
  FoodSource.user: 'user',
  FoodSource.userCorrected: 'user-corrected',
};

_FoodSearchResponse _$FoodSearchResponseFromJson(Map<String, dynamic> json) =>
    _FoodSearchResponse(
      items: _resultsFromJson(json['items'] as List),
    );

Map<String, dynamic> _$FoodSearchResponseToJson(_FoodSearchResponse instance) =>
    <String, dynamic>{
      'items': _resultsToJson(instance.items),
    };
