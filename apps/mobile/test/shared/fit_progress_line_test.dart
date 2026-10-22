import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/shared/widgets/fit_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner 2026-10-22: onboarding shows a thin line at the top that fills in
/// the glow colour as each step is reached.
void main() {
  tearDown(() => FitPalette.current = FitPalette.fitosDark);

  Future<FractionallySizedBox> pumpLine(
    WidgetTester tester,
    int step,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FitProgressLine(step: step, total: 7)),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('flow.progress')),
        matching: find.byType(FractionallySizedBox),
      ),
    );
  }

  testWidgets('fills to the step reached: 1 of 7, 4 of 7, 7 of 7',
      (tester) async {
    expect((await pumpLine(tester, 1)).widthFactor, closeTo(1 / 7, 1e-9));
    expect((await pumpLine(tester, 4)).widthFactor, closeTo(4 / 7, 1e-9));
    expect((await pumpLine(tester, 7)).widthFactor, 1);
  });

  testWidgets('it is a 3 px line in the palette glow (lime on FITOS Dark)',
      (tester) async {
    await pumpLine(tester, 2);
    expect(
      tester.getSize(find.byKey(const ValueKey('flow.progress'))).height,
      3,
    );
    final fill = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (fill.decoration as BoxDecoration).color,
      FitPalette.fitosDark.glow,
    );
    expect(FitPalette.fitosDark.glow, const Color(0xFFC6F432));
  });
}
