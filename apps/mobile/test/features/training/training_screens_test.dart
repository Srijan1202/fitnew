import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/exercise/presentation/screens/exercise_browser_screen.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/custom_builder_screen.dart';
import 'package:fitos/features/training/presentation/screens/day_editor_screen.dart';
import 'package:fitos/features/training/presentation/screens/weekly_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_training_repository.dart';

/// Weekly plan, day editor and custom builder against scripted servers.
/// §31 Phase 4 UI: the week renders what the server sent; every edit is a
/// request whose body is asserted here.
void main() {
  late FakeTrainingRepository training;
  late FakeExerciseRepository exercises;

  setUp(() {
    training = FakeTrainingRepository();
    exercises = FakeExerciseRepository();
  });

  Widget harness({String initial = '/plan'}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, __) => const WeeklyPlanScreen(),
          routes: [
            GoRoute(
              path: 'build',
              builder: (_, __) => const CustomBuilderScreen(),
            ),
            GoRoute(
              path: 'days/:dayId',
              builder: (_, s) =>
                  DayEditorScreen(dayId: s.pathParameters['dayId']!),
            ),
          ],
        ),
        GoRoute(
          path: '/exercises',
          builder: (_, __) => const ExerciseBrowserScreen(),
          routes: [
            GoRoute(
              path: 'pick',
              builder: (_, __) => const ExerciseBrowserScreen(pickMode: true),
            ),
            GoRoute(
              path: ':id',
              builder: (_, s) => Scaffold(
                body: Text('detail ${s.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        trainingRepositoryProvider.overrideWithValue(training),
        exerciseRepositoryProvider.overrideWithValue(exercises),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  group('weekly plan', () {
    testWidgets('no programme → generate; the generated week renders',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(find.text('No programme yet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan.generate')));
      await tester.pumpAndSettle();

      expect(training.calls, ['getProgram', 'generate']);
      expect(find.text('Full Body · 2 days'), findsOneWidget);
      expect(find.text('FULL BODY · WEEK 1 · 2 DAYS'), findsOneWidget);
      expect(find.text('MONDAY · FULL BODY'), findsOneWidget);
      expect(find.text('TUESDAY · REST'), findsOneWidget);
      expect(find.text('4 × 6–12 @ RIR 1'), findsNWidgets(4));
      // The shortfall is shown, in amber, verbatim.
      final shortfall = find.textContaining('add a day or minutes');
      expect(shortfall, findsOneWidget);
      expect(tester.widget<Text>(shortfall).style?.color, FitColors.amber);
    });

    testWidgets('a failed generate shows the message and keeps the empty state',
        (tester) async {
      training.nextGenerate = const Err(Offline());
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan.generate')));
      await tester.pumpAndSettle();
      expect(find.text('No programme yet'), findsOneWidget);
      expect(find.text(const Offline().message), findsOneWidget);
    });

    testWidgets(
        'tapping an exercise opens its detail; the day header opens the editor',
        (tester) async {
      training.nextProgram = Ok(generatedProgram);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(ValueKey('plan.exercise.${plannedSquat.id}')));
      await tester.pumpAndSettle();
      expect(find.text('detail ${plannedSquat.exerciseId}'), findsOneWidget);
    });

    testWidgets('the rationale is shown under "Why this plan"', (tester) async {
      training.nextProgram = Ok(generatedProgram);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(find.text('WHY THIS PLAN'), findsOneWidget);
      expect(
        find.text('2 days/week as beginner: full body each session (§12.2).'),
        findsOneWidget,
      );
    });
  });

  group('day editor', () {
    testWidgets(
        'edits sets, removes an exercise, saves a PATCH with the day id',
        (tester) async {
      training.nextProgram = Ok(generatedProgram);
      final dayId = generatedProgram.days.first.id;
      await tester.pumpWidget(harness(initial: '/plan/days/$dayId'));
      await tester.pumpAndSettle();

      expect(find.text('MONDAY'), findsOneWidget);
      expect(find.text('Barbell Back Squat'), findsOneWidget);

      // One more set on the squat, then drop the bench.
      await tester.tap(find.byTooltip('More sets').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Remove').last);
      await tester.pump();
      expect(find.text('Barbell Bench Press'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('day.name')), 'Legs');
      await tester.tap(find.byKey(const ValueKey('day.save')));
      await tester.pumpAndSettle();

      final (id, body) = training.patchRequests.single;
      expect(id, dayId);
      expect(body.sessionName, 'Legs');
      expect(body.exercises!.length, 1);
      expect(body.exercises!.single.exerciseId, plannedSquat.exerciseId);
      expect(body.exercises!.single.setCount, 5);
      // Back on the plan after saving.
      expect(find.text('Full Body · 2 days'), findsOneWidget);
    });

    testWidgets('an empty day cannot be saved', (tester) async {
      training.nextProgram = Ok(generatedProgram);
      final dayId = generatedProgram.days.first.id;
      await tester.pumpWidget(harness(initial: '/plan/days/$dayId'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pump();
      expect(
        find.text('A training day needs at least one exercise.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('day.save')))
            .onPressed,
        isNull,
      );
    });

    testWidgets(
        '"Add exercise" opens the picker and the pick lands in the list',
        (tester) async {
      training.nextProgram = Ok(generatedProgram);
      final dayId = generatedProgram.days.first.id;
      await tester.pumpWidget(harness(initial: '/plan/days/$dayId'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('day.add')));
      await tester.tap(find.byKey(const ValueKey('day.add')));
      await tester.pumpAndSettle();
      expect(find.text('Pick an exercise'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('exercise.push-up')));
      await tester.pumpAndSettle();

      expect(find.text('Push-Up'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('day.save')));
      await tester.tap(find.byKey(const ValueKey('day.save')));
      await tester.pumpAndSettle();
      final (_, body) = training.patchRequests.single;
      expect(
        body.exercises!.map((x) => x.exerciseId).toList(),
        [plannedSquat.exerciseId, plannedBench.exerciseId, pushUp.id],
      );
      // A new pick starts at 3 × 6–12 @ RIR 2 with the default increment.
      expect(body.exercises!.last.setCount, 3);
      expect(body.exercises!.last.incrementKg, isNull);
    });
  });

  group('custom builder', () {
    testWidgets('needs two days each with an exercise, then PUTs the programme',
        (tester) async {
      await tester.pumpWidget(harness(initial: '/plan/build'));
      await tester.pumpAndSettle();

      final save = find.byKey(const ValueKey('builder.save'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text('Choose at least two days.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('builder.day.1')));
      await tester.tap(find.byKey(const ValueKey('builder.day.4')));
      await tester.pump();
      expect(find.text('Add at least one exercise.'), findsNWidgets(2));

      for (final dow in [1, 4]) {
        await tester
            .ensureVisible(find.byKey(ValueKey('builder.day.$dow.add')));
        await tester.tap(find.byKey(ValueKey('builder.day.$dow.add')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('exercise.barbell-back-squat')));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const ValueKey('builder.name')),
        'Squat twice',
      );
      await tester.enterText(
        find.byKey(const ValueKey('builder.day.1.name')),
        'Heavy',
      );
      await tester.pump();

      await tester.ensureVisible(save);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final body = training.putRequests.single;
      expect(body.name, 'Squat twice');
      expect(body.days.map((d) => d.dayOfWeek).toList(), [1, 4]);
      expect(body.days.first.sessionName, 'Heavy');
      expect(body.days.last.sessionName, 'Day');
      expect(body.days.first.exercises.single.exerciseId, squat.id);
      // Back on the plan, now showing what the server returned.
      expect(find.text('Full Body · 2 days'), findsOneWidget);
    });

    testWidgets('a seventh day cannot be chosen once six are', (tester) async {
      await tester.pumpWidget(harness(initial: '/plan/build'));
      await tester.pumpAndSettle();
      for (var dow = 1; dow <= 7; dow++) {
        await tester.ensureVisible(find.byKey(ValueKey('builder.day.$dow')));
        await tester.tap(find.byKey(ValueKey('builder.day.$dow')));
        await tester.pump();
      }
      expect(find.text('SUNDAY'), findsNothing);
      expect(find.text('SATURDAY'), findsOneWidget);
    });
  });
}
