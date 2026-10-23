import 'package:fitos/app.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/premium/domain/app_icons.dart';
import 'package:fitos/features/premium/domain/streak_rewards.dart';
import 'package:fitos/features/home/data/streak_api.dart';
import 'package:fitos/features/premium/domain/premium.dart';
import 'package:fitos/features/premium/presentation/app_icon_controller.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:fitos/features/premium/presentation/rewards_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_ai_api.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_rewards_api.dart';
import '../../support/fake_streak_api.dart';
import '../../support/fake_app_icon_switcher.dart';
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
  // Beta 3.2: a phone whose launcher icon can change (null: the default
  // switcher, which finds no Android channel under test).
  FakeAppIconSwitcher? icons;
  // Beta 3.3 (ADR-033): the server's feature switches.
  FakeMetaApi? meta;
  // Beta 3.4: streak rewards earned, and the streak (with new rewards).
  late FakeRewardsApi rewards;
  late FakeStreakApi streak;

  setUp(() {
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
    db = AppDatabase.inMemory();
    premium = FakePremiumApi();
    weekly = FakeWeeklyReportApi();
    FitPalette.current = FitPalette.fitosDark;
    ai = null;
    icons = null;
    meta = null;
    rewards = FakeRewardsApi();
    streak = FakeStreakApi();
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
            meta: meta,
            rewards: rewards,
            streak: streak,
          ),
          if (icons != null) appIconSwitcherProvider.overrideWithValue(icons!),
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
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('profile.premium.line')))
            .data,
        'Active',
      );
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
    testWidgets('switched off by the admin: no entry on Progress (ADR-033)',
        (tester) async {
      premium.premium = true;
      meta = FakeMetaApi(flags: {'weekly-report': false});
      await start(tester);
      await tap(tester, 'nav.Progress');
      expect(find.byKey(const ValueKey('progress.weekly')), findsNothing);
    });

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
        find.byKey(const ValueKey('profile.changeGoal')),
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

  group('app icons (beta 3.2)', () {
    testWidgets('a phone where the icon cannot change shows no picker',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      expect(find.byKey(const ValueKey('profile.theme')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile.appIcon')), findsNothing);
    });

    testWidgets('free: Gold is locked and opens Premium; White is open',
        (tester) async {
      icons = FakeAppIconSwitcher();
      await start(tester);
      await tap(tester, 'home.profile');
      expect(find.text('APP ICON'), findsOneWidget);
      await tap(tester, 'appIcon.gold');
      expect(find.byKey(const ValueKey('premium.sheet')), findsOneWidget);
      expect(icons!.chosen, isEmpty);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tap(tester, 'appIcon.white');
      expect(icons!.chosen, [AppIcon.white]);
    });

    testWidgets('a refusal says so and keeps the icon', (tester) async {
      icons = FakeAppIconSwitcher()..refuse = true;
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'appIcon.white');
      expect(find.text('Your phone did not change the icon.'), findsOneWidget);
      expect(icons!.icon, AppIcon.standard);
    });

    testWidgets('premium: Gold is chosen; losing premium goes back to Standard',
        (tester) async {
      premium.premium = true;
      icons = FakeAppIconSwitcher();
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'appIcon.gold');
      expect(find.byKey(const ValueKey('premium.sheet')), findsNothing);
      expect(icons!.icon, AppIcon.gold);

      premium.premium = false;
      final container =
          ProviderScope.containerOf(tester.element(find.byType(FitOSApp)));
      container.invalidate(premiumStatusProvider);
      await tester.pumpAndSettle();
      expect(icons!.chosen, [AppIcon.gold, AppIcon.standard]);
    });
  });

  group('streak rewards (beta 3.4)', () {
    testWidgets(
        'earned pictures are open, unearned ones say how to earn them; nothing goes to Premium',
        (tester) async {
      rewards.rewards = {StreakReward.spark};
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'profile.avatar');
      await tap(tester, 'avatar.choice.century');
      expect(find.text(StreakReward.century.howToEarn), findsOneWidget);
      expect(find.byKey(const ValueKey('premium.sheet')), findsNothing);
      await tap(tester, 'avatar.choice.spark');
      expect(premium.calls, contains('avatar:spark'));
    });

    testWidgets(
        'the Ember theme: locked until earned, then chosen like any other',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.ember');
      expect(find.text(StreakReward.emberTheme.howToEarn), findsOneWidget);
      expect(FitPalette.current.id, 'fitos-dark');

      rewards.rewards = {StreakReward.emberTheme};
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)))
          .invalidate(earnedRewardsProvider);
      await tester.pumpAndSettle();
      await tap(tester, 'theme.ember');
      expect(FitPalette.current.id, 'ember');
    });

    testWidgets(
        'Profile lists every reward with what is left; the Ember rim shows once earned and can be switched off; the 100-day badge',
        (tester) async {
      rewards.rewards = {
        StreakReward.spark,
        StreakReward.emberTheme,
        StreakReward.blazeIcon,
        StreakReward.emberRim,
        StreakReward.century,
      };
      streak.next = const Streak(
        current: 3,
        best: 101,
        todayCounted: true,
        weekDone: null,
        weekPlanned: null,
      );
      await start(tester);
      expect(find.byKey(const ValueKey('avatar.ember')), findsOneWidget);
      await tap(tester, 'home.profile');
      expect(
        find.byKey(const ValueKey('profile.centuryBadge')),
        findsOneWidget,
      );
      await tap(tester, 'profile.emberRim.switch');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('avatar.ember')), findsNothing);

      await tap(tester, 'home.profile');
      await tap(tester, 'profile.rewards');
      for (final r in StreakReward.values) {
        expect(
          tester
              .widget<Text>(find.byKey(ValueKey('rewards.${r.id}.status')))
              .data,
          'Earned',
        );
      }
    });

    testWidgets('what is left is counted from the best streak', (tester) async {
      streak.next = const Streak(
        current: 2,
        best: 10,
        todayCounted: true,
        weekDone: null,
        weekPlanned: null,
      );
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'profile.rewards');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('rewards.ember-theme.status')),
            )
            .data,
        '4 more days than your best',
      );
    });

    testWidgets('new rewards are celebrated once on Home', (tester) async {
      rewards.rewards = {StreakReward.spark};
      streak.next = const Streak(
        current: 7,
        best: 7,
        todayCounted: true,
        weekDone: null,
        weekPlanned: null,
        newRewards: ['spark'],
      );
      await start(tester);
      expect(find.byKey(const ValueKey('rewards.celebrate')), findsOneWidget);
      expect(find.text('• Spark picture'), findsOneWidget);
      await tap(tester, 'rewards.celebrate.ok');
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)))
          .invalidate(streakProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rewards.celebrate')), findsNothing);
    });
  });

  test('perks name the four premium features', () {
    expect(
      kPremiumPerks.map((p) => p.$1),
      ['FITOS AI', 'Weekly report', 'Themes and app icons', 'Premium pictures'],
    );
  });
}
