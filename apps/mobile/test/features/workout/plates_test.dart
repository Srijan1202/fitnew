import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/workout/domain/plates.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/widgets/plate_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beta 6.4 (N3, owner Q2): the plates on each side, for the gym's own bar
/// and plates.
void main() {
  const std = GymPlates.standard;

  test('the fewest plates per side, heaviest first', () {
    expect(platesFor(100, std).load.perSide, [25, 15]);
    expect(platesFor(100, std).exact, isTrue);
    expect(platesFor(60, std).load.perSide, [20]);
    expect(platesFor(62.5, std).load.perSide, [20, 1.25]);
    expect(platesFor(142.5, std).load.perSide, [25, 25, 10, 1.25]);
    expect(platesFor(20, std).load.perSide, isEmpty);
    expect(platesFor(20, std).exact, isTrue);
  });

  test('a weight that cannot be made says the nearest below and above', () {
    final a = platesFor(61, std);
    expect(a.exact, isFalse);
    expect(a.load.totalKg, 60);
    expect([a.below, a.above], [60, 62.5]);
    // Lighter than the bar: the bar.
    final b = platesFor(15, std);
    expect([b.exact, b.below, b.above, b.load.totalKg], [false, null, 20, 20]);
    // Without 1.25s, 62.5 is out of reach.
    final noSmall = std.copyWith(plates: [25, 20, 15, 10, 5, 2.5]);
    final c = platesFor(62.5, noSmall);
    expect([c.exact, c.below, c.above], [false, 60, 65]);
  });

  test('the gym’s bar and odd plates', () {
    final gym = std.copyWith(barKg: 15, plates: [20, 10, 2]);
    expect(platesFor(59, gym).load.perSide, [20, 2]);
    expect(platesFor(59, gym).exact, isTrue);
    // 4 kg a side is 2 + 2.
    expect(platesFor(23, gym).load.perSide, [2, 2]);
  });

  test(
      'settings: kept sorted, unknown sizes dropped, the standard set by '
      'default', () {
    final g = GymPlates.fromJson({
      'barKg': 15,
      'plates': [5, 25, 7, 5],
    });
    expect(g.barKg, 15);
    expect(g.plates, [25, 5]);
    expect(GymPlates.fromJson({'barKg': 12}).barKg, 20);
    expect(GymPlates.fromJson(const {}).plates, kStandardPlates);
    expect(GymPlates.fromJson(g.toJson()).plates, [25, 5]);
    expect(std.summary, '20 kg bar · 7 plates');
    expect(std.copyWith(plates: [25]).summary, '20 kg bar · 1 plate');
  });

  test('kilograms in words', () {
    expect([60, 62.5, 1.25, 0.5].map((x) => kgText(x.toDouble())).toList(), [
      '60',
      '62.5',
      '1.25',
      '0.5',
    ]);
  });

  testWidgets(
      'the sheet: the plates drawn, steps of 2.5 kg, and the gym changed '
      'from it (kept)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((_) async => prefs),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlateSheet(context, kg: 100),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    Finder key(String k) => find.byKey(ValueKey(k));
    expect(
      tester.widget<Text>(key('plates.answer')).data,
      '20 kg bar + 25 + 15 each side',
    );
    // Heaviest by the collar, on both sides.
    expect(key('plates.left.0.25'), findsOneWidget);
    expect(key('plates.right.1.15'), findsOneWidget);
    await tester.tap(key('plates.more'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(key('plates.kg')).data, '102.5 kg');
    expect(
      tester.widget<Text>(key('plates.answer')).data,
      '20 kg bar + 25 + 15 + 1.25 each side',
    );
    expect(key('plates.notExact'), findsNothing);

    // The gym has no 1.25s: 102.5 cannot be made.
    await tester.tap(key('plates.gym'));
    await tester.pumpAndSettle();
    await tester.tap(key('plates.size.1.25'));
    await tester.pumpAndSettle();
    await tester.tap(key('plates.bar.15'));
    await tester.pumpAndSettle();
    expect(prefs.getString(GymPlatesController.key), contains('"barKg":15'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(key('plates.notExact')).data,
      "102.5 kg can't be made with your plates. Nearest: 100 kg or 105 kg.",
    );
  });
}
