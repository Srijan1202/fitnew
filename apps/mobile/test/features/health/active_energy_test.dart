import 'package:fitos/features/health/domain/active_energy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 3.2 (ADR-008 amendment): a workout's active calories and the day's
/// total with Health Connect, never counting the same minutes twice.
/// Every expectation is a hand calculation.
void main() {
  group('workoutActiveKcal', () {
    test('typical resistance training: (3.5 − 1) × kg × hours', () {
      // 60 min, 70 kg, 18 sets (< 20 an hour): 2.5 × 70 × 1 = 175.
      expect(
        workoutActiveKcal(
          durationMinutes: 60,
          bodyWeightKg: 70,
          workingSets: 18,
        ),
        175,
      );
    });

    test('a dense session (20+ working sets an hour) uses 5.0', () {
      // 45 min, 80 kg, 15 sets = 20 an hour: 4 × 80 × 0.75 = 240.
      expect(
        workoutActiveKcal(
          durationMinutes: 45,
          bodyWeightKg: 80,
          workingSets: 15,
        ),
        240,
      );
      // 14 sets in 45 min = 18.7 an hour: 2.5 × 80 × 0.75 = 150.
      expect(
        workoutActiveKcal(
          durationMinutes: 45,
          bodyWeightKg: 80,
          workingSets: 14,
        ),
        150,
      );
    });

    test('capped at three hours; nothing without a duration or a weight', () {
      // 300 min counts as 180: 2.5 × 60 × 3 = 450.
      expect(
        workoutActiveKcal(
          durationMinutes: 300,
          bodyWeightKg: 60,
          workingSets: 10,
        ),
        450,
      );
      expect(
        workoutActiveKcal(
          durationMinutes: 0,
          bodyWeightKg: 70,
          workingSets: 10,
        ),
        0,
      );
      expect(
        workoutActiveKcal(
          durationMinutes: 60,
          bodyWeightKg: null,
          workingSets: 10,
        ),
        0,
      );
      expect(
        workoutActiveKcal(
          durationMinutes: 60,
          bodyWeightKg: 0,
          workingSets: 10,
        ),
        0,
      );
    });
  });

  group('combineActiveEnergy', () {
    test('no Health Connect: the workouts alone', () {
      final e = combineActiveEnergy(
        healthDayKcal: null,
        workouts: const [
          WorkoutEnergy(
            name: 'Push',
            estimateKcal: 175,
            healthDuringKcal: null,
          ),
        ],
      );
      expect(e.fromHealth, isNull);
      expect(e.fromWorkouts, 175);
      expect(e.total, 175);
      expect(e.isEmpty, isFalse);
    });

    test('a watch that tracked the session: nothing added (no double count)',
        () {
      final e = combineActiveEnergy(
        healthDayKcal: 520,
        workouts: const [
          WorkoutEnergy(name: 'Push', estimateKcal: 175, healthDuringKcal: 210),
        ],
      );
      expect(e.fromWorkouts, 0);
      expect(e.total, 520);
    });

    test('a phone that only counted steps: the uncounted part is added', () {
      // Health Connect saw 40 kcal during the 175 kcal session: +135.
      final e = combineActiveEnergy(
        healthDayKcal: 280.4,
        workouts: const [
          WorkoutEnergy(name: 'Push', estimateKcal: 175, healthDuringKcal: 40),
        ],
      );
      expect(e.fromHealth, 280);
      expect(e.fromWorkouts, 135);
      expect(e.total, 415);
    });

    test('two sessions, each on its own window; nothing at all is empty', () {
      final e = combineActiveEnergy(
        healthDayKcal: 300,
        workouts: const [
          WorkoutEnergy(name: 'Push', estimateKcal: 175, healthDuringKcal: 0),
          WorkoutEnergy(name: 'Core', estimateKcal: 60, healthDuringKcal: 59.6),
        ],
      );
      expect(e.fromWorkouts, 175);
      expect(e.total, 475);
      expect(
        combineActiveEnergy(healthDayKcal: null, workouts: const []).isEmpty,
        isTrue,
      );
      expect(
        combineActiveEnergy(healthDayKcal: 0, workouts: const []).isEmpty,
        isFalse,
        reason: 'Health Connect said 0: that is a figure',
      );
    });
  });
}
