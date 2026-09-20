import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/exercise/presentation/screens/exercise_browser_screen.dart';
import 'package:fitos/features/exercise/presentation/screens/exercise_detail_screen.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';

/// Browser and detail against a scripted server. Asserts §31 Phase 3's UI:
/// browse, filter (by asking the server), open a detail with alternatives.
void main() {
  late FakeExerciseRepository repo;

  setUp(() => repo = FakeExerciseRepository());

  /// A tiny router so `context.push` from a row has somewhere to go.
  Widget harness({String initial = '/exercises'}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/exercises',
          builder: (_, __) => const ExerciseBrowserScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, s) =>
                  ExerciseDetailScreen(id: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [exerciseRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  testWidgets('lists what the server returned with the count', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Barbell Back Squat'), findsOneWidget);
    expect(find.text('Push-Up'), findsOneWidget);
    expect(find.text('2 exercises'), findsOneWidget);
    expect(find.text('Quads, Glutes · Squat · Barbell'), findsOneWidget);
  });

  testWidgets('tapping an equipment toggle asks the server, not the list',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(repo.queries.length, 1);

    await tester.tap(find.byKey(const ValueKey('equipment.Dumbbells')));
    await tester.pumpAndSettle();

    expect(repo.queries.length, 2);
    expect(repo.queries.last.equipment, {Equipment.dumbbell});
    // Still showing the server's answer — the fake returned both rows.
    expect(find.text('Barbell Back Squat'), findsOneWidget);
  });

  testWidgets('a muscle toggle is exclusive and taps off again',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('muscle.Chest')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.muscle, MuscleGroup.chest);

    await tester.tap(find.byKey(const ValueKey('muscle.Back')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.muscle, MuscleGroup.back);

    await tester.tap(find.byKey(const ValueKey('muscle.Back')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.muscle, isNull);
  });

  testWidgets('typing in search is debounced into one request', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('exercises.search')),
      'pu',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercises.search')),
      'push',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.queries.length, 1, reason: 'not yet — debounce pending');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repo.queries.length, 2);
    expect(repo.queries.last.q, 'push');
  });

  testWidgets('an empty answer offers to clear the filters', (tester) async {
    repo.nextList = (q) => Ok(
          ExerciseListResponse(
            items: q.hasFilters ? const [] : const [squat, pushUp],
            total: q.hasFilters ? 0 : 2,
            limit: 200,
            offset: 0,
          ),
        );
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pattern.Squat')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Back Squat'), findsOneWidget);
    expect(repo.queries.last.hasFilters, isFalse);
  });

  testWidgets('a failed load shows the message and Try again', (tester) async {
    repo.nextList = (_) => const Err(Offline());
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Could not load the library'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repo.nextList = (_) => const Ok(
          ExerciseListResponse(
            items: [pushUp],
            total: 1,
            limit: 200,
            offset: 0,
          ),
        );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Push-Up'), findsOneWidget);
  });

  testWidgets(
      'a row opens the detail: muscles, needs, steps, skip-if, alternatives',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('exercise.barbell-back-squat')));
    await tester.pumpAndSettle();

    expect(repo.detailIds, [squat.id]);
    expect(find.text('Barbell Back Squat'), findsOneWidget);
    expect(find.text('SQUAT · INTERMEDIATE'), findsOneWidget);
    expect(find.text('Quads, Glutes'), findsOneWidget);
    expect(find.text('Hamstrings'), findsOneWidget);
    expect(find.text('Barbell'), findsOneWidget);
    expect(
      find.text('5 kg when you clear the top of the rep range'),
      findsOneWidget,
    );
    // Contraindications in amber: the caution colour, the only colour here.
    final skip = find.text('knee, lower back is bothering you');
    expect(skip, findsOneWidget);
    expect(tester.widget<Text>(skip).style?.color, FitColors.amber);
    // Steps verbatim and numbered.
    expect(find.text('Set the bar across your upper back.'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // Alternatives with their reason and equipment.
    expect(find.text('Goblet Squat'), findsOneWidget);
    expect(find.text('Different equipment · Dumbbells'), findsOneWidget);
    expect(find.text('Easier on the joints · Machines'), findsOneWidget);
  });

  testWidgets('an alternative navigates to its own detail', (tester) async {
    await tester.pumpWidget(harness(initial: '/exercises/${squat.id}'));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const ValueKey('alternative.goblet-squat')));
    await tester.tap(find.byKey(const ValueKey('alternative.goblet-squat')));
    await tester.pumpAndSettle();

    expect(repo.detailIds, [squat.id, '33333333-3333-4333-8333-333333333333']);
  });
}
