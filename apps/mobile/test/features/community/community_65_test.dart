import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/club_screen.dart';
import 'package:fitos/features/community/presentation/community_providers.dart';
import 'package:fitos/features/community/presentation/community_screen.dart';
import 'package:fitos/features/community/presentation/community_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_community_api.dart';

/// Beta 6.5 (Clubs together): the feed on from joining (K0), and a club's
/// feed beside its board (K1).
void main() {
  late FakeCommunityApi api;

  const club = Club(
    id: 'club-1',
    name: 'VIT Lifters',
    code: 'ABCD2345',
    members: 3,
    mine: false,
  );

  CommunityProfile me({Set<FeedKind> feed = const {...FeedKind.values}}) =>
      CommunityProfile(
        handle: 'srijan',
        avatarId: null,
        country: 'IN',
        onWorld: false,
        joinedAt: DateTime.utc(2026, 11, 8),
        feed: feed,
      );

  FeedPost post(String id, String h, {bool mine = false}) => FeedPost(
        id: id,
        person: CommunityPerson(
          userId: 'u-$h',
          handle: h,
          avatarId: null,
          country: null,
        ),
        kind: PostKind.session,
        title: 'Push',
        value: null,
        at: DateTime.now().subtract(const Duration(hours: 2)),
        kudos: 0,
        cheered: false,
        mine: mine,
        cheeredBy: const [],
      );

  Widget app({String initial = Routes.community, Object? extra}) {
    final router = GoRouter(
      initialLocation: initial,
      initialExtra: extra,
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
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'joining says, before Join, that friends and clubs will see '
      'what is shared, and where to turn it off', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    api = FakeCommunityApi();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(key('community.join'), findsOneWidget);
    await tester.ensureVisible(key('community.join.sharing'));
    expect(
      find.text(
        'Your friends and your clubs will see the sessions you finish, your '
        'runs, records and streak milestones. Turn any of them off in '
        'Community settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'settings: every kind on, shared with friends and clubs; one '
      'turned off is sent', (tester) async {
    api = FakeCommunityApi(profile: me());
    await tester.pumpWidget(app(initial: Routes.communitySettings));
    await tester.pumpAndSettle();
    expect(
      find.text('SHARED WITH YOUR FRIENDS AND YOUR CLUBS'),
      findsOneWidget,
    );
    for (final k in FeedKind.values) {
      final s =
          tester.widget<Switch>(key('communitySettings.feedSwitch.${k.wire}'));
      expect(s.value, isTrue, reason: k.wire);
    }
    await tap(tester, 'communitySettings.feedSwitch.run');
    expect(api.calls.last, startsWith('update-share session,record,streak '));
  });

  testWidgets(
      'a club: the board first, then its feed — members’ posts, '
      'cheered by a club-mate', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club]
      ..clubFeeds = {
        club.id: Feed(
          items: [post('p1', 'ananya'), post('p2', 'srijan', mine: true)],
          next: null,
          nudges: const [],
        ),
      };
    await tester
        .pumpWidget(app(initial: Routes.communityClub(club.id), extra: club));
    await tester.pumpAndSettle();
    expect(key('club.code'), findsOneWidget);
    expect(key('clubFeed.list'), findsNothing);

    await tap(tester, 'club.half.feed');
    expect(key('clubFeed.list'), findsOneWidget);
    expect(api.calls, contains('club-feed club-1'));
    expect(find.text('@ananya'), findsNothing);
    expect(find.textContaining('finished Push'), findsNWidgets(2));
    // Your own post has no cheer button; a club-mate's does.
    expect(key('feed.cheer.p2'), findsNothing);
    await tap(tester, 'feed.cheer.p1');
    expect(api.calls.last, 'cheer p1');
    expect(
      find.textContaining('Members see only what each person shares'),
      findsOneWidget,
    );
  });

  testWidgets('a club with nothing shared yet says so', (tester) async {
    api = FakeCommunityApi(profile: me())..myClubs = [club];
    await tester
        .pumpWidget(app(initial: Routes.communityClub(club.id), extra: club));
    await tester.pumpAndSettle();
    await tap(tester, 'club.half.feed');
    expect(
      find.text(
        'Nothing here yet. When members share their sessions, runs and '
        'records, they show here.',
      ),
      findsOneWidget,
    );
  });
}
