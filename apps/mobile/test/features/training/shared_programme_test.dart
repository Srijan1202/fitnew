import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/training/data/shared_programme_api.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/plan_start_screen.dart';
import 'package:fitos/features/training/presentation/screens/shared_programme_screen.dart';
import 'package:fitos/features/training/presentation/screens/workout_week_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Beta 3.3 (ADR-034): share your programme as a code; use someone else's.
class FakeSharedApi implements SharedProgrammeApi {
  final previews = <String>[];
  final used = <String>[];
  int shares = 0;
  SharedProgramme? programme;
  Program? copy;

  @override
  Future<Result<MyShare>> share() async {
    shares++;
    return const Ok(
      MyShare(
        code: 'K7Q2XM',
        name: 'Push Pull',
        url: 'https://tryfitos.me/p/K7Q2XM',
      ),
    );
  }

  @override
  Future<Result<SharedProgramme>> preview(String code) async {
    previews.add(code);
    final p = programme;
    return p == null ? const Err(NotFound()) : Ok(p);
  }

  @override
  Future<Result<Program>> use(String code) async {
    used.add(code);
    return Ok(copy!);
  }
}

class RecordingSharer implements TextSharer {
  final sent = <String>[];

  @override
  Future<void> share(String text) async => sent.add(text);
}

const _pushPull = SharedProgramme(
  code: 'K7Q2XM',
  name: 'Push Pull',
  daysPerWeek: 2,
  days: [
    SharedDay(
      dayOfWeek: 1,
      sessionName: 'Push',
      isRest: false,
      exercises: [
        SharedExercise(
          name: 'Barbell Bench Press',
          setCount: 3,
          repMin: 6,
          repMax: 8,
          missingEquipment: ['barbell'],
        ),
      ],
    ),
    SharedDay(dayOfWeek: 2, sessionName: 'Rest', isRest: true, exercises: []),
    SharedDay(
      dayOfWeek: 4,
      sessionName: 'Pull',
      isRest: false,
      exercises: [
        SharedExercise(
          name: 'Lat Pulldown',
          setCount: 3,
          repMin: 10,
          repMax: 10,
          missingEquipment: [],
        ),
      ],
    ),
  ],
);

void main() {
  group('parseShareCode', () {
    test('a code typed any way, or the whole link; nothing else', () {
      expect(parseShareCode('FIT-K7Q2XM'), 'K7Q2XM');
      expect(parseShareCode(' fit-k7q2xm '), 'K7Q2XM');
      expect(parseShareCode('k7q2xm'), 'K7Q2XM');
      expect(parseShareCode('https://tryfitos.me/p/K7Q2XM'), 'K7Q2XM');
      expect(
        parseShareCode(
          'Try my programme: code FIT-K7Q2XM · tryfitos.me/p/K7Q2XM',
        ),
        'K7Q2XM',
      );
      expect(parseShareCode('FIT-K7Q2X'), isNull);
      expect(parseShareCode('O0I1L5'), isNull);
      expect(parseShareCode(''), isNull);
    });

    test('the message names the code and the link', () {
      const s = MyShare(
        code: 'K7Q2XM',
        name: 'Push Pull',
        url: 'https://tryfitos.me/p/K7Q2XM',
      );
      expect(
        s.message,
        'Try my FITOS programme "Push Pull": code FIT-K7Q2XM · https://tryfitos.me/p/K7Q2XM',
      );
      expect(_pushPull.days.first.exercises.first.prescription, '3 × 6–8');
      expect(_pushPull.days.last.exercises.first.prescription, '3 × 10');
    });
  });

  group('screens', () {
    late FakeTrainingRepository training;
    late AppDatabase db;
    late FakeSharedApi shared;
    late RecordingSharer sharer;
    late FakeMetaApi meta;

    setUp(() {
      training = FakeTrainingRepository();
      db = AppDatabase.inMemory();
      shared = FakeSharedApi();
      sharer = RecordingSharer();
      meta = FakeMetaApi();
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
              ),
              GoRoute(
                path: 'shared',
                builder: (_, __) => const SharedProgrammeScreen(),
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
          exerciseRepositoryProvider
              .overrideWithValue(FakeExerciseRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          sharedProgrammeApiProvider.overrideWithValue(shared),
          textSharerProvider.overrideWithValue(sharer),
          ...workoutOverrides(db, FakeWorkoutApi(), meta: meta),
        ],
        child:
            MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
      );
    }

    testWidgets('Share programme: a code, sent through the share sheet',
        (tester) async {
      training.stored = generatedProgram;
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan.share')));
      await tester.pumpAndSettle();
      expect(shared.shares, 1);
      expect(find.text('FIT-K7Q2XM'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share.send')));
      await tester.pumpAndSettle();
      expect(sharer.sent.single, contains('FIT-K7Q2XM'));
    });

    testWidgets(
        'Use a shared programme: a code shows the programme and what you lack; used after confirming, back on Training',
        (tester) async {
      training.stored = generatedProgram;
      shared
        ..programme = _pushPull
        ..copy = generatedProgram;
      await tester.pumpWidget(harness(initial: '/plan/shared'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('shared.code')),
        'nonsense',
      );
      await tester.tap(find.byKey(const ValueKey('shared.look')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shared.error')), findsOneWidget);
      expect(shared.previews, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('shared.code')),
        'fit-k7q2xm',
      );
      await tester.tap(find.byKey(const ValueKey('shared.look')));
      await tester.pumpAndSettle();
      expect(shared.previews, ['K7Q2XM']);
      expect(find.text('Push Pull'), findsOneWidget);
      expect(find.text('Needs barbell'), findsOneWidget);
      expect(find.text('3 × 6–8'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('shared.use')));
      await tester.tap(find.byKey(const ValueKey('shared.use')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('replaces your current programme'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shared.confirm.use')));
      await tester.pumpAndSettle();
      expect(shared.used, ['K7Q2XM']);
      expect(find.byType(WorkoutWeekScreen), findsOneWidget);
    });

    testWidgets('a stopped or unknown code says so', (tester) async {
      await tester.pumpWidget(harness(initial: '/plan/shared'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('shared.code')),
        'K7Q2XM',
      );
      await tester.tap(find.byKey(const ValueKey('shared.look')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No programme is shared with that code'),
        findsOneWidget,
      );
    });

    testWidgets('switched off by the admin: no Share or Use entries anywhere',
        (tester) async {
      training.stored = generatedProgram;
      meta.flags = {'share-programme': false};
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan.menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan.share')), findsNothing);
      expect(find.byKey(const ValueKey('plan.useShared')), findsNothing);
      await tester.tap(find.text('Change programme'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('start.custom')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('start.shared')), findsNothing);
    });

    testWidgets('a new user can start from a shared programme', (tester) async {
      await tester.pumpWidget(harness(initial: '/plan/new'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('start.shared')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('start.shared')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start.shared')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedProgrammeScreen), findsOneWidget);
    });
  });
}
