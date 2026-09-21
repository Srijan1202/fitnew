import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/exercise/presentation/screens/exercise_browser_screen.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:fitos/features/workout/presentation/screens/active_session_screen.dart';
import 'package:fitos/features/workout/presentation/screens/session_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// The active workout, on the phone's database against the fake server:
/// one tap logs the pre-filled set, the rest timer starts, extra and drop
/// sets, supersets, leaving keeps the session, finishing shows the summary.
void main() {
  late AppDatabase db;
  late FakeWorkoutApi api;
  late FakeExerciseRepository exercises;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    exercises = FakeExerciseRepository();
  });
  tearDown(() => db.close());

  Widget harness(String clientSessionId) {
    final router = GoRouter(
      initialLocation: '/plan/session/$clientSessionId',
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, __) => const Scaffold(body: Text('PLAN')),
          routes: [
            GoRoute(
              path: 'session/:id',
              builder: (_, s) =>
                  ActiveSessionScreen(clientSessionId: s.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'summary',
                  builder: (_, s) => SessionSummaryScreen(
                    clientSessionId: s.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/exercises/pick',
          builder: (_, __) => const ExerciseBrowserScreen(pickMode: true),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('TODAY')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  /// The screen ticks a clock every second, so `pumpAndSettle` never
  /// settles; two pumps cover a route transition and the database streams.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// Start a session from the fake's day and mount the screen.
  Future<WorkoutSession> pumpSession(
    WidgetTester tester, {
    bool offline = false,
  }) async {
    container = ProviderContainer(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        exerciseRepositoryProvider.overrideWithValue(exercises),
        ...workoutOverrides(db, api),
      ],
    );
    addTearDown(container.dispose);
    api.offline = offline;
    final repo = container.read(workoutRepositoryProvider);
    final session = await repo.startSession(day: api.todayResponse);
    // A fixed clock: the rest countdown reads exactly what was started.
    container.read(restTimerProvider.notifier).clock =
        () => DateTime.utc(2026, 9, 21, 10);
    // The rest timer's tick must not outlive the test.
    addTearDown(() => container.read(restTimerProvider.notifier).skip());
    await tester.pumpWidget(harness(session.clientSessionId));
    await settle(tester);
    return session;
  }

  /// The weight cell is a tappable InkWell around the number.
  String weightOf(WidgetTester tester, String key) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .data!;

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
  }

  String squatKey(WorkoutSession s) =>
      'session.${s.exercises.first.clientExerciseId}';
  Text textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key)));

  testWidgets(
      'opens on the first exercise, pre-filled from the plan and last time, with "Last time" shown',
      (tester) async {
    final s = await pumpSession(tester);
    final k = squatKey(s);
    expect(find.text('Barbell Back Squat'), findsOneWidget);
    expect(find.text('Standing Calf Raise'), findsOneWidget);
    expect(textOf(tester, '$k.last').data, 'Last time: 70×10  70×9  70×8');
    // Three pending rows: reps = the plan's target (12), weight = last time (70), RIR = the plan (1).
    for (final i in [1, 2, 3]) {
      expect(textOf(tester, '$k.set.$i.reps').data, '12');
      expect(weightOf(tester, '$k.set.$i.weight'), '70');
      expect(textOf(tester, '$k.set.$i.rir').data, '1');
    }
    expect(textOf(tester, '$k.count').data, '0 / 3');
    expect(textOf(tester, 'session.sets').data, '0 / 5');
    // The second exercise is collapsed.
    expect(
      find.byKey(
        ValueKey('session.${s.exercises[1].clientExerciseId}.set.1'),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'one tap logs the set with its numbers, turns it pine, starts the rest timer (90 s for a compound)',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    final k = squatKey(s);
    // Edit first: two reps fewer on set 1.
    await tester.tap(find.byKey(ValueKey('$k.set.1.reps.minus')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('$k.set.1.reps.minus')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);

    final local = (await container
        .read(workoutRepositoryProvider)
        .session(s.clientSessionId))!;
    final logged = local.exercises.first.sets.single;
    expect(logged.reps, 10);
    expect(logged.weightKg, 70);
    expect(logged.rir, 1);
    expect(logged.setType, SetType.working);
    expect(textOf(tester, '$k.count').data, '1 / 3');
    expect(textOf(tester, 'session.sets').data, '1 / 5');
    expect(find.byKey(const ValueKey('rest.bar')), findsOneWidget);
    expect(textOf(tester, 'rest.remaining').data, '1:30');
    // Nothing reached the server: airplane mode.
    expect(api.sessions, isEmpty);
    expect(find.byKey(const ValueKey('sync.pending')), findsOneWidget);

    // +15 / skip on the rest timer.
    await tester.tap(find.byKey(const ValueKey('rest.plus')));
    await tester.pump();
    expect(textOf(tester, 'rest.remaining').data, '1:45');
    await tester.tap(find.byKey(const ValueKey('rest.skip')));
    await tester.pump();
    expect(find.byKey(const ValueKey('rest.bar')), findsNothing);

    // A logged set can be corrected in place and un-logged.
    await tester.tap(find.byKey(ValueKey('$k.set.1.weight.plus')));
    await settle(tester);
    expect(
      (await container
              .read(workoutRepositoryProvider)
              .session(s.clientSessionId))!
          .exercises
          .first
          .sets
          .single
          .weightKg,
      75,
    );
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);
    expect(
      (await container
              .read(workoutRepositoryProvider)
              .session(s.clientSessionId))!
          .exercises
          .first
          .sets,
      isEmpty,
    );
  });

  testWidgets(
      '+ Add set and Drop set: extra rows beyond the plan, a drop set logged under its working set',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    final k = squatKey(s);
    expect(find.byKey(ValueKey('$k.set.4')), findsNothing);
    await reveal(tester, find.byKey(ValueKey('$k.addSet')));
    await tester.tap(find.byKey(ValueKey('$k.addSet')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.set.4')), findsOneWidget);
    // The extra row copies the row above.
    expect(textOf(tester, '$k.set.4.reps').data, '12');

    expect(
      tester.widget<TextButton>(find.byKey(ValueKey('$k.dropSet'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);
    await reveal(tester, find.byKey(ValueKey('$k.dropSet')));
    await tester.tap(find.byKey(ValueKey('$k.dropSet')));
    await settle(tester);
    await reveal(tester, find.byKey(ValueKey('$k.set.1.drop')));
    expect(find.byKey(ValueKey('$k.set.1.drop')), findsOneWidget);
    expect(find.text('DROP'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('$k.set.1.drop.weight.minus')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('$k.set.1.drop.done')));
    await settle(tester);
    final local = (await container
        .read(workoutRepositoryProvider)
        .session(s.clientSessionId))!;
    final drop =
        local.exercises.first.sets.firstWhere((t) => t.setType == SetType.drop);
    expect(drop.setIndex, 1);
    expect(drop.weightKg, 65);
    // Drop sets never count as working sets.
    expect(textOf(tester, '$k.count').data, '1 / 3');
  });

  testWidgets('superset with next marks both exercises; un-superset clears',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    final k = squatKey(s);
    await reveal(tester, find.byKey(ValueKey('$k.supersetToggle')));
    await tester.tap(find.byKey(ValueKey('$k.supersetToggle')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.superset')), findsOneWidget);
    final local = (await container
        .read(workoutRepositoryProvider)
        .session(s.clientSessionId))!;
    expect(local.exercises[0].supersetGroup, 1);
    expect(local.exercises[1].supersetGroup, 1);
    await tester.tap(find.byKey(ValueKey('$k.supersetToggle')));
    await settle(tester);
    expect(find.byKey(ValueKey('$k.superset')), findsNothing);
  });

  testWidgets('leaving keeps the session active; Android back asks first',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    await tester.tap(find.byKey(ValueKey('${squatKey(s)}.set.1.done')));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Leave the session?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('session.leave.confirm')));
    await settle(tester);
    expect(find.text('PLAN'), findsOneWidget);
    final active =
        await container.read(workoutRepositoryProvider).activeSession();
    expect(active?.clientSessionId, s.clientSessionId);
    expect(active?.workingSetsLogged, 1);
  });

  testWidgets(
      'Finish completes the session and shows the summary; once synced, the records appear',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    final k = squatKey(s);
    for (final i in [1, 2, 3]) {
      await tester.tap(find.byKey(ValueKey('$k.set.$i.done')));
      await settle(tester);
    }
    await tester.tap(find.byKey(const ValueKey('session.finish')));
    await settle(tester);
    await settle(tester);
    expect(find.byKey(const ValueKey('summary.title')), findsOneWidget);
    expect(textOf(tester, 'summary.sets').data, '3');
    expect(textOf(tester, 'summary.tonnage').data, '2520'); // 70×12 ×3
    // Offline: the engine's part is pending, honestly.
    expect(find.byKey(const ValueKey('summary.pending')), findsOneWidget);
    expect(find.textContaining('Heaviest'), findsNothing);

    api.offline = false;
    await container.read(workoutRepositoryProvider).sync();
    await settle(tester);
    expect(find.byKey(const ValueKey('summary.pending')), findsNothing);
    expect(find.textContaining('Heaviest'), findsOneWidget);
    expect(api.sessions[s.clientSessionId]!.status, SessionStatus.completed);
    await reveal(tester, find.byKey(const ValueKey('summary.done')));
    await tester.tap(find.byKey(const ValueKey('summary.done')));
    await settle(tester);
    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets('Discard abandons the session', (tester) async {
    final s = await pumpSession(tester, offline: true);
    await tester.tap(find.byKey(const ValueKey('session.menu')));
    await settle(tester);
    await tester.tap(find.text('Discard session'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('session.discard.confirm')));
    await settle(tester);
    expect(find.text('PLAN'), findsOneWidget);
    expect(
      (await container
              .read(workoutRepositoryProvider)
              .session(s.clientSessionId))!
          .status,
      SessionStatus.abandoned,
    );
    expect(
      await container.read(workoutRepositoryProvider).activeSession(),
      isNull,
    );
  });

  testWidgets(
      'Add exercise via the picker appends an exercise the user can log against',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    await reveal(tester, find.byKey(const ValueKey('session.addExercise')));
    await tester.tap(find.byKey(const ValueKey('session.addExercise')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('exercise.push-up')));
    await settle(tester);
    final local = (await container
        .read(workoutRepositoryProvider)
        .session(s.clientSessionId))!;
    expect(local.exercises.length, 3);
    expect(local.exercises.last.name, 'Push-Up');
    final k = 'session.${local.exercises.last.clientExerciseId}';
    // No plan for it: one pending row, logged like any other.
    await reveal(tester, find.byKey(ValueKey('$k.set.1')));
    expect(find.byKey(ValueKey('$k.set.1')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('$k.set.1.done')));
    await settle(tester);
    expect(
      (await container
              .read(workoutRepositoryProvider)
              .session(s.clientSessionId))!
          .exercises
          .last
          .sets
          .length,
      1,
    );
  });

  testWidgets(
      'the rest default is 60 s after an isolation lift and the row values round-trip the plan',
      (tester) async {
    final s = await pumpSession(tester, offline: true);
    final curl = 'session.${s.exercises[1].clientExerciseId}';
    await tester.tap(find.byKey(ValueKey('$curl.header')));
    await settle(tester);
    expect(textOf(tester, '$curl.set.1.reps').data, '15');
    expect(weightOf(tester, '$curl.set.1.weight'), '—');
    await tester.tap(find.byKey(ValueKey('$curl.set.1.done')));
    await settle(tester);
    expect(textOf(tester, 'rest.remaining').data, '1:00');
    expect(
      container.read(restTimerProvider)?.exerciseName,
      'Standing Calf Raise',
    );
    expect(FitColors.pine, isNotNull);
  });
}
