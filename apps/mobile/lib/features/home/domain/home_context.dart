import '../../health/domain/entities/health.dart';
import '../../profile/domain/entities/profile.dart';
import '../../workout/domain/entities/workout.dart';

/// Phase 6.5 — everything the Home screen and the suggestion engine look
/// at, assembled once from providers (owner D3: a device-side context
/// because health data never leaves the phone). Every number in here was
/// computed elsewhere — by the server (recommendations, deload, neglect,
/// targets, volume statuses) or by the health provider; the engine only
/// compares and orders.
class HomeContext {
  const HomeContext({
    required this.date,
    required this.hourOfDay,
    required this.today,
    required this.activeSession,
    required this.completedToday,
    required this.targets,
    required this.nutrition,
    required this.health,
    required this.connection,
    required this.stepGoal,
    required this.volume,
    required this.week,
  });

  /// Local date yyyy-mm-dd and the local hour (0–23) in the user's zone.
  final String date;
  final int hourOfDay;

  /// The server's day: session state, recommendations, deload, neglect.
  /// Null when it could not be fetched and nothing is cached.
  final TodayResponse? today;

  /// The session in progress on this phone, if any.
  final WorkoutSession? activeSession;

  /// The session completed today, with its summary (records), if any.
  final WorkoutSession? completedToday;

  /// The user's nutrition targets (Phase 2), if any.
  final NutritionTargets? targets;

  /// What has been logged today — honestly `notLogged` until Phase 8.
  final NutritionContext nutrition;

  final HealthSnapshot? health;
  final HealthConnectionState? connection;

  /// Owner D4.
  final int stepGoal;

  /// The current week's volume statuses, if fetched.
  final VolumeResponse? volume;

  /// This week's consistency, already counted.
  final WeekContext week;

  bool get healthUnsupported =>
      connection == null || connection!.sdk == HealthSdkStatus.unavailable;
  bool get healthConnected => connection?.isConnected ?? false;
}

/// Food logged today. Phase 8 fills it; until then it is `notLogged`.
class NutritionContext {
  const NutritionContext({
    required this.logged,
    this.kcal,
    this.proteinG,
    this.mealsRemaining,
  });

  static const notLogged = NutritionContext(logged: false);

  final bool logged;
  final int? kcal;
  final int? proteinG;
  final int? mealsRemaining;
}

/// Simple counts for "This week". Nutrition is omitted until Phase 8.
class WeekContext {
  const WeekContext({
    required this.trainingDone,
    required this.trainingPlanned,
    required this.movementDays,
    required this.sleepDays,
  });

  static const empty = WeekContext(
    trainingDone: 0,
    trainingPlanned: 0,
    movementDays: null,
    sleepDays: null,
  );

  final int trainingDone;
  final int trainingPlanned;

  /// Days of this week at or above the step goal; null = no step data.
  final int? movementDays;

  /// Nights of this week with a sleep record; null = no sleep data.
  final int? sleepDays;
}
