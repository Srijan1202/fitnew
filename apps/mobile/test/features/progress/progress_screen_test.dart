import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/app_shell.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/progress/domain/progress.dart';
import 'package:fitos/features/progress/presentation/progress_providers.dart';
import 'package:fitos/features/progress/presentation/progress_screen.dart';
import 'package:fitos/features/progress/presentation/trend_chart.dart';
import 'package:fitos/features/today/presentation/today_providers.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/screens/volume_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercise_repository.dart';
import '../../support/fake_health_provider.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_progress_api.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 12 — Progress & Recovery (ADR-018): the server's summary drawn as
/// is — the trend weight the headline, raw readings hairlines, the weekly
/// rate only after 10 days, changes only over ≥ 7 days, never a
/// day-over-day figure — plus the Volume heatmap, adherence, consistency and
/// the phone's own Health Connect recovery context (no score). Offline: the
/// cached summary, labelled; readings online only. Beta 3.9 (owner-approved
/// redesign): today first, a section with nothing to show is a line in "Get
/// started", the newest record in Strength, weeks named by their Monday.
void main() {
  const today = '2026-09-21';
  late AppDatabase db;
  late FakeWorkoutApi api;
  late FakeHealthProvider health;
  late FakeProgressApi progress;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    health = FakeHealthProvider()
      ..connection_ = HealthConnectionState.disconnected;
    progress = FakeProgressApi(today: today);
  });
  tearDown(() => db.close());

  ProgressSummary rich({double? weekly = -0.4, int days = 30}) {
    final noise = [0.9, -1.1, 0.4, -0.6, 1.2, -0.8, 0.3, -1.0, 0.7, -0.2];
    final start = DateTime.parse('2026-08-23');
    return ProgressSummary(
      window: ProgressWindow.d30,
      today: today,
      from: '2026-08-23',
      weight: WeightProgress(
        points: [
          for (var i = 0; i < days; i++)
            WeightPoint(
              date: start
                  .add(Duration(days: i))
                  .toIso8601String()
                  .substring(0, 10),
              rawKg: 75 + noise[i % 10] - i * 0.03,
              trendKg: 75 - i * 0.03,
            ),
        ],
        currentTrendKg: 74.1,
        weeklyChangeKg: weekly,
        daysOfData: days,
        isReliable: weekly != null,
        windowChangeKg: -0.9,
        windowChangeDays: days - 1,
      ),
      measurements: const [
        SiteProgress(
          site: MeasurementSite.waist,
          latestDate: today,
          latestCm: 84.5,
          changeCm: -1.5,
          changeDays: 20,
        ),
        SiteProgress(
          site: MeasurementSite.arm,
          latestDate: today,
          latestCm: 35.5,
          changeCm: null,
          changeDays: null,
        ),
      ],
      prs: const [
        PrRecord(
          id: 'pr-1',
          exerciseId: 'ex-bench',
          exerciseName: 'Bench Press',
          prType: 'weight',
          value: 85,
          previous: 80,
          reason: '85 kg beats your best of 80 kg.',
          achievedOn: '2026-09-19',
        ),
      ],
      bestLifts: const [
        BestLift(
          exerciseId: 'ex-bench',
          exerciseName: 'Bench Press',
          estimated1RmKg: 93.5,
          weightKg: 85,
          reps: 3,
          date: '2026-09-19',
        ),
      ],
      adherence: const Adherence(
        protein: AdherenceCount(met: 2, of: 4, percent: 50),
        calories: AdherenceCount(met: 3, of: 4, percent: 75),
        loggedDays: 4,
        daysWithoutTarget: 0,
      ),
      consistency: const Consistency(
        weeks: [
          WeekConsistency(isoWeek: '2026-W38', completed: 3, planned: 3),
          WeekConsistency(isoWeek: '2026-W39', completed: 1, planned: 1),
        ],
        completed: 4,
        planned: 4,
        percent: 100,
      ),
    );
  }

  /// Two weeks of chest volume, owned (the Volume screen's own shape).
  VolumeResponse someVolume() {
    MuscleWeek chest(double sets, LandmarkStatus status) => MuscleWeek(
          muscle: MuscleGroup.chest,
          hardSets: sets,
          tonnageKg: sets * 400,
          status: status,
          landmarks: const VolumeLandmarks(
            mv: 4,
            mev: 8,
            mavLow: 12,
            mavHigh: 20,
            mrv: 22,
          ),
          owned: true,
        );
    return api.volumeResponse.copyWith(
      weeks: [
        VolumeWeek(
          isoWeek: '2026-W37',
          muscles: [chest(6, LandmarkStatus.belowMev)],
        ),
        VolumeWeek(
          isoWeek: '2026-W38',
          muscles: [chest(10, LandmarkStatus.mevToMav)],
        ),
      ],
      owned: [MuscleGroup.chest],
    );
  }

  /// [shell]: Progress inside the app's own tab shell, its bar floating
  /// over the tab (beta 4.8: Log weight's Save hid behind it).
  Widget app({bool shell = false}) {
    final router = shell
        ? GoRouter(
            initialLocation: Routes.progress,
            routes: [
              StatefulShellRoute.indexedStack(
                builder: (_, __, navigationShell) =>
                    AppShell(navigationShell: navigationShell),
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: Routes.progress,
                        builder: (_, __) => const ProgressScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          )
        : GoRouter(
            initialLocation: Routes.progress,
            routes: [
              GoRoute(
                path: Routes.progress,
                builder: (_, __) => const ProgressScreen(),
              ),
              GoRoute(
                path: Routes.volume,
                builder: (_, __) => const Scaffold(body: Text('VOLUME')),
              ),
              GoRoute(
                path: Routes.healthData,
                builder: (_, __) => const Scaffold(body: Text('HEALTH')),
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
        ...workoutOverrides(db, api, progress: progress),
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

  Iterable<String> allText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

  testWidgets(
      'the header and every section; the trend is the headline, the raw reading small below it',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    api.volumeResponse = someVolume();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(textOf(tester, 'progress.title'), 'Progress & Recovery');
    expect(textOf(tester, 'progress.weight.trend'), '74.1 kg');
    final headline =
        tester.widget<Text>(key('progress.weight.trend')).style!.fontSize!;
    final raw = tester.widget<Text>(key('progress.weight.raw'));
    expect(raw.style!.fontSize!, lessThan(headline));
    expect(raw.style!.color, FitColors.ink35);
    expect(textOf(tester, 'progress.weight.rate'), '−0.4 kg / week');
    expect(textOf(tester, 'progress.weight.change'), '−0.9 kg');
    expect(
      textOf(tester, 'progress.weight.fluctuation'),
      ProgressScreen.fluctuation,
    );
    // Beta 3.9's order: today first, then what was logged; nothing to start.
    for (final label in [
      'TODAY',
      'WEIGHT',
      'STRENGTH',
      'TRAINING',
      'Weekly volume per muscle',
      'NUTRITION',
      'BODY',
    ]) {
      await reveal(tester, find.text(label));
    }
    expect(key('progress.start'), findsNothing);
  });

  testWidgets(
      'beta 4.8 (owner): inside the tabs, Log weight’s Save is above the bottom bar and saves',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(shell: true));
    await settle(tester);
    await reveal(tester, key('progress.weight.log'));
    await tester.tap(key('progress.weight.log'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: key('progress.sheet.value'),
        matching: find.byType(EditableText),
      ),
      '72.4',
    );
    // A tap that would land on the bar instead fails the test.
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(progress.writes, isNotEmpty);
  });

  testWidgets('before 10 days of readings there is no weekly rate — it says so',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich(weekly: null, days: 6);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(textOf(tester, 'progress.weight.rate'), 'After 10 days of readings');
    expect(find.text('6 so far'), findsOneWidget);
  });

  testWidgets(
      'one reading: no squeezed chart and no "not yet" tiles — a panel says the line starts with the next reading',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich(weekly: null, days: 1);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(textOf(tester, 'progress.weight.trend'), '74.1 kg');
    expect(key('progress.weight.sparse'), findsOneWidget);
    expect(key('progress.chart'), findsNothing);
    expect(key('progress.weight.rate'), findsNothing);
    expect(key('progress.weight.log'), findsOneWidget);
  });

  testWidgets('the chart: kg on the right, the window\'s dates below',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('progress.chart'), findsOneWidget);
    expect(
      find.descendant(
        of: key('progress.chart.dates'),
        matching: find.text('23 Aug'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('progress.chart.dates'),
        matching: find.text('21 Sep'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('progress.chart.kg'),
        matching: find.byType(Text),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('no day-over-day figure and no red anywhere on the page (§17)',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('photos.card'));
    final forbidden = RegExp(
      r'yesterday|since last|day-over-day|vs\.? yesterday|today vs|per day change',
      caseSensitive: false,
    );
    for (final t in allText(tester)) {
      expect(forbidden.hasMatch(t), isFalse, reason: t);
    }
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.color, isNot(FitColors.oxide), reason: t.data);
    }
  });

  testWidgets(
      'measurements, strength, adherence and consistency say exactly the server\'s numbers',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.best.ex-bench'));
    expect(textOf(tester, 'progress.best.ex-bench'), '93.5 kg');
    expect(find.text('From 85.0 kg × 3 · 19 Sep'), findsOneWidget);
    await reveal(tester, key('progress.consistency'));
    expect(textOf(tester, 'progress.consistency'), '4 / 4');
    expect(
      textOf(tester, 'progress.consistency.caption'),
      'Planned sessions done · 100%',
    );
    // Beta 3.9: a week is named by its Monday, not its ISO number.
    expect(textOf(tester, 'progress.consistency.2026-W38'), '14 Sep · 3/3');
    await reveal(tester, key('progress.adherence.calories'));
    expect(textOf(tester, 'progress.adherence.protein'), '50%');
    expect(
      textOf(tester, 'progress.adherence.protein.days'),
      '2 of 4 logged days',
    );
    expect(textOf(tester, 'progress.adherence.calories'), '75%');
    expect(
      textOf(tester, 'progress.adherence.calories.days'),
      '3 of 4 logged days',
    );
    await reveal(tester, key('progress.measurement.arm'));
    expect(textOf(tester, 'progress.measurement.waist'), '84.5 cm');
    expect(
      textOf(tester, 'progress.measurement.waist.change'),
      '−1.5 cm over 20 days',
    );
    expect(textOf(tester, 'progress.measurement.arm'), '35.5 cm');
    expect(
      textOf(tester, 'progress.measurement.arm.change'),
      'Change shows after 7 days',
    );
    expect(
      textOf(tester, 'progress.measurement.missing'),
      'Not measured yet: chest, thigh, hip',
    );

    // Beta 4.1.1 (owner): inches, shown from the same centimetres.
    await tester.tap(key('length.unit.inch'));
    await settle(tester);
    expect(textOf(tester, 'progress.measurement.waist'), '33.3 in');
    expect(
      textOf(tester, 'progress.measurement.waist.change'),
      '−0.6 in over 20 days',
    );
    expect(textOf(tester, 'progress.measurement.arm'), '14.0 in');
  });

  testWidgets(
      'S24 regression: 24 sessions in a 4-session week fit on a 360 px screen — 4 squares and "+20", no overflow',
      (tester) async {
    tester.view
      ..physicalSize = const Size(360 * 3, 640 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final base = rich();
    progress.summaries[ProgressWindow.d7] = ProgressSummary(
      window: base.window,
      today: base.today,
      from: base.from,
      weight: base.weight,
      measurements: base.measurements,
      prs: base.prs,
      bestLifts: base.bestLifts,
      adherence: base.adherence,
      consistency: const Consistency(
        weeks: [
          WeekConsistency(isoWeek: '2026-W39', completed: 24, planned: 4),
          WeekConsistency(isoWeek: '2026-W40', completed: 0, planned: 5),
          WeekConsistency(isoWeek: '2026-W41', completed: 0, planned: 5),
          WeekConsistency(isoWeek: '2026-W42', completed: 0, planned: 5),
          WeekConsistency(isoWeek: '2026-W43', completed: 0, planned: 3),
        ],
        completed: 24,
        planned: 22,
        percent: 109,
      ),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.consistency.2026-W43'));
    expect(tester.takeException(), isNull);
    expect(textOf(tester, 'progress.consistency.2026-W39'), '21 Sep · 24/4');
    expect(textOf(tester, 'progress.consistency.2026-W39.extra'), '+20');
    expect(key('progress.consistency.2026-W40.extra'), findsNothing);
  });

  testWidgets(
      'beta 3.9: the newest record sits in Strength; the rest open on a tap and close again',
      (tester) async {
    final base = rich();
    progress.summaries[ProgressWindow.d7] = ProgressSummary(
      window: base.window,
      today: base.today,
      from: base.from,
      weight: base.weight,
      measurements: base.measurements,
      prs: [
        ...base.prs,
        const PrRecord(
          id: 'pr-2',
          exerciseId: 'ex-squat',
          exerciseName: 'Back Squat',
          prType: 'weight',
          value: 110,
          previous: 105,
          reason: '110 kg beats your best of 105 kg.',
          achievedOn: '2026-09-17',
        ),
      ],
      bestLifts: base.bestLifts,
      adherence: base.adherence,
      consistency: base.consistency,
    );
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.records.toggle'));
    // 19 Sep is newer than 17 Sep.
    expect(
      find.descendant(
        of: key('progress.records.latest'),
        matching: find.text('New best: Bench Press · 19 Sep'),
      ),
      findsOneWidget,
    );
    expect(
      textOf(tester, 'progress.records.count'),
      'All 2 records this period',
    );
    expect(key('progress.pr.pr-1'), findsNothing);
    await tester.tap(key('progress.records.toggle'));
    await settle(tester);
    expect(key('progress.pr.pr-1'), findsOneWidget);
    expect(key('progress.pr.pr-2'), findsOneWidget);
    expect(find.text('110 kg beats your best of 105 kg.'), findsOneWidget);
    expect(key('progress.records.latest'), findsNothing);
    await tester.tap(key('progress.records.toggle'));
    await settle(tester);
    expect(key('progress.pr.pr-1'), findsNothing);
    expect(key('progress.records.latest'), findsOneWidget);
  });

  testWidgets('one record: shown in Strength with nothing to open',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.records.latest'));
    expect(find.text('85 kg beats your best of 80 kg.'), findsOneWidget);
    expect(key('progress.records.toggle'), findsNothing);
  });

  testWidgets(
      'empty history: no empty sections — each is a line in the start list, nothing invented',
      (tester) async {
    api.volumeResponse = someVolume();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('progress.weight.trend'), findsNothing);
    for (final label in [
      'WEIGHT',
      'STRENGTH',
      'NUTRITION',
      'BODY',
      'RECOVERY',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // The Volume screen has weeks, so Training is drawn and says 0.
    await reveal(tester, key('progress.consistency'));
    expect(textOf(tester, 'progress.consistency'), '0');
    expect(
      textOf(tester, 'progress.consistency.caption'),
      'Completed · no programme to compare',
    );
    await reveal(tester, key('progress.start'));
    expect(find.text('STILL TO START'), findsOneWidget);
    for (final k in [
      'progress.weight.log',
      'progress.start.food',
      'progress.measurement.log',
      'progress.start.photo',
    ]) {
      await reveal(tester, key(k));
    }
    expect(key('progress.start.training'), findsNothing);
    // Health Connect is not on this phone: nothing to connect.
    expect(key('progress.start.health'), findsNothing);
  });

  testWidgets('nothing at all: "Get started" leads, straight after Today',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(key('progress.start.training'), findsOneWidget);
    expect(find.text('TRAINING'), findsNothing);
    expect(
      tester.getTopLeft(find.text('GET STARTED')).dy,
      greaterThan(tester.getTopLeft(find.text('TODAY')).dy),
    );
  });

  testWidgets('loading shows a quiet bar; the window switch fetches 90 days',
      (tester) async {
    progress
      ..summaries[ProgressWindow.d7] = rich()
      ..delay = const Duration(milliseconds: 300);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 50));
    expect(key('progress.loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(key('progress.loading'), findsNothing);
    await tester.tap(key('progress.window.90d'));
    await settle(tester);
    expect(progress.calls, contains('summary 90d'));
  });

  testWidgets('beta 3.2: the window reads 1W · 1M · 3M and opens on one week',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(progress.calls.first, 'summary 7d');
    expect(find.text('1W'), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('3M'), findsOneWidget);
    await tester.tap(key('progress.window.30d'));
    await settle(tester);
    expect(progress.calls.last, 'summary 30d');
  });

  testWidgets('unavailable with nothing cached: says why (offline vs server)',
      (tester) async {
    progress.failure = const Offline();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      textOf(tester, 'progress.unavailable'),
      'Progress needs a connection.',
    );
    progress.failure = const Unknown();
    container(tester).invalidate(progressSummaryProvider);
    await settle(tester);
    expect(
      textOf(tester, 'progress.unavailable'),
      'Progress is unavailable right now.',
    );
  });

  testWidgets(
      'offline with a cached summary: shown, labelled with its time; readings fail clearly and nothing is queued',
      (tester) async {
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('progress.cached'), findsNothing);
    progress.failure = const Offline();
    container(tester).invalidate(progressSummaryProvider);
    await settle(tester);
    expect(
      textOf(tester, 'progress.cached'),
      startsWith('Offline — showing your progress from '),
    );
    expect(
      textOf(tester, 'progress.cached'),
      endsWith('Logging needs a connection.'),
    );
    expect(textOf(tester, 'progress.weight.trend'), '74.1 kg');

    await reveal(tester, key('progress.weight.log'));
    await tester.tap(key('progress.weight.log'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: key('progress.sheet.value'),
        matching: find.byType(EditableText),
      ),
      '72.4',
    );
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(
      textOf(tester, 'progress.sheet.error'),
      startsWith("You're offline. Readings are saved online only"),
    );
    expect(progress.writes, isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
    expect(await db.select(db.nutritionSyncQueue).get(), isEmpty);
    expect(await db.select(db.todayEventQueue).get(), isEmpty);
  });

  testWidgets(
      'weight entry: saved to the server; today\'s reading marks TODAY\'s log-weight evidence',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(key('progress.weight.log'));
    await settle(tester);
    // Validation first.
    await tester.enterText(
      find.descendant(
        of: key('progress.sheet.value'),
        matching: find.byType(EditableText),
      ),
      '12',
    );
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(find.text('That does not look right.'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: key('progress.sheet.value'),
        matching: find.byType(EditableText),
      ),
      '72.4',
    );
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(progress.writes, [
      {'weightKg': 72.4},
    ]);
    expect(key('progress.sheet.save'), findsNothing);
    expect(container(tester).read(weightSavedOnProvider), today);
  });

  testWidgets('measurement entry: pick a site, one value in cm',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.measurement.log'));
    await tester.tap(key('progress.measurement.log'));
    await settle(tester);
    await tester.tap(key('progress.sheet.site.hip'));
    await tester.enterText(
      find.descendant(
        of: key('progress.sheet.value'),
        matching: find.byType(EditableText),
      ),
      '98',
    );
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(progress.writes, [
      {'site': 'hip', 'valueCm': 98.0},
    ]);
  });

  testWidgets(
      'beta 4.1.1: a measurement typed in inches is saved in centimetres, and checked in them',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.measurement.log'));
    await tester.tap(key('progress.measurement.log'));
    await settle(tester);
    // The sheet's own switch (the section's is behind it).
    await tester.tap(key('length.unit.inch').last);
    await settle(tester);
    expect(find.text('MEASUREMENT (IN)'), findsOneWidget);
    await tester.tap(key('progress.sheet.site.waist'));
    final field = find.descendant(
      of: key('progress.sheet.value'),
      matching: find.byType(EditableText),
    );
    // 2 in is 5 cm: too small for a waist.
    await tester.enterText(field, '2');
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(find.text('That does not look right.'), findsOneWidget);
    await tester.enterText(field, '32.5');
    await tester.tap(key('progress.sheet.save'));
    await settle(tester);
    expect(progress.writes.single['site'], 'waist');
    expect(progress.writes.single['valueCm'], closeTo(82.55, 1e-9));
  });

  testWidgets(
      'the heatmap is the Volume screen\'s own weeks, statuses and words; it opens Volume',
      (tester) async {
    api.volumeResponse = someVolume();
    await tester.pumpWidget(app());
    await settle(tester);
    final v = api.volumeResponse;
    expect(v.weeks, hasLength(2));
    await reveal(tester, key('progress.volume.open'));
    for (final muscle in v.owned) {
      for (final (i, w) in v.weeks.indexed) {
        final status =
            w.muscles.where((m) => m.muscle == muscle).firstOrNull?.status ??
                LandmarkStatus.none;
        final cell = key('progress.volume.${muscle.wire}.$i');
        expect(cell, findsOneWidget);
        final sem = tester.widget<Semantics>(
          find.descendant(of: cell, matching: find.byType(Semantics)).first,
        );
        expect(sem.properties.label, VolumeWording.label(status));
      }
    }
    await tester.tap(key('progress.volume.open'));
    await settle(tester);
    expect(find.text('VOLUME'), findsOneWidget);
  });

  testWidgets(
      'recovery: no check-in and no Health Connect — Today offers the check-in and no Recovery section is drawn (Phase 13)',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    // Phase 13: a score exists only from the server, after a check-in — none here.
    expect(key('recovery.readiness'), findsNothing);
    expect(key('recovery.checkIn.open'), findsOneWidget);
    expect(key('recovery.readiness.details'), findsNothing);
    expect(key('progress.recovery.empty'), findsNothing);
    expect(key('progress.recovery.note'), findsNothing);
  });

  testWidgets(
      'recovery with short sleep: the reading, and the existing advisory',
      (tester) async {
    health
      ..connection_ = const HealthConnectionState(
        sdk: HealthSdkStatus.available,
        granted: {HealthMetricKind.sleep, HealthMetricKind.restingHeartRate},
      )
      ..snapshot_ = HealthSnapshot.empty(
        date: today,
        timezone: 'Asia/Kolkata',
        availability: HealthAvailability.noData,
        fetchedAt: FakeHealthProvider.fetchedAt,
      ).copyWith(
        sleep: metricOf(HealthMetricKind.sleep, 330, unit: 'min'),
        restingHeartRate:
            metricOf(HealthMetricKind.restingHeartRate, 58, unit: 'bpm'),
        weight: metricOf(HealthMetricKind.weight, 73.2, unit: 'kg'),
      );
    progress.summaries[ProgressWindow.d7] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    // Health Connect weight: a separate line, never the trend.
    expect(
      textOf(tester, 'progress.weight.healthConnect'),
      'Health Connect: 73.2 kg · on this phone, not in the trend',
    );
    expect(textOf(tester, 'progress.weight.trend'), '74.1 kg');
    await reveal(tester, key('progress.recovery.advisory'));
    expect(textOf(tester, 'progress.sleep'), '5h 30m');
    expect(textOf(tester, 'progress.rhr'), '58 bpm');
    expect(
      textOf(tester, 'progress.recovery.note'),
      contains('not part of readiness'),
    );
  });

  test(
      'trend geometry: dates on x across the window, both series inside y; the trend bold, raw hairlines, ink only',
      () {
    const pts = [
      WeightPoint(date: '2026-08-23', rawKg: 76, trendKg: 75),
      WeightPoint(date: '2026-09-06', rawKg: 74, trendKg: 74.8),
      WeightPoint(date: '2026-09-21', rawKg: 75, trendKg: 74.6),
    ];
    final g =
        TrendGeometry.of(pts, '2026-08-23', '2026-09-21', const Size(290, 160));
    expect(g.trend.first.dx, 0);
    expect(g.trend.last.dx, 290);
    expect(g.trend[1].dx, closeTo(290 * 14 / 29, 1e-9));
    for (final o in [...g.raw, ...g.trend]) {
      expect(o.dy, inInclusiveRange(0, 160));
    }
    // Higher kg is higher on screen.
    expect(g.raw[0].dy, lessThan(g.raw[1].dy));
    expect(g.minKg, lessThan(74));
    expect(g.maxKg, greaterThan(76));
    // Beta 3.9: whole steps an even number apart. Beta 4.8 (owner: "the
    // graph became so small"): half-kilogram steps under 3 kg of readings —
    // 73.5 · 75 · 76.5, not 73 · 75 · 77.
    expect([g.minKg, g.maxKg], [73.5, 76.5]);
    expect(g.step, 0.5);
    // A wider range keeps whole kilograms.
    final wide = TrendGeometry.of(
      [
        const WeightPoint(date: '2026-08-23', rawKg: 80, trendKg: 79),
        const WeightPoint(date: '2026-09-21', rawKg: 74, trendKg: 75),
      ],
      '2026-08-23',
      '2026-09-21',
      const Size(290, 160),
    );
    expect(wide.step, 1);
    expect([wide.minKg, wide.maxKg], [73, 81]);
    // The x axis starts at the first reading inside the window.
    expect(
      TrendChart.startOf(
        [const WeightPoint(date: '2026-10-26', rawKg: 61.4, trendKg: 61.2)],
        '2026-10-24',
      ),
      '2026-10-26',
    );
    expect(TrendChart.startOf(const [], '2026-10-24'), '2026-10-24');
    expect(TrendPainter.rawStroke, 1);
    expect(
      TrendPainter.trendStroke,
      greaterThanOrEqualTo(TrendPainter.rawStroke * 2),
    );
    expect(TrendPainter.rawColor, FitColors.ink35);
    expect(TrendPainter.trendColor, FitColors.ink);
    expect(
      TrendGeometry.of(
        const [],
        '2026-08-23',
        '2026-09-21',
        const Size(290, 160),
      ).trend,
      isEmpty,
    );
  });

  for (final (name, size, textScale) in [
    ('360x640', const Size(360, 640), 1.0),
    ('360x640 at 200 % text', const Size(360, 640), 2.0),
    ('S24 (412x915)', const Size(412, 915), 1.0),
    ('S24 at 200 % text', const Size(412, 915), 2.0),
  ]) {
    testWidgets('layout: $name — no overflow top to bottom; entry sheet usable',
        (tester) async {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      progress.summaries[ProgressWindow.d7] = rich();
      await tester.pumpWidget(app());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await reveal(tester, key('photos.card'));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        key('progress.weight.log'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(key('progress.weight.log'));
      await settle(tester);
      expect(key('progress.sheet.save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
