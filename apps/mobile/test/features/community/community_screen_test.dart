import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/club_screen.dart';
import 'package:fitos/features/community/presentation/community_providers.dart';
import 'package:fitos/features/community/presentation/community_screen.dart';
import 'package:fitos/features/community/presentation/community_settings_screen.dart';
import 'package:fitos/features/privacy/presentation/policy_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_community_api.dart';

/// Beta 5.8 (ADR-057): Community on the phone — joining says what is and is
/// never shared and sends the consent's policy version; Friends | Clubs |
/// World; requests answered; boards with your row marked; the world board
/// only by choice; clubs; blocking and reporting; leaving; the admin's
/// switch off.
void main() {
  late FakeCommunityApi api;

  CommunityProfile me({bool onWorld = false, String? country = 'IN'}) =>
      CommunityProfile(
        handle: 'srijan',
        avatarId: null,
        country: country,
        onWorld: onWorld,
        joinedAt: DateTime.utc(2026, 11, 8),
      );

  setUp(() => api = FakeCommunityApi());

  Widget app() {
    final router = GoRouter(
      initialLocation: Routes.community,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
        GoRoute(
          path: Routes.community,
          builder: (_, __) => const CommunityScreen(),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (_, __) => const CommunitySettingsScreen(),
            ),
            GoRoute(
              path: 'clubs/:id',
              builder: (_, s) => ClubScreen(
                clubId: s.pathParameters['id']!,
                club: s.extra is Club ? s.extra! as Club : null,
              ),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        communityApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tap(WidgetTester tester, String k) async {
    if (key(k).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        key(k),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
    }
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'not joined: what others see and what is never shared; the handle is '
      'checked; joining sends it plain with the policy version, off the world '
      'board unless chosen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(key('community.join'), findsOneWidget);
    expect(find.text('What others see'), findsOneWidget);
    expect(
      find.textContaining('Weights, food, body measurements'),
      findsOneWidget,
    );
    expect(key('community.settings'), findsNothing);

    await tester.enterText(key('community.join.handle'), 'a b');
    await tap(tester, 'community.join.submit');
    expect(find.text('Use 3–20 letters, numbers or _.'), findsOneWidget);
    expect(api.calls, isEmpty);

    api.joinFailure = const Conflict('taken', path: 'handle', issue: 'taken');
    await tester.enterText(key('community.join.handle'), '@Srijan');
    await tap(tester, 'community.join.submit');
    expect(find.text('That handle is taken.'), findsOneWidget);

    api.joinFailure = null;
    await tap(tester, 'community.join.country');
    await tester.enterText(key('community.country.search'), 'Germ');
    await tester.pumpAndSettle();
    await tester.tap(key('community.country.DE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Germany'), findsOneWidget);
    await tap(tester, 'community.join.submit');
    expect(api.calls, contains('join srijan DE false $kPolicyVersion'));
    expect(key('community.tab'), findsOneWidget);
    expect(key('community.settings'), findsOneWidget);
  });

  testWidgets(
      'friends: a request answered; the board with your row marked; run km '
      'instead of sessions', (tester) async {
    api
      ..profile = me()
      ..lists = FriendLists(
        friends: [person('ana')],
        incoming: [person('ben')],
        outgoing: [person('cara')],
      )
      ..board = (metric, _) => Board(
            metric: metric,
            weekFrom: '2026-11-02',
            weekTo: '2026-11-08',
            rows: [
              row(1, 'ana', sessions: 4, runM: 12400, streak: 9),
              row(2, 'srijan', sessions: 3, me: true, country: 'IN'),
            ],
            me: null,
            total: 2,
          );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Friends · 1'), findsOneWidget);
    expect(key('community.incoming.ben'), findsOneWidget);
    expect(key('community.outgoing.cara'), findsOneWidget);
    expect(find.textContaining('@srijan (you)'), findsOneWidget);
    expect(
      tester.widget<Text>(key('community.value.ana')).data,
      '4 sessions',
    );
    expect(find.textContaining('9-day streak'), findsOneWidget);
    await tap(tester, 'community.accept.ben');
    expect(api.calls, contains('accept u-ben'));
    expect(key('community.incoming.ben'), findsNothing);

    await tap(tester, 'community.metric.distance');
    expect(tester.widget<Text>(key('community.value.ana')).data, '12.4 km');
    expect(api.calls, contains('friends-board distance'));
  });

  testWidgets('add a friend by handle: search, then Add', (tester) async {
    api
      ..profile = me()
      ..found = [person('dev_lifts'), person('devika')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.addFriend');
    await tester.enterText(key('community.add.search'), '@Dev');
    await tester.pumpAndSettle();
    expect(api.calls, contains('search dev'));
    expect(key('community.found.devika'), findsOneWidget);
    await tester.tap(key('community.add.devika'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('add devika'));
    expect(find.text('Request sent to @devika.'), findsOneWidget);
  });

  testWidgets('someone on a board: block or report them', (tester) async {
    api
      ..profile = me()
      ..board = (metric, _) => Board(
            metric: metric,
            weekFrom: '2026-11-02',
            weekTo: '2026-11-08',
            rows: [row(1, 'rude_one', sessions: 7), row(2, 'srijan', me: true)],
            me: null,
            total: 2,
          );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // Your own row opens nothing.
    await tester.tap(key('community.row.srijan'));
    await tester.pumpAndSettle();
    expect(key('community.person.block'), findsNothing);
    await tester.tap(key('community.row.rude_one'));
    await tester.pumpAndSettle();
    await tester.tap(key('community.person.report'));
    await tester.pumpAndSettle();
    expect(key('community.report.club-name'), findsNothing);
    await tester.tap(key('community.report.cheating'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('report u-rude_one cheating'));
    await tester.tap(key('community.row.rude_one'));
    await tester.pumpAndSettle();
    await tester.tap(key('community.person.block'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('block u-rude_one'));
  });

  testWidgets(
      'the world board: seen without being on it, joined by choice; '
      'everywhere or your country', (tester) async {
    api.profile = me();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.tab.world');
    expect(key('community.world.off'), findsOneWidget);
    expect(api.calls, contains('world-board sessions all'));
    await tap(tester, 'community.world.join');
    expect(api.calls, contains('update   true'));
    expect(key('community.world.off'), findsNothing);
    await tap(tester, 'community.world.country');
    expect(api.calls, contains('world-board sessions IN'));
  });

  testWidgets('clubs: make one and land on it with its code; leave it',
      (tester) async {
    api.profile = me();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.tab.clubs');
    expect(key('community.clubs.empty'), findsOneWidget);
    await tap(tester, 'community.club.new');
    await tester.enterText(key('community.club.field'), "VIT Men's Hostel");
    await tap(tester, 'community.club.ok');
    expect(api.calls, contains("club VIT Men's Hostel"));
    expect(tester.widget<Text>(key('club.code')).data, 'ABCD-2345');
    expect(api.calls, contains('club-board club-1 sessions'));
    await tap(tester, 'club.menu');
    await tester.tap(find.text('Leave the club'));
    await tester.pumpAndSettle();
    await tap(tester, 'club.leave.confirm');
    expect(api.calls, contains('leave-club club-1'));
  });

  testWidgets(
      'settings: unblock, the world switch, and leaving after a confirmation',
      (tester) async {
    api
      ..profile = me(onWorld: true)
      ..blockedPeople = [person('rude_one')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.settings');
    expect(find.text('@srijan'), findsOneWidget);
    await tap(tester, 'communitySettings.unblock.rude_one');
    expect(api.calls, contains('unblock u-rude_one'));
    await tap(tester, 'communitySettings.worldSwitch');
    expect(api.calls, contains('update   false'));
    await tap(tester, 'communitySettings.leave');
    await tap(tester, 'communitySettings.leave.confirm');
    expect(api.calls, contains('leave'));
  });

  testWidgets("the admin's switch off: said plainly", (tester) async {
    api.failure = const Forbidden('off', issue: 'feature-off');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(key('community.problem')).data,
      'Community is switched off for now.',
    );
  });
}
