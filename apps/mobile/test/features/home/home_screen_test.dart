import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/presentation/screens/health_data_screen.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/home/presentation/widgets/name_prompt.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercise_repository.dart';
import '../../support/fake_food_log_api.dart';
import '../../support/fake_health_provider.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 6.5 — the Home screen (Part J): every health state renders
/// honestly (no Health Connect, not connected, partial, all), food says
/// "Not logged yet", sleep and body say why when missing, the carousel
/// follows the session (ready → in progress → done), and the Health Data
/// screen shows grants per category.
void main() {
  late AppDatabase db;
  late FakeWorkoutApi api;
  late FakeHealthProvider health;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeFoodLogApi foodLog;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    health = FakeHealthProvider();
    profile = FakeProfileRepository();
    foodLog = FakeFoodLogApi();
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
  });
  tearDown(() => db.close());

  Widget app({String initial = '/'}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: Routes.healthData,
          builder: (_, __) => const HealthDataScreen(),
        ),
        GoRoute(
          path: Routes.plan,
          builder: (_, __) => const Scaffold(body: Text('PLAN')),
        ),
        GoRoute(
          path: Routes.nutrition,
          builder: (_, __) => const Scaffold(body: Text('EAT')),
        ),
        GoRoute(
          path: Routes.volume,
          builder: (_, __) => const Scaffold(body: Text('VOLUME')),
        ),
        GoRoute(
          path: Routes.profile,
          builder: (_, __) => const Scaffold(body: Text('PROFILE')),
        ),
        GoRoute(
          path: '/plan/session/:id',
          builder: (_, s) =>
              Scaffold(body: Text('SESSION ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/plan/history/:id',
          builder: (_, s) =>
              Scaffold(body: Text('SUMMARY ${s.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionUserIdProvider.overrideWithValue(testProfile.id),
        exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        profileRepositoryProvider.overrideWithValue(profile),
        trainingRepositoryProvider.overrideWithValue(FakeTrainingRepository()),
        // Pinned: the engine rightly stops "eat protein" from 22:00, so a real
        // clock made J16 fail between 22:00 and midnight (found 2026-09-24).
        localHourProvider.overrideWithValue(12),
        ...workoutOverrides(db, api, foodLog: foodLog),
        ...healthOverrides(health),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Text textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key)));

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  const available = HealthConnectionState(
    sdk: HealthSdkStatus.available,
    granted: {},
  );

  HealthSnapshot snapshot(
    Set<HealthMetricKind> granted, {
    double? steps,
    double? active,
    double? total,
    double? sleep,
    double? rhr,
    double? weight,
    double? bodyFat,
    double? bmr,
  }) {
    final base = HealthSnapshot.empty(
      date: '2026-09-22',
      timezone: 'Asia/Kolkata',
      availability: HealthAvailability.permissionDenied,
      fetchedAt: FakeHealthProvider.fetchedAt,
    );
    HealthMetric m(HealthMetricKind k, double? v, String unit, {String? at}) {
      if (!granted.contains(k)) return base.metric(k);
      if (v == null) {
        return HealthMetric.unavailable(
          k,
          HealthAvailability.noData,
          unit: unit,
        );
      }
      return metricOf(k, v, unit: unit, at: at);
    }

    return base.copyWith(
      steps: m(HealthMetricKind.steps, steps, 'steps'),
      activeCalories: m(HealthMetricKind.activeCalories, active, 'kcal'),
      totalCalories: m(HealthMetricKind.totalCalories, total, 'kcal'),
      sleep: m(HealthMetricKind.sleep, sleep, 'min'),
      restingHeartRate: m(
        HealthMetricKind.restingHeartRate,
        rhr,
        'bpm',
        at: '2026-09-22T01:00:00.000Z',
      ),
      weight: m(
        HealthMetricKind.weight,
        weight,
        'kg',
        at: '2026-09-18T01:00:00.000Z',
      ),
      bodyFat: m(
        HealthMetricKind.bodyFat,
        bodyFat,
        '%',
        at: '2026-09-18T01:00:00.000Z',
      ),
      bmr: m(
        HealthMetricKind.bmr,
        bmr,
        'kcal/day',
        at: '2026-09-18T01:00:00.000Z',
      ),
      weekSteps: granted.contains(HealthMetricKind.steps)
          ? [9000, 2000, steps, null, null, null, null]
          : const [],
      weekSleep: granted.contains(HealthMetricKind.sleep)
          ? [400, 380, sleep, null, null, null, null]
          : const [],
    );
  }

  testWidgets(
      'server unreachable with nothing cached: Home says so in one line with Retry; health still shows; Retry refetches',
      (tester) async {
    api.offline = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.serverNotice')), findsOneWidget);
    expect(find.text("Can't reach FITOS"), findsOneWidget);
    expect(find.textContaining('You appear to be offline.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home.skeleton')), findsNothing);
    // Health data is the phone's; it is unaffected.
    expect(find.byKey(const ValueKey('home.steps')), findsOneWidget);

    api.offline = false;
    await tester.tap(find.byKey(const ValueKey('home.serverNotice.retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.serverNotice')), findsNothing);
    expect(textOf(tester, 'home.workout').data, 'Legs');
  });

  testWidgets(
      'no Health Connect on the phone: Home loads, every health block says so, no connect suggestion',
      (tester) async {
    health.connection_ = HealthConnectionState.disconnected;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.date')), findsOneWidget);
    expect(textOf(tester, 'home.steps').data, 'Not on this phone');
    expect(textOf(tester, 'home.activeCalories').data, 'Not on this phone');
    expect(
      textOf(tester, 'home.recovery.empty').data,
      startsWith('Recovery metrics need Health Connect'),
    );
    expect(find.byKey(const ValueKey('home.recovery.connect')), findsNothing);
    expect(find.byKey(const ValueKey('home.weight')), findsNothing);
    expect(
      find.byKey(const ValueKey('home.more.connect-health')),
      findsNothing,
    );
    // The workout is still there: Legs, ready.
    expect(textOf(tester, 'home.workout').data, 'Legs');
    expect(find.byKey(const ValueKey('home.suggestion.start')), findsOneWidget);
    expect(find.text('Training volume →'), findsOneWidget);
  });

  testWidgets(
      'not connected: "Connect Health data" in the blocks, in recovery, and in More for you → opens Health Data',
      (tester) async {
    health.connection_ = available;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.steps').data, 'Connect Health data');
    expect(
      textOf(tester, 'home.recovery.empty').data,
      'Connect Health data to see recovery metrics.',
    );
    await reveal(
      tester,
      find.byKey(const ValueKey('home.more.connect-health')),
    );
    await tester.tap(find.byKey(const ValueKey('home.more.connect-health')));
    await tester.pumpAndSettle();
    expect(find.byType(HealthDataScreen), findsOneWidget);
    expect(textOf(tester, 'health.status').data, 'Not connected');
    expect(textOf(tester, 'health.activity.grant').data, 'Not allowed');
    // Connect grants what the (fake) sheet allows: steps and sleep.
    health.grantOnRequest = {HealthMetricKind.steps, HealthMetricKind.sleep};
    await reveal(tester, find.byKey(const ValueKey('health.connect')));
    await tester.tap(find.byKey(const ValueKey('health.connect')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'health.status').data, 'Connected');
    expect(textOf(tester, 'health.activity.grant').data, 'Partly allowed');
    expect(textOf(tester, 'health.recovery.grant').data, 'Partly allowed');
    expect(textOf(tester, 'health.body.grant').data, 'Not allowed');
    expect(health.calls, contains(startsWith('request:')));
  });

  testWidgets(
      'only steps granted: steps show with the goal; the rest of activity and recovery say "Not allowed"; no body',
      (tester) async {
    health.connection_ = const HealthConnectionState(
      sdk: HealthSdkStatus.available,
      granted: {HealthMetricKind.steps},
    );
    health.snapshot_ = snapshot({HealthMetricKind.steps}, steps: 6842);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.steps').data, '6,842');
    expect(find.text('86% of 8,000'), findsOneWidget);
    expect(textOf(tester, 'home.activeCalories').data, 'Not allowed');
    expect(
      textOf(tester, 'home.recovery.empty').data,
      startsWith('Allow sleep and heart-rate data'),
    );
    expect(find.byKey(const ValueKey('home.weight')), findsNothing);
    // This week: movement counts the days at or above the goal (one so far).
    await reveal(tester, find.byKey(const ValueKey('home.week.movement')));
    expect(textOf(tester, 'home.week.movement').data, '1 / 7');
    expect(find.byKey(const ValueKey('home.week.sleep')), findsNothing);
  });

  testWidgets(
      'all permissions with data: activity, recovery, body with freshness, this week',
      (tester) async {
    health.connection_ = HealthConnectionState(
      sdk: HealthSdkStatus.available,
      granted: HealthMetricKind.values.toSet(),
    );
    health.snapshot_ = snapshot(
      HealthMetricKind.values.toSet(),
      steps: 6842,
      active: 482,
      total: 2010,
      sleep: 345,
      rhr: 62,
      weight: 60.5,
      bodyFat: 17.5,
      bmr: 1480,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.activeCalories').data, '482 kcal');
    expect(find.text('2,010 kcal in total'), findsOneWidget);
    expect(textOf(tester, 'home.sleep').data, '5h 45m');
    expect(textOf(tester, 'home.rhr').data, '62 bpm');
    await reveal(tester, find.byKey(const ValueKey('home.weight')));
    expect(textOf(tester, 'home.weight').data, '60.5 kg');
    expect(find.text('Last recorded 18 Sep'), findsWidgets);
    expect(textOf(tester, 'home.bodyFat').data, '17.5%');
    expect(textOf(tester, 'home.bmr').data, '1,480 kcal/day');
    await reveal(tester, find.byKey(const ValueKey('home.week.sleep')));
    expect(textOf(tester, 'home.week.sleep').data, '3 / 7');
    // Short sleep → the recovery card is in the carousel.
    await reveal(tester, find.byKey(const ValueKey('home.carousel')));
    expect(find.byKey(const ValueKey('home.suggestion.recover')), findsWidgets);
    await reveal(tester, find.byKey(const ValueKey('home.footer')));
    expect(textOf(tester, 'home.footer').data, contains('stays on this phone'));
  });

  testWidgets(
      'no nutrition data: Food says "Not logged yet" with the target, never 0 kcal',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.food').data, 'Not logged yet');
    expect(find.text('Target 2,276 kcal · 106 g protein'), findsOneWidget);
    expect(find.textContaining('0 kcal'), findsNothing);
    expect(
      find.byKey(const ValueKey('home.suggestion.eat-protein')),
      findsNothing,
    );
  });

  testWidgets(
      'sleep granted but no data: "No data yet", no recovery suggestion',
      (tester) async {
    health.connection_ = const HealthConnectionState(
      sdk: HealthSdkStatus.available,
      granted: {HealthMetricKind.sleep, HealthMetricKind.restingHeartRate},
    );
    health.snapshot_ =
        snapshot({HealthMetricKind.sleep, HealthMetricKind.restingHeartRate});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.sleep').data, 'No data yet');
    expect(textOf(tester, 'home.rhr').data, 'No data yet');
    expect(find.byKey(const ValueKey('home.suggestion.recover')), findsNothing);
  });

  testWidgets(
      'starting a workout moves the carousel to "in progress"; the Workout block follows',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.suggestion.start.title').data, 'Legs is ready');
    expect(
      textOf(tester, 'home.suggestion.start.subtitle').data,
      '2 movements · ~18 min',
    );
    await tester
        .tap(find.byKey(const ValueKey('home.suggestion.start.action')));
    await tester.pumpAndSettle();
    expect(find.textContaining('SESSION '), findsOneWidget);
    // Back on Home: the phone's active session drives the card.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'home.suggestion.resume.title').data,
      'Legs is in progress',
    );
    expect(textOf(tester, 'home.workout').data, 'Legs');
    expect(find.text('In progress · 0 sets'), findsOneWidget);
    expect(find.byKey(const ValueKey('home.suggestion.start')), findsNothing);
  });

  testWidgets(
      'a completed workout: the "done" card with the summary, the Workout block says Completed',
      (tester) async {
    api.todayResponse = api.todayResponse
        .copyWith(completedSessionId: '00000000-0000-4000-8000-000000000042');
    api.sessions['done'] = WorkoutSession(
      id: '00000000-0000-4000-8000-000000000042',
      clientSessionId: 'done',
      status: SessionStatus.completed,
      programId: api.todayResponse.programId,
      programDayId: api.todayResponse.programDayId,
      name: 'Legs',
      startedAt: '2026-09-22T04:00:00.000Z',
      completedAt: '2026-09-22T04:50:00.000Z',
      durationSeconds: 3000,
      notes: null,
      exercises: const [],
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
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.suggestion.done.title').data, 'Legs done');
    expect(
      textOf(tester, 'home.suggestion.done.subtitle').data,
      '5 sets · 1800 kg moved',
    );
    expect(find.text('Completed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home.suggestion.done.action')));
    await tester.pumpAndSettle();
    expect(
      find.text('SUMMARY 00000000-0000-4000-8000-000000000042'),
      findsOneWidget,
    );
  });

  testWidgets(
      'the carousel shows one dot per card and the header greets by the hour',
      (tester) async {
    health.connection_ = const HealthConnectionState(
      sdk: HealthSdkStatus.available,
      granted: {HealthMetricKind.sleep},
    );
    health.snapshot_ = snapshot({HealthMetricKind.sleep}, sleep: 300);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // start + recover → two cards, two dots.
    expect(find.byKey(const ValueKey('home.dot.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.dot.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.dot.2')), findsNothing);
    // Persona C's profile carries a name (Phase 6.6): greeted by it.
    expect(
      textOf(tester, 'home.greeting').data,
      anyOf(
        'Good morning, Persona',
        'Good afternoon, Persona',
        'Good evening, Persona',
        'Good night, Persona',
      ),
    );
    await tester.tap(find.byKey(const ValueKey('home.profile')));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets(
      'a permission revoked outside FITOS: Refresh re-reads the grants and the old value is gone, not kept as current',
      (tester) async {
    health.connection_ = const HealthConnectionState(
      sdk: HealthSdkStatus.available,
      granted: {HealthMetricKind.steps},
    );
    health.snapshot_ = snapshot({HealthMetricKind.steps}, steps: 6842);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.steps').data, '6,842');

    // Revoked in Health Connect while FITOS was in the background.
    health.connection_ = available;
    health.snapshot_ = null;
    await tester.tap(find.byKey(const ValueKey('home.steps')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('health.refresh')));
    await tester.tap(find.byKey(const ValueKey('health.refresh')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'health.status').data, 'Not connected');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home.steps').data, 'Connect Health data');
    expect(find.text('6,842'), findsNothing);
    expect(health.calls.where((c) => c == 'connection').length, greaterThan(1));
  });

  testWidgets(
      'no name yet: the greeting stands alone, Home asks once; Save writes the profile and the greeting follows',
      (tester) async {
    profile.nextProfile = Ok(
      (profile.nextProfile as Ok<UserProfileDetail>)
          .value
          .copyWith(displayName: null),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'home.greeting').data,
      anyOf('Good morning', 'Good afternoon', 'Good evening', 'Good night'),
    );
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('User'), findsNothing);
    expect(find.byKey(const ValueKey('home.namePrompt')), findsOneWidget);
    // Empty → Save disabled.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('home.namePrompt.save')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('home.namePrompt.field')),
        matching: find.byType(TextField),
      ),
      'Srijan',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home.namePrompt.save')));
    await tester.pumpAndSettle();
    expect(profile.calls, contains('setDisplayName:Srijan'));
    expect(find.byKey(const ValueKey('home.namePrompt')), findsNothing);
    expect(textOf(tester, 'home.greeting').data, endsWith(', Srijan'));
  });

  testWidgets('"Not now" hides the name prompt and remembers it on this phone',
      (tester) async {
    profile.nextProfile = Ok(
      (profile.nextProfile as Ok<UserProfileDetail>)
          .value
          .copyWith(displayName: null),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.namePrompt.notNow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home.namePrompt')), findsNothing);
    expect(profile.calls, isNot(contains(startsWith('setDisplayName'))));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NamePrompt.dismissedKey), isTrue);
  });
  group('Phase 8 — Home food from the server day (agrees with EAT)', () {
    FoodLog logOf(
      String date, {
      required List<double> kcal,
      required List<double> protein,
    }) =>
        FoodLog(
          id: 'server-1',
          clientLogId: '11111111-1111-4111-8111-111111111111',
          loggedAt: '${date}T07:30:00.000Z',
          localDate: date,
          mealSlot: MealSlot.lunch,
          entryMethod: EntryMethod.search,
          savedMealId: null,
          items: [
            FoodLogItem(
              id: 'i',
              position: 0,
              foodId: 'f',
              foodName: 'Thali',
              foodSource: FoodSource.estimated,
              basis: NutritionBasis.perServing,
              servingLabel: '1 plate',
              servingGrams: null,
              servings: 1,
              grams: null,
              kcalLow: kcal[0],
              kcalHigh: kcal[1],
              proteinLow: protein[0],
              proteinHigh: protein[1],
              carbLow: 100,
              carbHigh: 120,
              fatLow: 30,
              fatHigh: 40,
              fibreLow: null,
              fibreHigh: null,
              confidence: NutritionConfidence.medium,
            ),
          ],
          totals: FakeFoodLogApi.totalsOf(const []),
        );

    Future<void> seed(
      WidgetTester tester,
      FoodLog Function(String today) make,
    ) async {
      final container =
          ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      final today = container.read(localTodayProvider);
      final log = make(today);
      foodLog.logs[log.clientLogId] = log;
      container.invalidate(nutritionDayRefreshProvider(today));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets(
        'the Food tile shows the server day as a range against the target — the numbers EAT shows',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await seed(
        tester,
        (d) => logOf(d, kcal: [1210, 1480], protein: [60, 75]),
      );
      expect(textOf(tester, 'home.food').data, '1,210–1,480 / 2,276 kcal');
      expect(find.text('60–75 / 106 g protein'), findsOneWidget);
    });

    testWidgets(
        'J16: "protein low" fires only when even the HIGH end is under 75 % of the target',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      // 106 g target → 75 % is 79.5 g. High end 75 g: under even at best → suggest.
      await seed(
        tester,
        (d) => logOf(d, kcal: [1210, 1480], protein: [60, 75]),
      );
      final container =
          ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      expect(container.read(homeNutritionProvider).proteinG, 75);
      expect(
        container.read(homeSuggestionsProvider).map((s) => s.id),
        contains('eat-protein'),
      );
    });

    testWidgets(
        'J16: a range whose high end reaches 75 % does not claim protein is low',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await seed(
        tester,
        (d) => logOf(d, kcal: [1210, 1480], protein: [60, 90]),
      );
      final container =
          ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      final n = container.read(homeNutritionProvider);
      expect(
        [n.proteinLow, n.proteinG, n.kcalLow, n.kcal],
        [60, 90, 1210, 1480],
      );
      expect(
        container.read(homeSuggestionsProvider).map((s) => s.id),
        isNot(contains('eat-protein')),
      );
    });
  });
}
