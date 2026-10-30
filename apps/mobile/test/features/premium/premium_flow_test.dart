import 'package:fitos/app.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/theme_controller.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/premium/domain/app_icons.dart';
import 'package:fitos/features/premium/domain/streak_rewards.dart';
import 'package:fitos/features/running/domain/efforts.dart';
import 'package:fitos/features/home/data/streak_api.dart';
import 'package:fitos/features/premium/domain/premium.dart';
import 'package:fitos/features/premium/presentation/app_icon_controller.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:fitos/features/premium/presentation/rewards_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/shared/widgets/fit_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    FitPalette.current = FitPalette.dark;
    FitPalette.followsDevice = true;
    ai = null;
    icons = null;
    meta = null;
    rewards = FakeRewardsApi();
    streak = FakeStreakApi();
  });
  tearDown(() async {
    FitPalette.current = FitPalette.dark;
    FitPalette.followsDevice = true;
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
    testWidgets(
        'owner 2026-10-30: Automatic is the default — Dark in dark mode, Light in light mode, following a switch of the phone; choosing a theme pins it; Cobalt is free',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.auto');
      expect(FitPalette.current.id, 'dark');
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(FitPalette.current.id, 'light');

      await tap(tester, 'theme.cobalt');
      expect(find.byKey(const ValueKey('premium.sheet')), findsNothing);
      expect(FitPalette.current.id, 'cobalt');
      // Pinned: the phone's mode no longer moves it.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(FitPalette.current.id, 'cobalt');
      expect(
        (await SharedPreferences.getInstance()).getString(kThemePreference),
        'cobalt',
      );

      await tap(tester, 'theme.auto');
      expect(FitPalette.current.id, 'dark');
      expect(
        (await SharedPreferences.getInstance()).getString(kThemePreference),
        isNull,
      );
    });

    testWidgets('free: Night is locked and opens Premium; FITOS Dark stays',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.night');
      expect(find.byKey(const ValueKey('premium.sheet')), findsOneWidget);
      expect(FitPalette.current.id, 'dark');
    });

    testWidgets('free: FITOS Light is open to everyone; Paper is gone',
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
      // The type follows the palette (it once kept the first palette's ink).
      expect(
        Theme.of(tester.element(find.text('THEME'))).textTheme.bodyLarge?.color,
        FitPalette.fitosLight.ink,
      );
      // Owner 2026-10-30: Paper is no longer offered; a phone that kept it
      // opens on Automatic.
      expect(find.byKey(const ValueKey('theme.paper')), findsNothing);
      expect(FitPalette.byId('paper'), isNull);
    });

    testWidgets(
        'premium: Night repaints the app in place; losing premium falls back to FITOS Dark',
        (tester) async {
      premium.premium = true;
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.night');
      expect(FitPalette.current.id, 'night');
      // The page's canvas (FitCanvas): the Scaffolds above it are clear.
      final canvas = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(FitCanvas).last,
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(canvas.color, FitPalette.night.paper);
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
      // Back to Automatic: Light with the test's light mode.
      expect(FitPalette.current.id, 'light');
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
      expect(FitPalette.current.id, 'dark');

      rewards.rewards = {StreakReward.emberTheme};
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)))
          .invalidate(earnedRewardsProvider);
      await tester.pumpAndSettle();
      await tap(tester, 'theme.ember');
      expect(FitPalette.current.id, 'ember');
    });

    testWidgets(
        'owner 2026-10-30: the admin unlocks every reward theme, icon, picture and rim for testing; the count stays what was earned; locked again, the phone goes back',
        (tester) async {
      rewards.unlocked = true;
      await start(tester);
      await tap(tester, 'home.profile');
      // Nothing earned, yet the streak and running themes open.
      await tap(tester, 'theme.ember');
      expect(FitPalette.current.id, 'ember');
      await tap(tester, 'theme.mileage');
      expect(FitPalette.current.id, 'mileage');
      expect(find.byKey(const ValueKey('profile.emberRim')), findsOneWidget);
      expect(
        tester
            .widget<FitRow>(find.byKey(const ValueKey('profile.rewards')))
            .value,
        '0 of ${StreakReward.values.length + RunBadge.values.length}',
      );

      rewards.unlocked = false;
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)))
          .invalidate(rewardsUnlockAllProvider);
      await tester.pumpAndSettle();
      expect(FitPalette.current.id, 'light');
      expect(find.byKey(const ValueKey('profile.emberRim')), findsNothing);
    });

    testWidgets(
        'beta 4.2: the Road theme opens with a first half marathon, and a phone that has it but not the badge goes back to FITOS Dark',
        (tester) async {
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'theme.road');
      expect(
        find.text(RunBadge.firstHalf.unlockHowTo!),
        findsOneWidget,
      );
      expect(FitPalette.current.id, 'dark');

      rewards.badgesEarned = {
        RunBadge.firstHalf: DateTime.utc(2026, 10, 20),
      };
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)))
          .invalidate(earnedBadgesProvider);
      await tester.pumpAndSettle();
      await tap(tester, 'theme.road');
      expect(FitPalette.current.id, 'road');

      // Another account on the phone, without the badge.
      rewards.badgesEarned = {};
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)))
          .invalidate(earnedBadgesProvider);
      await tester.pumpAndSettle();
      expect(FitPalette.current.id, 'light');
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
      rewards.badgesEarned = {
        RunBadge.firstRun: DateTime.utc(2026, 10, 1),
      };
      await start(tester);
      await tap(tester, 'home.profile');
      await tap(tester, 'profile.rewards');
      String status(String id) =>
          tester.widget<Text>(find.byKey(ValueKey('rewards.$id.status'))).data!;
      expect(
        status('ember-theme'),
        'Unlocks at a 14-day streak: 4 more days than your best',
      );
      // Beta 4.8 (owner): a reward shows what it unlocks, with a lock on top
      // until earned — here the Ember theme's colours.
      expect(
        find.byKey(const ValueKey('reward.art.ember-theme')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reward.art.ember-theme.lock')),
        findsOneWidget,
      );
      // Beta 4.3: one page for every reward — the running badges, and what
      // Premium includes.
      expect(status('first-run'), startsWith('Earned'));
      expect(
        find.byKey(const ValueKey('reward.art.first-run.lock')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rewards.first-half.status')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('rewards.list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        status('first-half'),
        'Run a half marathon in one go to unlock it.',
      );
      expect(find.text('First half marathon · The Road theme'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('rewards.count'))).data,
        '1 of 25 earned',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rewards.premium.icons.status')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('rewards.list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        status('premium.icons'),
        'With Premium · Gold, Glow, Lime',
      );
    });

    testWidgets(
        'beta 4.8 (owner): the streak card opens Streak & rewards: the streak, the best, this week, and the month calendar with every day of the month, back to the joining month',
        (tester) async {
      // Joined 21 September; today is 29 October.
      final calendar = [
        for (var d = DateTime.utc(2026, 9);
            !d.isAfter(DateTime.utc(2026, 10, 29));
            d = d.add(const Duration(days: 1)))
          StreakDay(
            d.toIso8601String().substring(0, 10),
            d.isBefore(DateTime.utc(2026, 9, 21))
                ? StreakDayStatus.before
                : d.weekday == DateTime.sunday
                    ? StreakDayStatus.rest
                    : d.day == 14
                        ? StreakDayStatus.missed
                        : StreakDayStatus.logged,
          ),
      ];
      streak.next = Streak(
        current: 5,
        best: 12,
        todayCounted: true,
        weekDone: 2,
        weekPlanned: 4,
        calendar: calendar,
      );
      await start(tester);
      await tap(tester, 'home.streak');
      expect(find.text('Streak & rewards'), findsOneWidget);
      String text(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      BoxDecoration box(String date) => tester
          .widget<Container>(find.byKey(ValueKey('streak.day.$date')))
          .decoration! as BoxDecoration;
      expect(text('streak.current'), '5-day streak');
      expect(text('streak.best'), 'Best: 12 days');
      expect(text('streak.week'), '2/4');
      // This month, every day of it: the 30th and 31st still to come.
      expect(text('streak.grid.range'), 'October 2026');
      expect(text('streak.day.2026-10-01.date'), '1');
      expect(text('streak.day.2026-10-31.date'), '31');
      expect(box('2026-10-31').color, Colors.transparent);
      // A Sunday rest day is green (the rest colour), not the logged one.
      expect(box('2026-10-25').color, isNot(FitColors.accent));
      expect(box('2026-10-26').color, FitColors.accent);
      // Missed is an outline, never a fill.
      expect(box('2026-10-14').color, Colors.transparent);
      expect(box('2026-10-14').border, isNotNull);
      // The month before, back to the joining month; no further.
      await tap(tester, 'streak.month.prev');
      expect(text('streak.grid.range'), 'September 2026');
      expect(text('streak.day.2026-09-01.date'), '1');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('streak.month.prev')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'streak.month.next');
      expect(text('streak.grid.range'), 'October 2026');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('streak.month.next')))
            .onPressed,
        isNull,
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
