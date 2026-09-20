import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';

const squat = ExerciseSummary(
  id: '11111111-1111-4111-8111-111111111111',
  slug: 'barbell-back-squat',
  name: 'Barbell Back Squat',
  movementPattern: MovementPattern.squat,
  equipment: [Equipment.barbell],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
);

const pushUp = ExerciseSummary(
  id: '22222222-2222-4222-8222-222222222222',
  slug: 'push-up',
  name: 'Push-Up',
  movementPattern: MovementPattern.horizontalPush,
  equipment: [Equipment.bodyweight],
  difficulty: Difficulty.beginner,
  isUnilateral: false,
  primaryMuscles: [MuscleGroup.chest],
);

const squatDetail = ExerciseDetail(
  id: '11111111-1111-4111-8111-111111111111',
  slug: 'barbell-back-squat',
  name: 'Barbell Back Squat',
  movementPattern: MovementPattern.squat,
  equipment: [Equipment.barbell],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
  defaultIncrementKg: 5,
  instructions: [
    'Set the bar across your upper back.',
    'Sit down and back, knees over toes.',
    'Drive through the whole foot to stand.',
  ],
  videoUrl: null,
  muscles: [
    ExerciseMuscle(
      muscleGroup: MuscleGroup.quads,
      role: MuscleRole.primary,
      contribution: 1,
    ),
    ExerciseMuscle(
      muscleGroup: MuscleGroup.glutes,
      role: MuscleRole.primary,
      contribution: 1,
    ),
    ExerciseMuscle(
      muscleGroup: MuscleGroup.hamstrings,
      role: MuscleRole.secondary,
      contribution: 0.5,
    ),
  ],
  alternatives: [
    ExerciseAlternative(
      id: '33333333-3333-4333-8333-333333333333',
      slug: 'goblet-squat',
      name: 'Goblet Squat',
      reason: AlternativeReason.equipment,
      equipment: [Equipment.dumbbell],
    ),
    ExerciseAlternative(
      id: '44444444-4444-4444-8444-444444444444',
      slug: 'leg-press',
      name: 'Leg Press',
      reason: AlternativeReason.injury,
      equipment: [Equipment.machine],
    ),
  ],
  contraindications: [BodyPart.knee, BodyPart.lowerBack],
);

/// Scripted ExerciseRepository. Records every query so tests assert what
/// the server was asked, not what the client thinks it filtered.
class FakeExerciseRepository implements ExerciseRepository {
  Result<ExerciseListResponse> Function(ExerciseQuery) nextList =
      (q) => const Ok(
            ExerciseListResponse(
              items: [squat, pushUp],
              total: 2,
              limit: 200,
              offset: 0,
            ),
          );
  Result<ExerciseDetail> nextDetail = const Ok(squatDetail);

  final queries = <ExerciseQuery>[];
  final detailIds = <String>[];

  @override
  Future<Result<ExerciseListResponse>> list(ExerciseQuery query) async {
    queries.add(query);
    return nextList(query);
  }

  @override
  Future<Result<ExerciseDetail>> detail(String id) async {
    detailIds.add(id);
    return nextDetail;
  }
}
