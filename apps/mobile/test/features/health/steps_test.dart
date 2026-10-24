import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/health/data/health_connect_provider.dart';
import 'package:fitos/features/health/domain/steps_history.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/health/presentation/screens/steps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_health_channel.dart';
import '../../support/fake_health_provider.dart';

/// Beta 3.6 (owner): weekly steps, day by day, with a graph; this week and
/// the three before, read from Health Connect on the phone.
void main() {
  // Thursday 22 Oct 2026: this week runs Mon 19 – Sun 25.
  final thursday = DateTime.utc(2026, 10, 22);

  group('StepsHistory', () {
    test('reads from the Monday three weeks back through today', () {
      expect(StepsHistory.daysFor(thursday), 21 + 4);
      final h = StepsHistory(today: thursday, steps: List.filled(25, 1000));
      expect(h.firstDay, DateTime.utc(2026, 9, 28));
    });

    test('this week: days to come are empty; total, average, best, at goal',
        () {
      final steps = <double?>[
        ...List<double?>.filled(21, 5000),
        // Mon 19 – Thu 22.
        9000, null, 12000, 4000,
      ];
      final w = StepsHistory(today: thursday, steps: steps).week(0);
      expect(w.monday, DateTime.utc(2026, 10, 19));
      expect(w.days, [9000, null, 12000, 4000, null, null, null]);
      expect(w.futureFrom, 4);
      expect(w.daysSoFar, 4);
      expect(w.total, 25000);
      expect(w.average, 8333, reason: 'over the three days with data');
      expect(w.bestDay, 2);
      expect(w.daysAtGoal(8000), 2);
    });

    test('an earlier week is whole; a week with no data has no average', () {
      final steps = <double?>[
        ...List<double?>.filled(7, null),
        ...List.filled(18, 7000),
      ];
      final h = StepsHistory(today: thursday, steps: steps);
      expect(h.week(3).hasData, isFalse);
      expect(h.week(3).average, isNull);
      expect(h.week(3).bestDay, isNull);
      expect(h.week(1).futureFrom, 7);
      expect(h.week(1).total, 49000);
    });
  });

  test(
      'Health Connect: one steps total per local day, oldest first; none when steps are not granted',
      () async {
    final channel = FakeHealthChannel();
    final provider = HealthConnectProvider(
      channel,
      now: () => DateTime.utc(2026, 10, 22, 6),
    );
    expect(
      await provider.dailySteps(
        endDate: '2026-10-22',
        timezone: 'Asia/Kolkata',
        days: 3,
      ),
      isNull,
    );
    channel.granted = ['steps'];
    channel.stepsAggregate = 4321;
    final days = await provider.dailySteps(
      endDate: '2026-10-22',
      timezone: 'Asia/Kolkata',
      days: 3,
    );
    expect(days, [4321, 4321, 4321]);
    final ranges = channel.ranges
        .where((r) => r.$1 == 'aggregate:steps')
        .map((r) => r.$2.toUtc())
        .toList()
      ..sort();
    // 20, 21 and 22 Oct from local midnight (IST = UTC+5:30).
    expect(ranges, [
      DateTime.utc(2026, 10, 19, 18, 30),
      DateTime.utc(2026, 10, 20, 18, 30),
      DateTime.utc(2026, 10, 21, 18, 30),
    ]);
  });

  group('Steps screen', () {
    late FakeHealthProvider health;

    setUp(() {
      SharedPreferences.setMockInitialValues({'health.stepGoal': 8000});
      health = FakeHealthProvider();
    });

    Widget app() {
      final router = GoRouter(
        initialLocation: '/steps',
        routes: [
          GoRoute(path: '/steps', builder: (_, __) => const StepsScreen()),
          GoRoute(
            path: '/profile/health',
            builder: (_, __) => const Scaffold(body: Text('HEALTH')),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          ...healthOverrides(health),
          localTodayProvider.overrideWithValue('2026-10-22'),
          userTimezoneProvider.overrideWithValue('Asia/Kolkata'),
        ],
        child:
            MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
      );
    }

    String text(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets(
        'the week: a bar a day, dashes for no data, nothing for days to come; the figures',
        (tester) async {
      health.stepsByDay = [
        ...List<double?>.filled(14, 6000),
        ...List<double?>.filled(7, 10000), // last week
        9000, null, 12000, 4000, // this week so far
      ];
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(health.calls, contains('dailySteps:2026-10-22:25'));
      expect(text(tester, 'steps.title'), 'This week');
      expect(text(tester, 'steps.line'), '25,000 steps');
      expect(find.byKey(const ValueKey('steps.day.0.bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('steps.day.1.none')), findsOneWidget);
      expect(find.byKey(const ValueKey('steps.day.4.bar')), findsNothing);
      expect(find.byKey(const ValueKey('steps.day.4.none')), findsNothing);
      expect(find.byKey(const ValueKey('steps.day.goal')), findsOneWidget);
      expect(text(tester, 'steps.average'), '8,333');
      expect(text(tester, 'steps.best'), 'Wed · 12,000');
      expect(text(tester, 'steps.atGoal'), '2 of 4');

      // A bar tapped shows its day.
      await tester.tap(find.byKey(const ValueKey('steps.day.2')));
      await tester.pumpAndSettle();
      expect(text(tester, 'steps.line'), 'Wed 21 Oct · 12,000 steps');

      // Last week, then no further back than four weeks.
      await tester.tap(find.byKey(const ValueKey('steps.earlier')));
      await tester.pumpAndSettle();
      expect(text(tester, 'steps.title'), 'Last week');
      expect(text(tester, 'steps.line'), '70,000 steps');
      expect(text(tester, 'steps.atGoal'), '7 of 7');
      await tester.tap(find.byKey(const ValueKey('steps.earlier')));
      await tester.tap(find.byKey(const ValueKey('steps.earlier')));
      await tester.pumpAndSettle();
      expect(text(tester, 'steps.title'), '28 Sep – 4 Oct');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('steps.earlier')))
            .onPressed,
        isNull,
      );
    });

    testWidgets(
        '4 weeks: the average a day of each week and the change on last week',
        (tester) async {
      health.stepsByDay = [
        ...List<double?>.filled(14, 6000),
        ...List<double?>.filled(7, 7000),
        9000,
        9000,
        9000,
        9000,
      ];
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 weeks'));
      await tester.pumpAndSettle();
      expect(text(tester, 'steps.line'), '9,000 a day');
      expect(text(tester, 'steps.change'), '+2,000 on last week');
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('steps.week.$i.bar')), findsOneWidget);
      }
      expect(find.text('19 Oct'), findsOneWidget);
    });

    testWidgets('steps not readable: Connect opens Health', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('steps.notConnected')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('steps.connect')));
      await tester.pumpAndSettle();
      expect(find.text('HEALTH'), findsOneWidget);
    });

    testWidgets('fits 360 px at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      health.stepsByDay = List<double?>.filled(25, 15000);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('4 weeks'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
