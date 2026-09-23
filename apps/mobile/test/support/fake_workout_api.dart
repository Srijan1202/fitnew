import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/workout/data/workout_api.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';

/// A tiny in-memory server that behaves like the real one where it
/// matters for sync: idempotent on client ids, one active session, 409
/// on logging to a completed session unless merging. Can be "offline".
class FakeWorkoutApi implements WorkoutApi {
  bool offline = false;

  /// Phase 6.7: while set, every call answers with this failure — the
  /// hosted outages (a 502 / 503 / 504 / Cloud Run 429 mapped by
  /// ErrorMapper), FITOS's own 429, or a 500 for contrast. Requests that
  /// reach the fake are counted in [calls] with a `down:` prefix.
  Failure? down;

  /// Every call, in order: 'start', 'logSets:3', 'complete', …
  final calls = <String>[];

  /// How many batches the position rule rejected (the S24's 409s).
  int positionConflicts = 0;

  /// Sessions by client id.
  final sessions = <String, WorkoutSession>{};
  int _ids = 0;
  String _id() =>
      '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}';

  Result<T> _guard<T>(Result<T> Function() body) {
    if (offline) return const Err(Offline());
    if (down case final failure?) {
      calls.add('down:${failure.runtimeType}');
      return Err(failure);
    }
    return body();
  }

