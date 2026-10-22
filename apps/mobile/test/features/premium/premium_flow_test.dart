import 'package:fitos/app.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/premium/domain/premium.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_ai_api.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_premium_api.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 19 (ADR-027): FITOS Premium through the whole app — AI locked for a
/// free user with the request in its place, the gold rim, the pictures, the
/// weekly report and the colour themes.
void main() {
  late FakeAuthRepository auth;
  late AppDatabase db;
  late FakePremiumApi premium;
  late FakeWeeklyReportApi weekly;
  // FITOS AI switched on on the server (the default fake has it off).
  FakeAiApi? ai;

  setUp(() {
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
    db = AppDatabase.inMemory();
    premium = FakePremiumApi();
    weekly = FakeWeeklyReportApi();
    FitPalette.current = FitPalette.fitosDark;
    ai = null;
  });
  tearDown(() async {
    FitPalette.current = FitPalette.fitosDark;
    auth.dispose();
    await db.close();
  });

  Widget app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider
              .overrideWithValue(FakeOnboardingRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          ...workoutOverrides(
            db,
            FakeWorkoutApi(),
            premium: premium,
            weekly: weekly,
            ai: ai,
          ),
        ],
        child: const FitOSApp(),
      );

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('FITOS AI is premium', () {
    testWidgets(
        'a free user sees what Premium is on the AI tab, and asks for it; the request then waits',
        (tester) async {
      await start(tester);
      await tap(tester, 'nav.AI');
      expect(find.byKey(const ValueKey('ai.premium')), findsOneWidget);
      expect(find.text('FITOS AI is part of Premium'), findsOneWidget);
      final input =
          tester.widget<TextField>(find.byKey(const ValueKey('ai.input')));
      expect(input.enabled, isFalse);

      await tester.enterText(
        find.byKey(const ValueKey('premium.message')),
        'I train five days a week',
      );
      await tap(tester, 'premium.request');
      expect(premium.calls, contains('request:I train five days a week'));
      expect(find.byKey(const ValueKey('premium.pending')), findsOneWidget);
    });

    testWidgets('a premium user gets the chat, not the pitch', (tester) async {
      premium.premium = true;
      ai = FakeAiApi();
      await start(tester);
      await tap(tester, 'nav.AI');
      expect(find.byKey(const ValueKey('ai.premium')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai.input')))
            .enabled,
        isTrue,
      );
    });
  });

  group('the profile picture', () {
    testWidgets(
        'free: no gold rim; premium: the gold rim, on Home and in Profile',
        (tester) async {
      await start(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home.profile')),
          matching: find.byKey(const ValueKey('avatar.free')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('premium users wear the gold rim', (tester) async {
      premium.premium = true;
      await start(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home.profile')),
          matching: find.byKey(const ValueKey('avatar.premium')),
        ),
        findsOneWidget,
      );
      await tap(tester, 'home.profile');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile.avatar')),
          matching: find.byKey(const ValueKey('avatar.premium')),
        ),
        findsOneWidget,
      );
      expect(find.text('Premium is on.'), findsOneWidget);
    });

    testWidgets(
        'ten pictures: a free one is saved; a premium one is locked and opens Premium instead',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'profile.avatar');
      expect(find.byKey(const ValueKey('avatar.picker')), findsOneWidget);
      for (final id in [
        'dumbbell',
        'runner',
        'yoga',
        'cyclist',
        'swimmer',
        'boxer',
        'hiker',
        'crown',
        'flame',
        'trophy',
      ]) {
        expect(
          find.byKey(ValueKey('avatar.choice.$id')),
          findsOneWidget,
          reason: id,
        );
      }
      await tap(tester, 'avatar.choice.crown');
      expect(find.byKey(const ValueKey('premium.sheet')), findsOneWidget);
      expect(premium.calls.where((c) => c.startsWith('avatar:')), isEmpty);
      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();
      await tap(tester, 'avatar.choice.runner');
      expect(premium.calls, contains('avatar:runner'));
      expect(find.byKey(const ValueKey('avatar.picker')), findsNothing);
    });
  });

  group('the weekly report', () {
    testWidgets('free: locked on Progress, and the report screen shows Premium',
        (tester) async {
      await start(tester);
      await tap(tester, 'nav.Progress');
      expect(
        find.byKey(const ValueKey('progress.weekly.locked')),
        findsOneWidget,
      );
      await tap(tester, 'progress.weekly');
      expect(find.byKey(const ValueKey('weekly.premium')), findsOneWidget);
      expect(weekly.asked, isEmpty);
    });

    testWidgets('premium: this week, its highlights, and the weeks before',
        (tester) async {
      premium.premium = true;
      await start(tester);
      await tap(tester, 'nav.Progress');
      await tap(tester, 'progress.weekly');
      expect(find.text('This week so far'), findsOneWidget);
      expect(find.text('3 of 4 planned sessions.'), findsOneWidget);
      expect(find.text('-0.4 kg'), findsOneWidget);
      await tap(tester, 'weekly.prev');
      expect(weekly.asked.last, '2026-W42');
      expect(find.text('Week of 2026-10-19'), findsOneWidget);
    });
  });

  group('colour themes', () {
    testWidgets('free: Night is locked and opens Premium; FITOS Dark stays',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.night');
      expect(find.byKey(const ValueKey('premium.sheet')), findsOneWidget);
      expect(FitPalette.current.id, 'fitos-dark');
    });

    testWidgets('free: FITOS Light and Paper are open to everyone',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.fitos-light');
      expect(find.byKey(const ValueKey('premium.sheet')), findsNothing);
      expect(FitPalette.current.id, 'fitos-light');
      // A button style built once kept FITOS Dark's white: invisible on light.
      final changeGoal = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Change goal'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(
        changeGoal.style?.foregroundColor?.resolve(<WidgetState>{}),
        FitPalette.fitosLight.ink,
      );
      await tap(tester, 'theme.paper');
      expect(FitPalette.current.id, 'paper');
      // The type follows the palette (it once kept the first palette's ink).
      expect(
        Theme.of(tester.element(find.text('THEME'))).textTheme.bodyLarge?.color,
        FitPalette.paperPalette.ink,
      );
    });

    testWidgets(
        'premium: Night repaints the app in place; losing premium falls back to FITOS Dark',
        (tester) async {
      premium.premium = true;
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.night');
      expect(FitPalette.current.id, 'night');
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      final bg = scaffold.backgroundColor ??
          Theme.of(tester.element(find.byType(Scaffold).last))
              .scaffoldBackgroundColor;
      expect(bg, FitPalette.night.paper);
      // Night's type is Night's ink, and the tab bar is Night's canvas — the
      // two that left dark-on-dark and light-on-light before.
      final ctx = tester.element(find.byType(Scaffold).last);
      expect(Theme.of(ctx).textTheme.bodyLarge?.color, FitPalette.night.ink);
      expect(Theme.of(ctx).textTheme.labelSmall?.color, FitPalette.night.ink35);
      expect(
        find.byKey(const ValueKey('profile.theme')),
        findsOneWidget,
        reason: 'still on Profile',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final bar =
          tester.widget<Container>(find.byKey(const ValueKey('nav.bar')));
      expect(
        (bar.decoration! as BoxDecoration).color,
        FitPalette.night.paper.withValues(alpha: 0.88),
      );

      premium.premium = false;
      final container =
          ProviderScope.containerOf(tester.element(find.byType(FitOSApp)));
      container.invalidate(premiumStatusProvider);
      await tester.pumpAndSettle();
      expect(FitPalette.current.id, 'fitos-dark');
    });
  });

  test('perks name the four premium features', () {
    expect(
      kPremiumPerks.map((p) => p.$1),
      ['FITOS AI', 'Weekly report', 'Colour themes', 'Premium pictures'],
    );
  });
}
