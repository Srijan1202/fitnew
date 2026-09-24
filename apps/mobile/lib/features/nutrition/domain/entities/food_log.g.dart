// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FoodLogItem _$FoodLogItemFromJson(Map<String, dynamic> json) => _FoodLogItem(
      id: json['id'] as String,
      position: (json['position'] as num).toInt(),
      foodId: json['foodId'] as String?,
      messDishSlug: json['messDishSlug'] as String? ?? null,
      foodName: json['foodName'] as String,
      foodSource: $enumDecode(_$FoodSourceEnumMap, json['foodSource']),
      basis: $enumDecodeNullable(_$NutritionBasisEnumMap, json['basis']),
      servingLabel: json['servingLabel'] as String?,
      servingGrams: (json['servingGrams'] as num?)?.toDouble(),
      servings: (json['servings'] as num).toDouble(),
      grams: (json['grams'] as num?)?.toDouble(),
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

Map<String, dynamic> _$FoodLogItemToJson(_FoodLogItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'position': instance.position,
      'foodId': instance.foodId,
      'messDishSlug': instance.messDishSlug,
      'foodName': instance.foodName,
      'foodSource': _$FoodSourceEnumMap[instance.foodSource]!,
      'basis': _$NutritionBasisEnumMap[instance.basis],
      'servingLabel': instance.servingLabel,
      'servingGrams': instance.servingGrams,
      'servings': instance.servings,
      'grams': instance.grams,
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

const _$FoodSourceEnumMap = {
  FoodSource.estimated: 'estimated',
  FoodSource.usda: 'usda',
  FoodSource.ifct: 'ifct',
  FoodSource.indb: 'indb',
  FoodSource.user: 'user',
  FoodSource.userCorrected: 'user-corrected',
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

_NutritionTotals _$NutritionTotalsFromJson(Map<String, dynamic> json) =>
    _NutritionTotals(
      kcalLow: (json['kcalLow'] as num).toDouble(),
      kcalHigh: (json['kcalHigh'] as num).toDouble(),
      proteinLow: (json['proteinLow'] as num).toDouble(),
      proteinHigh: (json['proteinHigh'] as num).toDouble(),
      carbLow: (json['carbLow'] as num).toDouble(),
      carbHigh: (json['carbHigh'] as num).toDouble(),
      fatLow: (json['fatLow'] as num).toDouble(),
      fatHigh: (json['fatHigh'] as num).toDouble(),
      fibreKnownLow: (json['fibreKnownLow'] as num).toDouble(),
      fibreKnownHigh: (json['fibreKnownHigh'] as num).toDouble(),
      fibreUnknownItems: (json['fibreUnknownItems'] as num).toInt(),
      itemCount: (json['itemCount'] as num).toInt(),
    );

Map<String, dynamic> _$NutritionTotalsToJson(_NutritionTotals instance) =>
    <String, dynamic>{
      'kcalLow': instance.kcalLow,
      'kcalHigh': instance.kcalHigh,
      'proteinLow': instance.proteinLow,
      'proteinHigh': instance.proteinHigh,
      'carbLow': instance.carbLow,
      'carbHigh': instance.carbHigh,
      'fatLow': instance.fatLow,
      'fatHigh': instance.fatHigh,
      'fibreKnownLow': instance.fibreKnownLow,
      'fibreKnownHigh': instance.fibreKnownHigh,
      'fibreUnknownItems': instance.fibreUnknownItems,
      'itemCount': instance.itemCount,
    };

_FoodLog _$FoodLogFromJson(Map<String, dynamic> json) => _FoodLog(
      id: json['id'] as String,
      clientLogId: json['clientLogId'] as String,
      loggedAt: json['loggedAt'] as String,
      localDate: json['localDate'] as String,
      mealSlot: $enumDecode(_$MealSlotEnumMap, json['mealSlot']),
      entryMethod: $enumDecode(_$EntryMethodEnumMap, json['entryMethod']),
      savedMealId: json['savedMealId'] as String?,
      messCode: json['messCode'] as String? ?? null,
      items: (json['items'] as List<dynamic>)
          .map((e) => FoodLogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totals: NutritionTotals.fromJson(json['totals'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FoodLogToJson(_FoodLog instance) => <String, dynamic>{
      'id': instance.id,
      'clientLogId': instance.clientLogId,
      'loggedAt': instance.loggedAt,
      'localDate': instance.localDate,
      'mealSlot': _$MealSlotEnumMap[instance.mealSlot]!,
      'entryMethod': _$EntryMethodEnumMap[instance.entryMethod]!,
      'savedMealId': instance.savedMealId,
      'messCode': instance.messCode,
      'items': instance.items,
      'totals': instance.totals,
    };

const _$MealSlotEnumMap = {
  MealSlot.breakfast: 'breakfast',
  MealSlot.lunch: 'lunch',
  MealSlot.snacks: 'snacks',
  MealSlot.dinner: 'dinner',
};

const _$EntryMethodEnumMap = {
  EntryMethod.search: 'search',
  EntryMethod.quickAdd: 'quick-add',
  EntryMethod.savedMeal: 'saved-meal',
  EntryMethod.mess: 'mess',
};

_RemainingRange _$RemainingRangeFromJson(Map<String, dynamic> json) =>
    _RemainingRange(
      target: (json['target'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      state: $enumDecode(_$RemainingStateEnumMap, json['state']),
    );

Map<String, dynamic> _$RemainingRangeToJson(_RemainingRange instance) =>
    <String, dynamic>{
      'target': instance.target,
      'low': instance.low,
      'high': instance.high,
      'state': _$RemainingStateEnumMap[instance.state]!,
    };

const _$RemainingStateEnumMap = {
  RemainingState.under: 'under',
  RemainingState.around: 'around',
  RemainingState.over: 'over',
};

_NutritionRemaining _$NutritionRemainingFromJson(Map<String, dynamic> json) =>
    _NutritionRemaining(
      kcal: RemainingRange.fromJson(json['kcal'] as Map<String, dynamic>),
      protein: RemainingRange.fromJson(json['protein'] as Map<String, dynamic>),
      carb: RemainingRange.fromJson(json['carb'] as Map<String, dynamic>),
      fat: RemainingRange.fromJson(json['fat'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$NutritionRemainingToJson(_NutritionRemaining instance) =>
    <String, dynamic>{
      'kcal': instance.kcal,
      'protein': instance.protein,
      'carb': instance.carb,
      'fat': instance.fat,
    };

_NutritionDay _$NutritionDayFromJson(Map<String, dynamic> json) =>
    _NutritionDay(
      date: json['date'] as String,
      today: json['today'] as String,
      timezone: json['timezone'] as String,
      targets: json['targets'] == null
          ? null
          : NutritionTargets.fromJson(json['targets'] as Map<String, dynamic>),
      totals: NutritionTotals.fromJson(json['totals'] as Map<String, dynamic>),
      remaining: json['remaining'] == null
          ? null
          : NutritionRemaining.fromJson(
              json['remaining'] as Map<String, dynamic>),
      logs: (json['logs'] as List<dynamic>)
          .map((e) => FoodLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$NutritionDayToJson(_NutritionDay instance) =>
    <String, dynamic>{
      'date': instance.date,
      'today': instance.today,
      'timezone': instance.timezone,
      'targets': instance.targets,
      'totals': instance.totals,
      'remaining': instance.remaining,
      'logs': instance.logs,
    };

_CreateLogResponse _$CreateLogResponseFromJson(Map<String, dynamic> json) =>
    _CreateLogResponse(
      log: FoodLog.fromJson(json['log'] as Map<String, dynamic>),
      day: NutritionDay.fromJson(json['day'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CreateLogResponseToJson(_CreateLogResponse instance) =>
    <String, dynamic>{
      'log': instance.log,
      'day': instance.day,
    };

_DeleteLogResponse _$DeleteLogResponseFromJson(Map<String, dynamic> json) =>
    _DeleteLogResponse(
      day: NutritionDay.fromJson(json['day'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeleteLogResponseToJson(_DeleteLogResponse instance) =>
    <String, dynamic>{
      'day': instance.day,
    };

_RecentFood _$RecentFoodFromJson(Map<String, dynamic> json) => _RecentFood(
      food: Food.fromJson(json['food'] as Map<String, dynamic>),
      lastLoggedAt: json['lastLoggedAt'] as String,
      lastBasis: $enumDecode(_$NutritionBasisEnumMap, json['lastBasis']),
      lastServingLabel: json['lastServingLabel'] as String,
      lastServings: (json['lastServings'] as num).toDouble(),
    );

Map<String, dynamic> _$RecentFoodToJson(_RecentFood instance) =>
    <String, dynamic>{
      'food': instance.food,
      'lastLoggedAt': instance.lastLoggedAt,
      'lastBasis': _$NutritionBasisEnumMap[instance.lastBasis]!,
      'lastServingLabel': instance.lastServingLabel,
      'lastServings': instance.lastServings,
    };

_RecentFoodsResponse _$RecentFoodsResponseFromJson(Map<String, dynamic> json) =>
    _RecentFoodsResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => RecentFood.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RecentFoodsResponseToJson(
        _RecentFoodsResponse instance) =>
    <String, dynamic>{
      'items': instance.items,
    };
