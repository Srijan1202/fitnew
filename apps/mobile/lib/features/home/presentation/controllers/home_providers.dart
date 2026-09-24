import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../health/domain/entities/health.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../today/presentation/today_providers.dart';
import '../../../training/presentation/controllers/program_controller.dart';
import '../../../workout/domain/entities/workout.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../domain/home_context.dart';
import '../../domain/home_suggestion_engine.dart';
import '../widgets/name_prompt.dart';

/// Phase 6.5 — the Home screen's context, assembled from what the app
/// already fetches (today, volume, profile, history, the active session)
/// plus the health snapshot. Every part is optional: a missing piece
/// leaves its section honest, never invented.

/// The session completed today, with its summary (records), when the
/// server says one exists.
final completedTodayProvider = FutureProvider<WorkoutSession?>((ref) async {
  requireSession(ref);
  final today = ref.watch(todayProvider).value;
  final id = today?.completedSessionId;
  if (id == null) return null;
  final r = await ref.watch(workoutRepositoryProvider).fetchSession(id);
  return r.when(ok: (s) => s, err: (_) => null);
});

/// The local hour in the user's calendar, sampled on each read.
final localHourProvider = Provider<int>((ref) {
  final zone = ref.watch(userTimezoneProvider);
  return tz.TZDateTime.now(userLocation(zone)).hour;
});

/// This week's counts, from data already on hand (Monday-first local week).
final weekContextProvider = Provider<WeekContext>((ref) {
  final date = ref.watch(localTodayProvider);
  final history = ref.watch(historyProvider).value;
  final program = ref.watch(programControllerProvider).value;
  final health = ref.watch(healthSnapshotProvider).value;
  final goal = ref.watch(stepGoalProvider);

  final monday = _mondayOf(date);
  var done = 0;
  if (history != null && monday != null) {
    for (final s in history.items) {
      if (s.status != SessionStatus.completed) continue;
      final local = _localDate(s.startedAt, ref.read(userTimezoneProvider));
      if (local != null && !local.isBefore(monday)) done++;
    }
  }
  final planned = program?.days.where((d) => !d.isRest).length ?? 0;

  int? movement;
  if (health != null && health.weekSteps.any((v) => v != null)) {
    movement = health.weekSteps.where((v) => v != null && v >= goal).length;
  }
  int? sleep;
  if (health != null && health.weekSleep.any((v) => v != null)) {
    sleep = health.weekSleep.where((v) => v != null).length;
  }
  return WeekContext(
    trainingDone: done,
    trainingPlanned: planned,
    movementDays: movement,
    sleepDays: sleep,
  );
});

DateTime? _mondayOf(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

DateTime? _localDate(String iso, String zone) {
  final at = DateTime.tryParse(iso);
  if (at == null) return null;
  final l = tz.TZDateTime.from(at.toUtc(), userLocation(zone));
  return DateTime(l.year, l.month, l.day);
}

/// Phase 6.6: the canonical display name — the profile's answer once
/// loaded, else what the session carried at sign-in. Null when unknown.
final displayNameProvider = Provider<String?>((ref) {
  final profile = ref.watch(profileControllerProvider).value;
  if (profile != null) return profile.profile.displayName;
  final auth = ref.watch(authControllerProvider).value;
  return auth is AuthSignedIn ? auth.profile.displayName : null;
});

/// Whether Home should ask for a name: the profile is loaded, has none,
/// and the user has not said "Not now" on this phone.
final askForNameProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileControllerProvider).value;
  if (profile == null || profile.profile.displayName != null) return false;
  return !ref.watch(namePromptDismissedProvider);
});

/// Today's food from the server's day (Phase 8) — the same cached day the
/// EAT screen shows, so the two always agree. Owner J16: the suggestion
/// engine gets the conservative high ends (see [NutritionContext]).
final homeNutritionProvider = Provider<NutritionContext>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return NutritionContext.notLogged;
  }
  final today = ref.watch(localTodayProvider);
  // Keeps today's day fetched (and refetched after the queue delivers).
  ref.watch(nutritionDayRefreshProvider(today));
  final server = ref.watch(nutritionDayViewProvider(today)).value?.server;
  if (server == null || server.totals.itemCount == 0) {
    return NutritionContext.notLogged;
  }
  final t = server.totals;
  return NutritionContext(
    logged: true,
    kcal: t.kcalHigh.round(),
    proteinG: t.proteinHigh.round(),
    kcalLow: t.kcalLow.round(),
    proteinLow: t.proteinLow.round(),
  );
});

final homeContextProvider = Provider<HomeContext>((ref) {
  final profile = ref.watch(profileControllerProvider).value;
  return HomeContext(
    displayName: ref.watch(displayNameProvider),
    date: ref.watch(localTodayProvider),
    hourOfDay: ref.watch(localHourProvider),
    today: ref.watch(todayProvider).value,
    activeSession: ref.watch(activeSessionProvider).value,
    completedToday: ref.watch(completedTodayProvider).value,
    targets: profile?.goal.targets,
    nutrition: ref.watch(homeNutritionProvider),
    health: ref.watch(healthSnapshotProvider).value,
    connection: ref.watch(healthConnectionProvider).value,
    stepGoal: ref.watch(stepGoalProvider),
    volume: ref.watch(volumeProvider).value,
    week: ref.watch(weekContextProvider),
  );
});

/// The device-only suggestions for the current context (resume, sleep,
/// steps, Health Connect).
final homeSuggestionsProvider = Provider<List<Suggestion>>((ref) {
  return const HomeSuggestionEngine().evaluate(ref.watch(homeContextProvider));
});

/// "Your next move" (Phase 11): the server's TODAY actions — live, or the
/// cached plan for today while offline, labelled — merged with the device
/// suggestions by band, at most four.
final homeNextMovesProvider = Provider<List<Suggestion>>((ref) {
  final view = ref.watch(todayPlanProvider).value;
  final plan = view?.plan;
  return HomeSuggestionEngine.merge(
    plan == null ? const [] : ref.watch(visibleTodayActionsProvider),
    ref.watch(homeSuggestionsProvider),
    planDate: plan?.date ?? ref.watch(localTodayProvider),
    cached: view?.source == TodayPlanSource.cached,
  );
});

/// True while the first `/training/today` or `/today` answer is still in
/// flight (so Home shows a skeleton instead of an empty carousel).
final homeLoadingProvider = Provider<bool>((ref) {
  final today = ref.watch(todayProvider);
  final plan = ref.watch(todayPlanProvider);
  return (today.isLoading && today.value == null) ||
      (plan.isLoading && plan.value == null);
});

/// The server-side failure Home should say out loud (Phase 6.6 Gate 6):
/// `/today` failed and there is no earlier answer to show, so the training
/// parts of Home are missing — the user deserves to know why, and a way to
/// retry. Null while loading, or once any answer has arrived.
final homeServerFailureProvider = Provider<Failure?>((ref) {
  final today = ref.watch(todayProvider);
  if (!today.hasError || today.value != null) return null;
  final e = today.error;
  return e is Failure ? e : const Unknown();
});

/// Health availability shortcuts for the metric blocks.
extension HealthAvailabilityText on HealthAvailability {
  /// The short line a block shows when there is no value.
  String get blockText => switch (this) {
        HealthAvailability.available => '',
        HealthAvailability.notConnected => 'Connect Health data',
        HealthAvailability.permissionDenied => 'Not allowed',
        HealthAvailability.noData => 'No data yet',
        HealthAvailability.temporarilyUnavailable => 'Unavailable right now',
        HealthAvailability.unsupported => 'Not on this phone',
      };
}
