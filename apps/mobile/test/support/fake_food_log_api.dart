import 'dart:async';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/nutrition/data/food_log_api.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';

/// A scripted nutrition server for Phase 8 tests. It behaves like the API:
/// idempotent by clientLogId, snapshots at log time with the test's own
/// numbers, sums the day. [failNext] / [offline] / [unauthenticated] script
/// failures; [calls] records every request.
class FakeFoodLogApi implements FoodLogApi {
  FakeFoodLogApi({this.todayDate = '2026-09-24', this.targets});

  String todayDate;
  NutritionTargets? targets;

  /// Every server log by clientLogId, and which are deleted.
  final Map<String, FoodLog> logs = {};
  final Set<String> deleted = {};
  final List<String> calls = [];

  bool offline = false;
  bool unauthenticated = false;

  /// Failures to return, in order, before behaving normally.
  final List<Failure> failNext = [];

  /// Failures for creates only (a refusal of that one log).
  final List<Failure> failNextCreate = [];

  /// The server takes the next create, but its reply is lost on the way.
  bool loseNextReply = false;

  /// While set, a create waits here — it is "on the wire".
  Completer<void>? gate;

  List<RecentFood> recent = [];
  List<SavedMeal> meals = [];

  /// Per food id, the snapshot the server would take (a test sets it).
  final Map<String, FoodLogItem Function(LogFoodItemRequest)> snapshot = {};

  /// Phase 9: per mess dish slug, the snapshot the server would take.
  final Map<String, FoodLogItem Function(LogMessDishRequest)> messSnapshot = {};

  Failure? _failure() {
    if (unauthenticated) return const Unauthenticated();
    if (offline) return const Offline();
    if (failNext.isNotEmpty) return failNext.removeAt(0);
    return null;
  }

  static NutritionTotals totalsOf(Iterable<FoodLogItem> items) {
    double sum(double Function(FoodLogItem) f) =>
        items.fold(0, (s, i) => s + f(i));
    double r(double v) => (v * 10).roundToDouble() / 10;
    final known = items.where((i) => i.fibreLow != null);
    return NutritionTotals(
      kcalLow: sum((i) => i.kcalLow),
      kcalHigh: sum((i) => i.kcalHigh),
      proteinLow: r(sum((i) => i.proteinLow)),
      proteinHigh: r(sum((i) => i.proteinHigh)),
      carbLow: r(sum((i) => i.carbLow)),
      carbHigh: r(sum((i) => i.carbHigh)),
      fatLow: r(sum((i) => i.fatLow)),
      fatHigh: r(sum((i) => i.fatHigh)),
      fibreKnownLow: r(known.fold(0, (s, i) => s + i.fibreLow!)),
      fibreKnownHigh: r(known.fold(0, (s, i) => s + i.fibreHigh!)),
      fibreUnknownItems: items.where((i) => i.fibreLow == null).length,
      itemCount: items.length,
    );
  }

  NutritionDay dayOf(String date) {
    final live = logs.values
        .where((l) => l.localDate == date && !deleted.contains(l.clientLogId))
        .toList();
    final totals = totalsOf(live.expand((l) => l.items));
    final t = targets;
    RemainingRange rem(double target, double lo, double hi) {
      final low = target - hi;
      final high = target - lo;
      return RemainingRange(
        target: target,
        low: low,
        high: high,
        state: low >= 0
            ? RemainingState.under
            : high < 0
                ? RemainingState.over
                : RemainingState.around,
      );
    }

    return NutritionDay(
      date: date,
      today: todayDate,
      timezone: 'Asia/Kolkata',
      targets: t,
      totals: totals,
      remaining: t == null
          ? null
          : NutritionRemaining(
              kcal: rem(t.kcal.toDouble(), totals.kcalLow, totals.kcalHigh),
              protein: rem(
                t.proteinG.toDouble(),
                totals.proteinLow,
                totals.proteinHigh,
              ),
              carb: rem(t.carbG.toDouble(), totals.carbLow, totals.carbHigh),
              fat: rem(t.fatG.toDouble(), totals.fatLow, totals.fatHigh),
            ),
      logs: live,
    );
  }

  static FoodLogItem quickItem(QuickAdd q) => FoodLogItem(
        id: 'item-q',
        position: 0,
        foodId: null,
        foodName: q.name ?? 'Quick add',
        foodSource: FoodSource.user,
        basis: null,
        servingLabel: null,
        servingGrams: null,
        servings: 1,
        grams: null,
        kcalLow: q.kcal,
        kcalHigh: q.kcal,
        proteinLow: q.proteinG,
        proteinHigh: q.proteinG,
        carbLow: q.carbG,
        carbHigh: q.carbG,
        fatLow: q.fatG,
        fatHigh: q.fatG,
        fibreLow: q.fibreG,
        fibreHigh: q.fibreG,
        confidence: NutritionConfidence.medium,
      );

  @override
  Future<Result<NutritionDay>> today() async {
    calls.add('today');
    final f = _failure();
    if (f != null) return Err(f);
    return Ok(dayOf(todayDate));
  }

  @override
  Future<Result<NutritionDay>> day(String date) async {
    calls.add('day $date');
    final f = _failure();
    if (f != null) return Err(f);
    return Ok(dayOf(date));
  }

