import 'dart:ui' show Tristate;

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/routing/app_shell.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/day_editor_screen.dart';
import 'package:fitos/features/training/presentation/screens/workout_week_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercise_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// The app shell and Android back, on the real route table (owner review
/// 2026-09-21: `GoError: There is nothing to pop` after switching days).
///
/// Android back is what `WidgetsBinding.handlePopRoute` delivers: the same
/// path the system button takes. It must never throw, and where it lands
/// must be deterministic.
void main() {
  late FakeTrainingRepository training;
  late FakeExerciseRepository exercises;
  late FakeProfileRepository profile;
  late AppDatabase db;
  late FakeWorkoutApi workoutApi;
  late FakeAuthRepository auth;

  setUp(() {
    training = FakeTrainingRepository()..stored = generatedProgram;
    exercises = FakeExerciseRepository();
    profile = FakeProfileRepository();
    db = AppDatabase.inMemory();
    workoutApi = FakeWorkoutApi();
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
  });
  tearDown(() async {
    auth.dispose();
    await db.close();
  });

  Widget app({String initial = '/plan'}) {
    final key = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: key,
      initialLocation: initial,
      routes: buildRoutes(key),
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue(testProfile.id),
        authRepositoryProvider.overrideWithValue(auth),
        trainingRepositoryProvider.overrideWithValue(training),
        exerciseRepositoryProvider.overrideWithValue(exercises),
        profileRepositoryProvider.overrideWithValue(profile),
        ...workoutOverrides(db, workoutApi),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  /// The system back button.
  Future<bool> androidBack(WidgetTester tester) async {
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    return handled;
  }

  Finder bar() => find.byKey(const ValueKey('nav.Training'));

  group('Android back', () {
    testWidgets(
        'plan → Monday → Tuesday → Wednesday → back lands on TODAY, never a GoError',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);

      for (final dow in [1, 2, 3, 4, 2]) {
        await tester.tap(find.byKey(ValueKey('day.tab.$dow')));
        await tester.pumpAndSettle();
      }
      // Days are state on one screen, not a stack of routes.
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);

      final handled = await androidBack(tester);
      expect(handled, isTrue);
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'TODAY');
      expect(find.byType(WorkoutWeekScreen), findsNothing);
    });

    testWidgets(
        'after a programme is generated (`go /plan`) back still has somewhere to go',
        (tester) async {
      training.stored = null;
      training.nextGenerate = Ok(generatedProgram);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      // No programme: the three modes, as the Training tab's root.
      expect(find.byKey(const ValueKey('start.generate')), findsOneWidget);
      expect(bar(), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('start.generate')));
      await tester.pumpAndSettle();
      expect(bar(), findsNothing, reason: 'deeper screens hide the bar');
      await tester.tap(find.byKey(const ValueKey('generate.go')));
      await tester.pumpAndSettle();
      expect(find.text('Barbell Back Squat'), findsOneWidget);
      expect(bar(), findsOneWidget);

      expect(await androidBack(tester), isTrue);
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a deeper training screen pops back to the plan, with the bar',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit this day'));
      await tester.pumpAndSettle();
      expect(find.byType(DayEditorScreen), findsOneWidget);
      expect(bar(), findsNothing);

      expect(await androidBack(tester), isTrue);
      expect(find.byType(DayEditorScreen), findsNothing);
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);
      expect(bar(), findsOneWidget);
    });

    testWidgets('on TODAY, back leaves the app (nothing to pop, no exception)',
        (tester) async {
      await tester.pumpWidget(app(initial: '/'));
      await tester.pumpAndSettle();
      expect(await androidBack(tester), isFalse);
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('bottom navigation', () {
    testWidgets(
        'five destinations; each shows its screen and marks itself selected',
        (tester) async {
      await tester.pumpWidget(app(initial: '/'));
      await tester.pumpAndSettle();
      for (final label in ['Home', 'Training', 'AI', 'Nutrition', 'Market']) {
        expect(find.byKey(ValueKey('nav.$label')), findsOneWidget);
      }

      Future<void> go(String label) async {
        await tester.tap(find.byKey(ValueKey('nav.$label')));
        await tester.pumpAndSettle();
      }

      bool selected(String label) =>
          tester
              .getSemantics(find.byKey(ValueKey('nav.$label')))
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;

      expect(selected('Home'), isTrue);
      await go('AI');
      expect(find.text('AI CHAT'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(
        find.text('The AI fitness assistant will live here.'),
        findsOneWidget,
      );
      expect(selected('AI'), isTrue);
      expect(selected('Home'), isFalse);

      await go('Nutrition');
      expect(
        find.text(
          'Your targets, the mess menu and food logging will live here.',
        ),
        findsOneWidget,
      );
      expect(selected('Nutrition'), isTrue);

      await go('Market');
      expect(
        find.text('Supplements and gear from campus vendors will live here.'),
        findsOneWidget,
      );
      expect(selected('Market'), isTrue);

      await go('Training');
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);
      expect(selected('Training'), isTrue);

      await go('Home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(selected('Home'), isTrue);
    });

    testWidgets('a tab keeps its state: the selected day survives a round trip',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day.tab.4')));
      await tester.pumpAndSettle();
      expect(find.text('THURSDAY'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav.AI')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.Training')));
      await tester.pumpAndSettle();
      expect(find.text('THURSDAY'), findsOneWidget);
    });

    testWidgets('the bar is never duplicated under a deeper screen',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav.Home')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change programme'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav.Home')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('start.professional')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav.Home')), findsNothing);
      // Back, back: the plan with exactly one bar.
      await androidBack(tester);
      await androidBack(tester);
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('nav.Home')), findsOneWidget);
    });
  });

  group('floating bottom navigation (Phase 6.5)', () {
    testWidgets(
        'the bar floats over the body: translucent, hairline border, 60 px, inset from the edges, body extended under it',
        (tester) async {
      await tester.pumpWidget(app(initial: '/'));
      await tester.pumpAndSettle();
      final scaffold = tester.widget<Scaffold>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('nav.bar')),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(scaffold.extendBody, isTrue);
      final bar =
          tester.widget<Container>(find.byKey(const ValueKey('nav.bar')));
      final deco = bar.decoration! as BoxDecoration;
      expect(deco.color!.a, lessThan(1.0), reason: 'translucent');
      expect(deco.color!.a, greaterThan(0.8), reason: 'still paper');
      expect(deco.border, isNotNull);
      expect(deco.boxShadow, hasLength(1));
      final size = tester.getSize(find.byKey(const ValueKey('nav.bar')));
      expect(size.height, FitBottomBar.contentHeight);
      final rect = tester.getRect(find.byKey(const ValueKey('nav.bar')));
      final screen = tester.getSize(find.byType(MaterialApp));
      expect(rect.left, FitBottomBar.sideMargin);
      expect(screen.width - rect.right, FitBottomBar.sideMargin);
      expect(screen.height - rect.bottom, FitBottomBar.bottomMargin);
      // Every item is a full-height touch target.
      for (final label in ['Home', 'Training', 'AI', 'Nutrition', 'Market']) {
        expect(
          tester.getSize(find.byKey(ValueKey('nav.$label'))).height,
          FitBottomBar.contentHeight,
        );
      }
    });

    testWidgets('the floating bar still switches every tab and keeps state',
        (tester) async {
      await tester.pumpWidget(app(initial: '/'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.Training')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day.tab.3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.Home')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav.Training')));
      await tester.pumpAndSettle();
      // The day chosen before leaving is still selected (indexed stack).
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('day.tab.3')), findsOneWidget);
    });
  });
}
