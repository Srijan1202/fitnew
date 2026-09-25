import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/nutrition/data/nutrition_log_repository.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_logger.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/today/domain/today.dart';
import 'package:fitos/features/today/presentation/today_providers.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercise_repository.dart';
import '../../support/fake_food_log_api.dart';
import '../../support/fake_health_provider.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_today_api.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 11 — TODAY on Home: the server's actions are the cards (at most
/// four with the device-only ones, by band), each says why, and the phone
/// records how the user responds — shown once, opened on a tap, accepted
/// on the primary button (then the existing flow), dismissed on "Not
/// today" (and gone for the day), completed only when the server holds the
/// evidence. Offline: the cached plan for today, labelled; never invented.
void main() {
  // The fake server's training day.
  const date = '2026-09-21';
  late AppDatabase db;
  late FakeWorkoutApi api;
  late FakeHealthProvider health;
  late FakeProfileRepository profile;
  late FakeFoodLogApi foodLog;
  late FakeTodayApi today;
  late FakeAuthRepository auth;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    health = FakeHealthProvider()
      ..connection_ = HealthConnectionState.disconnected;
    profile = FakeProfileRepository();
    foodLog = FakeFoodLogApi();
    today = FakeTodayApi(date: date);
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
  });
  tearDown(() => db.close());

  TodayPlan plan(List<TodayAction> actions) => TodayPlan(
        date: date,
        generatedAt: '${date}T06:30:00.000Z',
        engineVersion: 'today-1',
        actions: actions,
      );

  Widget page(String text) => Scaffold(body: Text(text));

  Widget app() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: Routes.plan, builder: (_, __) => page('PLAN')),
        GoRoute(path: Routes.history, builder: (_, __) => page('HISTORY')),
        GoRoute(
          path: '/plan/history/:id',
          builder: (_, s) => page('SUMMARY ${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/plan/session/:id',
          builder: (_, s) => page('SESSION ${s.pathParameters['id']}'),
        ),
        GoRoute(path: Routes.nutrition, builder: (_, __) => page('EAT')),
        GoRoute(path: Routes.mess, builder: (_, __) => page('MESS')),
        GoRoute(
          path: Routes.foodLog,
          builder: (_, s) {
            final t = s.extra! as LogTarget;
            return page('LOG ${t.date} ${t.slot.wire}');
          },
        ),
        GoRoute(
          path: Routes.personalDetails,
          builder: (_, __) => page('DETAILS'),
        ),
        GoRoute(path: Routes.healthData, builder: (_, __) => page('HEALTH')),
        GoRoute(path: Routes.volume, builder: (_, __) => page('VOLUME')),
        GoRoute(path: Routes.profile, builder: (_, __) => page('PROFILE')),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionUserIdProvider.overrideWithValue(testProfile.id),
        exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        profileRepositoryProvider.overrideWithValue(profile),
        trainingRepositoryProvider.overrideWithValue(FakeTrainingRepository()),
        localHourProvider.overrideWithValue(12),
        localTodayProvider.overrideWithValue(date),
        ...workoutOverrides(db, api, foodLog: foodLog, today: today),
        ...healthOverrides(health),
      ],
      // As FitOSApp does: the completion watcher lives at the root.
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(todayCompletionWatcherProvider);
          return MaterialApp.router(
            theme: FitTheme.build(),
            routerConfig: router,
          );
        },
      ),
    );
  }

  /// A widget test that, at its end, unmounts Home and lets Drift close the
  /// ledger's stream query (its close is a zero-length timer).
  void testToday(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen, skipOffstage: false)),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> refresh(WidgetTester tester) async {
    container(tester).invalidate(todayPlanProvider);
    await settle(tester);
  }

  Finder card(String kind) => find.byKey(ValueKey('home.suggestion.$kind'));
  Finder key(String k) => find.byKey(ValueKey(k));
  String textOf(WidgetTester tester, String k) =>
      tester.widget<Text>(key(k)).data!;

  final start = FakeTodayApi.action(
    TodayKind.startWorkout,
    id: 'a-start',
    headline: 'Legs is ready',
    detail: '2 movements · about 18 min.',
    reason: const TodayReason(
      'session-scheduled',
      {'sessionName': 'Legs', 'exerciseCount': 2, 'minutes': 18},
    ),
  );
  final eat = FakeTodayApi.action(
    TodayKind.eatProtein,
    id: 'a-eat',
    subjectKey: 'lunch',
    rank: 2,
    target: ActionTarget.eat,
    headline: '98–106 g protein to go',
    detail:
        'Protein logged today is under three quarters of your 106 g target.',
    reason: const TodayReason('protein-behind', {
      'slot': 'lunch',
      'proteinTarget': 106,
      'proteinLow': 0,
      'proteinHigh': 8,
      'kcalLeftLow': 2100,
      'kcalLeftHigh': 2276,
    }),
  );
  final progress = FakeTodayApi.action(
    TodayKind.progressLoad,
    id: 'a-progress',
    subjectKey: 'ex-squat',
    rank: 3,
  );
  final neglect = FakeTodayApi.action(
    TodayKind.muscleNeglected,
    id: 'a-neglect',
    subjectKey: 'calves',
    rank: 4,
    basis: ActionBasis.logged,
  );
  final weight = FakeTodayApi.action(
    TodayKind.logWeight,
    id: 'a-weight',
    rank: 5,
    target: ActionTarget.progress,
    reason: const TodayReason('weigh-in-due', {'daysSinceWeighIn': 3}),
  );

  testToday(
      'first day, nothing on file: no server cards and no invented ones — the section is left out',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('home.carousel'), findsNothing);
    expect(find.text('Your next move'), findsNothing);
    expect(today.todayCalls, greaterThan(0));
  });

  testToday(
      'server actions are the cards: headline, detail, eyebrow; at most four; in the server rank order',
      (tester) async {
    today.plan = plan([weight, neglect, progress, eat, start]);
    await tester.pumpWidget(app());
    await settle(tester);
    final moves = container(tester).read(homeNextMovesProvider);
    expect(
      moves.map((s) => s.id),
      ['start-workout', 'eat-protein', 'progress-load', 'muscle-neglected'],
    );
    expect(
      textOf(tester, 'home.suggestion.start-workout.title'),
      'Legs is ready',
    );
    expect(
      textOf(tester, 'home.suggestion.start-workout.subtitle'),
      '2 movements · about 18 min.',
    );
    expect(textOf(tester, 'home.suggestion.start-workout.eyebrow'), 'TRAIN');
    expect(key('home.dot.3'), findsOneWidget);
    expect(key('home.dot.4'), findsNothing);
    // The forbidden device cards are gone (P6); so is "More for you".
    expect(find.text('More for you'), findsNothing);
    expect(card('done'), findsNothing);
    expect(card('volume'), findsNothing);
  });

  testToday(
      'the current rank orders the cards: a re-ranked plan reorders them, same ids, no new rows',
      (tester) async {
    today.plan = plan([start, eat]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      container(tester).read(homeNextMovesProvider).map((s) => s.today!.id),
      ['a-start', 'a-eat'],
    );
    // A deload now outranks both; the start card keeps its id at rank 2.
    final deload = FakeTodayApi.action(TodayKind.deload, id: 'a-deload');
    today.plan = plan([
      deload,
      FakeTodayApi.action(
        TodayKind.startWorkout,
        id: 'a-start',
        rank: 2,
        headline: 'Legs is ready',
      ),
      FakeTodayApi.action(
        TodayKind.eatProtein,
        id: 'a-eat',
        subjectKey: 'lunch',
        rank: 3,
      ),
    ]);
    await refresh(tester);
    expect(
      container(tester).read(homeNextMovesProvider).map((s) => s.today!.id),
      ['a-deload', 'a-start', 'a-eat'],
    );
  });

  testToday(
      'shown goes once for the card on screen — not on every rebuild or refetch; a card paged to is shown then',
      (tester) async {
    today.plan = plan([start, eat]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(today.sent, ['a-start:shown']);
    await refresh(tester);
    await tester.pump();
    await settle(tester);
    expect(today.sent, ['a-start:shown']);
    await tester.fling(key('home.carousel'), const Offset(-600, 0), 1500);
    await settle(tester);
    expect(today.sent, ['a-start:shown', 'a-eat:shown']);
  });

  testToday(
      'tapping a card is "opened": the why sheet has the words, the reason facts and the basis; its button is "accepted" and starts the flow',
      (tester) async {
    today.plan = plan([eat]);
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(key('home.suggestion.eat-protein.open'));
    await settle(tester);
    expect(key('today.why'), findsOneWidget);
    expect(textOf(tester, 'today.why.headline'), '98–106 g protein to go');
    expect(textOf(tester, 'today.why.fact.Meal'), 'Lunch');
    expect(textOf(tester, 'today.why.fact.Protein so far'), '0–8 of 106 g');
    expect(textOf(tester, 'today.why.fact.Left today'), '2100–2276 kcal');
    expect(
      textOf(tester, 'today.why.basis'),
      'Why this was suggested: calculated from your plan and logs.',
    );
    expect(today.sent, ['a-eat:shown', 'a-eat:opened']);
    await tester.tap(key('today.why.primary'));
    await settle(tester);
    // No mess configured: the log flow for the action's meal and day.
    expect(find.text('LOG $date lunch'), findsOneWidget);
    expect(today.sent, ['a-eat:shown', 'a-eat:opened', 'a-eat:accepted']);
  });

  for (final (label, kind, destination) in [
    ('start-workout', TodayKind.startWorkout, 'SESSION'),
    ('rest-day', TodayKind.restDay, 'PLAN'),
    ('deload', TodayKind.deload, 'PLAN'),
    ('injured-limitation', TodayKind.injuredLimitation, 'PLAN'),
    ('progress-load', TodayKind.progressLoad, 'PLAN'),
    ('muscle-neglected', TodayKind.muscleNeglected, 'PLAN'),
    ('log-weight', TodayKind.logWeight, 'DETAILS'),
    ('celebrate-pr', TodayKind.celebratePr, 'HISTORY'),
  ]) {
    testToday(
        'the primary button on $label is "accepted" and opens the existing flow',
        (tester) async {
      today.plan = plan([FakeTodayApi.action(kind, id: 'a-1')]);
      await tester.pumpWidget(app());
      await settle(tester);
      await tester.tap(key('home.suggestion.$label.action'));
      await settle(tester);
      expect(find.textContaining(destination), findsOneWidget);
      expect(today.sent, ['a-1:shown', 'a-1:accepted']);
    });
  }

  testToday(
      'Phase 12 calorie-adjust: the card says the change; accepting sends it now and opens EAT; completed once the server holds the new target',
      (tester) async {
    final adjust = FakeTodayApi.action(
      TodayKind.calorieAdjust,
      id: 'a-adjust',
      target: ActionTarget.eat,
      headline: 'Move your target to 2146 kcal',
      detail:
          'Your trend weight is rising about 0.70 kg a week, off pace for your goal.',
      reason: const TodayReason('calorie-target-off-trend', {
        'currentKcal': 2276,
        'newKcal': 2146,
        'deltaKcal': -130,
        'weeklyChangeKg': 0.7,
      }),
    );
    today.plan = plan([adjust]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      textOf(tester, 'home.suggestion.calorie-adjust.eyebrow'),
      'EAT · TARGET',
    );
    expect(find.text('Use 2146 kcal'), findsOneWidget);
    await tester.tap(key('home.suggestion.calorie-adjust.open'));
    await settle(tester);
    expect(textOf(tester, 'today.why.fact.Current target'), '2276 kcal');
    expect(textOf(tester, 'today.why.fact.Suggested'), '2146 kcal');
    expect(textOf(tester, 'today.why.fact.Trend'), '+0.70 kg a week');
    // The server applies it when the accepted event arrives: a new target row.
    profile.nextGoal = Ok(
      GoalResponse(
        goal: (profile.nextGoal as Ok<GoalResponse>).value.goal,
        targets: (profile.nextGoal as Ok<GoalResponse>).value.targets!.copyWith(
              kcal: 2146,
              reason: 'calorie-adjust',
              effectiveFrom: date,
            ),
      ),
    );
    await tester.tap(key('today.why.primary'));
    await settle(tester);
    expect(find.text('EAT'), findsOneWidget);
    expect(
      today.sent,
      containsAllInOrder(
        ['a-adjust:shown', 'a-adjust:opened', 'a-adjust:accepted'],
      ),
    );
    expect(today.sent.where((e) => e == 'a-adjust:completed'), hasLength(1));
  });

  testToday('with a mess configured, an eat action opens MESS', (tester) async {
    profile.nextProfile = Ok(
      (profile.nextProfile as Ok<UserProfileDetail>).value.copyWith(
            mess: const MessRef(
              providerId: 'vit-vellore',
              hostelId: 'mens',
              messId: 'veg',
            ),
          ),
    );
    today.plan = plan([eat]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('What to eat'), findsOneWidget);
    await tester.tap(key('home.suggestion.eat-protein.action'));
    await settle(tester);
    expect(find.text('MESS'), findsOneWidget);
  });

  testToday(
      '"Not today" is dismissed: the card goes at once and stays gone for the day, even if a stale answer still carries it',
      (tester) async {
    today.plan = plan([start, weight]);
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.fling(key('home.carousel'), const Offset(-600, 0), 1500);
    await settle(tester);
    await tester.tap(key('home.suggestion.log-weight.dismiss'));
    await settle(tester);
    expect(card('log-weight'), findsNothing);
    expect(today.sent, contains('a-weight:dismissed'));
    await refresh(tester);
    expect(card('log-weight'), findsNothing);
    // Once accepted, "Not today" is no longer offered.
    await tester.tap(key('home.suggestion.start-workout.action'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(key('home.suggestion.start-workout.dismiss'), findsNothing);
  });

  testToday(
      'completed: never on accept alone; sent once the server day has a log in that meal',
      (tester) async {
    today.plan = plan([eat]);
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(key('home.suggestion.eat-protein.action'));
    await settle(tester);
    expect(today.sent, isNot(contains('a-eat:completed')));

    // The user logs lunch (the EAT flow's own queue); once the server
    // confirms it, the server's day is on the phone — that is the evidence.
    final c = container(tester);
    final food = c.read(nutritionLogRepositoryProvider);
    await food.log(
      const CreateLogRequest.quickAdd(
        clientLogId: '11111111-1111-4111-8111-111111111111',
        loggedAt: '${date}T07:30:00.000Z',
        mealSlot: MealSlot.lunch,
        quickAdd: QuickAdd(kcal: 500, proteinG: 30, carbG: 50, fatG: 15),
      ),
      localDate: date,
      preview: const PendingPreview(items: []),
    );
    food.sync();
    await settle(tester);
    expect(today.sent.where((e) => e == 'a-eat:completed'), hasLength(1));
    // Not twice.
    food.sync();
    await settle(tester);
    expect(today.sent.where((e) => e == 'a-eat:completed'), hasLength(1));
  });

  testToday(
      'a log in the meal without accept is not a completion; informational actions are never completed',
      (tester) async {
    today.plan =
        plan([eat, FakeTodayApi.action(TodayKind.restDay, id: 'a-rest')]);
    foodLog.logs['11111111-1111-4111-8111-111111111111'] = FoodLog(
      id: 'server-1',
      clientLogId: '11111111-1111-4111-8111-111111111111',
      loggedAt: '${date}T07:30:00.000Z',
      localDate: date,
      mealSlot: MealSlot.lunch,
      entryMethod: EntryMethod.quickAdd,
      savedMealId: null,
      items: const [],
      totals: FakeFoodLogApi.totalsOf(const []),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    expect(today.sent, isNot(contains('a-eat:completed')));
    await tester.fling(key('home.carousel'), const Offset(-600, 0), 1500);
    await settle(tester);
    await tester.tap(key('home.suggestion.rest-day.action'));
    await settle(tester);
    expect(today.sent, contains('a-rest:accepted'));
    expect(today.sent, isNot(contains('a-rest:completed')));
  });

  testToday(
      'offline with today\'s plan cached: shown labelled, actions still work and queue; nothing reaches the server until it answers',
      (tester) async {
    today.plan = plan([start, weight]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('home.today.cached'), findsNothing);

    today
      ..todayFailure = const Offline()
      ..eventFailure = const Offline()
      ..events.clear();
    await refresh(tester);
    expect(key('home.today.cached'), findsOneWidget);
    expect(
      textOf(tester, 'home.suggestion.start-workout.eyebrow'),
      'TRAIN · OFFLINE',
    );
    await tester.tap(key('home.suggestion.start-workout.open'));
    await settle(tester);
    await tester.tap(key('today.why.dismiss'));
    await settle(tester);
    expect(card('start-workout'), findsNothing);
    final queued = await db.select(db.todayEventQueue).get();
    expect(queued.map((q) => q.event), containsAll(['opened', 'dismissed']));
    expect(queued.every((q) => q.attempts == 0), isTrue);

    // Back online: the queue drains with the same client ids.
    today
      ..todayFailure = null
      ..eventFailure = null;
    await container(tester).read(todayRepositoryProvider).drain();
    await settle(tester);
    expect(
      today.events.map((e) => e.request.clientEventId).toSet(),
      queued.map((q) => q.clientEventId).toSet(),
    );
    expect(await db.select(db.todayEventQueue).get(), isEmpty);
  });

  testToday(
      'offline with no plan for today: no server card, an honest line; device-only suggestions remain',
      (tester) async {
    today.todayFailure = const Offline();
    health
      ..connection_ = const HealthConnectionState(
        sdk: HealthSdkStatus.available,
        granted: {HealthMetricKind.sleep},
      )
      ..snapshot_ = HealthSnapshot.empty(
        date: '2026-09-22',
        timezone: 'Asia/Kolkata',
        availability: HealthAvailability.noData,
        fetchedAt: FakeHealthProvider.fetchedAt,
      ).copyWith(
        sleep: metricOf(HealthMetricKind.sleep, 300, unit: 'min'),
      );
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      textOf(tester, 'home.today.unavailable'),
      'Suggestions need a connection.',
    );
    expect(card('recover'), findsOneWidget);
    expect(card('start-workout'), findsNothing);
  });

  testToday('a cached plan from an earlier day is never shown as today\'s',
      (tester) async {
    today.plan = TodayPlan(
      date: '2026-09-20',
      generatedAt: '2026-09-20T06:30:00.000Z',
      engineVersion: 'today-1',
      actions: [start],
    );
    await tester.pumpWidget(app());
    await settle(tester);
    today.todayFailure = const Offline();
    await refresh(tester);
    expect(card('start-workout'), findsNothing);
    expect(key('home.today.unavailable'), findsOneWidget);
  });

  testToday('server and device cards merge by band', (tester) async {
    health
      ..connection_ = const HealthConnectionState(
        sdk: HealthSdkStatus.available,
        granted: {HealthMetricKind.sleep},
      )
      ..snapshot_ = HealthSnapshot.empty(
        date: '2026-09-22',
        timezone: 'Asia/Kolkata',
        availability: HealthAvailability.noData,
        fetchedAt: FakeHealthProvider.fetchedAt,
      ).copyWith(
        sleep: metricOf(HealthMetricKind.sleep, 300, unit: 'min'),
      );
    today.plan = plan([start, neglect.copyWithRank(2), weight.copyWithRank(3)]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      container(tester).read(homeNextMovesProvider).map((s) => s.id),
      ['start-workout', 'muscle-neglected', 'recover', 'log-weight'],
    );
  });

  for (final (name, size, textScale) in [
    ('360x640', const Size(360, 640), 1.0),
    ('360x640 at 200 % text', const Size(360, 640), 2.0),
    ('S24 (412x915)', const Size(412, 915), 1.0),
    ('S24 at 200 % text', const Size(412, 915), 2.0),
  ]) {
    testToday('layout: $name — no overflow, both choices reachable',
        (tester) async {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      today.plan = plan([eat, start]);
      await tester.pumpWidget(app());
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('home.suggestion.start-workout.action'), findsOneWidget);
      expect(key('home.suggestion.start-workout.dismiss'), findsOneWidget);
      await tester.ensureVisible(key('home.suggestion.start-workout.dismiss'));
      await settle(tester);
      await tester.tap(key('home.suggestion.start-workout.dismiss'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(card('start-workout'), findsNothing);
    });
  }
}

extension on TodayAction {
  TodayAction copyWithRank(int rank) => TodayAction(
        id: id,
        kindWire: kindWire,
        subjectKey: subjectKey,
        rank: rank,
        priority: priority,
        basis: basis,
        target: target,
        reason: reason,
        headline: headline,
        detail: detail,
      );
}
