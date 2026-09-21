import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../health/domain/entities/health.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../training/presentation/controllers/program_controller.dart';
import '../../../workout/domain/entities/workout.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../domain/home_context.dart';
import '../../domain/home_suggestion_engine.dart';

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

final homeContextProvider = Provider<HomeContext>((ref) {
  final profile = ref.watch(profileControllerProvider).value;
  return HomeContext(
    date: ref.watch(localTodayProvider),
    hourOfDay: ref.watch(localHourProvider),
    today: ref.watch(todayProvider).value,
    activeSession: ref.watch(activeSessionProvider).value,
    completedToday: ref.watch(completedTodayProvider).value,
    targets: profile?.goal.targets,
    // Phase 8 fills this; until then it is honestly not logged.
    nutrition: NutritionContext.notLogged,
    health: ref.watch(healthSnapshotProvider).value,
    connection: ref.watch(healthConnectionProvider).value,
    stepGoal: ref.watch(stepGoalProvider),
    volume: ref.watch(volumeProvider).value,
    week: ref.watch(weekContextProvider),
  );
});

/// The engine's ordered list for the current context.
final homeSuggestionsProvider = Provider<List<Suggestion>>((ref) {
  return const HomeSuggestionEngine().evaluate(ref.watch(homeContextProvider));
});

/// True while the first `/today` answer is still in flight (so Home shows
/// a skeleton instead of an empty carousel).
final homeLoadingProvider = Provider<bool>((ref) {
  final today = ref.watch(todayProvider);
  return today.isLoading && today.value == null;
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
