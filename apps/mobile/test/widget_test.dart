import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitos/app.dart';
import 'package:fitos/core/theme/tokens.dart';

void main() {
  testWidgets('renders the placeholder on the paper ground', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitOSApp()));
    await tester.pumpAndSettle();

    expect(find.text('FITOS'), findsOneWidget);
    expect(find.text('Phase 0'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(
      scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
      FitColors.paper,
    );
  });

  testWidgets('uses ink, not colour, for the primary type', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitOSApp()));
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.text('Phase 0'));
    final context = tester.element(find.text('Phase 0'));
    final style = heading.style ?? Theme.of(context).textTheme.displayMedium!;
    expect(style.color, FitColors.ink);
  });
}