  /// The day a log lands on: its loggedAt in IST (the fake's user zone).
  static String localDateOf(String loggedAt) {
    final t = DateTime.parse(loggedAt).toUtc().add(
          const Duration(hours: 5, minutes: 30),
        );
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Result<CreateLogResponse>> createLog(CreateLogRequest request) async {
    calls.add('create ${request.clientLogId}');
    final g = gate;
    if (g != null) await g.future;
    final f = _failure() ??
        (failNextCreate.isEmpty ? null : failNextCreate.removeAt(0));
    if (f != null) return Err(f);
    final existing = logs[request.clientLogId];
    if (existing != null) {
      return Ok(
        CreateLogResponse(log: existing, day: dayOf(existing.localDate)),
      );
    }
    final List<FoodLogItem> items;
    switch (request.entryMethod) {
      case EntryMethod.search:
        items = [
          for (final i in request.items!)
            (snapshot[i.foodId] ??
                (_) => throw StateError('no snapshot for ${i.foodId}'))(i),
        ];
      case EntryMethod.quickAdd:
        items = [quickItem(request.quickAdd!)];
      case EntryMethod.mess:
        items = [
          for (final i in request.messItems!)
            (messSnapshot[i.dishSlug] ??
                (_) => throw StateError('no snapshot for ${i.dishSlug}'))(i),
        ];
      case EntryMethod.savedMeal:
        final meal = meals.firstWhere((m) => m.id == request.savedMealId);
        items = [
          for (final it in meal.items)
            switch (it) {
              SavedFoodItem(
                :final foodId,
                :final servingLabel,
                :final basis,
                :final servings
              ) =>
                snapshot[foodId]!(
                  LogFoodItemRequest(
                    foodId: foodId,
                    basis: basis,
                    servingLabel: servingLabel,
                    servings: servings,
                  ),
                ),
              SavedMessItem(:final dishSlug, :final servings) =>
                messSnapshot[dishSlug]!(
                  LogMessDishRequest(dishSlug: dishSlug, servings: servings),
                ),
              SavedQuickAddItem() => quickItem(
                  QuickAdd(
                    name: it.quickAddName,
                    kcal: it.kcal,
                    proteinG: it.proteinG,
                    carbG: it.carbG,
                    fatG: it.fatG,
                    fibreG: it.fibreG,
                  ),
                ),
            },
        ];
    }
    final log = FoodLog(
      id: 'server-${request.clientLogId}',
      clientLogId: request.clientLogId,
      loggedAt: request.loggedAt,
      localDate: localDateOf(request.loggedAt),
      mealSlot: request.mealSlot,
      entryMethod: request.entryMethod,
      savedMealId: request.savedMealId,
      messCode: request.mess,
      items: items,
      totals: totalsOf(items),
    );
    logs[request.clientLogId] = log;
    if (loseNextReply) {
      loseNextReply = false;
      return const Err(Unknown());
    }
    return Ok(CreateLogResponse(log: log, day: dayOf(log.localDate)));
  }

  @override
  Future<Result<DeleteLogResponse>> deleteLog(String clientLogId) async {
    calls.add('delete $clientLogId');
    final f = _failure();
    if (f != null) return Err(f);
    final log = logs[clientLogId];
    if (log == null) return const Err(NotFound());
    deleted.add(clientLogId);
    return Ok(DeleteLogResponse(day: dayOf(log.localDate)));
  }

  @override
  Future<Result<List<RecentFood>>> recentFoods({int limit = 20}) async {
    calls.add('recent');
    final f = _failure();
    if (f != null) return Err(f);
    return Ok(recent);
  }

  @override
  Future<Result<List<SavedMeal>>> savedMeals() async {
    calls.add('savedMeals');
    final f = _failure();
    if (f != null) return Err(f);
    return Ok(meals);
  }

  @override
  Future<Result<SavedMeal>> createSavedMeal(
    CreateSavedMealRequest request,
  ) async {
    calls.add('createSavedMeal');
    final f = _failure();
    if (f != null) return Err(f);
    final items = <SavedMealItem>[
      for (final id in request.fromClientLogIds)
        for (final i in logs[id]!.items)
          i.isQuickAdd
              ? SavedQuickAddItem(
                  quickAddName: i.foodName,
                  kcal: i.kcalLow,
                  proteinG: i.proteinLow,
                  carbG: i.carbLow,
                  fatG: i.fatLow,
                  fibreG: i.fibreLow,
                )
              : SavedFoodItem(
                  foodId: i.foodId!,
                  foodName: i.foodName,
                  basis: i.basis!,
                  servingLabel: i.servingLabel!,
                  servings: i.servings,
                  grams: i.grams,
                  row: null,
                ),
    ];
    final meal = SavedMeal(
      id: 'meal-${meals.length + 1}',
      clientMealId: request.clientMealId,
      name: request.name,
      items: items,
      createdAt: '2026-09-24T12:00:00.000Z',
    );
    meals = [...meals, meal];
    return Ok(meal);
  }

  @override
  Future<Result<void>> deleteSavedMeal(String id) async {
    calls.add('deleteSavedMeal $id');
    final f = _failure();
    if (f != null) return Err(f);
    meals = meals.where((m) => m.id != id).toList();
    return const Ok(null);
  }
}
