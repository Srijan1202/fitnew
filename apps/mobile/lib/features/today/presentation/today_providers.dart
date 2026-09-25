import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../workout/domain/entities/workout.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../data/today_api.dart';
import '../data/today_event_sync.dart';
import '../data/today_repository.dart';
import '../domain/today.dart';
import '../domain/today_completion.dart';

final todayApiProvider = Provider<TodayApi>((ref) {
  return DioTodayApi(ref.watch(dioProvider));
});

/// TODAY's repository and its own event queue engine (Phase 11, D9). The
/// workout and nutrition engines are untouched; they share the database.
final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(todayApiProvider);
  final repo = TodayRepository(
    db,
    api,
    TodayEventSync(db, api, wakeItself: ref.watch(syncWakesItselfProvider)),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Where the plan on screen came from.
enum TodayPlanSource {
  /// Just fetched: the server's current decision.
  live,

  /// The last valid answer for TODAY's date, shown because the server could
  /// not be reached — labelled as such, never as a fresh decision.
  cached,

  /// Nothing to show: no answer, and no cached one for today.
  unavailable,
}

class TodayPlanView {
  const TodayPlanView({
    required this.plan,
    required this.source,
    this.storedAt,
    this.failure,
  });

  final TodayPlan? plan;
  final TodayPlanSource source;

  /// When a cached plan was fetched (UTC ISO).
  final String? storedAt;

  /// Why the live fetch failed, if it did.
  final Failure? failure;

  bool get offline => failure is Offline;
}

/// `GET /v1/today`, refetched when the server's view may have moved (a
/// session started / completed here, the food queue delivered, a weight
/// saved) and on resume / pull-to-refresh. Offline, the last answer for
/// the SAME local date is shown as cached; an older one is never shown —
/// the phone never makes, or passes off, a decision (D8).
final todayPlanProvider = FutureProvider<TodayPlanView>(
  (ref) async {
    requireSession(ref);
    ref
      ..watch(serverRefreshProvider)
      ..watch(weightSavedOnProvider);
    final today = ref.watch(localTodayProvider);
    final repo = ref.watch(todayRepositoryProvider);
    final food = ref
        .watch(nutritionLogRepositoryProvider)
        .drained
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(food.cancel);

    final result = await repo.refresh();
    switch (result) {
      case Ok(:final value):
        unawaited(repo.prune(today));
        return TodayPlanView(plan: value, source: TodayPlanSource.live);
      case Err(:final failure):
        final cached = await repo.cached();
        if (cached != null && cached.plan.date == today) {
          return TodayPlanView(
            plan: cached.plan,
            source: TodayPlanSource.cached,
            storedAt: cached.storedAt,
            failure: failure,
          );
        }
        return TodayPlanView(
          plan: null,
          source: TodayPlanSource.unavailable,
          failure: failure,
        );
    }
  },
  retry: (_, __) => null,
);

/// The events recorded on this phone for one local date, live.
final todayLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, date) {
  requireSession(ref);
  return ref.watch(todayRepositoryProvider).watchLedger(date);
});

/// The server actions Home may draw now: the plan's, minus any the user
/// dismissed on this phone today (hidden at once, before the server's next
/// answer omits them too), in the server's rank order.
final visibleTodayActionsProvider = Provider<List<TodayAction>>((ref) {
  final view = ref.watch(todayPlanProvider).value;
  final plan = view?.plan;
  if (plan == null) return const [];
  final ledger = ref.watch(todayLedgerProvider(plan.date)).value ?? const [];
  final dismissedIds = <String>{};
  final dismissedSubjects = <String>{};
  for (final e in ledger) {
    if (e.event != TodayEventName.dismissed) continue;
    dismissedIds.add(e.recommendationId);
    dismissedSubjects.add('${e.kind}\u0000${e.subjectKey}');
  }
  return [
    for (final a in plan.actions)
      if (a.kind != null &&
          !dismissedIds.contains(a.id) &&
          !dismissedSubjects.contains('${a.kindWire}\u0000${a.subjectKey}'))
        a,
  ];
});

