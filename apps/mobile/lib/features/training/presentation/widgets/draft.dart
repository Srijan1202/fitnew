import '../../../exercise/domain/entities/exercise.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../domain/entities/program.dart';

/// An exercise being edited in the day editor or the builder: identity to
/// show, prescription to send. Pure client state until saved.
class DraftExercise {
  const DraftExercise({
    required this.key,
    required this.exerciseId,
    required this.name,
    required this.primaryMuscles,
    required this.equipment,
    required this.incrementKg,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
    required this.sets,
  });

  factory DraftExercise.fromPlanned(PlannedExercise x) => DraftExercise(
        key: x.id,
        exerciseId: x.exerciseId,
        name: x.name,
        primaryMuscles: x.primaryMuscles,
        equipment: x.equipment,
        incrementKg: x.incrementKg,
        repMin: x.repMin,
        repMax: x.repMax,
        targetRir: x.targetRir,
        sets: x.sets,
      );

  /// A fresh pick: 3 × 6–12 @ RIR 2 — the §12.1 muscle-gain row — no weight
  /// until the user types one.
  factory DraftExercise.fromSummary(ExerciseSummary s, {required int nonce}) =>
      DraftExercise(
        key: '${s.id}#$nonce',
        exerciseId: s.id,
        name: s.name,
        primaryMuscles: s.primaryMuscles,
        equipment: s.equipment,
        // The library's own increment is applied by the server when omitted.
        incrementKg: null,
        repMin: 6,
        repMax: 12,
        targetRir: 2,
        sets: [
          for (var i = 1; i <= 3; i++)
            PlannedSet(
              setIndex: i,
              repsMin: 6,
              repsMax: 12,
              weightKg: null,
              rir: 2,
            ),
        ],
      );

  /// Stable identity for lists and reorders.
  final String key;
  final String exerciseId;
  final String name;
  final List<MuscleGroup> primaryMuscles;
  final List<Equipment> equipment;
  final double? incrementKg;
  final int repMin;
  final int repMax;
  final int targetRir;
  final List<PlannedSet> sets;

  DraftExercise copyWith({List<PlannedSet>? sets}) => DraftExercise(
        key: key,
        exerciseId: exerciseId,
        name: name,
        primaryMuscles: primaryMuscles,
        equipment: equipment,
        incrementKg: incrementKg,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
        sets: sets ?? this.sets,
      );

  /// Change the number of sets: added sets copy the last one's targets.
  DraftExercise withSetCount(int count) {
    final n = count.clamp(1, 10);
    final next = <PlannedSet>[];
    for (var i = 1; i <= n; i++) {
      final source = i <= sets.length ? sets[i - 1] : sets.last;
      next.add(source.copyWith(setIndex: i));
    }
    return copyWith(sets: next);
  }

  DraftExercise withSet(PlannedSet set) => copyWith(
        sets: [for (final s in sets) s.setIndex == set.setIndex ? set : s],
      );

  CustomExercise toCustom() => CustomExercise(
        exerciseId: exerciseId,
        setCount: sets.length,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
        incrementKg: incrementKg,
        sets: sets.map((s) => s.toCustom()).toList(),
      );
}
