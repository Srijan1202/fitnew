import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/training/domain/repositories/training_repository.dart';

const _squatId = '11111111-1111-4111-8111-111111111111';
const _benchId = '22222222-2222-4222-8222-222222222222';

const plannedSquat = PlannedExercise(
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  exerciseId: _squatId,
  slug: 'barbell-back-squat',
  name: 'Barbell Back Squat',
  movementPattern: MovementPattern.squat,
  equipment: [Equipment.barbell],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
  orderIndex: 0,
  setCount: 4,
  repMin: 6,
  repMax: 12,
  targetRir: 1,
  incrementKg: 5,
  reason: 'squat for quads and glutes: 4 sets → quads 4, glutes 4.',
);

const plannedBench = PlannedExercise(
  id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  exerciseId: _benchId,
  slug: 'barbell-bench-press',
  name: 'Barbell Bench Press',
  movementPattern: MovementPattern.horizontalPush,
  equipment: [Equipment.barbell],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: [MuscleGroup.chest],
  orderIndex: 0,
  setCount: 4,
  repMin: 6,
  repMax: 12,
  targetRir: 1,
  incrementKg: 2.5,
  reason: 'horizontal push for chest: 4 sets → chest 4, triceps 2.',
);

ProgramDay _day(int dow, String name, List<PlannedExercise> xs) => ProgramDay(
      id: 'dddddddd-dddd-4ddd-8ddd-${dow.toString().padLeft(12, '0')}',
      dayOfWeek: dow,
      sessionName: name,
      focus: const [],
      isRest: false,
      estimatedMinutes: xs.fold(0, (s, x) => s + x.setCount) * 7 ~/ 2,
      exercises: xs,
    );

ProgramDay _rest(int dow) => ProgramDay(
      id: 'dddddddd-dddd-4ddd-8ddd-${dow.toString().padLeft(12, '0')}',
      dayOfWeek: dow,
      sessionName: 'Rest',
      focus: const [],
      isRest: true,
      estimatedMinutes: 0,
      exercises: const [],
    );

/// A two-day generated programme with one shortfall, as the server would send it.
final generatedProgram = Program(
  id: 'pppppppp-pppp-4ppp-8ppp-pppppppppppp',
  name: 'Full Body · 2 days',
  splitType: SplitType.fullBody,
  daysPerWeek: 2,
  source: ProgramSource.generated,
  mesocycleWeek: 1,
  active: true,
  createdAt: '2026-09-21T09:00:00.000Z',
  days: [
    _day(1, 'Full Body', [plannedSquat, plannedBench]),
    _rest(2),
    _rest(3),
    _day(4, 'Full Body', [
      plannedBench.copyWith(id: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000004'),
      plannedSquat.copyWith(id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000004'),
    ]),
    _rest(5),
    _rest(6),
    _rest(7),
  ],
  weeklyVolume: const {'quads': 8, 'glutes': 8, 'chest': 8, 'triceps': 4},
  rationale: const [
    '2 days/week as beginner: full body each session (§12.2).',
    'Below target: calves (session-time).',
  ],
  shortfalls: const [
    VolumeShortfall(
      muscle: MuscleGroup.calves,
      targetSets: 8,
      plannedSets: 0,
      reason: ShortfallReason.sessionTime,
      detail:
          '60-minute sessions × 2 days leave 0 of 8 sets for calves; add a day or minutes to reach MEV.',
    ),
  ],
);

/// Scripted TrainingRepository. Records every request body so tests assert
/// what the server was sent.
class FakeTrainingRepository implements TrainingRepository {
  Result<Program?> nextProgram = const Ok(null);
  Result<Program> nextGenerate = Ok(generatedProgram);
  Result<Program> nextPut = Ok(generatedProgram);
  Result<Program> nextPatch = Ok(generatedProgram);

  final calls = <String>[];
  final generateRequests = <GenerateProgramRequest>[];
  final putRequests = <PutProgramRequest>[];
  final patchRequests = <(String, PatchProgramDayRequest)>[];

  @override
  Future<Result<Program?>> getProgram() async {
    calls.add('getProgram');
    return nextProgram;
  }

  @override
  Future<Result<Program>> generate(GenerateProgramRequest request) async {
    calls.add('generate');
    generateRequests.add(request);
    return nextGenerate;
  }

  @override
  Future<Result<Program>> putProgram(PutProgramRequest request) async {
    calls.add('putProgram');
    putRequests.add(request);
    return nextPut;
  }

  @override
  Future<Result<Program>> patchDay(
    String dayId,
    PatchProgramDayRequest request,
  ) async {
    calls.add('patchDay:$dayId');
    patchRequests.add((dayId, request));
    return nextPatch;
  }
}
