import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../profile/domain/entities/profile.dart';
import 'food.dart';

part 'food_log.freezed.dart';
part 'food_log.g.dart';

/// Wire shapes of `@fitos/contracts` nutrition-log.ts (Phase 8). Every
/// logged number is the server's snapshot, taken when the food was logged;
/// every total is the server's sum. The app renders them. The only numbers
/// the app computes are the display-only portion previews (owner J10), and
/// those never stand in for a total.

enum MealSlot {
  @JsonValue('breakfast')
  breakfast('breakfast', 'Breakfast'),
  @JsonValue('lunch')
  lunch('lunch', 'Lunch'),
  @JsonValue('snacks')
  snacks('snacks', 'Snacks'),
  @JsonValue('dinner')
  dinner('dinner', 'Dinner');

  const MealSlot(this.wire, this.label);
  final String wire;
  final String label;

  static MealSlot fromWire(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => MealSlot.snacks);

  /// The default slot by local hour — a default only; the user picks.
  static MealSlot forHour(int hour) => hour < 11
      ? MealSlot.breakfast
      : hour < 16
          ? MealSlot.lunch
          : hour < 19
              ? MealSlot.snacks
              : MealSlot.dinner;
}

enum EntryMethod {
  @JsonValue('search')
  search('search'),
  @JsonValue('quick-add')
  quickAdd('quick-add'),
  @JsonValue('saved-meal')
  savedMeal('saved-meal');

  const EntryMethod(this.wire);
  final String wire;
}

enum RemainingState {
  @JsonValue('under')
  under('under'),
  @JsonValue('around')
  around('around'),
  @JsonValue('over')
  over('over');

  const RemainingState(this.wire);
  final String wire;
}

@freezed
abstract class FoodLogItem with _$FoodLogItem {
  const FoodLogItem._();

  const factory FoodLogItem({
    required String id,
    required int position,
    required String? foodId,
    required String foodName,
    required FoodSource foodSource,
    required NutritionBasis? basis,
    required String? servingLabel,
    required double? servingGrams,
    required double servings,
    required double? grams,
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
  }) = _FoodLogItem;

  factory FoodLogItem.fromJson(Map<String, dynamic> json) =>
      _$FoodLogItemFromJson(json);

  bool get isQuickAdd => basis == null;
}

@freezed
abstract class NutritionTotals with _$NutritionTotals {
  const NutritionTotals._();

  const factory NutritionTotals({
    required double kcalLow,
    required double kcalHigh,
    required double proteinLow,
    required double proteinHigh,
    required double carbLow,
    required double carbHigh,
    required double fatLow,
    required double fatHigh,
    required double fibreKnownLow,
    required double fibreKnownHigh,
    required int fibreUnknownItems,
    required int itemCount,
  }) = _NutritionTotals;

  factory NutritionTotals.fromJson(Map<String, dynamic> json) =>
      _$NutritionTotalsFromJson(json);

  bool get isEmpty => itemCount == 0;
}

@freezed
abstract class FoodLog with _$FoodLog {
  const factory FoodLog({
    required String id,
    required String clientLogId,
    required String loggedAt,
    required String localDate,
    required MealSlot mealSlot,
    required EntryMethod entryMethod,
    required String? savedMealId,
    required List<FoodLogItem> items,
    required NutritionTotals totals,
  }) = _FoodLog;

  factory FoodLog.fromJson(Map<String, dynamic> json) =>
      _$FoodLogFromJson(json);
}

@freezed
abstract class RemainingRange with _$RemainingRange {
  const factory RemainingRange({
    required double target,
    required double low,
    required double high,
    required RemainingState state,
  }) = _RemainingRange;

  factory RemainingRange.fromJson(Map<String, dynamic> json) =>
      _$RemainingRangeFromJson(json);
}

@freezed
abstract class NutritionRemaining with _$NutritionRemaining {
  const factory NutritionRemaining({
    required RemainingRange kcal,
    required RemainingRange protein,
    required RemainingRange carb,
    required RemainingRange fat,
  }) = _NutritionRemaining;

  factory NutritionRemaining.fromJson(Map<String, dynamic> json) =>
      _$NutritionRemainingFromJson(json);
}

@freezed
abstract class NutritionDay with _$NutritionDay {
  const factory NutritionDay({
    required String date,
    required String today,
    required String timezone,
    required NutritionTargets? targets,
    required NutritionTotals totals,
    required NutritionRemaining? remaining,
    required List<FoodLog> logs,
  }) = _NutritionDay;

  factory NutritionDay.fromJson(Map<String, dynamic> json) =>
      _$NutritionDayFromJson(json);
}

