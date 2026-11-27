import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/shared/widgets/fit_action_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 6.7 (A1, A4): a card's actions on one line, the rest in a menu;
/// chosen chips in the accent.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: FitTheme.build(),
        home: Scaffold(body: child),
      );

  testWidgets('two buttons on the line, the rest in the ⋯ menu',
      (tester) async {
    final tapped = <String>[];
    FitAction a(String l, {bool d = false}) =>
        FitAction(l, () => tapped.add(l), key: ValueKey(l), destructive: d);
    await tester.pumpWidget(
      host(FitActionRow(actions: [a('one'), a('two'), a('three', d: true)])),
    );
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsNothing);

    await tester.tap(find.text('two'));
    await tester.tap(find.byKey(const ValueKey('actions.more')));
    await tester.pumpAndSettle();
    final three = tester.widget<Text>(find.text('three'));
    expect(three.style?.color, FitColors.oxide);
    await tester.tap(find.text('three'));
    await tester.pumpAndSettle();
    expect(tapped, ['two', 'three']);
  });

  testWidgets('no menu with two or fewer; nothing at all with none',
      (tester) async {
    await tester.pumpWidget(
      host(
        FitActionRow(
          actions: [FitAction('only', () {}, key: const ValueKey('only'))],
        ),
      ),
    );
    expect(find.byKey(const ValueKey('actions.more')), findsNothing);
    await tester.pumpWidget(host(const FitActionRow(actions: [])));
    expect(find.byType(TextButton), findsNothing);
  });

  test('a chosen chip is in the accent, its label on the accent', () {
    final chips = FitTheme.build().chipTheme;
    expect(chips.selectedColor, FitColors.accent);
    final label = chips.labelStyle!.color! as WidgetStateColor;
    expect(label.resolve({WidgetState.selected}), FitColors.onAccent);
    expect(label.resolve({}), FitColors.ink);
  });
}
