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
              path: 'pick',
              builder: (_, __) => const ExerciseBrowserScreen(pickMode: true),
            ),
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
    // Compact rows: primary muscle · equipment. Everything else is detail.
    expect(find.text('Quads · Barbell'), findsOneWidget);
    expect(find.text('Quads, Glutes · Squat · Barbell'), findsNothing);
  });

  testWidgets('tapping an equipment toggle asks the server, not the list',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(repo.queries.length, 1);

    // Filters live behind a button each; the sheet toggles, Done closes.
    await tester.tap(find.byKey(const ValueKey('filter.equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment.Dumbbells')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filters.done')));
    await tester.pumpAndSettle();

    expect(repo.queries.length, 2);
    expect(repo.queries.last.equipment, {Equipment.dumbbell});
    // The button now says what is chosen.
    expect(find.text('Dumbbells'), findsOneWidget);
    // Still showing the server's answer — the fake returned both rows.
    expect(find.text('Barbell Back Squat'), findsOneWidget);
  });

  testWidgets('a muscle toggle is exclusive and taps off again',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('filter.muscle')));
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
    await tester.tap(find.byKey(const ValueKey('filters.done')));
    await tester.pumpAndSettle();
    expect(find.text('Muscle'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('filter.pattern')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pattern.Squat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filters.done')));
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

  group('the picker (owner review 2026-09-21)', () {
    const longName = ExerciseSummary(
      id: '44444444-4444-4444-8444-444444444444',
      slug: 'single-arm-chest-supported-incline-dumbbell-row-with-pause',
      name:
          'Single-Arm Chest-Supported Incline Dumbbell Row With A Two-Second Pause At The Top',
      movementPattern: MovementPattern.horizontalPull,
      equipment: [Equipment.dumbbell, Equipment.machine, Equipment.cable],
      difficulty: Difficulty.advanced,
      isUnilateral: true,
      primaryMuscles: [MuscleGroup.back, MuscleGroup.shoulders],
    );

    /// A small phone: 360 × 640 logical px.
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets(
        'compact rows: name, primary muscle · equipment, an arrow — nothing else; no overflow on a small phone with long names',
        (tester) async {
      await phone(tester);
      repo.nextList = (_) => const Ok(
            ExerciseListResponse(
              items: [longName, squat, pushUp],
              total: 3,
              limit: 200,
              offset: 0,
            ),
          );
      await tester.pumpWidget(harness(initial: '/exercises/pick'));
      await tester.pumpAndSettle();

      expect(find.text('ADD EXERCISE'), findsOneWidget);
      expect(find.text(longName.name), findsOneWidget);
      expect(find.text('Back · Dumbbells + Machines + Cables'), findsOneWidget);
      // Nothing the detail screen owns leaks into the list.
      expect(find.textContaining('Horizontal pull'), findsNothing);
      expect(find.textContaining('ADVANCED'), findsNothing);
      // No RenderFlex overflow anywhere, and every row is inside the screen.
      expect(tester.takeException(), isNull);
      final width = tester.view.physicalSize.width;
      for (final row in [longName, squat, pushUp]) {
        final rect =
            tester.getRect(find.byKey(ValueKey('exercise.${row.slug}')));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      // The filter buttons fit too.
      for (final k in ['filter.muscle', 'filter.equipment', 'filter.pattern']) {
        expect(
          tester.getRect(find.byKey(ValueKey(k))).height,
          greaterThanOrEqualTo(44),
        );
      }
    });

    testWidgets(
        'search and filters work in the picker, and picking returns the exercise',
        (tester) async {
      await phone(tester);
      ExerciseSummary? picked;
      final router = GoRouter(
        initialLocation: '/host',
        routes: [
          GoRoute(
            path: '/host',
            builder: (context, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey('host.pick'),
                  onPressed: () async {
                    picked =
                        await context.push<ExerciseSummary>('/exercises/pick');
                  },
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/exercises/pick',
            builder: (_, __) => const ExerciseBrowserScreen(pickMode: true),
          ),
          GoRoute(
            path: '/exercises/:id',
            builder: (_, s) =>
                Scaffold(body: Text('detail ${s.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [exerciseRepositoryProvider.overrideWithValue(repo)],
          child:
              MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('host.pick')));
      await tester.pumpAndSettle();

      // Search narrows via the server.
      await tester.enterText(
        find.byKey(const ValueKey('exercises.search')),
        'squat',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repo.queries.last.q, 'squat');
      // A filter sheet, then Done.
      await tester.tap(find.byKey(const ValueKey('filter.muscle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('muscle.Quads')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filters.done')));
      await tester.pumpAndSettle();
      expect(repo.queries.last.muscle, MuscleGroup.quads);
      expect(find.text('Quads'), findsWidgets);

      // The "i" opens the detail without picking.
      await tester
          .tap(find.byKey(const ValueKey('exercise.barbell-back-squat.info')));
      await tester.pumpAndSettle();
      expect(find.text('detail ${squat.id}'), findsOneWidget);
      expect(picked, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Tapping the row returns it to the caller.
      await tester
          .tap(find.byKey(const ValueKey('exercise.barbell-back-squat')));
      await tester.pumpAndSettle();
      expect(picked, squat);
      expect(find.byKey(const ValueKey('host.pick')), findsOneWidget);
    });
  });
}
