import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../data/mess_api.dart';
import '../data/mess_repository.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/mess.dart';
import '../domain/recommendation.dart';

final messApiProvider = Provider<MessApi>((ref) {
  return DioMessApi(ref.watch(dioProvider));
});

final messRepositoryProvider = Provider<MessRepository>((ref) {
  return MessRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(messApiProvider),
  );
});

/// A menu request: a date and a mess code (null = the user's own mess).
typedef MenuKey = ({String date, String? code});

/// A mess menu. Refetched when a food log reaches the server (the "logged"
/// marks). When today's own menu arrives, tomorrow's is fetched ahead so
/// both can be shown offline (owner D18).
final messMenuProvider = FutureProvider.autoDispose.family<MenuState, MenuKey>(
  (ref, key) async {
    requireSession(ref);
    final repo = ref.watch(messRepositoryProvider);
    final sub = ref
        .watch(nutritionLogRepositoryProvider)
        .drained
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);
    final state = await repo.menu(key.date, code: key.code);
    final today = ref.read(localTodayProvider);
    if (key.code == null &&
        key.date == today &&
        state is MenuLoaded &&
        !state.fromCache) {
      unawaited(repo.menu(shiftDate(today, 1)));
    }
    return state;
  },
  retry: (_, __) => null,
);

/// The six messes, for the pickers (Profile, onboarding, browsing).
final messesProvider = FutureProvider.autoDispose<List<Mess>>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(messRepositoryProvider).messes();
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// The day the MESS screen shows: today by default; back 30 days (the log
/// window) and forward 14 (a published or inferred menu to plan by).
class MessDate extends Notifier<String> {
  static const back = 30;
  static const ahead = 14;

  @override
  String build() => ref.watch(localTodayProvider);

  String get today => ref.read(localTodayProvider);

  bool get canGoBack => state.compareTo(shiftDate(today, -back)) > 0;
  bool get canGoForward => state.compareTo(shiftDate(today, ahead)) < 0;

  void previous() {
    if (canGoBack) state = shiftDate(state, -1);
  }

  void next() {
    if (canGoForward) state = shiftDate(state, 1);
  }

  void set(String date) => state = date;

  void toToday() => state = today;
}

final messDateProvider = NotifierProvider<MessDate, String>(MessDate.new);

/// Which mess the MESS screen shows: null = the user's own. Browsing another
/// mess never changes the setting (owner D14).
class MessBrowse extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String? code) => state = code;
}

final messBrowseProvider =
    NotifierProvider<MessBrowse, String?>(MessBrowse.new);

/* ---------------------------------------------------- Phase 10 -- */

/// A recommendation request: today or tomorrow, a mess (null = mine), a
/// meal (null = the server's default: the next one not logged).
typedef RecommendKey = ({String date, String? code, String? slot});

/// What the app has for a recommendation. Never a saved copy: offline or on
/// any failure there is NO plate, only the reason (requirement 22).
sealed class RecommendState {
  const RecommendState();
}

class RecommendLoaded extends RecommendState {
  const RecommendLoaded(this.recommendation);
  final MessRecommendation recommendation;
}

class RecommendOffline extends RecommendState {
  const RecommendOffline();
}

/// No mess configured (and none given).
class RecommendNoMess extends RecommendState {
  const RecommendNoMess();
}

class RecommendFailed extends RecommendState {
  const RecommendFailed(this.failure);
  final Failure failure;
}

/// Fetched fresh every time it is watched; refetched when a food log
/// reaches the server (what remains changes). Not cached anywhere.
final messRecommendProvider =
    FutureProvider.autoDispose.family<RecommendState, RecommendKey>(
  (ref, key) async {
    requireSession(ref);
    final sub = ref
        .watch(nutritionLogRepositoryProvider)
        .drained
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);
    final r = await ref
        .watch(messApiProvider)
        .recommend(date: key.date, mess: key.code, slot: key.slot);
    return switch (r) {
      Ok(:final value) => RecommendLoaded(value),
      Err(:final failure) => switch (failure) {
          Offline() => const RecommendOffline(),
          NotFound() when key.code == null => const RecommendNoMess(),
          _ => RecommendFailed(failure),
        },
    };
  },
  retry: (_, __) => null,
);
