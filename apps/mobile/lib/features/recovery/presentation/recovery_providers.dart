import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../today/presentation/today_providers.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../data/recovery_api.dart';
import '../data/recovery_repository.dart';
import '../domain/recovery.dart';

final recoveryApiProvider =
    Provider<RecoveryApi>((ref) => DioRecoveryApi(ref.watch(dioProvider)));

final recoveryRepositoryProvider = Provider<RecoveryRepository>((ref) {
  return RecoveryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(recoveryApiProvider),
  );
});

enum RecoverySource {
  /// Just fetched.
  live,

  /// The last valid view, shown because the server could not be reached —
  /// labelled with its time.
  cached,

  /// Nothing to show.
  unavailable,
}

class RecoveryView {
  const RecoveryView({
    required this.today,
    required this.source,
    this.storedAt,
    this.failure,
  });

  final RecoveryToday? today;
  final RecoverySource source;
  final String? storedAt;
  final Failure? failure;

  bool get offline => failure is Offline;
}

/// `GET /v1/recovery/today`: refetched when the server's view may have moved
/// (a session synced) and on pull-to-refresh. Offline, the last view is shown
/// labelled as cached.
final recoveryTodayProvider = FutureProvider<RecoveryView>(
  (ref) async {
    requireSession(ref);
    ref.watch(serverRefreshProvider);
    final repo = ref.watch(recoveryRepositoryProvider);
    final result = await repo.refresh();
    switch (result) {
      case Ok(:final value):
        return RecoveryView(today: value, source: RecoverySource.live);
      case Err(:final failure):
        final cached = await repo.cached();
        return cached == null
            ? RecoveryView(
                today: null,
                source: RecoverySource.unavailable,
                failure: failure,
              )
            : RecoveryView(
                today: cached.today,
                source: RecoverySource.cached,
                storedAt: cached.storedAt,
                failure: failure,
              );
    }
  },
  retry: (_, __) => null,
);

/// Saving the check-in. Online only: a failure is returned for the card to
/// say out loud; nothing is queued (ADR-019 D11).
class RecoveryActions {
  RecoveryActions(this._ref);

  final Ref _ref;

  Future<Failure?> checkIn(LogRecoveryRequest request) async {
    final r = await _ref.read(recoveryRepositoryProvider).log(request);
    switch (r) {
      case Ok():
        // Readiness moved: the display, TODAY's suggestions and the deload
        // state (Training) are all read again from the server.
        _ref
          ..invalidate(recoveryTodayProvider)
          ..invalidate(todayPlanProvider)
          ..invalidate(todayProvider)
          ..invalidate(volumeProvider);
        return null;
      case Err(:final failure):
        return failure;
    }
  }
}

final recoveryActionsProvider = Provider<RecoveryActions>(RecoveryActions.new);
