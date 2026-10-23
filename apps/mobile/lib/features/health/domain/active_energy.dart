/// Beta 3.2 (ADR-008 amendment): active calories, combined on the phone.
///
/// Health Connect knows what the phone or a watch counted; FITOS knows the
/// workouts logged in it. Both are combined here, on the phone only: Health
/// Connect data never leaves it (owner B4). Nothing here changes a food
/// target (owner: shown only).
///
/// A workout's estimate: active kcal = (MET − 1) × kg × hours. The "− 1"
/// removes resting energy, as Health Connect's *active* calories do. MET is
/// from the 2024 Compendium of Physical Activities: 3.5 for typical
/// resistance training (code 02050), 5.0 for dense, vigorous sessions of
/// 20 or more working sets an hour (code 02052). Duration is the session's
/// own, capped at 3 hours.
library;

const kWorkoutMetModerate = 3.5;
const kWorkoutMetVigorous = 5.0;
const kVigorousSetsPerHour = 20;
const kWorkoutMinutesCap = 180;

/// The estimate for one logged workout, in whole kcal; 0 without a duration
/// or a weight.
int workoutActiveKcal({
  required int durationMinutes,
  required double? bodyWeightKg,
  required int workingSets,
}) {
  final kg = bodyWeightKg;
  if (durationMinutes <= 0 || kg == null || kg <= 0) return 0;
  final minutes =
      durationMinutes > kWorkoutMinutesCap ? kWorkoutMinutesCap : durationMinutes;
  final hours = minutes / 60;
  final met = workingSets / hours >= kVigorousSetsPerHour
      ? kWorkoutMetVigorous
      : kWorkoutMetModerate;
  return ((met - 1) * kg * hours).round();
}

/// One logged workout today, with what Health Connect counted during it.
class WorkoutEnergy {
  const WorkoutEnergy({
    required this.name,
    required this.estimateKcal,
    required this.healthDuringKcal,
  });

  final String name;

  /// FITOS's estimate for the session.
  final int estimateKcal;

  /// Health Connect's active kcal inside the session's window; null when
  /// Health Connect cannot say (not connected, not granted, an error).
  final double? healthDuringKcal;

  /// What this workout adds on top of Health Connect: the part it did not
  /// already count, never below 0.
  int get addedKcal {
    final counted = healthDuringKcal ?? 0;
    final extra = estimateKcal - counted;
    return extra <= 0 ? 0 : extra.round();
  }
}

/// Today's active calories, and where they came from.
class ActiveEnergy {
  const ActiveEnergy({
    required this.fromHealth,
    required this.workouts,
  });

  /// Health Connect's active kcal for the day; null when it cannot say.
  final int? fromHealth;
  final List<WorkoutEnergy> workouts;

  int get fromWorkouts => workouts.fold(0, (s, w) => s + w.addedKcal);

  /// The day's total: Health Connect's figure plus what the workouts add.
  int get total => (fromHealth ?? 0) + fromWorkouts;

  /// Nothing to show: no Health Connect figure and no workout estimate.
  bool get isEmpty => fromHealth == null && fromWorkouts == 0;
}

/// Combines Health Connect's day with today's workouts. A watch that tracked
/// the gym session is not counted twice; a phone that only counted steps gets
/// the workout added.
ActiveEnergy combineActiveEnergy({
  required double? healthDayKcal,
  required List<WorkoutEnergy> workouts,
}) =>
    ActiveEnergy(
      fromHealth: healthDayKcal?.round(),
      workouts: workouts,
    );
