import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/presentation/screens/goal_editor_screen.dart';
import 'package:fitos/features/profile/presentation/screens/targets_editor_screen.dart';
import 'package:fitos/features/profile/presentation/widgets/targets_display.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_profile_repository.dart';

/// Beta 3.2 (ADR-031): set your own calories and protein. The limits and
/// FITOS's suggestion are the server's; the carbs and fat before saving are
/// a preview of FITOS's split; the save answers with the targets and any
/// warnings; "Use FITOS's suggestion" goes back.
void main() {
  late FakeProfileRepository profile;

  setUp(() {
    profile = FakeProfileRepository();
    final p = profile.nextProfile;
    if (p is Ok<UserProfileDetail>) {
      profile.nextProfile = Ok(p.value.copyWith(latestWeightKg: 70.0));
    }
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(String initial) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: Routes.profile,
          builder: (_, __) => const Scaffold(body: Text('PROFILE')),
          routes: [
            GoRoute(
              path: 'targets',
              builder: (_, __) => const TargetsEditorScreen(),
            ),
            GoRoute(path: 'goal', builder: (_, __) => const GoalEditorScreen()),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;
  String value(WidgetTester tester, String prefix) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('$prefix.value')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets(
      'opens on the targets in effect with FITOS’s suggestion, the limits and a preview of the split; steppers change it; Save sends calories and protein and shows the targets and warnings',
      (tester) async {
    tall(tester);
    profile.customWarnings = const [
      '29 % above FITOS\'s suggestion of 2276 kcal.',
    ];
    await tester.pumpWidget(app(Routes.targetsEditor));
    await tester.pumpAndSettle();

    expect(value(tester, 'targets.kcal'), '2276');
    expect(value(tester, 'targets.protein'), '106');
    expect(
      text(tester, 'targets.suggestion'),
      'FITOS suggests 2276 kcal · 106 g protein',
    );
    // fat = max(0.8 × 70 = 56, 2276 × 0.22 / 9 = 55.6) → 56; carbs = (2276 − 424 − 504) / 4 = 337.
    expect(text(tester, 'targets.split'), '≈ 337 g carbs · 56 g fat');
    expect(find.textContaining('Limits: 1200–6000 kcal'), findsOneWidget);
    // FITOS's own targets: nothing to reset.
    expect(find.byKey(const ValueKey('targets.reset')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('targets.kcal.plus')));
    await tester.tap(find.byKey(const ValueKey('targets.protein.plus')));
    await tester.pump();
    expect(value(tester, 'targets.kcal'), '2326');
    expect(value(tester, 'targets.protein'), '111');

    await tester.tap(find.byKey(const ValueKey('targets.save')));
    await tester.pumpAndSettle();
    expect(profile.customSaves, [(2326, 111)]);
    expect(find.byKey(const ValueKey('targets.yours')), findsOneWidget);
    expect(
      text(tester, 'targets.warning.0'),
      '29 % above FITOS\'s suggestion of 2276 kcal.',
    );
    // Now custom: the way back is offered.
    expect(find.byKey(const ValueKey('targets.reset')), findsOneWidget);
  });

  testWidgets(
      'typing a value clamps to the limits; protein that does not fit the calories says so and Save waits',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(app(Routes.targetsEditor));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('targets.kcal.value')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('targets.kcal.field')),
      '900',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value(tester, 'targets.kcal'), '1200'); // clamped up to the minimum

    await tester.tap(find.byKey(const ValueKey('targets.protein.value')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('targets.protein.field')),
      '500',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      value(tester, 'targets.protein'),
      '191',
    ); // clamped down to the maximum
    // 191 g protein (764 kcal) + the 56 g fat floor (504 kcal) > 1200 kcal.
    expect(
      text(tester, 'targets.split'),
      startsWith(
        'That much protein and the minimum fat don’t fit in 1200 kcal',
      ),
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('targets.save')))
          .onPressed,
      isNull,
    );
    expect(profile.customSaves, isEmpty);
  });

  testWidgets('a custom target: "Use FITOS’s suggestion" goes back and says so',
      (tester) async {
    tall(tester);
    await profile.setCustomTargets(kcal: 2000, proteinG: 150);
    await tester.pumpWidget(app(Routes.targetsEditor));
    await tester.pumpAndSettle();
    expect(value(tester, 'targets.kcal'), '2000');
    await tester.tap(find.byKey(const ValueKey('targets.reset')));
    await tester.pumpAndSettle();
    expect(profile.resets, 1);
    expect(find.byKey(const ValueKey('targets.resetDone')), findsOneWidget);
    expect(value(tester, 'targets.kcal'), '2276');
  });

  testWidgets(
      'the goal editor warns that a new goal replaces your own target; FITOS’s targets get no warning',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(app(Routes.goalEditor));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goal.customNote')), findsNothing);

    await profile.setCustomTargets(kcal: 2000, proteinG: 150);
    await tester.pumpWidget(Container());
    await tester.pumpWidget(app(Routes.goalEditor));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goal.customNote')), findsOneWidget);
  });

  testWidgets('targets display: "YOUR TARGET" on custom targets only',
      (tester) async {
    Widget show(bool custom) => MaterialApp(
          theme: FitTheme.build(),
          home: Scaffold(
            body: TargetsDisplay(
              targets:
                  personaCTargets.copyWith(source: custom ? 'custom' : 'fitos'),
            ),
          ),
        );
    await tester.pumpWidget(show(false));
    expect(find.byKey(const ValueKey('targets.yours')), findsNothing);
    await tester.pumpWidget(show(true));
    expect(find.byKey(const ValueKey('targets.yours')), findsOneWidget);
  });
}
