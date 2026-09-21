import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/home/domain/home_context.dart';
import 'package:fitos/features/home/domain/home_suggestion_engine.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_api.dart';

/// Phase 6.5 — the deterministic Home engine (Part J): each rule fires on
/// exactly its condition and never on missing data; the order is fixed by
/// §16.1 bands and rule order; no user-facing score.
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

  test('active workout → resume, above everything but a deload', () {
    final c = ctx(today: trainingDay, active: session);
    final all = engine.evaluate(c);
    expect(all.first.id, 'resume');
    expect(all.first.action, SuggestionAction.resumeWorkout);
    expect(all.first.metadata['clientSessionId'], 'c1');
    expect(ids(c), isNot(contains('start')));
  });

  test('scheduled workout not started → start, with movements and minutes', () {
    final s = engine.evaluate(ctx(today: trainingDay)).first;
    expect(s.id, 'start');
    expect(s.title, 'Legs is ready');
    expect(s.subtitle, '2 movements · ~18 min');
    expect(s.reason, isNotEmpty);
  });

  test('completed today → done with the summary; no start', () {
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
        prs: [],
      ),
    );
    final c = ctx(
      today: trainingDay.copyWith(completedSessionId: 's1'),
      completed: done,
    );
    final all = engine.evaluate(c);
    expect(all.first.id, 'done');
    expect(all.first.subtitle, '5 sets · 1800 kg moved');
    expect(ids(c), isNot(contains('start')));
  });

  test(
      'protein below 75% with the day ahead → food; on track → calories instead (XOR)',
      () {
    final low = ctx(
      today: trainingDay,
      nutrition: const NutritionContext(logged: true, kcal: 900, proteinG: 78),
    );
    final lowIds = ids(low);
    expect(lowIds, contains('eat-protein'));
    expect(lowIds, isNot(contains('eat-meal')));
    expect(
      engine.evaluate(low).firstWhere((s) => s.id == 'eat-protein').title,
      '42 g protein left today',
    );

    final ok = ctx(
      today: trainingDay,
      nutrition: const NutritionContext(logged: true, kcal: 900, proteinG: 100),
    );
    expect(ids(ok), contains('eat-meal'));
    expect(ids(ok), isNot(contains('eat-protein')));

    // Late in the evening neither fires; not logged never fires.
    expect(
      ids(
        ctx(
          today: trainingDay,
          nutrition:
              const NutritionContext(logged: true, kcal: 900, proteinG: 78),
          hour: 22,
        ),
      ),
      isNot(contains('eat-protein')),
    );
    expect(
      ids(ctx(today: trainingDay)),
      isNot(anyOf(contains('eat-protein'), contains('eat-meal'))),
    );
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
        engine.evaluate(ctx(today: trainingDay, snapshot: health(sleep: 372)));
    final r = short.firstWhere((s) => s.id == 'recover');
    expect(r.title, 'Sleep was 6h 12m');
    expect(r.subtitle, "Keep today's session controlled");
    expect(
      ids(ctx(today: trainingDay, snapshot: health(sleep: 372))),
      contains('recover'),
    );
    expect(
      ids(ctx(today: trainingDay, snapshot: health(sleep: 7 * 60))),
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
      'Health Connect available but not connected → connect (secondary); unsupported → nothing',
      () {
    final c = ctx(today: restDay, connection: notConnected);
    final s = engine.evaluate(c).firstWhere((s) => s.id == 'connect-health');
    expect(s.surface, SuggestionSurface.secondary);
    expect(
      HomeSuggestionEngine.carousel(engine.evaluate(c)).map((s) => s.id),
      isNot(contains('connect-health')),
    );
    expect(
      HomeSuggestionEngine.more(engine.evaluate(c)).map((s) => s.id),
      contains('connect-health'),
    );
    expect(
      ids(
        ctx(
          today: restDay,
          connection: HealthConnectionState.disconnected,
        ),
      ),
      isNot(contains('connect-health')),
    );
  });

  test('deload offer outranks everything and suppresses the rest-day card', () {
    final offered = restDay.copyWith(
      deload: const DeloadState(
        state: DeloadStatus.offered,
        trigger: DeloadTrigger.fatigue,
        reason: 'Reps have dropped three sessions running.',
        endsOn: null,
      ),
    );
    final all = engine.evaluate(ctx(today: offered, active: session));
    expect(all.first.id, 'deload');
    expect(all.first.subtitle, 'Reps have dropped three sessions running.');
    expect(all.map((s) => s.id), isNot(contains('rest-day')));
    expect(all[1].id, 'resume');
  });

  test('neglected muscles → training suggestion naming them', () {
    final t = trainingDay.copyWith(
      neglected: const [
        NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: 9),
      ],
    );
    final s =
        engine.evaluate(ctx(today: t)).firstWhere((s) => s.id == 'neglect');
    expect(s.title, 'Calves has been waiting');
    expect(s.subtitle, '9 days since a working set');
    expect(s.action, SuggestionAction.viewPlan);
  });

  test('PR today → celebrate, with the record\'s own reason', () {
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
    final all = engine.evaluate(
      ctx(
        today: trainingDay.copyWith(completedSessionId: 's1'),
        completed: done,
      ),
    );
    final pr = all.firstWhere((s) => s.id == 'pr');
    expect(pr.title, 'New record on Barbell Back Squat');
    expect(pr.subtitle, '80 kg beats your best of 75 kg.');
    expect(all.first.id, 'done');
    expect(all.first.subtitle, endsWith('· 1 record'));
  });

  test('volume at the ceiling → secondary suggestion to the volume screen', () {
    const v = VolumeResponse(
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
    final s = engine
        .evaluate(ctx(today: restDay, volume: v))
        .firstWhere((s) => s.id == 'volume');
    expect(s.title, 'Chest is at its ceiling');
    expect(s.surface, SuggestionSurface.secondary);
  });

  test('rest day with nothing else is still an action, not a shrug', () {
    final all = engine.evaluate(ctx(today: restDay));
    expect(all.first.id, 'rest-day');
    expect(all.first.title, 'Rest day');
  });

  test(
      'ordering is deterministic and follows the bands: deload, resume/start, protein, done, neglect, recover, rest, pr, volume, move, connect',
      () {
    final t = trainingDay.copyWith(
      neglected: const [
        NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: 9),
      ],
    );
    final c = ctx(
      today: t,
      nutrition: const NutritionContext(logged: true, kcal: 900, proteinG: 78),
      snapshot: health(steps: 1000, sleep: 300),
      hour: 20,
      connection: connected,
    );
    final a = ids(c);
    final b = ids(c);
    expect(a, b);
    expect(a, ['start', 'eat-protein', 'neglect', 'recover', 'move']);
    final all = engine.evaluate(c);
    expect(all.map((s) => s.priority).toList(), [90, 88, 68, 65, 40]);
    // The carousel is the first four primary suggestions; the fifth goes to "More for you".
    expect(
      HomeSuggestionEngine.carousel(all).map((s) => s.id),
      ['start', 'eat-protein', 'neglect', 'recover'],
    );
    expect(HomeSuggestionEngine.more(all).map((s) => s.id), ['move']);
    // Every suggestion states its reason.
    for (final s in all) {
      expect(s.reason, isNotEmpty, reason: s.id);
    }
  });
}
