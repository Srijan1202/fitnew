import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/training/domain/repositories/training_repository.dart';

const _squatId = '11111111-1111-4111-8111-111111111111';
const _benchId = '22222222-2222-4222-8222-222222222222';

List<PlannedSet> uniformSets(int n, {double? weightKg}) => [
      for (var i = 1; i <= n; i++)
        PlannedSet(
          setIndex: i,
          repsMin: 6,
          repsMax: 12,
          weightKg: weightKg,
          rir: 1,
        ),
    ];

final plannedSquat = PlannedExercise(
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  exerciseId: _squatId,
  slug: 'barbell-back-squat',
  name: 'Barbell Back Squat',
  movementPattern: MovementPattern.squat,
  equipment: const [Equipment.barbell],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: const [MuscleGroup.quads, MuscleGroup.glutes],
  orderIndex: 0,
  setCount: 4,
  repMin: 6,
  repMax: 12,
  targetRir: 1,
  incrementKg: 5,
  reason: 'squat for quads and glutes: 4 sets → quads 4, glutes 4.',
  sets: uniformSets(4),
);

final plannedBench = PlannedExercise(
  id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  exerciseId: _benchId,
  slug: 'barbell-bench-press',
  name: 'Barbell Bench Press',
  movementPattern: MovementPattern.horizontalPush,
  equipment: const [Equipment.barbell],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: const [MuscleGroup.chest],
  orderIndex: 1,
  setCount: 3,
  repMin: 6,
  repMax: 12,
  targetRir: 1,
  incrementKg: 2.5,
  reason: 'horizontal push for chest: 3 sets → chest 3, triceps 1.5.',
  sets: uniformSets(3, weightKg: 40),
);