  WorkoutSession? _byServerId(String id) {
    for (final s in sessions.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  static const _kSquat = ExerciseSummary(
    id: '11111111-1111-4111-8111-111111111111',
    slug: 'barbell-back-squat',
    name: 'Barbell Back Squat',
    movementPattern: MovementPattern.squat,
    equipment: [Equipment.barbell],
    difficulty: Difficulty.intermediate,
    isUnilateral: false,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
  );

  /// Catalogue metadata the fake knows: the day's exercises, else squat.
  TodayExercise? _known(String exerciseId) {
    for (final x in todayResponse.exercises) {
      if (x.exerciseId == exerciseId) return x;
    }
    return null;
  }

  SessionExercise _exercise(SeededExercise x) {
    final k = _known(x.exerciseId);
    return SessionExercise(
      id: _id(),
      clientExerciseId: x.clientExerciseId,
      exerciseId: x.exerciseId,
      slug: k?.slug ?? _kSquat.slug,
      name: k?.name ?? _kSquat.name,
      movementPattern: k?.movementPattern ?? _kSquat.movementPattern,
      equipment: k?.equipment ?? _kSquat.equipment,
      difficulty: k?.difficulty ?? _kSquat.difficulty,
      primaryMuscles: k?.primaryMuscles ?? _kSquat.primaryMuscles,
      secondaryMuscles: k?.secondaryMuscles ?? const [MuscleGroup.hamstrings],
      incrementKg: k?.incrementKg ?? 5,
      orderIndex: x.orderIndex,
      supersetGroup: null,
      plannedExerciseId: x.plannedExerciseId,
      recommendation: k?.recommendation,
      priorBest: k?.priorBest ?? PriorBest.none,
      originalTargets: k?.originalTargets,
      targets: k?.targets ??
          const [
            PlannedSet(
              setIndex: 1,
              repsMin: 6,
              repsMax: 12,
              weightKg: null,
              rir: 1,
            ),
            PlannedSet(
              setIndex: 2,
              repsMin: 6,
              repsMax: 12,
              weightKg: null,
              rir: 1,
            ),
            PlannedSet(
              setIndex: 3,
              repsMin: 6,
              repsMax: 12,
              weightKg: null,
              rir: 1,
            ),
          ],
      prefill: k?.prefill ?? const [],
      lastPerformance: k?.lastPerformance,
      sets: const [],
    );
  }

  /// The active programme's day ids, when a test scripts a programme
  /// change. Null accepts any day (most tests).
  Set<String>? activeProgramDayIds;

  /// Every start request as received (the S24 404s were in the body).
  final startRequests = <StartSessionRequest>[];

  @override
  Future<Result<WorkoutSession>> start(StartSessionRequest request) async {
    calls.add('start');
    startRequests.add(request);
    return _guard(() {
      final existing = sessions[request.clientSessionId];
      if (existing != null) return Ok(existing);
      // The server checks the day before the one-active-session guard.
      final days = activeProgramDayIds;
      if (days != null &&
          request.programDayId != null &&
          !days.contains(request.programDayId)) {
        return const Err(
          NotFound('That day is not in your active programme.'),
        );
      }
      final active =
          sessions.values.where((s) => s.status == SessionStatus.active);
      if (active.isNotEmpty) {
        return Err(
          Conflict(
            'A session is already in progress.',
            path: 'activeSessionId',
            issue: active.first.id,
          ),
        );
      }
      final session = WorkoutSession(
        id: _id(),
        clientSessionId: request.clientSessionId,
        status: SessionStatus.active,
        programId: null,
        programDayId: request.programDayId,
        name: request.programDayId == null ? 'Session' : 'Legs',
        startedAt: request.startedAt,
        completedAt: null,
        durationSeconds: null,
        notes: null,
        exercises: [
          for (final x in request.exercises ?? const <SeededExercise>[])
            _exercise(x),
        ],
        summary: null,
      );
      sessions[request.clientSessionId] = session;
      return Ok(session);
    });
  }

  @override
  Future<Result<WorkoutSession>> get(String id) async {
    calls.add('get');
    return _guard(() {
      final s = _byServerId(id);
      return s == null ? const Err(Unknown('No such session.')) : Ok(s);
    });
  }

  @override
  Future<Result<WorkoutSession>> logSets(
    String id,
    LogSetsRequest request,
  ) async {
    calls.add('logSets:${request.sets.length}${request.merge ? ':merge' : ''}');
    return _guard(() {
      final s = _byServerId(id);
      if (s == null) return const Err(Unknown('No such session.'));
      if (s.status != SessionStatus.active && !request.merge) {
        return Err(
          Conflict(
            'This session is ${s.status.wire}.',
            path: 'session',
            issue: s.status.wire,
          ),
        );
      }
      // The server's one-live-set-per-position rule (set_logs_live_position),
      // all or nothing like its transaction: a set at a taken position under a
      // different client id rejects the whole batch.
      for (final input in request.sets) {
        final x = s.exercises
            .where((e) => e.clientExerciseId == input.clientExerciseId)
            .firstOrNull;
        final taken = x?.sets.any(
          (t) =>
              t.setIndex == input.setIndex &&
              t.setType == input.setType &&
              t.clientSetId != input.clientSetId,
        );
        if (taken ?? false) {
          positionConflicts++;
          return const Err(
            Conflict(
              'A set already exists at that position; correct it instead of logging it twice.',
              path: 'sets',
              issue: 'position taken',
            ),
          );
        }
      }
      var exercises = s.exercises;
      for (final input in request.sets) {
        exercises = [
          for (final x in exercises)
            if (x.clientExerciseId == input.clientExerciseId)
              x.copyWith(
                sets: x.sets.any((t) => t.clientSetId == input.clientSetId)
                    ? x.sets
                    : [
                        ...x.sets,
                        SetLog(
                          id: _id(),
                          clientSetId: input.clientSetId,
                          setIndex: input.setIndex,
                          setType: input.setType,
                          weightKg: input.weightKg,
                          reps: input.reps,
                          rir: input.rir,
                          isPr: false,
                          loggedAt: input.loggedAt,
                          plannedSetId: input.plannedSetId,
                        ),
                      ],
              )
            else
              x,
        ];
      }
      final next = s.copyWith(exercises: exercises);
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<WorkoutSession>> patchSet(
    String id,
    String setId,
    PatchSetRequest request,
  ) async {
    calls.add('patchSet');
    return _guard(() {
      final s = _byServerId(id)!;
      final next = s.copyWith(
        exercises: [
          for (final x in s.exercises)
            x.copyWith(
              sets: [
                for (final t in x.sets)
                  if (t.id == setId)
                    t.copyWith(
                      reps: request.reps ?? t.reps,
                      weightKg: request.weightCleared
                          ? null
                          : (request.weightKg ?? t.weightKg),
                      rir: request.rirCleared ? null : (request.rir ?? t.rir),
                      setType: request.setType ?? t.setType,
                    )
                  else
                    t,
              ],
            ),
        ],
      );
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<WorkoutSession>> deleteSet(String id, String setId) async {
    calls.add('deleteSet');
    return _guard(() {
      final s = _byServerId(id)!;
      final next = s.copyWith(
        exercises: [
          for (final x in s.exercises)
            x.copyWith(sets: x.sets.where((t) => t.id != setId).toList()),
        ],
      );
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<WorkoutSession>> addExercise(
    String id,
    AddSessionExerciseRequest request,
  ) async {
    calls.add('addExercise');
    return _guard(() {
      final s = _byServerId(id)!;
      if (s.exercises
          .any((x) => x.clientExerciseId == request.clientExerciseId)) {
        return Ok(s);
      }
      final next = s.copyWith(
        exercises: [
          ...s.exercises,
          _exercise(
            SeededExercise(
              clientExerciseId: request.clientExerciseId,
              exerciseId: request.exerciseId,
              plannedExerciseId: request.plannedExerciseId,
              orderIndex: request.orderIndex ?? s.exercises.length,
            ),
          ).copyWith(targets: const [], supersetGroup: request.supersetGroup),
        ],
      );
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<WorkoutSession>> patchExercise(
    String id,
    String exerciseId,
    PatchSessionExerciseRequest request,
  ) async {
    calls.add('patchExercise');
    return _guard(() {
      final s = _byServerId(id)!;
      final next = s.copyWith(
        exercises: [
          for (final x in s.exercises)
            if (x.id == exerciseId)
              if (request.removed)
                ...const <SessionExercise>[]
              else
                x.copyWith(
                  orderIndex: request.orderIndex ?? x.orderIndex,
                  supersetGroup: request.supersetCleared
                      ? null
                      : (request.supersetGroup ?? x.supersetGroup),
                  exerciseId: request.exerciseId ?? x.exerciseId,
                )
            else
              x,
        ],
      );
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<WorkoutSession>> complete(
    String id,
    CompleteSessionRequest request,
  ) async {
    calls.add('complete');
    return _guard(() {
      final s = _byServerId(id)!;
      if (s.status == SessionStatus.completed) return Ok(s);
      final working = s.exercises.fold<int>(
        0,
        (n, x) => n + x.sets.where((t) => t.setType == SetType.working).length,
      );
      final next = s.copyWith(
        status: SessionStatus.completed,
        completedAt: request.completedAt,
        durationSeconds: 3300,
        notes: request.notes,
        summary: SessionSummary(
          durationSeconds: 3300,
          totalSets: working,
          workingSets: working,
          tonnageKg: 1800,
          hardSetsByMuscle: const {'quads': 3, 'glutes': 3, 'hamstrings': 1.5},
          exercisesCompleted: 1,
          exercisesSkipped: 0,
          prs: [
            if (working > 0)
              PersonalRecord(
                prType: PrType.weight,
                exerciseId: _kSquat.id,
                exerciseName: _kSquat.name,
                value: 80,
                previous: 75,
                setLogId: s.exercises.first.sets.first.id,
                reason:
                    '80 kg is the most you have lifted on this exercise (previous best 75 kg).',
              ),
          ],
        ),
      );
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<WorkoutSession>> abandon(String id) async {
    calls.add('abandon');
    return _guard(() {
      final s = _byServerId(id)!;
      final next = s.copyWith(
        status: SessionStatus.abandoned,
        completedAt: '2026-09-21T11:00:00.000Z',
      );
      sessions[s.clientSessionId] = next;
      return Ok(next);
    });
  }

  @override
  Future<Result<SessionListResponse>> list({
    String? before,
    int limit = 20,
    SessionStatus? status,
  }) async {
    calls.add('list');
    return _guard(
      () => Ok(
        SessionListResponse(
          items: [
            for (final s in sessions.values
                .where((s) => s.status != SessionStatus.active))
              SessionListItem(
                id: s.id,
                status: s.status,
                name: s.name,
                startedAt: s.startedAt,
                completedAt: s.completedAt,
                durationSeconds: s.durationSeconds,
                exerciseCount: s.exercises.length,
                workingSets: s.workingSetsLogged,
                tonnageKg: 1800,
                prCount: s.summary?.prs.length ?? 0,
              ),
          ],
          nextBefore: null,
        ),
      ),
    );
  }

  /// Scripted "today".
  TodayResponse todayResponse = const TodayResponse(
    date: '2026-09-21',
    dayOfWeek: 1,
    programId: 'pppppppp-pppp-4ppp-8ppp-pppppppppppp',
    programDayId: 'dddddddd-dddd-4ddd-8ddd-000000000001',
    sessionName: 'Legs',
    isRest: false,
    focus: [MuscleGroup.quads, MuscleGroup.glutes],
    exercises: [
      TodayExercise(
        plannedExerciseId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        exerciseId: '11111111-1111-4111-8111-111111111111',
        slug: 'barbell-back-squat',
        name: 'Barbell Back Squat',
        movementPattern: MovementPattern.squat,
        equipment: [Equipment.barbell],
        difficulty: Difficulty.intermediate,
        primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
        secondaryMuscles: [MuscleGroup.hamstrings],
        orderIndex: 0,
        incrementKg: 5,
        targets: [
          PlannedSet(
            setIndex: 1,
            repsMin: 6,
            repsMax: 12,
            weightKg: null,
            rir: 1,
          ),
          PlannedSet(
            setIndex: 2,
            repsMin: 6,
            repsMax: 12,
            weightKg: null,
            rir: 1,
          ),
          PlannedSet(
            setIndex: 3,
            repsMin: 6,
            repsMax: 12,
            weightKg: 60,
            rir: 1,
          ),
        ],
        prefill: [
          SetPrefill(
            setIndex: 1,
            reps: 12,
            weightKg: 70,
            rir: 1,
            weightSource: 'last-session',
          ),
          SetPrefill(
            setIndex: 2,
            reps: 12,
            weightKg: 70,
            rir: 1,
            weightSource: 'last-session',
          ),
          SetPrefill(
            setIndex: 3,
            reps: 12,
            weightKg: 70,
            rir: 1,
            weightSource: 'last-session',
          ),
        ],
        lastPerformance: LastPerformance(
          sessionId: '99999999-9999-4999-8999-999999999999',
          completedAt: '2026-09-14T10:50:00.000Z',
          sets: [
            LastSet(setIndex: 1, weightKg: 70, reps: 10, rir: 2),
            LastSet(setIndex: 2, weightKg: 70, reps: 9, rir: 1),
            LastSet(setIndex: 3, weightKg: 70, reps: 8, rir: 1),
          ],
        ),
      ),
      TodayExercise(
        plannedExerciseId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        exerciseId: '22222222-2222-4222-8222-222222222222',
        slug: 'standing-calf-raise',
        name: 'Standing Calf Raise',
        movementPattern: MovementPattern.calfRaise,
        equipment: [Equipment.machine],
        difficulty: Difficulty.beginner,
        primaryMuscles: [MuscleGroup.calves],
        secondaryMuscles: [],
        orderIndex: 1,
        incrementKg: 2.5,
        targets: [
          PlannedSet(
            setIndex: 1,
            repsMin: 8,
            repsMax: 15,
            weightKg: null,
            rir: 1,
          ),
          PlannedSet(
            setIndex: 2,
            repsMin: 8,
            repsMax: 15,
            weightKg: null,
            rir: 1,
          ),
        ],
        prefill: [
          SetPrefill(
            setIndex: 1,
            reps: 15,
            weightKg: null,
            rir: 1,
            weightSource: 'none',
          ),
          SetPrefill(
            setIndex: 2,
            reps: 15,
            weightKg: null,
            rir: 1,
            weightSource: 'none',
          ),
        ],
        lastPerformance: null,
      ),
    ],
    activeSession: null,
    completedSessionId: null,
  );

  @override
  Future<Result<TodayResponse>> today({int? dayOfWeek}) async {
    calls.add('today');
    return _guard(() => Ok(todayResponse));
  }

  /* --------------------------------------------------------- Phase 6 -- */

  /// Scripted deload state; accept/decline move it the way the server does.
  DeloadState deload = DeloadState.none;
  VolumeResponse volumeResponse = const VolumeResponse(
    weeks: [],
    owned: [],
    neglected: [],
    mesocycleWeek: 1,
    deload: DeloadState.none,
  );
  ProgressionDetail? progressionDetail;

  @override
  Future<Result<VolumeResponse>> volume() async {
    calls.add('volume');
    return _guard(() => Ok(volumeResponse));
  }

  @override
  Future<Result<ProgressionDetail>> progression(String exerciseId) async {
    calls.add('progression:$exerciseId');
    return _guard(() {
      final d = progressionDetail;
      if (d == null || d.exerciseId != exerciseId) {
        return const Err(Unknown('No history for that lift.'));
      }
      return Ok(d);
    });
  }

  @override
  Future<Result<DeloadState>> acceptDeload() async {
    calls.add('deload:accept');
    return _guard(() {
      if (deload.state == DeloadStatus.none) {
        return const Err(Conflict('No deload has been offered.'));
      }
      deload = DeloadState(
        state: DeloadStatus.active,
        trigger: deload.trigger,
        reason: deload.reason,
        endsOn: '2026-09-28',
      );
      todayResponse = todayResponse.copyWith(deload: deload);
      return Ok(deload);
    });
  }

  @override
  Future<Result<DeloadState>> declineDeload() async {
    calls.add('deload:decline');
    return _guard(() {
      deload = DeloadState.none;
      todayResponse = todayResponse.copyWith(deload: deload);
      return Ok(deload);
    });
  }
}
