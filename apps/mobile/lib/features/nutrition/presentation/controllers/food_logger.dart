import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../health/presentation/controllers/health_providers.dart';
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import '../widgets/food_widgets.dart';
import 'food_log_providers.dart';

/// Where a log goes: a day in the user's calendar and a meal slot.
class LogTarget {
  const LogTarget({required this.date, required this.slot});
  final String date;
  final MealSlot slot;
}

/// Turns a choice on screen into a queued log: the request (with a fresh
/// clientLogId, minted once per log) and its display-only preview. It never
/// computes a total — the server does, when the log reaches it.
class FoodLogger {
  FoodLogger(
    this._repo, {
    required this.zone,
    required this.today,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NutritionLogRepository _repo;
  final String zone;
  final String today;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  /// A representative local time for a slot, when logging to a past day.
  static int slotHour(MealSlot slot) => switch (slot) {
        MealSlot.breakfast => 8,
        MealSlot.lunch => 13,
        MealSlot.snacks => 17,
        MealSlot.dinner => 20,
      };

  /// The instant the log is for: now, on today; the slot's hour of that day
  /// in the user's zone, on a past day — so the server places it on it.
  String loggedAtFor(LogTarget target) {
    if (target.date == today) return _now().toUtc().toIso8601String();
    final p = target.date.split('-').map(int.parse).toList();
    final local = tz.TZDateTime(
      userLocation(zone),
      p[0],
      p[1],
      p[2],
      slotHour(target.slot),
    );
    return local.toUtc().toIso8601String();
  }

  /// "1.5 × 1 katori (225 g)", "57 g".
  static String portionText(
    FoodNutrition row,
    PortionResult portion, {
    required bool asGrams,
  }) {
    if (asGrams || row.basis == NutritionBasis.per100g) {
      return '${FoodFormat.number(portion.grams!)} g';
    }
    final n = FoodFormat.number(portion.servings!);
    final g = portion.grams;
    final grams = g != null && !row.servingLabel.contains('(')
        ? ' (${FoodFormat.number(g)} g)'
        : '';
    return '$n × ${row.servingLabel}$grams';
  }

  Future<void> logFood(
    Food food,
    FoodNutrition row,
    PortionResult portion, {
    required bool asGrams,
    required LogTarget target,
  }) {
    final request = CreateLogRequest.search(
      clientLogId: _uuid.v4(),
      loggedAt: loggedAtFor(target),
      mealSlot: target.slot,
      items: [
        LogFoodItemRequest(
          foodId: food.id,
          basis: row.basis,
          servingLabel: row.servingLabel,
          servings: asGrams ? null : portion.servings,
          grams: asGrams ? portion.grams : null,
        ),
      ],
    );
    return _repo.log(
      request,
      localDate: target.date,
      preview: PendingPreview(
        items: [
          PendingItem(
            name: food.name,
            portion: portionText(row, portion, asGrams: asGrams),
            preview: PortionPreview.scale(row, portion.servings!),
          ),
        ],
      ),
    );
  }

  /// Phase 9: a dish from a mess menu. The request names the mess, the menu
  /// date and the dish — no numbers; the server snapshots the dish's stored
  /// estimate when the log reaches it (online or later, from the queue).
  Future<void> logMessDish({
    required String messCode,
    required String menuDate,
    required String dishSlug,
    required String dishName,
    required FoodNutrition row,
    required PortionResult portion,
    required bool asGrams,
    required LogTarget target,
  }) {
    final request = CreateLogRequest.mess(
      clientLogId: _uuid.v4(),
      loggedAt: loggedAtFor(target),
      mealSlot: target.slot,
      mess: messCode,
      menuDate: menuDate,
      messItems: [
        LogMessDishRequest(
          dishSlug: dishSlug,
          servings: asGrams ? null : portion.servings,
          grams: asGrams ? portion.grams : null,
        ),
      ],
    );
    return _repo.log(
      request,
      localDate: target.date,
      preview: PendingPreview(
        items: [
          PendingItem(
            name: dishName,
            portion: portionText(row, portion, asGrams: asGrams),
            preview: PortionPreview.scale(row, portion.servings!),
          ),
        ],
      ),
    );
  }

  /// Phase 10: "Log this plate" — ONE mess log, one item per plate dish at
  /// its whole servings, for today's menu. The previews are the plate's own
  /// numbers (the server's snapshot of the stored estimate); the server takes
  /// the snapshot again when the log arrives.
  Future<void> logMessPlate({
    required String messCode,
    required String menuDate,
    required List<
            ({
              String dishSlug,
              String name,
              int servings,
              String servingLabel,
              PreviewNutrition preview
            })>
        items,
    required LogTarget target,
  }) =>
      _repo.log(
        CreateLogRequest.mess(
          clientLogId: _uuid.v4(),
          loggedAt: loggedAtFor(target),
          mealSlot: target.slot,
          mess: messCode,
          menuDate: menuDate,
          messItems: [
            for (final i in items)
              LogMessDishRequest(
                dishSlug: i.dishSlug,
                servings: i.servings.toDouble(),
              ),
          ],
        ),
        localDate: target.date,
        preview: PendingPreview(
          items: [
            for (final i in items)
              PendingItem(
                name: i.name,
                portion: '${i.servings} × ${i.servingLabel}',
                preview: i.preview,
              ),
          ],
        ),
      );

  Future<void> logQuickAdd(QuickAdd quickAdd, {required LogTarget target}) =>
      _repo.log(
        CreateLogRequest.quickAdd(
          clientLogId: _uuid.v4(),
          loggedAt: loggedAtFor(target),
          mealSlot: target.slot,
          quickAdd: quickAdd,
        ),
        localDate: target.date,
        preview: PendingPreview(
          items: [
            PendingItem(
              name: quickAdd.name ?? 'Quick add',
              portion: 'Quick add',
              preview: PortionPreview.quickAdd(quickAdd),
            ),
          ],
        ),
      );

  Future<void> logSavedMeal(SavedMeal meal, {required LogTarget target}) =>
      _repo.log(
        CreateLogRequest.savedMeal(
          clientLogId: _uuid.v4(),
          loggedAt: loggedAtFor(target),
          mealSlot: target.slot,
          savedMealId: meal.id,
        ),
        localDate: target.date,
        preview: PendingPreview(
          items: [
            for (final item in meal.items)
              switch (item) {
                SavedFoodItem(
                  :final row,
                  :final servings,
                  :final servingLabel
                ) =>
                  PendingItem(
                    name: item.foodName,
                    portion: '${FoodFormat.number(servings)} × $servingLabel',
                    preview: row == null
                        ? null
                        : PortionPreview.scale(row, servings),
                  ),
                SavedMessItem(:final row, :final servings) => PendingItem(
                    name: item.dishName,
                    portion: row == null
                        ? FoodFormat.number(servings)
                        : '${FoodFormat.number(servings)} × ${row.servingLabel}',
                    preview: row == null
                        ? null
                        : PortionPreview.scale(row, servings),
                  ),
                SavedQuickAddItem() => PendingItem(
                    name: item.quickAddName,
                    portion: 'Quick add',
                    preview: PortionPreview.quickAdd(
                      QuickAdd(
                        kcal: item.kcal,
                        proteinG: item.proteinG,
                        carbG: item.carbG,
                        fatG: item.fatG,
                        fibreG: item.fibreG,
                      ),
                    ),
                  ),
              },
          ],
        ),
      );
}

final foodLoggerProvider = Provider<FoodLogger>((ref) {
  return FoodLogger(
    ref.watch(nutritionLogRepositoryProvider),
    zone: ref.watch(userTimezoneProvider),
    today: ref.watch(localTodayProvider),
  );
});
