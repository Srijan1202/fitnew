import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/progress/presentation/progress_screen.dart';
import 'package:fitos/features/recovery/domain/recovery.dart';
import 'package:fitos/features/recovery/presentation/recovery_providers.dart';
import 'package:fitos/features/today/domain/today.dart';
import 'package:fitos/features/today/presentation/today_words.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/widgets/deload_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercise_repository.dart';
import '../../support/fake_health_provider.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_recovery_api.dart';
import '../../support/fake_today_api.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 13 — Recovery (§18; ADR-019): the check-in (every question
/// optional, online only), the server's readiness drawn as is (score, band,
/// advice, what went in and what was not logged, the escalation), Health
/// Connect's sleep as a hint that is never sent, and TODAY's advisory
/// low-readiness words. Beta 3.9: the check-in opens in a sheet from the
/// Today strip at the top of Progress; what went in is in Recovery below.
void main() {
  const today = '2026-09-21';
  late AppDatabase db;
  late FakeWorkoutApi api;
  late FakeHealthProvider health;
  late FakeRecoveryApi recovery;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    health = FakeHealthProvider()
      ..connection_ = HealthConnectionState.disconnected;
    recovery = FakeRecoveryApi(date: today);
  });
  tearDown(() => db.close());

  Readiness readiness({
    int score = 48,
    ReadinessBand band = ReadinessBand.reduce,
    int lowDays = 0,
  }) =>
      Readiness(
        score: score,
        band: band,
        advice:
            'Consider one fewer set on your accessory lifts today. Your main lifts stay as planned.',
        components: const [
          ReadinessComponent(
            key: ReadinessComponentKey.sleep,
            penalty: 20,
            max: 25,
            available: true,
          ),
          ReadinessComponent(
            key: ReadinessComponentKey.soreness,
            penalty: 0,
            max: 20,
            available: true,
          ),
          ReadinessComponent(
            key: ReadinessComponentKey.energy,
            penalty: 0,
            max: 20,
            available: false,
          ),
          ReadinessComponent(
            key: ReadinessComponentKey.performance,
            penalty: 0,
            max: 25,
            available: false,
          ),
          ReadinessComponent(
            key: ReadinessComponentKey.adherence,
            penalty: 0,
            max: 10,
            available: false,
          ),
        ],
        lowDays: lowDays,
      );

  Widget app() {
    final router = GoRouter(
      initialLocation: Routes.progress,
      routes: [
        GoRoute(
          path: Routes.progress,
          builder: (_, __) => const ProgressScreen(),
        ),
      ],
    );
    final auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionUserIdProvider.overrideWithValue(testProfile.id),
        exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        trainingRepositoryProvider.overrideWithValue(FakeTrainingRepository()),
        localHourProvider.overrideWithValue(12),
        localTodayProvider.overrideWithValue(today),
        ...workoutOverrides(db, api, recovery: recovery),
        ...healthOverrides(health),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  String textOf(WidgetTester tester, String k) =>
      tester.widget<Text>(key(k)).data!;
  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(ProgressScreen, skipOffstage: false)),
      );

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String k) async {
    await reveal(tester, key(k));
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  /// A tap inside the check-in sheet (its own scroll view).
  Future<void> tapIn(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, String k) => tester
      .widgetList<Semantics>(
        find.descendant(of: key(k), matching: find.byType(Semantics)),
      )
      .any((s) => s.properties.selected ?? false);

  testWidgets(
      'no check-in yet: Today offers it; the sheet, every question optional; Save waits for one answer and sends exactly what was answered',
      (tester) async {
    recovery.readinessAfterCheckIn = readiness();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('recovery.checkIn'), findsNothing);
    await tap(tester, 'recovery.checkIn.open');
    expect(find.text('How are you today?'), findsOneWidget);
    expect(key('recovery.readiness'), findsNothing);
    expect(textOf(tester, 'recovery.sleep.value'), 'Not set');
    final save = key('recovery.save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    expect(find.text('Answer one to save'), findsOneWidget);

    // Sleep starts at 7.5 h on the first tap, then moves by half an hour.
    await tapIn(tester, 'recovery.sleep.more');
    expect(textOf(tester, 'recovery.sleep.value'), '7.5 h');
    await tapIn(tester, 'recovery.sleep.more');
    expect(textOf(tester, 'recovery.sleep.value'), '8 h');
    await tapIn(tester, 'recovery.sleep.less');
    await tapIn(tester, 'recovery.sleep.less');
    await tapIn(tester, 'recovery.sleep.less');
    expect(textOf(tester, 'recovery.sleep.value'), '6.5 h');
    await tapIn(tester, 'recovery.soreness.3');
    await tapIn(tester, 'recovery.energy.4');
    expect(selected(tester, 'recovery.energy.4'), isTrue);
    // Tapping the chosen value again clears it: the question goes unanswered.
    await tapIn(tester, 'recovery.stress.2');
    await tapIn(tester, 'recovery.stress.2');
    expect(selected(tester, 'recovery.stress.2'), isFalse);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tapIn(tester, 'recovery.save');
    await settle(tester);

    expect(recovery.writes, [
      {
        'sleepHours': 6.5,
        'sleepQuality': null,
        'soreness': 3,
        'energy': 4,
        'stress': null,
      },
    ]);
    // The sheet closes; the server's readiness leads Today, drawn as is.
    expect(key('recovery.checkIn'), findsNothing);
    expect(key('recovery.checkIn.open'), findsNothing);
    await reveal(tester, key('recovery.readiness'));
    expect(textOf(tester, 'recovery.readiness.score'), '48');
    expect(textOf(tester, 'recovery.readiness.band'), '/ 100 · Go lighter');
    expect(
      textOf(tester, 'recovery.readiness.advice'),
      contains('one fewer set on your accessory lifts'),
    );
    expect(
      textOf(tester, 'recovery.log.summary'),
      'Checked in today: 6.5 h sleep · soreness 3/5 · energy 4/5',
    );
    expect(key('recovery.checkIn'), findsNothing);
  });

  testWidgets(
      'the readiness display: what went in, what was not logged — never guessed; the run and the deload offer',
      (tester) async {
    recovery.current = RecoveryToday(
      date: today,
      log: const RecoveryLog(date: today, sleepHours: 5, soreness: 1),
      readiness: readiness(score: 25, band: ReadinessBand.rest, lowDays: 3),
    );
    api.todayResponse = api.todayResponse.copyWith(
      deload: const DeloadState(
        state: DeloadStatus.offered,
        trigger: DeloadTrigger.readiness,
        reason: 'Your readiness has been under 35 for 3 days running.',
        endsOn: null,
      ),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      textOf(tester, 'recovery.readiness.run'),
      'Under 35 for 3 days running.',
    );
    expect(
      textOf(tester, 'recovery.readiness.deload'),
      'A lighter week is offered in Training. Nothing changes unless you accept it.',
    );
    await reveal(tester, key('recovery.readiness.note'));
    expect(textOf(tester, 'recovery.component.sleep'), '−20 of 25');
    expect(textOf(tester, 'recovery.component.soreness'), 'No effect');
    // Beta 3.9: a bar is what is left of the part's share, full when it took nothing.
    LinearProgressIndicator bar(String part) => tester.widget(
          key('recovery.component.$part.bar'),
        );
    expect(bar('sleep').value, closeTo(5 / 25, 1e-9));
    expect(bar('soreness').value, 1);
    // The parts with nothing to go on: one quiet line, never guessed.
    expect(key('recovery.component.energy'), findsNothing);
    expect(
      textOf(tester, 'recovery.components.missing'),
      'Not in the score: energy (not answered), training (not enough recent training), nutrition (no food logged this week).',
    );
    // Health Connect is not on this phone: one line, not a card.
    expect(
      textOf(tester, 'progress.recovery.empty'),
      'Sleep and resting heart rate need Health Connect, which is not on this phone.',
    );
    expect(textOf(tester, 'progress.sleep'), '5h 00m');
    expect(
      textOf(tester, 'recovery.readiness.note'),
      startsWith('Advice only — your plan never changes on its own.'),
    );
  });

  testWidgets(
      'changing today\'s check-in: the card opens with the saved answers, and the day is replaced',
      (tester) async {
    recovery.current = RecoveryToday(
      date: today,
      log: const RecoveryLog(
        date: today,
        sleepHours: 7,
        soreness: 2,
        energy: 4,
        stress: 3,
      ),
      readiness: readiness(score: 80, band: ReadinessBand.ready),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await tap(tester, 'recovery.edit');
    expect(textOf(tester, 'recovery.sleep.value'), '7 h');
    expect(selected(tester, 'recovery.soreness.2'), isTrue);
    await tapIn(tester, 'recovery.soreness.4');
    expect(selected(tester, 'recovery.soreness.2'), isFalse);
    await tapIn(tester, 'recovery.save');
    await settle(tester);
    expect(recovery.writes.single, {
      'sleepHours': 7.0,
      'sleepQuality': null,
      'soreness': 4,
      'energy': 4,
      'stress': 3,
    });
    expect(key('recovery.checkIn'), findsNothing);
  });

  testWidgets(
      'offline: a check-in fails out loud and nothing is stored or queued',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    recovery.failure = const Offline();
    await tap(tester, 'recovery.checkIn.open');
    await tapIn(tester, 'recovery.energy.2');
    await tapIn(tester, 'recovery.save');
    await settle(tester);
    expect(
      textOf(tester, 'recovery.error'),
      "You're offline. Check-ins are saved online only — nothing was stored. Try again when you're connected.",
    );
    expect(recovery.writes, isEmpty);
    expect(
      key('recovery.checkIn'),
      findsOneWidget,
    ); // the answers stay to retry
  });

  testWidgets(
      'offline with a cached view: shown labelled with its time; changing it waits for a connection',
      (tester) async {
    recovery.current = RecoveryToday(
      date: today,
      log: const RecoveryLog(date: today, soreness: 2),
      readiness: readiness(score: 90, band: ReadinessBand.ready),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    recovery.failure = const Offline();
    container(tester).invalidate(recoveryTodayProvider);
    await settle(tester);
    await reveal(tester, key('recovery.cached'));
    expect(
      textOf(tester, 'recovery.cached'),
      startsWith('Offline — showing your check-in from '),
    );
    expect(textOf(tester, 'recovery.readiness.score'), '90');
    await reveal(tester, key('recovery.edit'));
    expect(tester.widget<TextButton>(key('recovery.edit')).onPressed, isNull);
  });

  testWidgets('offline with nothing cached: says so, and no card to fill',
      (tester) async {
    recovery.failure = const Offline();
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('recovery.unavailable'));
    expect(
      textOf(tester, 'recovery.unavailable'),
      'Check-ins need a connection.',
    );
    expect(key('recovery.checkIn.open'), findsNothing);
    expect(key('recovery.checkIn'), findsNothing);
  });

  testWidgets(
      'Health Connect\'s sleep is a hint from this phone: never pre-filled, never sent',
      (tester) async {
    health
      ..connection_ = const HealthConnectionState(
        sdk: HealthSdkStatus.available,
        granted: {HealthMetricKind.sleep},
      )
      ..snapshot_ = HealthSnapshot.empty(
        date: today,
        timezone: 'Asia/Kolkata',
        availability: HealthAvailability.noData,
        fetchedAt: FakeHealthProvider.fetchedAt,
      ).copyWith(sleep: metricOf(HealthMetricKind.sleep, 400, unit: 'min'));
    await tester.pumpWidget(app());
    await settle(tester);
    await tap(tester, 'recovery.checkIn.open');
    await tester.ensureVisible(key('recovery.sleep.healthConnect'));
    expect(
      textOf(tester, 'recovery.sleep.healthConnect'),
      'Health Connect: 6 h 40 min last night — on this phone, not sent.',
    );
    expect(textOf(tester, 'recovery.sleep.value'), 'Not set');
    await tapIn(tester, 'recovery.soreness.1');
    await tapIn(tester, 'recovery.save');
    await settle(tester);
    expect(recovery.writes.single['sleepHours'], isNull);
  });

  for (final (name, size, scale) in [
    ('360x640 at 200 % text', const Size(360, 640), 2.0),
    ('S24 (412x915) at 200 % text', const Size(412, 915), 2.0),
  ]) {
    testWidgets('layout: $name — the sheet and the display fit',
        (tester) async {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      recovery.readinessAfterCheckIn = readiness(lowDays: 2);
      await tester.pumpWidget(app());
      await settle(tester);
      await tap(tester, 'recovery.checkIn.open');
      expect(tester.takeException(), isNull);
      await tapIn(tester, 'recovery.stress.5');
      await tapIn(tester, 'recovery.save');
      await settle(tester);
      await reveal(tester, key('recovery.readiness.note'));
      expect(tester.takeException(), isNull);
    });
  }

  /* ----------------------------------------------------------- TODAY -- */

  group('TODAY low-readiness (band 89): words from the reason, advice only',
      () {
    TodayAction action(Map<String, Object?> values) => FakeTodayApi.action(
          TodayKind.lowReadiness,
          reason: TodayReason('readiness-low', values),
        );

    test('reduce: names the accessories; opens today\'s session', () {
      final a = action({
        'readiness': 48,
        'band': 'reduce',
        'accessories': ['Cable Lateral Raise', 'Triceps Pushdown'],
        'lowDays': 0,
      });
      expect(TodayWords.eyebrow(TodayKind.lowReadiness), 'TRAIN · RECOVERY');
      expect(
        TodayWords.primary(a, messConfigured: false),
        "Open today's session",
      );
      expect(TodayWords.facts(a.reason), [
        ('Readiness', '48 of 100'),
        ('Suggestion', 'One fewer set on accessories'),
        ('Accessories', 'Cable Lateral Raise and Triceps Pushdown'),
        ('Your plan', 'Unchanged unless you choose to'),
      ]);
    });

    test('rest: the run from two days; opens the plan', () {
      final a = action({
        'readiness': 25,
        'band': 'rest',
        'accessories': <String>[],
        'lowDays': 3,
      });
      expect(TodayWords.primary(a, messConfigured: false), 'Open your plan');
      expect(TodayWords.facts(a.reason), [
        ('Readiness', '25 of 100'),
        ('Suggestion', 'Consider resting today'),
        ('Under 35', '3 days running'),
        ('Your plan', 'Unchanged unless you choose to'),
      ]);
    });

    test('informational: never completed, whatever the evidence', () {
      expect(TodayKind.lowReadiness.completable, isFalse);
      expect(TodayKind.fromWire('low-readiness'), TodayKind.lowReadiness);
    });

    test(
        'the deload offer names the readiness trigger; the rest day carries readiness',
        () {
      expect(
        TodayWords.facts(
          const TodayReason('deload-offered', {'trigger': 'readiness'}),
        ),
        [('Signal', 'Readiness under 35 for three days or more')],
      );
      expect(
        TodayWords.facts(
          const TodayReason('rest-day', {
            'hasProgramme': true,
            'nextSessionName': null,
            'nextSessionDate': null,
            'kcalTarget': null,
            'proteinTarget': null,
            'readiness': 82,
          }),
        ),
        [('Readiness', '82 of 100')],
      );
    });
  });

  testWidgets('Training: the deload panel says when low readiness offered it',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...workoutOverrides(db, api)],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const Scaffold(
            body: DeloadPanel(
              deload: DeloadState(
                state: DeloadStatus.offered,
                trigger: DeloadTrigger.readiness,
                reason: 'Your readiness has been under 35 for 3 days running.',
                endsOn: null,
              ),
              mesocycleWeek: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('DELOAD OFFERED · LOW READINESS THREE DAYS RUNNING'),
      findsOneWidget,
    );
    // Never applied without the user's accept.
    expect(api.calls.where((c) => c.startsWith('deload:')), isEmpty);
  });
}