@freezed
abstract class CreateLogResponse with _$CreateLogResponse {
  const factory CreateLogResponse({
    required FoodLog log,
    required NutritionDay day,
  }) = _CreateLogResponse;

  factory CreateLogResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateLogResponseFromJson(json);
}

@freezed
abstract class DeleteLogResponse with _$DeleteLogResponse {
  const factory DeleteLogResponse({required NutritionDay day}) =
      _DeleteLogResponse;

  factory DeleteLogResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteLogResponseFromJson(json);
}

@freezed
abstract class RecentFood with _$RecentFood {
  const factory RecentFood({
    required Food food,
    required String lastLoggedAt,
    required NutritionBasis lastBasis,
    required String lastServingLabel,
    required double lastServings,
  }) = _RecentFood;

  factory RecentFood.fromJson(Map<String, dynamic> json) =>
      _$RecentFoodFromJson(json);
}

@freezed
abstract class RecentFoodsResponse with _$RecentFoodsResponse {
  const factory RecentFoodsResponse({required List<RecentFood> items}) =
      _RecentFoodsResponse;

  factory RecentFoodsResponse.fromJson(Map<String, dynamic> json) =>
      _$RecentFoodsResponseFromJson(json);
}

/// A saved meal's item: a food at a portion (logging re-snapshots it), or a
/// quick add's own values. Written by hand: the wire is a union on `kind`.
sealed class SavedMealItem {
  const SavedMealItem();

  factory SavedMealItem.fromJson(Map<String, dynamic> json) =>
      json['kind'] == 'quick-add'
          ? SavedQuickAddItem.fromJson(json)
          : SavedFoodItem.fromJson(json);

  Map<String, dynamic> toJson();
  String get name;
}

class SavedFoodItem extends SavedMealItem {
  const SavedFoodItem({
    required this.foodId,
    required this.foodName,
    required this.basis,
    required this.servingLabel,
    required this.servings,
    required this.grams,
    required this.row,
  });

  factory SavedFoodItem.fromJson(Map<String, dynamic> json) => SavedFoodItem(
        foodId: json['foodId'] as String,
        foodName: json['foodName'] as String,
        basis: NutritionBasis.values
            .firstWhere((b) => b.wire == json['basis'] as String),
        servingLabel: json['servingLabel'] as String,
        servings: (json['servings'] as num).toDouble(),
        grams: (json['grams'] as num?)?.toDouble(),
        row: json['row'] == null
            ? null
            : FoodNutrition.fromJson(json['row'] as Map<String, dynamic>),
      );

  final String foodId;
  final String foodName;
  final NutritionBasis basis;
  final String servingLabel;
  final double servings;
  final double? grams;

  /// The food's row as it is now — for a display-only preview. Null when the
  /// food is no longer available to this user.
  final FoodNutrition? row;

  @override
  String get name => foodName;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': 'food',
        'foodId': foodId,
        'foodName': foodName,
        'basis': basis.wire,
        'servingLabel': servingLabel,
        'servings': servings,
        'grams': grams,
        'row': row?.toJson(),
      };
}

class SavedQuickAddItem extends SavedMealItem {
  const SavedQuickAddItem({
    required this.quickAddName,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.fibreG,
  });

