import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/local_workout_repository.dart';
import '../../data/workout_api.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';

/// One database for the app's lifetime; cleared on sign-out.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final workoutApiProvider = Provider<WorkoutApi>((ref) {
  return DioWorkoutApi(ref.watch(dioProvider));
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return LocalWorkoutRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(workoutApiProvider),
  );
});

/// Drains the queue when connectivity returns, when the app resumes and
/// when a session changes user. Watched once, from the app root.
class SyncCoordinator {
  SyncCoordinator(this._repo, Stream<List<ConnectivityResult>> connectivity) {
    _sub = connectivity.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _repo.sync();
    });
    _lifecycle = AppLifecycleListener(onResume: () => _repo.sync());
    _repo.sync();
  }

  final WorkoutRepository _repo;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  late final AppLifecycleListener _lifecycle;

  void dispose() {
    _sub.cancel();
    _lifecycle.dispose();
  }
}

/// The platform's connectivity events; tests hand in a stream of their own.
final connectivityStreamProvider =
    Provider<Stream<List<ConnectivityResult>>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) {
  // Sign-out wipes the phone's rows: the next user starts from nothing.
  ref.listen<String?>(sessionUserIdProvider, (previous, next) {
    if (previous != null && next == null) {
      ref.read(workoutRepositoryProvider).clearLocal();
    }
  });
  // No session, no sync: the queue belongs to a signed-in user.
  if (ref.watch(sessionUserIdProvider) == null) return null;
  final coordinator = SyncCoordinator(
    ref.watch(workoutRepositoryProvider),
    ref.watch(connectivityStreamProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Pending / parked counts for the small "n not synced · Retry" pill.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(workoutRepositoryProvider).watchSync();
});

/// The session in progress on this phone, live.
final activeSessionProvider = StreamProvider<WorkoutSession?>((ref) {
  requireSession(ref);
  return ref.watch(workoutRepositoryProvider).watchActiveSession();
});

/// One session by client id, live.
final sessionProvider =
    StreamProvider.family<WorkoutSession?, String>((ref, clientSessionId) {
  return ref.watch(workoutRepositoryProvider).watchSession(clientSessionId);
});

/// Today's day with targets and last performance; cached for offline.
final todayProvider = FutureProvider<TodayResponse>(
  (ref) async {
    requireSession(ref);
    final result = await ref.watch(workoutRepositoryProvider).today();
    return result.when(ok: (t) => t, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// A programme day by weekday, for the day screen's Start button.
final dayProvider = FutureProvider.family<TodayResponse, int>(
  (ref, dayOfWeek) async {
    requireSession(ref);
    final result =
        await ref.watch(workoutRepositoryProvider).today(dayOfWeek: dayOfWeek);
    return result.when(ok: (t) => t, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// History, first page; more pages are loaded by the screen.
final historyProvider = FutureProvider<SessionListResponse>(
  (ref) async {
    requireSession(ref);
    final result = await ref.watch(workoutRepositoryProvider).history();
    return result.when(ok: (r) => r, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// A completed session by SERVER id (history detail).
final sessionDetailProvider =
    FutureProvider.family<WorkoutSession, String>((ref, serverId) async {
  requireSession(ref);
  final result =
      await ref.watch(workoutRepositoryProvider).fetchSession(serverId);
  return result.when(ok: (s) => s, err: (Failure f) => throw f);
});
