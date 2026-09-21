import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/presentation/screens/health_data_screen.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercise_repository.dart';
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

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    health = FakeHealthProvider();
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
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        trainingRepositoryProvider.overrideWithValue(FakeTrainingRepository()),
        ...workoutOverrides(db, api),
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
    expect(
      textOf(tester, 'home.greeting').data,
      anyOf('GOOD MORNING', 'GOOD AFTERNOON', 'GOOD EVENING', 'GOOD NIGHT'),
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
}
