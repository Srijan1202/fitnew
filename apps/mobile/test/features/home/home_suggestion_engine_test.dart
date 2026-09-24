import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/home/domain/home_context.dart';
import 'package:fitos/features/home/domain/home_suggestion_engine.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/today/domain/today.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_today_api.dart';
import '../../support/fake_workout_api.dart';

/// Phase 6.5, shrunk by Phase 11 — the deterministic Home engine: the
/// device-only rules (resume, sleep, steps, Health Connect) fire on exactly
/// their condition and never on missing data; everything else is the
/// server's TODAY plan, merged by band and capped at four.
void main() {
  const engine = HomeSuggestionEngine();
  final fake = FakeWorkoutApi();
  final trainingDay = fake.todayResponse; // Legs, 2 exercises, 5 sets
  final restDay = trainingDay.copyWith(
    isRest: true,
    sessionName: null,
    exercises: const [],
    programDayId: null,
  );

  const targets = NutritionTargets(
    effectiveFrom: '2026-09-01',
    kcal: 1800,
    proteinG: 120,
    carbG: 200,
    fatG: 60,
    fiberG: 30,
    bmr: 1500,
    tdeeEstimate: 2200,
    rationale: [],
    reason: 'r',
  );

  HealthMetric metric(HealthMetricKind k, double? v, {String unit = ''}) =>
      v == null
          ? HealthMetric.unavailable(k, HealthAvailability.noData, unit: unit)
          : HealthMetric(
              kind: k,
              availability: HealthAvailability.available,
              value: v,
              unit: unit,
              start: null,
              end: null,
              updatedAt: '2026-09-22T06:00:00.000Z',
            );

  HealthSnapshot health({double? steps, double? sleep}) => HealthSnapshot.empty(
        date: '2026-09-22',
        timezone: 'Asia/Kolkata',
        availability: HealthAvailability.noData,
        fetchedAt: '2026-09-22T06:00:00.000Z',
      ).copyWith(
        steps: metric(HealthMetricKind.steps, steps, unit: 'steps'),
        sleep: metric(HealthMetricKind.sleep, sleep, unit: 'min'),
      );

  const connected = HealthConnectionState(
    sdk: HealthSdkStatus.available,
    granted: {HealthMetricKind.steps, HealthMetricKind.sleep},
  );
  const notConnected = HealthConnectionState(
    sdk: HealthSdkStatus.available,
    granted: {},
  );

  HomeContext ctx({
    TodayResponse? today,
    WorkoutSession? active,
    WorkoutSession? completed,
    NutritionContext nutrition = NutritionContext.notLogged,
    HealthSnapshot? snapshot,
    HealthConnectionState? connection = connected,
    int hour = 10,
    int stepGoal = 8000,
    VolumeResponse? volume,
  }) =>
      HomeContext(
        date: '2026-09-22',
        hourOfDay: hour,
        today: today,
        activeSession: active,
        completedToday: completed,
        targets: targets,
        nutrition: nutrition,
        health: snapshot,
        connection: connection,
        stepGoal: stepGoal,
        volume: volume,
        week: WeekContext.empty,
      );

  List<String> ids(HomeContext c) =>
      engine.evaluate(c).map((s) => s.id).toList();

  const session = WorkoutSession(
    id: 's1',
    clientSessionId: 'c1',
    status: SessionStatus.active,
    programId: 'p',
    programDayId: 'd',
    name: 'Legs',
    startedAt: '2026-09-22T04:00:00.000Z',
    completedAt: null,
    durationSeconds: null,
    notes: null,
    exercises: [],
    summary: null,
  );

  test('no signals → no suggestions (the section is omitted)', () {
    expect(ids(ctx(today: null, connection: null)), isEmpty);
  });

  test('active workout on this phone → resume', () {
    final c = ctx(today: trainingDay, active: session);
    final all = engine.evaluate(c);
    expect(all.first.id, 'resume');
    expect(all.first.priority, 92);
    expect(all.first.action, SuggestionAction.resumeWorkout);
    expect(all.first.metadata['clientSessionId'], 'c1');
  });

  test(
      'Phase 11 (D2/D13, P6): the server-owned rules and the done / volume cards never fire on the device',
      () {
    final offered = restDay.copyWith(
      deload: const DeloadState(
        state: DeloadStatus.offered,
        trigger: DeloadTrigger.fatigue,
        reason: 'Reps have dropped three sessions running.',
        endsOn: null,
      ),
    );
    final done = session.copyWith(
      status: SessionStatus.completed,
      summary: const SessionSummary(
        durationSeconds: 3000,
        totalSets: 5,
        workingSets: 5,
        tonnageKg: 1800,
        hardSetsByMuscle: {},
        exercisesCompleted: 2,
        exercisesSkipped: 0,
        prs: [
          PersonalRecord(
            prType: PrType.weight,
            exerciseId: 'x',
            exerciseName: 'Barbell Back Squat',
            value: 80,
            previous: 75,
            setLogId: 'l',
            reason: '80 kg beats your best of 75 kg.',
          ),
        ],
      ),
    );
    const atCeiling = VolumeResponse(
      weeks: [
        VolumeWeek(
          isoWeek: '2026-W39',
          muscles: [
            MuscleWeek(
              muscle: MuscleGroup.chest,
              hardSets: 22,
              tonnageKg: 0,
              status: LandmarkStatus.atMrv,
              landmarks: VolumeLandmarks(
                mv: 4,
                mev: 8,
                mavLow: 12,
                mavHigh: 20,
                mrv: 22,
              ),
              owned: true,
            ),
          ],
        ),
      ],
      owned: [MuscleGroup.chest],
      neglected: [],
      mesocycleWeek: 3,
      deload: DeloadState.none,
    );
    final contexts = [
      ctx(today: trainingDay), // was: start
      ctx(today: restDay), // was: rest-day
      ctx(today: offered), // was: deload
      ctx(
        today: trainingDay.copyWith(
          neglected: const [
            NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: 9),
          ],
        ),
      ), // was: neglect
      ctx(
        today: trainingDay,
        nutrition:
            const NutritionContext(logged: true, kcal: 900, proteinG: 78),
      ), // was: eat-protein
      ctx(
        today: trainingDay,
        nutrition:
            const NutritionContext(logged: true, kcal: 900, proteinG: 100),
      ), // was: eat-meal
      ctx(
        today: trainingDay.copyWith(completedSessionId: 's1'),
        completed: done,
      ), // was: done + pr
      ctx(today: restDay, volume: atCeiling), // was: volume
    ];
    for (final c in contexts) {
      expect(ids(c), isEmpty);
    }
  });

  test('movement: only with step data, and only late enough', () {
    // 3,000 of 8,000 at 10:00 → nothing yet.
    expect(
      ids(ctx(today: restDay, snapshot: health(steps: 3000), hour: 10)),
      isNot(contains('move')),
    );
    // 3,000 at 15:00 → under half the goal.
    final afternoon = engine
        .evaluate(ctx(today: restDay, snapshot: health(steps: 3000), hour: 15));
    final move = afternoon.firstWhere((s) => s.id == 'move');
    expect(move.title, "You're 5,000 steps from your goal");
    expect(move.subtitle, 'An easy 50-minute walk gets you there');
    // 6,000 at 15:00 → above half, nothing; at 19:00 → under the goal.
    expect(
      ids(ctx(today: restDay, snapshot: health(steps: 6000), hour: 15)),
      isNot(contains('move')),
    );
    expect(
      ids(ctx(today: restDay, snapshot: health(steps: 6000), hour: 19)),
      contains('move'),
    );
    // No step data → never.
    expect(
      ids(ctx(today: restDay, snapshot: health(), hour: 20)),
      isNot(contains('move')),
    );
  });

  test('recovery: sleep under six hours, only when sleep is available', () {
    final short =
        engine.evaluate(ctx(today: trainingDay, snapshot: health(sleep: 345)));
    final r = short.firstWhere((s) => s.id == 'recover');
    expect(r.title, 'Sleep was 5h 45m');
    expect(r.subtitle, "Keep today's session controlled");
    // 6h 12m is not "meaningfully low" under owner D5.
    expect(
      ids(ctx(today: trainingDay, snapshot: health(sleep: 372))),
      isNot(contains('recover')),
    );
    expect(
      ids(ctx(today: trainingDay, snapshot: health())),
      isNot(contains('recover')),
    );
  });

  test('recovery fires at 5h 59m, not at 6h 00m', () {
    expect(
      ids(ctx(today: restDay, snapshot: health(sleep: 359))),
      contains('recover'),
    );
    expect(
      ids(ctx(today: restDay, snapshot: health(sleep: 360))),
      isNot(contains('recover')),
    );
  });

  test(
      'Health Connect available but not connected → connect (35, competes by band — P6); unsupported → nothing',
      () {
    final c = ctx(today: restDay, connection: notConnected);
    final s = engine.evaluate(c).firstWhere((s) => s.id == 'connect-health');
    expect(s.priority, 35);
    expect(
      HomeSuggestionEngine.merge(const [], engine.evaluate(c), planDate: 'd')
          .map((s) => s.id),
      contains('connect-health'),
    );
    expect(
      ids(ctx(today: restDay, connection: HealthConnectionState.disconnected)),
      isNot(contains('connect-health')),
    );
  });

  test('device ordering is deterministic by band: resume, recover, move', () {
    final c = ctx(
      today: trainingDay,
      active: session,
      snapshot: health(steps: 1000, sleep: 300),
      hour: 20,
    );
    expect(ids(c), ids(c));
    expect(ids(c), ['resume', 'recover', 'move']);
    for (final s in engine.evaluate(c)) {
      expect(s.reason, isNotEmpty, reason: s.id);
    }
  });

  group('merge with the server TODAY plan (Phase 11)', () {
    TodayAction a(TodayKind k, {int rank = 1, int? priority}) =>
        FakeTodayApi.action(k, rank: rank, priority: priority);

    test(
        'server actions and device suggestions by band, capped at four; the server rank order within the plan',
        () {
      final device = engine.evaluate(
        ctx(
          today: trainingDay,
          snapshot: health(steps: 1000, sleep: 300),
          hour: 20,
        ),
      );
      final merged = HomeSuggestionEngine.merge(
        [
          a(TodayKind.muscleNeglected, rank: 4),
          a(TodayKind.startWorkout),
          a(TodayKind.progressLoad, rank: 3),
          a(TodayKind.eatProtein, rank: 2),
        ],
        device,
        planDate: '2026-09-22',
      );
      expect(
        merged.map((s) => s.id),
        ['start-workout', 'eat-protein', 'progress-load', 'muscle-neglected'],
      );
      expect(merged, hasLength(HomeSuggestionEngine.maxCards));
      expect(
        merged.every((s) => s.isServer && s.planDate == '2026-09-22'),
        isTrue,
      );
    });

    test('a device suggestion with a higher band sits between server actions',
        () {
      final device = engine.evaluate(
        ctx(today: trainingDay, snapshot: health(sleep: 300)),
      );
      final merged = HomeSuggestionEngine.merge(
        [a(TodayKind.startWorkout), a(TodayKind.restDay, rank: 2)],
        device,
        planDate: 'd',
      );
      expect(merged.map((s) => s.id), ['start-workout', 'recover', 'rest-day']);
    });

    test('equal bands: the server action first, then the device rule', () {
      final device = engine.evaluate(
        ctx(today: trainingDay, snapshot: health(sleep: 300)),
      ); // recover, 65
      final merged = HomeSuggestionEngine.merge(
        [a(TodayKind.restDay, priority: 65)],
        device,
        planDate: 'd',
      );
      expect(merged.map((s) => s.id), ['rest-day', 'recover']);
    });

    test(
        'a session open on this phone: resume replaces the server start card; the rest stay',
        () {
      final device = engine.evaluate(ctx(today: trainingDay, active: session));
      final merged = HomeSuggestionEngine.merge(
        [a(TodayKind.startWorkout), a(TodayKind.eatMeal, rank: 2)],
        device,
        planDate: 'd',
      );
      expect(merged.map((s) => s.id), ['resume', 'eat-meal']);
    });

    test('an unknown kind from a newer server is not drawn; cached is carried',
        () {
      const unknown = TodayAction(
        id: 'x',
        kindWire: 'hydrate',
        subjectKey: '',
        rank: 1,
        priority: 99,
        basis: ActionBasis.calculated,
        target: ActionTarget.today,
        reason: TodayReason('x', {}),
        headline: 'h',
        detail: 'd',
      );
      final merged = HomeSuggestionEngine.merge(
        [unknown, a(TodayKind.logWeight, rank: 2)],
        const [],
        planDate: 'd',
        cached: true,
      );
      expect(merged.map((s) => s.id), ['log-weight']);
      expect(merged.single.cached, isTrue);
    });
  });
}
