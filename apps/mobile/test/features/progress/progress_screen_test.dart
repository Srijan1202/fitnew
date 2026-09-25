import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
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
/// cached summary, labelled; readings online only.
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

  Widget app() {
    final router = GoRouter(
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
    progress.summaries[ProgressWindow.d30] = rich();
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
    for (final label in [
      'WEIGHT',
      'MEASUREMENTS',
      'STRENGTH',
      'TRAINING VOLUME',
      'NUTRITION',
      'TRAINING CONSISTENCY',
      'RECOVERY',
    ]) {
      await reveal(tester, find.text(label));
    }
  });

  testWidgets('before 10 days of readings there is no weekly rate — it says so',
      (tester) async {
    progress.summaries[ProgressWindow.d30] = rich(weekly: null, days: 6);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      textOf(tester, 'progress.weight.rate'),
      'After 10 days of readings (6 so far)',
    );
  });

  testWidgets('no day-over-day figure and no red anywhere on the page (§17)',
      (tester) async {
    progress.summaries[ProgressWindow.d30] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.recovery.note'));
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
    progress.summaries[ProgressWindow.d30] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.measurement.arm'));
    expect(
      textOf(tester, 'progress.measurement.waist'),
      '84.5 cm · −1.5 cm over 20 days',
    );
    expect(textOf(tester, 'progress.measurement.arm'), '35.5 cm');
    await reveal(tester, key('progress.best.ex-bench'));
    expect(
      textOf(tester, 'progress.best.ex-bench'),
      'Est. 1RM 93.5 kg (85.0 × 3)',
    );
    expect(find.text('85 kg beats your best of 80 kg.'), findsOneWidget);
    await reveal(tester, key('progress.adherence.calories'));
    expect(
      textOf(tester, 'progress.adherence.protein'),
      '2 of 4 logged days · 50%',
    );
    expect(
      textOf(tester, 'progress.adherence.calories'),
      '3 of 4 logged days · 75%',
    );
    await reveal(tester, key('progress.consistency'));
    expect(textOf(tester, 'progress.consistency'), '4 of 4 planned · 100%');
    expect(textOf(tester, 'progress.consistency.2026-W38'), 'W38 3/3');
  });

  testWidgets('empty history: honest empty states, nothing invented',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('progress.weight.empty'), findsOneWidget);
    expect(key('progress.weight.trend'), findsNothing);
    await reveal(tester, key('progress.measurements.empty'));
    await reveal(tester, key('progress.strength.empty'));
    await reveal(tester, key('progress.adherence.protein'));
    expect(
      textOf(tester, 'progress.adherence.protein'),
      'No logged days with a target yet',
    );
    await reveal(tester, key('progress.consistency'));
    expect(
      textOf(tester, 'progress.consistency'),
      '0 completed · no programme to compare',
    );
  });

  testWidgets('loading shows a quiet bar; the window switch fetches 90 days',
      (tester) async {
    progress
      ..summaries[ProgressWindow.d30] = rich()
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
    progress.summaries[ProgressWindow.d30] = rich();
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
      'the heatmap is the Volume screen\'s own weeks, statuses and words; it opens Volume',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    final v = api.volumeResponse;
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
      'recovery: device-only context, the connect state, the sleep advisory — never a score',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await reveal(tester, key('progress.recovery.note'));
    expect(
      textOf(tester, 'home.recovery.empty'),
      'Recovery metrics need Health Connect, which is not on this phone.',
    );
    expect(textOf(tester, 'progress.recovery.note'), contains('no score'));
    expect(
      allText(tester)
          .any((t) => RegExp('readiness', caseSensitive: false).hasMatch(t)),
      isFalse,
    );
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
    progress.summaries[ProgressWindow.d30] = rich();
    await tester.pumpWidget(app());
    await settle(tester);
    // Health Connect weight: a separate line, never the trend.
    expect(
      textOf(tester, 'progress.weight.healthConnect'),
      'Health Connect: 73.2 kg · on this phone, not in the trend',
    );
    expect(textOf(tester, 'progress.weight.trend'), '74.1 kg');
    await reveal(tester, key('progress.recovery.advisory'));
    expect(textOf(tester, 'home.sleep'), '5h 30m');
    expect(textOf(tester, 'home.rhr'), '58 bpm');
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
      progress.summaries[ProgressWindow.d30] = rich();
      await tester.pumpWidget(app());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await reveal(tester, key('progress.recovery.note'));
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
