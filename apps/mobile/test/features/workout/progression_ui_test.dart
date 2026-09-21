import 'dart:convert';

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:fitos/features/workout/presentation/screens/active_session_screen.dart';
import 'package:fitos/features/workout/presentation/screens/volume_screen.dart';
import 'package:fitos/features/workout/presentation/widgets/today_session_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 6 on the phone: rows open with the recommended load and its
/// reason, one tap reverts to last time's weight, a beating set is a PR
/// (a tie is not), a deload week shows the plan's originals beside the
/// lighter numbers, the deload offer is accepted or declined, the volume
/// screen renders statuses and neglect, and a cached "today" carries the
/// recommendations offline. Every number here is the fake server's.
void main() {
  late AppDatabase db;
  late FakeWorkoutApi api;
  late FakeExerciseRepository exercises;
  late ProviderContainer container;

  const squatRec = ProgressionRecommendation(
    action: ProgressionAction.increaseLoad,
    weightKg: 75,
    repTarget: '6',
    targetRir: 1,
    reason: 'Every working set hit 12 reps at 1 RIR or better at 70 kg.',
    basis: 'calculated',
    sessionsConsidered: 1,
  );
  const squatBest =
      PriorBest(weightKg: 70, repsAtBestWeight: 10, estimated1rm: 93.3);

  /// The fake's day with a recommendation on the squat: rows open at 75 × 6.
  TodayResponse withRecommendation(TodayResponse t) => t.copyWith(
        exercises: [
          t.exercises.first.copyWith(
            recommendation: squatRec,
            priorBest: squatBest,
            prefill: [
              for (final p in t.exercises.first.prefill)
                p.copyWith(
                  weightKg: 75,
                  reps: 6,
                  weightSource: 'recommendation',
                ),
            ],
          ),
          ...t.exercises.skip(1),
        ],
      );

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    exercises = FakeExerciseRepository();
    api.todayResponse = withRecommendation(api.todayResponse);
  });
  tearDown(() => db.close());

  Widget harness(String initial) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(child: TodaySessionPanel()),
          ),
        ),
        GoRoute(
          path: '/plan',
          builder: (_, __) => const Scaffold(body: Text('PLAN')),
          routes: [
            GoRoute(
              path: 'session/:id',
              builder: (_, s) =>
                  ActiveSessionScreen(clientSessionId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'volume',
              builder: (_, __) => const VolumeScreen(),
            ),
          ],
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  void makeContainer() {
    container = ProviderContainer(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        exerciseRepositoryProvider.overrideWithValue(exercises),
        ...workoutOverrides(db, api),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<WorkoutSession> pumpSession(
    WidgetTester tester, {
    TodayResponse? day,
  }) async {
    makeContainer();
    final repo = container.read(workoutRepositoryProvider);
    final session = await repo.startSession(day: day ?? api.todayResponse);
    container.read(restTimerProvider.notifier).clock =
        () => DateTime.utc(2026, 9, 21, 10);
    addTearDown(() => container.read(restTimerProvider.notifier).skip());
    await tester
        .pumpWidget(harness('/plan/session/${session.clientSessionId}'));
    await settle(tester);
    return session;
  }

  Text textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key)));
  String weightOf(WidgetTester tester, String key) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .data!;
  String squatKey(WorkoutSession s) =>
      'session.${s.exercises.first.clientExerciseId}';

  testWidgets(
      'rows open with the recommended load and reps; the reason line is the engine\'s, in pine for increase-load',
      (tester) async {
    final s = await pumpSession(tester);
    final k = squatKey(s);
    for (final i in [1, 2, 3]) {
      expect(weightOf(tester, '$k.set.$i.weight'), '75');
      expect(textOf(tester, '$k.set.$i.reps').data, '6');
    }
    final line = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('$k.recommendation')),
        matching: find.byType(Text),
      ),
    );
    expect(line.data, startsWith('↑ 75 kg × 6 · 1 RIR — Every working set'));
    expect(line.style?.color, FitColors.pine);
    expect(line.maxLines, 1);
    // No recommendation on the calf raise (the fake sends none): no line.
    expect(
      find.byKey(
        ValueKey('session.${s.exercises[1].clientExerciseId}.recommendation'),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'tap the reason: the sheet shows the full reason and the last three sessions; "Use last time\'s weight" reverts every pending row',
      (tester) async {
    api.progressionDetail = ProgressionDetail(
      exerciseId: api.todayResponse.exercises.first.exerciseId,
      name: 'Barbell Back Squat',
      target: const ProgressionTarget(
        repMin: 6,
        repMax: 12,
        targetRir: 1,
        sets: 3,
        incrementKg: 5,
      ),
      recommendation: squatRec,
      history: const [
        ProgressionHistoryEntry(
          sessionId: '99999999-9999-4999-8999-999999999999',
          date: '2026-09-14',
          sets: [
            ProgressionHistorySet(setIndex: 1, weightKg: 70, reps: 12, rir: 1),
          ],
        ),
      ],
    );
    final s = await pumpSession(tester);
    final k = squatKey(s);
    // Log set 1 first: the revert must leave it alone.
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('$k.recommendation')));
    await settle(tester);
    expect(find.byKey(const ValueKey('recommendation.sheet')), findsOneWidget);
    expect(textOf(tester, 'recommendation.reason').data, squatRec.reason);
    expect(
      textOf(
        tester,
        'recommendation.history.99999999-9999-4999-8999-999999999999',
      ).data,
      '2026-09-14  70×12 @1',
    );
    await tester.tap(find.byKey(const ValueKey('recommendation.useLast')));
    await settle(tester);
    expect(find.byKey(const ValueKey('recommendation.sheet')), findsNothing);
    expect(weightOf(tester, '$k.set.1.weight'), '75'); // logged: untouched
    expect(weightOf(tester, '$k.set.2.weight'), '70');
    expect(weightOf(tester, '$k.set.3.weight'), '70');
    expect(textOf(tester, '$k.set.2.reps').data, '6'); // reps stay
    container.read(restTimerProvider.notifier).skip();
  });

  testWidgets(
      'PR moment: a heavier set stars its check and marks the header; a tie with the prior best does not',
      (tester) async {
    final s = await pumpSession(tester);
    final k = squatKey(s);
    // Set 1 at the recommended 75 kg beats the prior best of 70.
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.set.1.star')), findsOneWidget);
    expect(find.byKey(ValueKey('$k.pr')), findsOneWidget);
    // Set 2 at 75 × 6 again: equals the best of this session — no second star.
    await tester.tap(find.byKey(ValueKey('$k.set.2.done')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.set.2.star')), findsNothing);
    expect(find.byKey(ValueKey('$k.set.2.icon')), findsOneWidget);
    // Set 3 at 75 × 7: more reps at the best weight — a record again.
    await tester.tap(find.byKey(ValueKey('$k.set.3.reps.plus')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('$k.set.3.done')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.set.3.star')), findsOneWidget);
    container.read(restTimerProvider.notifier).skip();
  });

  testWidgets(
      'no prior best (baseline): logging never celebrates; bodyweight sets never do',
      (tester) async {
    api.todayResponse = api.todayResponse.copyWith(
      exercises: [
        api.todayResponse.exercises.first.copyWith(
          priorBest: PriorBest.none,
          recommendation: const ProgressionRecommendation(
            action: ProgressionAction.establishBaseline,
            weightKg: null,
            repTarget: '6–12',
            targetRir: 1,
            reason:
                'First time on this lift: find a load you can do 6–12 with 1 RIR.',
            basis: 'calculated',
            sessionsConsidered: 0,
          ),
        ),
        ...api.todayResponse.exercises.skip(1),
      ],
    );
    final s = await pumpSession(tester);
    final k = squatKey(s);
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.set.1.star')), findsNothing);
    expect(find.byKey(ValueKey('$k.pr')), findsNothing);
    final line = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('$k.recommendation')),
        matching: find.byType(Text),
      ),
    );
    expect(line.style?.color, FitColors.ink60);
    container.read(restTimerProvider.notifier).skip();
  });

  testWidgets(
      'deload week: the header says DELOAD WEEK, rows carry the lighter targets with the plan\'s original in ink35 beside them',
      (tester) async {
    final x = api.todayResponse.exercises.first;
    const original = [
      PlannedSet(setIndex: 1, repsMin: 6, repsMax: 12, weightKg: 80, rir: 1),
      PlannedSet(setIndex: 2, repsMin: 6, repsMax: 12, weightKg: 80, rir: 1),
      PlannedSet(setIndex: 3, repsMin: 6, repsMax: 12, weightKg: 80, rir: 1),
    ];
    // 3 sets × 0.6 → 2, 70 × 0.9 = 63, RIR 1 + 2 = 3 (the server's numbers).
    const lighter = [
      PlannedSet(setIndex: 1, repsMin: 6, repsMax: 12, weightKg: 63, rir: 3),
      PlannedSet(setIndex: 2, repsMin: 6, repsMax: 12, weightKg: 63, rir: 3),
    ];
    api.todayResponse = api.todayResponse.copyWith(
      deload: const DeloadState(
        state: DeloadStatus.active,
        trigger: DeloadTrigger.fatigue,
        reason: 'Deload week accepted.',
        endsOn: '2026-09-28',
      ),
      exercises: [
        x.copyWith(
          targets: lighter,
          originalTargets: original,
          recommendation: const ProgressionRecommendation(
            action: ProgressionAction.deload,
            weightKg: 63,
            repTarget: '12',
            targetRir: 3,
            reason:
                'Deload week: sets × 0.6, load × 0.9, two more reps in reserve.',
            basis: 'calculated',
            sessionsConsidered: 1,
          ),
          prefill: const [
            SetPrefill(
              setIndex: 1,
              reps: 12,
              weightKg: 63,
              rir: 3,
              weightSource: 'recommendation',
            ),
            SetPrefill(
              setIndex: 2,
              reps: 12,
              weightKg: 63,
              rir: 3,
              weightSource: 'recommendation',
            ),
          ],
        ),
        ...api.todayResponse.exercises.skip(1),
      ],
    );
    final s = await pumpSession(tester);
    final k = squatKey(s);
    expect(textOf(tester, 'session.kind').data, 'DELOAD WEEK');
    expect(
      textOf(tester, '$k.originals').data,
      'DELOAD · plan was 3 × 6–12 @ 80 kg',
    );
    expect(weightOf(tester, '$k.set.1.weight'), '63');
    expect(textOf(tester, '$k.set.1.rir').data, '3');
    final o = textOf(tester, '$k.set.1.original');
    expect(o.data, 'plan 80×6–12');
    expect(o.style?.color, FitColors.ink35);
    expect(find.byKey(ValueKey('$k.set.3')), findsNothing); // 2 rows, not 3
    final line = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('$k.recommendation')),
        matching: find.byType(Text),
      ),
    );
    expect(line.style?.color, FitColors.amber);
  });

  testWidgets(
      'TODAY: a deload offer shows the reason with Accept / Not now; Not now clears it; Accept makes it active — never silently',
      (tester) async {
    api.deload = const DeloadState(
      state: DeloadStatus.offered,
      trigger: DeloadTrigger.fatigue,
      reason:
          'Reps have dropped three sessions running on your squat and bench.',
      endsOn: null,
    );
    api.todayResponse = api.todayResponse.copyWith(
      deload: api.deload,
      mesocycleWeek: 4,
      neglected: const [
        NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: 9),
      ],
    );
    makeContainer();
    await tester.pumpWidget(harness('/'));
    await settle(tester);
    expect(find.byKey(const ValueKey('deload.offer')), findsOneWidget);
    expect(
      textOf(tester, 'deload.reason').data,
      'Reps have dropped three sessions running on your squat and bench.',
    );
    expect(
      textOf(tester, 'today.neglect.calves').data,
      'Calves: 9 days since a working set.',
    );
    expect(find.byKey(const ValueKey('today.start')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('deload.decline')));
    await settle(tester);
    expect(api.calls, contains('deload:decline'));
    expect(find.byKey(const ValueKey('deload.offer')), findsNothing);
    expect(textOf(tester, 'deload.week').data, 'Mesocycle week 4');

    // Offered again (a later day): Accept.
    api.deload = api.todayResponse.deload.copyWith(state: DeloadStatus.offered);
    api.todayResponse = api.todayResponse.copyWith(deload: api.deload);
    container.invalidate(todayProvider);
    await settle(tester);
    expect(find.byKey(const ValueKey('deload.offer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deload.accept')));
    await settle(tester);
    expect(api.calls, contains('deload:accept'));
    expect(textOf(tester, 'deload.active').data, 'DELOAD WEEK · ends 28 Sep');
  });

  testWidgets(
      'volume screen: plain rows this week, owned first; tap → this vs last week, explanation, four weeks in human labels; technical details behind a disclosure',
      (tester) async {
    VolumeWeek week(String iso, double chest, double calves) => VolumeWeek(
          isoWeek: iso,
          muscles: [
            MuscleWeek(
              muscle: MuscleGroup.chest,
              hardSets: chest,
              tonnageKg: chest * 400,
              status: chest >= 22
                  ? LandmarkStatus.atMrv
                  : chest >= 8
                      ? LandmarkStatus.mevToMav
                      : chest >= 4
                          ? LandmarkStatus.belowMev
                          : chest > 0
                              ? LandmarkStatus.belowMv
                              : LandmarkStatus.none,
              landmarks: const VolumeLandmarks(
                mv: 4,
                mev: 8,
                mavLow: 12,
                mavHigh: 20,
                mrv: 22,
              ),
              owned: true,
            ),
            MuscleWeek(
              muscle: MuscleGroup.calves,
              hardSets: calves,
              tonnageKg: 0,
              status:
                  calves == 0 ? LandmarkStatus.none : LandmarkStatus.belowMev,
              landmarks: const VolumeLandmarks(
                mv: 6,
                mev: 8,
                mavLow: 12,
                mavHigh: 16,
                mrv: 20,
              ),
              owned: true,
            ),
          ],
        );
    api.volumeResponse = VolumeResponse(
      weeks: [
        week('2026-W36', 10, 0),
        week('2026-W37', 12, 0),
        week('2026-W38', 22, 0),
        week('2026-W39', 2, 0),
      ],
      owned: const [MuscleGroup.chest, MuscleGroup.calves],
      neglected: const [
        NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: null),
      ],
      mesocycleWeek: 3,
      deload: DeloadState.none,
    );
    makeContainer();
    await tester.pumpWidget(harness('/plan/volume'));
    await settle(tester);
    // Primary screen: plain rows, this week only, no ISO week keys.
    expect(find.text('Training volume'), findsOneWidget);
    expect(
      find.text("How much you've trained each muscle this week."),
      findsOneWidget,
    );
    expect(
      textOf(tester, 'volume.currentWeek').data,
      'This week · 21–27 Sep',
    );
    expect(find.textContaining('W39'), findsNothing);
    expect(textOf(tester, 'volume.chest.sets').data, '2 sets');
    // 2 sets is below MV → "Very low" in oxide, and an oxide rule.
    final status = textOf(tester, 'volume.chest.status');
    expect(status.data, 'Very low');
    expect(status.style?.color, FitColors.oxide);
    final row = tester
        .widget<Container>(find.byKey(const ValueKey('volume.row.chest')));
    expect(
      ((row.decoration! as BoxDecoration).border! as Border).left.color,
      FitColors.oxide,
    );
    // Nothing technical on the primary screen.
    expect(find.byKey(const ValueKey('volume.chest.detail')), findsNothing);
    expect(find.textContaining('MEV'), findsNothing);
    expect(
      textOf(tester, 'volume.neglect.calves').data,
      'Calves has not been trained yet.',
    );
    expect(textOf(tester, 'deload.week').data, 'Mesocycle week 3');
    // Owned muscles come first: chest and calves, then the rest in order.
    final list =
        tester.widget<ListView>(find.byKey(const ValueKey('volume.list')));
    final delegate = list.childrenDelegate as SliverChildListDelegate;
    final rows = [
      for (final w in delegate.children)
        if (w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('volume.row.'))
          (w.key! as ValueKey<String>).value.substring('volume.row.'.length),
    ];
    expect(rows.take(2), ['chest', 'calves']);
    expect(rows.length, MuscleGroup.values.length);

    // Tap chest: this week vs last, the status in words, the explanation,
    // the four weeks in human labels with dates — still no landmarks.
    await tester.tap(find.byKey(const ValueKey('volume.row.chest.tap')));
    await settle(tester);
    expect(find.byKey(const ValueKey('volume.chest.detail')), findsOneWidget);
    expect(
      textOf(tester, 'volume.chest.compare').data,
      'This week 2 sets · last week 22 sets',
    );
    expect(textOf(tester, 'volume.chest.title').data, 'Very low volume');
    expect(
      textOf(tester, 'volume.chest.explanation').data,
      startsWith('Fewer sets than it takes to hold on to what you have.'),
    );
    // The header line and the history's first row both say this week.
    expect(find.text('This week · 21–27 Sep'), findsNWidgets(2));
    expect(find.text('Last week · 14–20 Sep'), findsOneWidget);
    expect(find.text('2 weeks ago · 7–13 Sep'), findsOneWidget);
    expect(find.text('3 weeks ago · 31 Aug – 6 Sep'), findsOneWidget);
    expect(
      textOf(tester, 'volume.chest.history.2026-W38').data,
      '22 sets',
    );
    expect(textOf(tester, 'volume.chest.history.2026-W36').data, '10 sets');
    expect(find.textContaining('MEV'), findsNothing);

    // "View technical details" keeps MV / MEV / MAV / MRV, the engine's
    // status and the weighting available.
    await tester.tap(find.byKey(const ValueKey('volume.chest.technical')));
    await settle(tester);
    expect(
      textOf(tester, 'volume.chest.landmarks').data,
      'MV 4 · MEV 8 · MAV 12–20 · MRV 22',
    );
    expect(find.text('below-mv'), findsOneWidget);
    expect(
      find.text('1 per primary muscle, 0.5 per secondary'),
      findsOneWidget,
    );
    expect(find.text('Hide technical details'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('volume.chest.technical')));
    await settle(tester);
    expect(find.byKey(const ValueKey('volume.chest.landmarks')), findsNothing);
    // Collapse the row.
    await tester.tap(find.byKey(const ValueKey('volume.row.chest.tap')));
    await settle(tester);
    expect(find.byKey(const ValueKey('volume.chest.detail')), findsNothing);
  });

  testWidgets(
      'offline: the cached today carries the recommendation, so a session seeded with no signal opens with it',
      (tester) async {
    makeContainer();
    final repo = container.read(workoutRepositoryProvider);
    // Online once: the answer is cached.
    expect(
      (await repo.today()).when(ok: (_) => true, err: (_) => false),
      isTrue,
    );
    api.offline = true;
    final cached = await repo.today();
    final t = cached.when(ok: (t) => t, err: (f) => throw f);
    expect(t.exercises.first.recommendation, squatRec);
    expect(t.exercises.first.priorBest, squatBest);
    // The cached JSON is the wire shape with the Phase 6 keys.
    final row = await db.select(db.cachedJson).getSingle();
    final json = jsonDecode(row.json) as Map<String, dynamic>;
    expect(
      (json['exercises'] as List<dynamic>).first,
      containsPair('recommendation', isNotNull),
    );
    final s = await repo.startSession(day: t);
    expect(s.exercises.first.recommendation, squatRec);
    expect(s.exercises.first.prefill.first.weightKg, 75);
    // And the volume screen reads its cache the same way.
    api.offline = false;
    await repo.volume();
    api.offline = true;
    expect(
      (await repo.volume()).when(ok: (_) => true, err: (_) => false),
      isTrue,
    );
  });
}
