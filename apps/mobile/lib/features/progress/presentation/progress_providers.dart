import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/activity_signal.dart';

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

/// The window the Progress page shows. Beta 3.2 (owner): one week by
/// default; the last choice is remembered on the phone (a trivial flag).
class ProgressWindowChoice extends Notifier<ProgressWindow> {
  static const _key = 'progress.window';

  @override
  ProgressWindow build() {
    unawaited(_restore());
    return ProgressWindow.d7;
  }

  Future<void> _restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null) state = ProgressWindow.fromWire(saved);
    } on Object {
      // No stored choice (or no storage): the default stands.
    }
  }

  void set(ProgressWindow w) {
    state = w;
    unawaited(_save(w));
  }

  Future<void> _save(ProgressWindow w) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, w.wire);
    } on Object {
      // Not remembered this time; nothing else depends on it.
    }
  }
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
        ActivitySignal.report(ActivityKind.weightLogged);
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  /// Beta 3.8: today's weigh-in from Home's popup. Saved as the profile's
  /// weight, as Personal details did before, so the targets follow it the
  /// same way; the reading lands in the same history as Progress's.
  Future<Failure?> logTodayWeight(double kg) async {
    final failure = await _ref
        .read(profileControllerProvider.notifier)
        .savePersonalDetails(PersonalDetailsChange(weightKg: kg));
    if (failure != null) return failure;
    _ref.invalidate(progressSummaryProvider);
    _ref
        .read(weightSavedOnProvider.notifier)
        .mark(_ref.read(localTodayProvider));
    ActivitySignal.report(ActivityKind.weightLogged);
    return null;
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