  factory SavedQuickAddItem.fromJson(Map<String, dynamic> json) =>
      SavedQuickAddItem(
        quickAddName: json['name'] as String,
        kcal: (json['kcal'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        carbG: (json['carbG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
        fibreG: (json['fibreG'] as num?)?.toDouble(),
      );

  final String quickAddName;
  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;
  final double? fibreG;

  @override
  String get name => quickAddName;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': 'quick-add',
        'name': quickAddName,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbG': carbG,
        'fatG': fatG,
        'fibreG': fibreG,
      };
}

class SavedMeal {
  const SavedMeal({
    required this.id,
    required this.clientMealId,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  factory SavedMeal.fromJson(Map<String, dynamic> json) => SavedMeal(
        id: json['id'] as String,
        clientMealId: json['clientMealId'] as String,
        name: json['name'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => SavedMealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final String clientMealId;
  final String name;
  final List<SavedMealItem> items;
  final String createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'clientMealId': clientMealId,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt,
      };
}

/* ------------------------------------------------------------ requests -- */

/// One food at a portion. Exactly one of [servings] / [grams].
class LogFoodItemRequest {
  const LogFoodItemRequest({
    required this.foodId,
    required this.basis,
    required this.servingLabel,
    this.servings,
    this.grams,
  }) : assert((servings == null) != (grams == null));

  factory LogFoodItemRequest.fromJson(Map<String, dynamic> json) =>
      LogFoodItemRequest(
        foodId: json['foodId'] as String,
        basis: NutritionBasis.values
            .firstWhere((b) => b.wire == json['basis'] as String),
        servingLabel: json['servingLabel'] as String,
        servings: (json['servings'] as num?)?.toDouble(),
        grams: (json['grams'] as num?)?.toDouble(),
      );

  final String foodId;
  final NutritionBasis basis;
  final String servingLabel;
  final double? servings;
  final double? grams;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'foodId': foodId,
        'basis': basis.wire,
        'servingLabel': servingLabel,
        if (servings != null) 'servings': servings,
        if (grams != null) 'grams': grams,
      };
}

/// Quick add (owner J6): kcal and the three macros required; fibre optional.
class QuickAdd {
  const QuickAdd({
    this.name,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    this.fibreG,
  });

  factory QuickAdd.fromJson(Map<String, dynamic> json) => QuickAdd(
        name: json['name'] as String?,
        kcal: (json['kcal'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        carbG: (json['carbG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
        fibreG: (json['fibreG'] as num?)?.toDouble(),
      );

  final String? name;
  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  /// Null when not known — sent as null, never 0.
  final double? fibreG;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbG': carbG,
        'fatG': fatG,
        'fibreG': fibreG,
      };
}

/// `POST /nutrition/logs`: one of three methods, each with its own payload.
class CreateLogRequest {
  const CreateLogRequest._({
    required this.clientLogId,
    required this.loggedAt,
    required this.mealSlot,
    required this.entryMethod,
    this.items,
    this.quickAdd,
    this.savedMealId,
  });

  const CreateLogRequest.search({
    required String clientLogId,
    required String loggedAt,
    required MealSlot mealSlot,
    required List<LogFoodItemRequest> items,
  }) : this._(
          clientLogId: clientLogId,
          loggedAt: loggedAt,
          mealSlot: mealSlot,
          entryMethod: EntryMethod.search,
          items: items,
        );

  const CreateLogRequest.quickAdd({
    required String clientLogId,
    required String loggedAt,
    required MealSlot mealSlot,
    required QuickAdd quickAdd,
  }) : this._(
          clientLogId: clientLogId,
          loggedAt: loggedAt,
          mealSlot: mealSlot,
          entryMethod: EntryMethod.quickAdd,
          quickAdd: quickAdd,
        );

  const CreateLogRequest.savedMeal({
    required String clientLogId,
    required String loggedAt,
    required MealSlot mealSlot,
    required String savedMealId,
  }) : this._(
          clientLogId: clientLogId,
          loggedAt: loggedAt,
          mealSlot: mealSlot,
          entryMethod: EntryMethod.savedMeal,
          savedMealId: savedMealId,
        );

  factory CreateLogRequest.fromJson(Map<String, dynamic> json) {
    final method = EntryMethod.values
        .firstWhere((m) => m.wire == json['entryMethod'] as String);
    return CreateLogRequest._(
      clientLogId: json['clientLogId'] as String,
      loggedAt: json['loggedAt'] as String,
      mealSlot: MealSlot.fromWire(json['mealSlot'] as String),
      entryMethod: method,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => LogFoodItemRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      quickAdd: json['quickAdd'] == null
          ? null
          : QuickAdd.fromJson(json['quickAdd'] as Map<String, dynamic>),
      savedMealId: json['savedMealId'] as String?,
    );
  }

  final String clientLogId;

  /// The instant it was eaten (UTC ISO). The server places it on a day in
  /// the user's zone.
  final String loggedAt;
  final MealSlot mealSlot;
  final EntryMethod entryMethod;
  final List<LogFoodItemRequest>? items;
  final QuickAdd? quickAdd;
  final String? savedMealId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientLogId': clientLogId,
        'loggedAt': loggedAt,
        'mealSlot': mealSlot.wire,
        'entryMethod': entryMethod.wire,
        if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
        if (quickAdd != null) 'quickAdd': quickAdd!.toJson(),
        if (savedMealId != null) 'savedMealId': savedMealId,
      };
}

/// Owner J7: from logged meals only.
class CreateSavedMealRequest {
  const CreateSavedMealRequest({
    required this.clientMealId,
    required this.name,
    required this.fromClientLogIds,
  });

  final String clientMealId;
  final String name;
  final List<String> fromClientLogIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientMealId': clientMealId,
        'name': name,
        'fromClientLogIds': fromClientLogIds,
      };
}