ProgramDay _day(int dow, String name, List<PlannedExercise> xs) => ProgramDay(
      id: 'dddddddd-dddd-4ddd-8ddd-${dow.toString().padLeft(12, '0')}',
      dayOfWeek: dow,
      sessionName: name,
      focus: const [MuscleGroup.quads, MuscleGroup.chest],
      isRest: false,
      estimatedMinutes: xs.fold(0, (s, x) => s + x.sets.length) * 7 ~/ 2,
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

/// A two-day generated programme with one shortfall, as the server sends it.
final generatedProgram = Program(
  id: 'pppppppp-pppp-4ppp-8ppp-pppppppppppp',
  name: 'Full Body · 2 days',
  splitType: SplitType.fullBody,
  daysPerWeek: 2,
  source: ProgramSource.generated,
  templateSlug: null,
  mesocycleWeek: 1,
  active: true,
  createdAt: '2026-09-21T09:00:00.000Z',
  days: [
    _day(1, 'Full Body', [plannedSquat, plannedBench]),
    _rest(2),
    _rest(3),
    _day(4, 'Full Body', [
      plannedBench.copyWith(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000004',
        orderIndex: 0,
      ),
      plannedSquat.copyWith(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000004',
        orderIndex: 1,
      ),
    ]),
    _rest(5),
    _rest(6),
    _rest(7),
  ],
  weeklyVolume: const {'quads': 8, 'glutes': 8, 'chest': 6, 'triceps': 3},
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

const pplTemplate = ProgramTemplate(
  slug: 'push-pull-legs',
  name: 'Push / Pull / Legs',
  daysPerWeek: 3,
  level: TemplateLevel.any,
  approxMinutes: 60,
  summary: 'Three sessions: pressing, pulling, then legs.',
  days: [
    TemplateDay(
      dayOfWeek: 1,
      sessionName: 'Push',
      muscles: [MuscleGroup.chest, MuscleGroup.shoulders, MuscleGroup.triceps],
    ),
    TemplateDay(
      dayOfWeek: 3,
      sessionName: 'Pull',
      muscles: [MuscleGroup.back, MuscleGroup.biceps],
    ),
    TemplateDay(
      dayOfWeek: 5,
      sessionName: 'Legs',
      muscles: [MuscleGroup.quads, MuscleGroup.hamstrings, MuscleGroup.glutes],
    ),
  ],
);

const broTemplate = ProgramTemplate(
  slug: 'bro-split',
  name: 'Bro Split',
  daysPerWeek: 5,
  level: TemplateLevel.intermediate,
  approxMinutes: 50,
  summary: 'One body part per day.',
  days: [
    TemplateDay(
      dayOfWeek: 1,
      sessionName: 'Chest',
      muscles: [MuscleGroup.chest],
    ),
    TemplateDay(dayOfWeek: 2, sessionName: 'Back', muscles: [MuscleGroup.back]),
    TemplateDay(
      dayOfWeek: 3,
      sessionName: 'Shoulders',
      muscles: [MuscleGroup.shoulders],
    ),
    TemplateDay(
      dayOfWeek: 5,
      sessionName: 'Legs',
      muscles: [MuscleGroup.quads],
    ),
    TemplateDay(
      dayOfWeek: 6,
      sessionName: 'Arms',
      muscles: [MuscleGroup.biceps, MuscleGroup.triceps],
    ),
  ],
);

PreviewExercise _previewOf(PlannedExercise x) => PreviewExercise(
      exerciseId: x.exerciseId,
      slug: x.slug,
      name: x.name,
      movementPattern: x.movementPattern,
      equipment: x.equipment,
      difficulty: x.difficulty,
      isUnilateral: x.isUnilateral,
      primaryMuscles: x.primaryMuscles,
      orderIndex: x.orderIndex,
      setCount: x.setCount,
      repMin: x.repMin,
      repMax: x.repMax,
      targetRir: x.targetRir,
      incrementKg: x.incrementKg,
      reason: x.reason,
      sets: uniformSets(x.setCount),
    );

PreviewDay _previewRest(int dow) => PreviewDay(
      dayOfWeek: dow,
      sessionName: 'Rest',
      focus: const [],
      isRest: true,
      estimatedMinutes: 0,
      exercises: const [],
    );

final pplPreview = TemplatePreview(
  template: pplTemplate,
  days: [
    PreviewDay(
      dayOfWeek: 1,
      sessionName: 'Push',
      focus: const [MuscleGroup.chest],
      isRest: false,
      estimatedMinutes: 42,
      exercises: [_previewOf(plannedBench)],
    ),
    _previewRest(2),
    PreviewDay(
      dayOfWeek: 3,
      sessionName: 'Pull',
      focus: const [MuscleGroup.back],
      isRest: false,
      estimatedMinutes: 35,
      exercises: [_previewOf(plannedSquat)],
    ),
    _previewRest(4),
    PreviewDay(
      dayOfWeek: 5,
      sessionName: 'Legs',
      focus: const [MuscleGroup.quads],
      isRest: false,
      estimatedMinutes: 53,
      exercises: [_previewOf(plannedSquat)],
    ),
    _previewRest(6),
    _previewRest(7),
  ],
  weeklyVolume: const {'chest': 3},
  rationale: const ['Push / Pull / Legs: 3 days/week — Three sessions.'],
  shortfalls: const [],
);

/// Scripted TrainingRepository. Records every request body so tests assert
/// what the server was sent.
class FakeTrainingRepository implements TrainingRepository {
  Result<Program?> nextProgram = const Ok(null);
  Result<Program> nextGenerate = Ok(generatedProgram);
  Result<Program> nextPut = Ok(generatedProgram);
  Result<Program>? nextPatch;
  Result<Program> nextRename = Ok(generatedProgram);
  Result<List<ProgramTemplate>> nextTemplates =
      const Ok([pplTemplate, broTemplate]);
  Result<TemplatePreview> nextPreview = Ok(pplPreview);
  Result<Program> nextApply = Ok(generatedProgram);

  final calls = <String>[];
  final generateRequests = <GenerateProgramRequest>[];
  final putRequests = <PutProgramRequest>[];
  final patchRequests = <(String, PatchProgramDayRequest)>[];
  final applyRequests = <(String, GenerateProgramRequest)>[];

  /// What the "server" holds; PATCH answers with the edited programme, as a
  /// real server does, unless [nextPatch] is scripted.
  Program? stored;

  @override
  Future<Result<Program?>> getProgram() async {
    calls.add('getProgram');
    if (stored != null) return Ok(stored);
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
    final scripted = nextPatch;
    if (scripted != null) return scripted;
    final current = stored ?? generatedProgram;
    final edited = current.copyWith(
      days: [
        for (final d in current.days)
          if (d.id == dayId) _applyPatch(d, request) else d,
      ],
    );
    stored = edited;
    return Ok(edited);
  }

  /// Fresh ids for rows the server would insert.
  static int _inserted = 0;

  /// The server's semantics exactly: a row that names an existing planned
  /// exercise by `id` is updated in place (same id); any other row is a new
  /// insert with a NEW id. A fake that matched by exercise id hid the bug
  /// where every save re-created the rows and collapsed the expanded card.
  static ProgramDay _applyPatch(ProgramDay d, PatchProgramDayRequest r) {
    final sets = r.exercises;
    if (sets == null) {
      return d.copyWith(
        sessionName: r.sessionName ?? d.sessionName,
        focus: r.focus ?? d.focus,
      );
    }
    final byId = {for (final x in d.exercises) x.id: x};
    final claimed = <String>{};
    final next = <PlannedExercise>[];
    for (var i = 0; i < sets.length; i++) {
      final c = sets[i];
      final kept = c.id != null && byId.containsKey(c.id) && claimed.add(c.id!)
          ? byId[c.id]!
          : null;
      final base = kept ??
          plannedSquat.copyWith(
            id: 'inserted-${++_inserted}',
            reason: null,
          );
      final movementChanged = base.exerciseId != c.exerciseId;
      next.add(
        base.copyWith(
          exerciseId: c.exerciseId,
          name: movementChanged ? 'Picked ${c.exerciseId}' : base.name,
          orderIndex: i,
          setCount: c.setCount,
          repMin: c.repMin,
          repMax: c.repMax,
          targetRir: c.targetRir,
          sets: [
            for (var j = 0; j < (c.sets?.length ?? c.setCount); j++)
              PlannedSet(
                setIndex: j + 1,
                repsMin: c.sets?[j].repsMin ?? c.repMin,
                repsMax: c.sets?[j].repsMax ?? c.repMax,
                weightKg: c.sets?[j].weightKg ?? c.startingWeightKg,
                rir: c.sets?[j].rir ?? c.targetRir,
              ),
          ],
        ),
      );
    }
    return d.copyWith(
      sessionName: r.sessionName ?? d.sessionName,
      focus: r.focus ?? d.focus,
      isRest: sets.isEmpty,
      exercises: next,
    );
  }

  @override
  Future<Result<Program>> rename(String name) async {
    calls.add('rename:$name');
    return nextRename;
  }

  @override
  Future<Result<List<ProgramTemplate>>> listTemplates() async {
    calls.add('listTemplates');
    return nextTemplates;
  }

  @override
  Future<Result<TemplatePreview>> previewTemplate(
    String slug,
    GenerateProgramRequest request,
  ) async {
    calls.add('previewTemplate:$slug');
    return nextPreview;
  }

  @override
  Future<Result<Program>> applyTemplate(
    String slug,
    GenerateProgramRequest request,
  ) async {
    calls.add('applyTemplate:$slug');
    applyRequests.add((slug, request));
    return nextApply;
  }
}
