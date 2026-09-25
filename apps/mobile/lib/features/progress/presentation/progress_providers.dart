import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../today/presentation/today_providers.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../data/progress_api.dart';
import '../data/progress_repository.dart';
import '../domain/progress.dart';

final progressApiProvider =
    Provider<ProgressApi>((ref) => DioProgressApi(ref.watch(dioProvider)));

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(progressApiProvider),
  );
});

/// The window the Progress page shows (owner D8): 30 days by default.
class ProgressWindowChoice extends Notifier<ProgressWindow> {
  @override
  ProgressWindow build() => ProgressWindow.d30;

  void set(ProgressWindow w) => state = w;
}

final progressWindowProvider =
    NotifierProvider<ProgressWindowChoice, ProgressWindow>(
  ProgressWindowChoice.new,
);

enum ProgressSource {
  /// Just fetched.
  live,

  /// The last valid summary, shown because the server could not be reached —
  /// labelled with its time (owner D9).
  cached,

  /// Nothing to show.
  unavailable,
}

class ProgressView {
  const ProgressView({
    required this.summary,
    required this.source,
    this.storedAt,
    this.failure,
  });

  final ProgressSummary? summary;
  final ProgressSource source;
  final String? storedAt;
  final Failure? failure;

  bool get offline => failure is Offline;
}

/// `GET /v1/progress/summary` for a window, refetched when the server's view
/// may have moved (a session synced, food delivered, a weight saved) and on
/// pull-to-refresh. Offline, the last summary is shown labelled as cached.
final progressSummaryProvider =
    FutureProvider.family<ProgressView, ProgressWindow>(
  (ref, window) async {
    requireSession(ref);
    ref
      ..watch(serverRefreshProvider)
      ..watch(weightSavedOnProvider);
    final repo = ref.watch(progressRepositoryProvider);
    final food = ref
        .watch(nutritionLogRepositoryProvider)
        .drained
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(food.cancel);
    final result = await repo.refresh(window);
    switch (result) {
      case Ok(:final value):
        return ProgressView(summary: value, source: ProgressSource.live);
      case Err(:final failure):
        final cached = await repo.cached(window);
        return cached == null
            ? ProgressView(
                summary: null,
                source: ProgressSource.unavailable,
                failure: failure,
              )
            : ProgressView(
                summary: cached.summary,
                source: ProgressSource.cached,
                storedAt: cached.storedAt,
                failure: failure,
              );
    }
  },
  retry: (_, __) => null,
);

/// Saving readings. Online only: a failure is returned for the sheet to say
/// out loud; nothing is queued (owner D9).
class ProgressActions {
  ProgressActions(this._ref);

  final Ref _ref;

  void _afterSave({required String date, required bool weight}) {
    _ref.invalidate(progressSummaryProvider);
    if (!weight) return;
    // The profile's weight line and TODAY's plan follow; a reading for today
    // is the log-weight action's completion evidence (Phase 11 flow).
    _ref.invalidate(profileControllerProvider);
    if (date == _ref.read(localTodayProvider)) {
      _ref.read(weightSavedOnProvider.notifier).mark(date);
    }
  }

  Future<Failure?> logWeight(double kg, {String? date}) async {
    final r = await _ref
        .read(progressRepositoryProvider)
        .logWeight(LogWeightRequest(weightKg: kg, date: date));
    switch (r) {
      case Ok(:final value):
        _afterSave(date: value.date, weight: true);
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  Future<Failure?> logMeasurement(
    MeasurementSite site,
    double cm, {
    String? date,
  }) async {
    final r = await _ref.read(progressRepositoryProvider).logMeasurement(
          LogMeasurementRequest(site: site, valueCm: cm, date: date),
        );
    switch (r) {
      case Ok(:final value):
        _afterSave(date: value.date, weight: false);
        return null;
      case Err(:final failure):
        return failure;
    }
  }
}

final progressActionsProvider = Provider<ProgressActions>(ProgressActions.new);
