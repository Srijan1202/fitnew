import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../data/food_log_api.dart';
import '../../data/nutrition_log_repository.dart';
import '../../data/nutrition_sync_engine.dart';
import '../../domain/entities/food_log.dart';

final foodLogApiProvider = Provider<FoodLogApi>((ref) {
  return DioFoodLogApi(ref.watch(dioProvider));
});

/// The food-log repository and its own sync engine (Phase 8). The workout
/// engine is untouched; they share the database, not code.
final nutritionLogRepositoryProvider = Provider<NutritionLogRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(foodLogApiProvider);
  final repo = NutritionLogRepository(
    db,
    api,
    NutritionSyncEngine(
      db,
      api,
      wakeItself: ref.watch(syncWakesItselfProvider),
    ),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Drains the food-log queue when connectivity returns, when the app
/// resumes, and once when a session starts (the kill / reopen case).
class NutritionSyncCoordinator {
  NutritionSyncCoordinator(
    this._repo,
    Stream<List<ConnectivityResult>> connectivity,
  ) {
    _sub = connectivity.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _repo.sync();
    });
    _lifecycle = AppLifecycleListener(onResume: _repo.sync);
    _repo.sync();
  }

  final NutritionLogRepository _repo;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  late final AppLifecycleListener _lifecycle;

  void dispose() {
    _sub.cancel();
    _lifecycle.dispose();
  }
}

/// Watched from the app root, beside the workout coordinator.
final nutritionSyncCoordinatorProvider =
    Provider<NutritionSyncCoordinator?>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return null;
  final coordinator = NutritionSyncCoordinator(
    ref.watch(nutritionLogRepositoryProvider),
    ref.watch(connectivityStreamProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// One day, live: the cached server day plus this phone's unconfirmed logs.
final nutritionDayViewProvider =
    StreamProvider.family<DayView, String>((ref, date) {
  requireSession(ref);
  return ref.watch(nutritionLogRepositoryProvider).watchDay(date);
});

/// Fetches [date] from the server into the cache — now, and again whenever
/// the queue delivers something. Its value says whether the day on screen is
/// current (Ok) or the last one loaded (Err: offline / not answering).
final nutritionDayRefreshProvider =
    FutureProvider.family<Result<NutritionDay>, String>((ref, date) async {
  requireSession(ref);
  final repo = ref.watch(nutritionLogRepositoryProvider);
  final sub = repo.drained.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.refreshDay(date);
});

/// The day the EAT screen shows: today by default; back through history,
/// never into the future.
class EatDate extends Notifier<String> {
  @override
  String build() => ref.watch(localTodayProvider);

  String get today => ref.read(localTodayProvider);

  void set(String date) {
    final t = today;
    state = date.compareTo(t) > 0 ? t : date;
  }

  void previous() => state = shiftDate(state, -1);

  void next() {
    final n = shiftDate(state, 1);
    if (n.compareTo(today) <= 0) state = n;
  }

  void toToday() => state = today;
}

final eatDateProvider = NotifierProvider<EatDate, String>(EatDate.new);

/// yyyy-mm-dd ± days, zone-free calendar arithmetic.
String shiftDate(String date, int days) {
  final p = date.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2] + days);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Owner J4: logging reaches today and 30 days back.
bool canLogOn(String date, String today) =>
    date.compareTo(today) <= 0 && date.compareTo(shiftDate(today, -30)) >= 0;

final recentFoodsProvider =
    FutureProvider.autoDispose<Cached<List<RecentFood>>>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(nutritionLogRepositoryProvider).recentFoods();
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final savedMealsProvider = FutureProvider.autoDispose<Cached<List<SavedMeal>>>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(nutritionLogRepositoryProvider).savedMeals();
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);
