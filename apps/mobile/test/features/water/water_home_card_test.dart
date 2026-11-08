import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/water/presentation/water_home_card.dart';
import 'package:fitos/features/water/presentation/water_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_water_api.dart';

/// Beta 6.0 (ADR-059): the Home water card — a glass a tap, the total sent
/// (never a "+250") once the taps stop, kept on the phone while offline and
/// sent when FITOS is back, the sheet's amounts, and the admin's switch.
void main() {
  late FakeWaterApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    api = FakeWaterApi();
  });

  Widget app({Map<String, bool> flags = const {}}) => ProviderScope(
        overrides: [
          sessionUserIdProvider.overrideWithValue('u-1'),
          localTodayProvider.overrideWithValue('2026-11-08'),
          waterApiProvider.overrideWithValue(api),
          appConfigProvider.overrideWith(
            (ref) async => AppConfig(flags: flags, minimumBuild: 0),
          ),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const Scaffold(body: WaterHomeCard()),
        ),
      );

  Finder key(String k) => find.byKey(ValueKey(k));
  String text(WidgetTester t, String k) => t.widget<Text>(key(k)).data!;

  Future<void> afterTaps(WidgetTester tester) async {
    await tester.pump(WaterController.sendAfter);
    await tester.pumpAndSettle();
  }

  testWidgets('a glass a tap; the taps are one send of the total',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(text(tester, 'home.water.value'), '0 ml');
    expect(text(tester, 'home.water.line'), 'of 2.75 L · 11 glasses to go');

    await tester.tap(key('home.water.add'));
    await tester.tap(key('home.water.add'));
    await tester.tap(key('home.water.add'));
    await tester.pump();
    expect(text(tester, 'home.water.value'), '750 ml');
    expect(text(tester, 'home.water.line'), contains('not synced yet'));
    await afterTaps(tester);
    expect(
      api.calls.where((c) => c.startsWith('set:')),
      ['set:2026-11-08:750'],
    );
    expect(text(tester, 'home.water.line'), 'of 2.75 L · 8 glasses to go');

    await tester.tap(key('home.water.less'));
    await afterTaps(tester);
    expect(text(tester, 'home.water.value'), '500 ml');
    expect(api.days['2026-11-08'], 500);
  });

  testWidgets('offline: the total is kept and sent when FITOS is back',
      (tester) async {
    api.failure = const Offline();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(key('home.water.add'));
    await afterTaps(tester);
    expect(text(tester, 'home.water.line'), contains('not synced yet'));
    expect(api.days, isEmpty);

    // Back online, the app opened again: the kept total goes up.
    api.failure = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(text(tester, 'home.water.value'), '250 ml');
    await afterTaps(tester);
    expect(api.days['2026-11-08'], 250);
    expect(text(tester, 'home.water.line'), isNot(contains('not synced')));
  });

  testWidgets('the sheet adds other amounts and says how the target is set',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(key('home.water.value'));
    await tester.pumpAndSettle();
    expect(find.text('Water today'), findsOneWidget);
    await tester.tap(key('water.sheet.500'));
    await tester.tap(key('water.sheet.1000'));
    await tester.pump();
    expect(text(tester, 'water.sheet.total'), '1.5 L of 2.75 L');
    expect(text(tester, 'water.sheet.how'), contains('35 ml for each kg'));
    await afterTaps(tester);
    expect(api.days['2026-11-08'], 1500);
  });

  testWidgets('target reached says so', (tester) async {
    api.days['2026-11-08'] = 2750;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(text(tester, 'home.water.value'), '2.75 L');
    expect(text(tester, 'home.water.line'), 'Target reached · 2.75 L');
  });

  testWidgets('switched off by the admin: no card, and nothing is sent',
      (tester) async {
    await tester.pumpWidget(app(flags: const {'water': false}));
    await tester.pumpAndSettle();
    expect(key('home.water'), findsNothing);
    expect(api.calls.where((c) => c.startsWith('set:')), isEmpty);
  });
}