/// The events recorded on this phone for each action id of today's plan.
final todayRecordedProvider = Provider<Map<String, Set<TodayEventName>>>((ref) {
  final plan = ref.watch(todayPlanProvider).value?.plan;
  if (plan == null) return const {};
  final ledger = ref.watch(todayLedgerProvider(plan.date)).value ?? const [];
  final out = <String, Set<TodayEventName>>{};
  for (final e in ledger) {
    (out[e.recommendationId] ??= {}).add(e.event);
  }
  return out;
});

/// Set when Personal details saved a weight on the server: the local date
/// it was saved for. The log-weight action's completion evidence, and a
/// cue to refetch the plan.
class WeightSavedOn extends Notifier<String?> {
  @override
  String? build() => null;

  void mark(String date) => state = date;
}

final weightSavedOnProvider =
    NotifierProvider<WeightSavedOn, String?>(WeightSavedOn.new);

/// What the server already holds for today (see [CompletionEvidence]).
final todayCompletionEvidenceProvider = Provider<CompletionEvidence>((ref) {
  final date = ref.watch(localTodayProvider);
  final training = ref.watch(todayProvider).value;
  final session = ref.watch(completedTodayProvider).value;
  final food = ref.watch(nutritionDayViewProvider(date)).value?.server;
  final targets = ref.watch(profileControllerProvider).value?.goal.targets;
  final onDay = training != null && training.date == date;
  return CompletionEvidence(
    date: date,
    sessionCompleted: onDay && training.completedSessionId != null,
    sessionExerciseIds: {
      if (session != null)
        for (final x in session.exercises) x.exerciseId,
    },
    sessionPrimaryMuscles: {
      if (session != null)
        for (final x in session.exercises)
          for (final m in x.primaryMuscles) m.wire,
    },
    loggedSlots: {
      if (food != null && food.date == date)
        for (final l in food.logs) l.mealSlot.wire,
    },
    weighed: ref.watch(weightSavedOnProvider) == date,
    deloadActive: onDay && training.deload.state == DeloadStatus.active,
    targetAdjusted: targets != null &&
        targets.reason == 'calorie-adjust' &&
        targets.effectiveFrom == date,
  );
});

/// Sends `completed` for an accepted action once the server holds the
/// evidence (never on accept alone). Watched from the app root.
final todayCompletionWatcherProvider = Provider<void>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return;
  final date = ref.watch(localTodayProvider);
  final repo = ref.watch(todayRepositoryProvider);
  void check() {
    final ledger = ref.read(todayLedgerProvider(date)).value;
    if (ledger == null) return;
    final due =
        dueCompletions(ledger, ref.read(todayCompletionEvidenceProvider));
    for (final action in due) {
      unawaited(repo.record(action, date, TodayEventName.completed));
    }
  }

  ref
    ..listen(todayLedgerProvider(date), (_, __) => check())
    ..listen(todayCompletionEvidenceProvider, (_, __) => check());
});

/// Drains the TODAY queue when connectivity returns, when the app resumes
/// (and refetches the plan then), and once when a session starts.
class TodayCoordinator {
  TodayCoordinator(
    this._repo,
    Stream<List<ConnectivityResult>> connectivity, {
    required VoidCallback onResume,
  }) {
    _sub = connectivity.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _repo.sync();
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _repo.sync();
        onResume();
      },
    );
    _repo.sync();
  }

  final TodayRepository _repo;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  late final AppLifecycleListener _lifecycle;

  void dispose() {
    _sub.cancel();
    _lifecycle.dispose();
  }
}

final todayCoordinatorProvider = Provider<TodayCoordinator?>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return null;
  final coordinator = TodayCoordinator(
    ref.watch(todayRepositoryProvider),
    ref.watch(connectivityStreamProvider),
    onResume: () => ref.invalidate(todayPlanProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
