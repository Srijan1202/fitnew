import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/exercise/presentation/screens/exercise_browser_screen.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/custom_builder_screen.dart';
import 'package:fitos/features/training/presentation/screens/day_editor_screen.dart';
import 'package:fitos/features/training/presentation/screens/generate_options_screen.dart';
import 'package:fitos/features/training/presentation/screens/plan_start_screen.dart';
import 'package:fitos/features/training/presentation/screens/template_library_screen.dart';
import 'package:fitos/features/training/presentation/screens/template_preview_screen.dart';
import 'package:fitos/features/training/presentation/screens/workout_week_screen.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:fitos/features/workout/presentation/screens/active_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// The Phase 4 rework's UI against scripted servers: one day at a time,
/// expandable cards, per-set edits that auto-save, three entry modes,
/// templates previewed before applied, a step-by-step builder.
void main() {
  late FakeTrainingRepository training;
  late FakeExerciseRepository exercises;
  late FakeProfileRepository profile;
  late AppDatabase db;
  late FakeWorkoutApi workoutApi;

  setUp(() {
    training = FakeTrainingRepository();
    exercises = FakeExerciseRepository();
    profile = FakeProfileRepository();
    db = AppDatabase.inMemory();
    workoutApi = FakeWorkoutApi();
  });
  tearDown(() => db.close());

  Widget harness({String initial = '/plan'}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, __) => const WorkoutWeekScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, __) => const PlanStartScreen(canGoBack: true),
              routes: [
                GoRoute(
                  path: 'generate',
                  builder: (_, __) => const GenerateOptionsScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'templates',
              builder: (_, __) => const TemplateLibraryScreen(),
              routes: [
                GoRoute(
                  path: ':slug',
                  builder: (_, s) =>
                      TemplatePreviewScreen(slug: s.pathParameters['slug']!),
                ),
              ],
            ),
            GoRoute(
              path: 'custom',
              builder: (_, __) => const CustomBuilderScreen(),
            ),
            GoRoute(
              path: 'days/:dayId/edit',
              builder: (_, s) =>
                  DayEditorScreen(dayId: s.pathParameters['dayId']!),
            ),
            GoRoute(
              path: 'session/:id',
              builder: (_, s) => ActiveSessionScreen(
                clientSessionId: s.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'history',
              builder: (_, __) => const Scaffold(body: Text('HISTORY')),
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
              builder: (_, s) =>
                  Scaffold(body: Text('detail ${s.pathParameters['id']}')),
            ),
          ],
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('TODAY')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        trainingRepositoryProvider.overrideWithValue(training),
        exerciseRepositoryProvider.overrideWithValue(exercises),
        profileRepositoryProvider.overrideWithValue(profile),
        ...workoutOverrides(db, workoutApi),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  /// Scroll a lazily-built list until [finder] is on screen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// Wait past the auto-save debounce and let the request settle.
  Future<void> autosave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  }

  group('workout week: one day at a time', () {
    testWidgets('a day selector on top; only the selected day is shown',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);

      // Seven tabs, every day.
      for (var dow = 1; dow <= 7; dow++) {
        expect(find.byKey(ValueKey('day.tab.$dow')), findsOneWidget);
      }
      // A training day is selected by default and its exercises are listed
      // ONCE — the other training day's copies are not on screen.
      expect(find.text('Full Body'), findsOneWidget);
      expect(find.text('Barbell Back Squat'), findsOneWidget);
      expect(find.text('Barbell Bench Press'), findsOneWidget);
      expect(find.text('2 exercises · 7 sets · ~25 min'), findsOneWidget);
    });

    testWidgets('tapping a day switches to it; a rest day says so',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('day.tab.2')));
      await settle(tester);
      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('Barbell Back Squat'), findsNothing);
      expect(find.byKey(const ValueKey('day.train')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('day.tab.4')));
      await settle(tester);
      expect(find.text('THURSDAY'), findsOneWidget);
      expect(find.text('Barbell Back Squat'), findsOneWidget);
    });

    testWidgets('cards are collapsed by default and expand on tap',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);

      final cardKey = 'exercise.${plannedSquat.id}';
      // Collapsed: name, primary, sets × reps, "set weight" nudge; no set rows.
      expect(find.text('4 × 6–12'), findsOneWidget);
      final nudge = find.text('set weight');
      expect(nudge, findsOneWidget);
      expect(tester.widget<Text>(nudge).style?.color, FitColors.amber);
      expect(find.byKey(ValueKey('$cardKey.set.1')), findsNothing);

      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      for (var i = 1; i <= 4; i++) {
        expect(find.byKey(ValueKey('$cardKey.set.$i')), findsOneWidget);
      }
      expect(find.text('WHY THIS EXERCISE'), findsOneWidget);
      expect(find.text(plannedSquat.reason!), findsOneWidget);
      expect(find.byKey(ValueKey('$cardKey.replace')), findsOneWidget);
      expect(find.byKey(ValueKey('$cardKey.remove')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      expect(find.byKey(ValueKey('$cardKey.set.1')), findsNothing);
    });

    testWidgets(
        'an expanded card stays expanded through every edit, the save, and a refresh (owner review)',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedSquat.id}';
      final set1 = find.byKey(ValueKey('$cardKey.set.1'));
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      expect(set1, findsOneWidget);

      for (final control in [
        'set.1.reps.plus',
        'set.1.reps.plus',
        'set.1.reps.minus',
        'set.2.weight.plus',
        'set.2.weight.minus',
        'set.3.rir.plus',
        'set.3.rir.minus',
      ]) {
        await tester.tap(find.byKey(ValueKey('$cardKey.$control')));
        await tester.pump();
        expect(set1, findsOneWidget, reason: '$control collapsed the card');
      }
      // Typing a weight.
      await tester.ensureVisible(find.byKey(ValueKey('$cardKey.set.4.weight')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('$cardKey.set.4.weight')));
      await settle(tester);
      await tester.enterText(
        find.byKey(ValueKey('$cardKey.set.4.weight.field')),
        '60',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(set1, findsOneWidget, reason: 'typing collapsed the card');

      // The auto-save lands: the server's answer replaces the programme.
      // Every row the client sent named the planned exercise it continues,
      // so the server kept the ids and the card is still the same card.
      await autosave(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await settle(tester);
      expect(find.byKey(const ValueKey('save.saved')), findsOneWidget);
      expect(training.patchRequests, isNotEmpty);
      for (final (_, body) in training.patchRequests) {
        expect(
          body.exercises!.map((x) => x.id).toList(),
          [plannedSquat.id, plannedBench.id],
        );
      }
      expect(set1, findsOneWidget, reason: 'the save collapsed the card');
      expect(
        tester.widget<Text>(find.byKey(ValueKey('$cardKey.set.1.reps'))).data,
        '13',
      );

      // A provider refresh (pull-to-refresh, a retry elsewhere) re-reads the
      // programme; the expansion is the screen's, keyed by id, and survives.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkoutWeekScreen)),
      );
      container.invalidate(programControllerProvider);
      await settle(tester);
      expect(set1, findsOneWidget, reason: 'a refresh collapsed the card');
      // Until the user collapses it.
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      expect(set1, findsNothing);
    });

    testWidgets(
        'a save the server answers with NEW ids (a row without its id) does collapse — the contract the fake enforces',
        (tester) async {
      // Documents the failure mode: the fake mirrors the server, so a row
      // sent without `id` comes back as a different planned exercise.
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final day = generatedProgram.days.first;
      final repo = training;
      final without =
          day.exercises.map((x) => x.toCustom().copyWith(id: null)).toList();
      final after = await repo.patchDay(
        day.id,
        PatchProgramDayRequest(exercises: without),
      );
      final ids = (after as Ok<Program>)
          .value
          .days
          .first
          .exercises
          .map((x) => x.id)
          .toList();
      expect(ids, isNot(contains(plannedSquat.id)));
      expect(ids, isNot(contains(plannedBench.id)));
    });

    testWidgets(
        'reps and weight are edited per set and auto-saved as one PATCH after a pause',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedSquat.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);

      // A 6–12 prescription opens at 12 on every set (owner decision); the
      // range stays underneath until the set is pinned.
      String reps(int set) => tester
          .widget<Text>(find.byKey(ValueKey('$cardKey.set.$set.reps')))
          .data!;
      for (final i in [1, 2, 3, 4]) {
        expect(reps(i), '12');
      }
      expect(find.text('6–12 reps'), findsNWidgets(4));
      // Set 1: + steps to 13, − twice to 11, then to 10; nothing else moves.
      await tester.tap(find.byKey(ValueKey('$cardKey.set.1.reps.plus')));
      await tester.pump();
      expect(reps(1), '13');
      for (final i in [1, 2, 3]) {
        await tester.tap(find.byKey(ValueKey('$cardKey.set.1.reps.minus')));
        await tester.pump();
        expect(reps(1), '${13 - i}');
      }
      expect(reps(2), '12');
      expect(reps(3), '12');
      expect(find.text('6–12 reps'), findsNWidgets(3));
      // Set 3: weight + twice steps by the exercise's increment (5 kg).
      await tester
          .ensureVisible(find.byKey(ValueKey('$cardKey.set.3.weight.plus')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('$cardKey.set.3.weight.plus')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('$cardKey.set.3.weight.plus')));
      await tester.pump();
      // Set 2 untouched.
      expect(
        training.patchRequests,
        isEmpty,
        reason: 'debounced, not yet sent',
      );

      await autosave(tester);
      // Back to the top: the save mark sits in the day header.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await settle(tester);
      expect(
        training.patchRequests.length,
        1,
        reason: 'edits coalesce into one PATCH',
      );
      final (dayId, body) = training.patchRequests.single;
      expect(dayId, generatedProgram.days.first.id);
      final squat = body.exercises!
          .firstWhere((x) => x.exerciseId == plannedSquat.exerciseId);
      expect(squat.sets!.length, 4);
      expect(squat.sets![0].repsMin, 10);
      expect(squat.sets![0].repsMax, 10);
      expect(squat.sets![1].weightKg, isNull);
      expect(squat.sets![2].weightKg, 10);
      expect(find.byKey(const ValueKey('save.saved')), findsOneWidget);
    });

    testWidgets('typing a weight commits on submit', (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedBench.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);

      await tester.ensureVisible(find.byKey(ValueKey('$cardKey.set.2.weight')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('$cardKey.set.2.weight')));
      await settle(tester);
      await tester.enterText(
        find.byKey(ValueKey('$cardKey.set.2.weight.field')),
        '42.5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await autosave(tester);

      final (_, body) = training.patchRequests.single;
      final bench = body.exercises!
          .firstWhere((x) => x.exerciseId == plannedBench.exerciseId);
      expect(bench.sets!.map((s) => s.weightKg).toList(), [40, 42.5, 40]);
    });

    testWidgets('edits survive leaving and reopening the screen',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedSquat.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('$cardKey.set.1.weight.plus')));
      await tester.pump();

      // Leave before the debounce fires: the pending edit is flushed at once.
      await tester.tap(find.byKey(const ValueKey('plan.menu')));
      await settle(tester);
      await tester.tap(find.text('Change programme'));
      await settle(tester);
      expect(training.patchRequests.length, 1);
      expect(find.text('How do you want to train?'), findsOneWidget);

      // Reopen: the server's copy (the fake stores PATCHes) has the weight.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(
        find.byKey(ValueKey('$cardKey.header')),
        findsOneWidget,
        reason: 'the reopened plan must show the same rows',
      );
      // The collapsed card already shows the saved starting weight.
      expect(find.text('5 kg'), findsOneWidget);
    });

    testWidgets(
        'a failed save keeps the edit, shows Retry, and retry sends it again',
        (tester) async {
      training.stored = generatedProgram;
      training.nextPatch = const Err(Offline());
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedSquat.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('$cardKey.set.1.rir.plus')));
      await autosave(tester);

      expect(find.byKey(const ValueKey('save.retry')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey('$cardKey.set.1.rir'))).data,
        '2',
        reason: 'the edit is still on screen',
      );

      training.nextPatch = null; // server back
      await tester.tap(find.byKey(const ValueKey('save.retry')));
      await settle(tester);
      expect(training.patchRequests.length, 2);
      expect(find.byKey(const ValueKey('save.saved')), findsOneWidget);
    });

    testWidgets('remove sends at once; the last exercise cannot be removed',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedBench.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(ValueKey('$cardKey.remove')));
      await settle(tester);
      await tester.tap(
        find.byKey(ValueKey('$cardKey.remove')),
        warnIfMissed: true,
      );
      await settle(tester);
      expect(
        training.calls,
        contains(startsWith('patchDay')),
        reason: training.calls.join(','),
      );
      expect(training.patchRequests.single.$2.exercises!.length, 1);
      expect(find.text('Barbell Bench Press'), findsNothing);
    });

    testWidgets(
        'replace opens the picker and swaps the movement, weights cleared',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedBench.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(ValueKey('$cardKey.replace')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('$cardKey.replace')));
      await settle(tester);
      expect(find.text('ADD EXERCISE'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exercise.push-up')));
      await settle(tester);

      final (_, body) = training.patchRequests.single;
      expect(
        body.exercises!.map((x) => x.exerciseId).toList(),
        [plannedSquat.exerciseId, pushUp.id],
      );
      expect(body.exercises![1].sets!.every((s) => s.weightKg == null), isTrue);
    });
  });

  group('set-count editing on the plan (Phase 5 carry-over)', () {
    testWidgets(
        '+ Add set copies the last set; a set can be removed; the PATCH carries the new count',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedSquat.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      expect(find.byKey(ValueKey('$cardKey.set.5')), findsNothing);

      await reveal(tester, find.byKey(ValueKey('$cardKey.addSet')));
      await tester.tap(find.byKey(ValueKey('$cardKey.addSet')));
      await settle(tester);
      expect(find.byKey(ValueKey('$cardKey.set.5')), findsOneWidget);
      expect(find.text('5 × 6–12'), findsOneWidget);

      await reveal(tester, find.byKey(ValueKey('$cardKey.set.2.remove')));
      await tester.tap(find.byKey(ValueKey('$cardKey.set.2.remove')));
      await settle(tester);
      expect(find.byKey(ValueKey('$cardKey.set.5')), findsNothing);
      expect(find.text('4 × 6–12'), findsOneWidget);

      await autosave(tester);
      final (_, body) = training.patchRequests.last;
      final squat = body.exercises!.firstWhere((x) => x.id == plannedSquat.id);
      expect(squat.setCount, 4);
      expect(squat.sets!.length, 4);
      // Ids preserved: the same card is still open after the save.
      expect(find.byKey(ValueKey('$cardKey.set.1')), findsOneWidget);
    });

    testWidgets('the last set cannot be removed', (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      final cardKey = 'exercise.${plannedBench.id}';
      await tester.tap(find.byKey(ValueKey('$cardKey.header')));
      await settle(tester);
      for (final i in [3, 2]) {
        await reveal(tester, find.byKey(ValueKey('$cardKey.set.$i.remove')));
        await tester.tap(find.byKey(ValueKey('$cardKey.set.$i.remove')));
        await settle(tester);
      }
      expect(find.byKey(ValueKey('$cardKey.set.1')), findsOneWidget);
      expect(find.byKey(ValueKey('$cardKey.set.1.remove')), findsNothing);
    });
  });

  group('starting a session from the plan', () {
    testWidgets(
        'Start session opens the active session, seeded from the day; Resume afterwards',
        (tester) async {
      training.stored = generatedProgram;
      // No signal in the gym: the seed comes from the plan itself.
      workoutApi.offline = true;
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('day.start')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day.start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('session.title')), findsOneWidget);
      // Seeded from the plan: its exercises, its per-set targets.
      final active = await ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('session.title'))),
      ).read(workoutRepositoryProvider).activeSession();
      expect(active, isNotNull);
      expect(active!.programDayId, generatedProgram.days.first.id);
      expect(
        active.exercises.map((x) => x.name),
        ['Barbell Back Squat', 'Barbell Bench Press'],
      );
      expect(active.exercises.first.targets.length, 4);

      // Back to the plan: the button now resumes.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('session.leave.confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('day.resume')), findsOneWidget);
    });

    testWidgets('a rest day offers an empty session; the menu lists History',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('day.tab.2')));
      await settle(tester);
      expect(find.byKey(const ValueKey('day.startEmpty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan.menu')));
      await settle(tester);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Start empty session'), findsWidgets);
    });
  });

  group('entry modes', () {
    testWidgets('no programme → the three modes, as three panels',
        (tester) async {
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.text('How do you want to train?'), findsOneWidget);
      expect(find.byKey(const ValueKey('start.generate')), findsOneWidget);
      expect(find.byKey(const ValueKey('start.professional')), findsOneWidget);
      expect(find.byKey(const ValueKey('start.custom')), findsOneWidget);
    });

    testWidgets(
        'generate: days and minutes prefilled from the profile, then one request',
        (tester) async {
      await tester.pumpWidget(harness());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('start.generate')));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('generate.days.5')));
      await tester.tap(find.byKey(const ValueKey('generate.minutes.45')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('generate.go')));
      await settle(tester);

      expect(withoutNulls(training.generateRequests.single.toJson()), {
        'daysPerWeek': 5,
        'preferredSessionMinutes': 45,
      });
      // Landed on the plan.
      expect(find.byKey(const ValueKey('day.tab.1')), findsOneWidget);
    });

    testWidgets(
        'professional: library → preview (nothing applied) → Use this program',
        (tester) async {
      await tester.pumpWidget(harness());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('start.professional')));
      await settle(tester);

      expect(find.text('Choose a training structure'), findsOneWidget);
      expect(find.text('Push / Pull / Legs'), findsOneWidget);
      expect(find.text('Bro Split'), findsOneWidget);
      expect(find.text('Push · Pull · Legs'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('template.push-pull-legs')));
      await settle(tester);
      expect(training.calls, contains('previewTemplate:push-pull-legs'));
      expect(training.calls, isNot(contains('applyTemplate:push-pull-legs')));
      expect(find.byKey(const ValueKey('preview.day.1')), findsOneWidget);
      expect(find.text('→ Push'), findsOneWidget);
      expect(find.text('→ Pull'), findsOneWidget);
      expect(find.text('→ Legs'), findsOneWidget);
      expect(find.text('Barbell Bench Press'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('template.use')));
      await settle(tester);
      expect(training.applyRequests.single.$1, 'push-pull-legs');
      expect(find.byKey(const ValueKey('day.tab.1')), findsOneWidget);
    });

    testWidgets('template library makes no superiority claims', (tester) async {
      await tester.pumpWidget(harness(initial: '/plan/templates'));
      await settle(tester);
      for (final word in ['best', 'optimal', 'scientifically']) {
        expect(find.textContaining(word), findsNothing);
      }
    });
  });

  group('custom builder wizard', () {
    testWidgets(
        'Days → Day details → Muscle groups → Exercises → Sets → Save sends one PUT',
        (tester) async {
      await tester.pumpWidget(harness(initial: '/plan/custom'));
      await settle(tester);

      // Step 1: name + days. Continue disabled until two days.
      final next = find.byKey(const ValueKey('builder.next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('builder.day.Mon')));
      await tester.tap(find.byKey(const ValueKey('builder.day.Thu')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('builder.name')),
        'Heavy twice',
      );
      await tester.pump();
      await tester.tap(next);
      await settle(tester);

      // Step 2: names.
      expect(find.text('Name each day'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('builder.day.1.name')),
        'Squat day',
      );
      await tester.pump();
      await tester.tap(next);
      await settle(tester);

      // Step 3: muscle groups (optional).
      expect(find.text('Muscle groups'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('builder.day.1.focus.Quads')));
      await tester.pump();
      await tester.tap(next);
      await settle(tester);

      // Step 4: exercises — Continue disabled until every day has one.
      expect(find.text('Exercises'), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      for (final dow in [1, 4]) {
        await tester
            .ensureVisible(find.byKey(ValueKey('builder.day.$dow.add')));
        await tester.tap(find.byKey(ValueKey('builder.day.$dow.add')));
        await settle(tester);
        await tester
            .tap(find.byKey(const ValueKey('exercise.barbell-back-squat')));
        await settle(tester);
      }
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await settle(tester);

      // Step 5: sets — 3 by default; bump to 4 and set a starting weight on set 1.
      expect(find.text('Sets, reps, starting weight'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('builder.day.1.exercise.0.sets.plus')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('builder.day.1.exercise.0.set.1.weight.plus'),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(next);
      await tester.tap(next);
      await settle(tester);

      // Step 6: review → save.
      expect(find.text('Heavy twice'), findsOneWidget);
      await tester.tap(next);
      await settle(tester);

      final body = training.putRequests.single;
      expect(body.name, 'Heavy twice');
      expect(body.days.map((d) => d.dayOfWeek).toList(), [1, 4]);
      expect(body.days.first.sessionName, 'Squat day');
      expect(body.days.first.focus, [MuscleGroup.quads]);
      final x = body.days.first.exercises.single;
      expect(x.exerciseId, squat.id);
      expect(x.setCount, 4);
      expect(x.sets!.length, 4);
      expect(
        x.sets![0].weightKg,
        2.5,
      ); // default increment for a pick with none known
      expect(x.sets![1].weightKg, isNull);
      expect(body.days.last.exercises.single.sets!.length, 3);
      // Back on the plan afterwards.
      expect(find.byKey(const ValueKey('day.tab.1')), findsOneWidget);
    });
  });

  group('day editor', () {
    testWidgets('rename, choose muscle groups, remove, and save a PATCH',
        (tester) async {
      training.stored = generatedProgram;
      final dayId = generatedProgram.days.first.id;
      await tester.pumpWidget(harness(initial: '/plan/days/$dayId/edit'));
      await settle(tester);

      expect(find.text('Edit this day'), findsOneWidget);
      // Toggles first (a focused text field would fight the drag), name after.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('day.focus.Calves')),
        find.byType(ListView).first,
        const Offset(0, -120),
      );
      await tester
          .ensureVisible(find.byKey(const ValueKey('day.focus.Calves')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('day.focus.Calves')));
      await tester.pump();
      // Back up to the name field (the list builds lazily), then type.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('day.name')),
        find.byType(ListView).first,
        const Offset(0, 120),
      );
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('day.name')),
        'Legs & chest',
      );
      await reveal(tester, find.byTooltip('Remove Barbell Bench Press'));
      await tester.tap(find.byTooltip('Remove Barbell Bench Press'));
      await tester.pump();
      expect(find.text('Barbell Bench Press'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('day.save')));
      await settle(tester);

      final (id, body) = training.patchRequests.single;
      expect(id, dayId);
      expect(body.sessionName, 'Legs & chest');
      expect(
        body.focus,
        containsAll(
          [MuscleGroup.quads, MuscleGroup.chest, MuscleGroup.calves],
        ),
      );
      expect(body.exercises!.single.exerciseId, plannedSquat.exerciseId);
      expect(body.exercises!.single.sets!.length, 4);
    });

    testWidgets(
        'an empty day cannot be saved; a rest day can be turned into a session',
        (tester) async {
      training.stored = generatedProgram;
      final restId = generatedProgram.days[1].id;
      await tester.pumpWidget(harness(initial: '/plan/days/$restId/edit'));
      await settle(tester);
      expect(find.text('Train this day'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('day.save')))
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byKey(const ValueKey('day.add')));
      await tester.tap(find.byKey(const ValueKey('day.add')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('exercise.push-up')));
      await settle(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('day.save')))
            .onPressed,
        isNotNull,
      );
    });
  });
}
