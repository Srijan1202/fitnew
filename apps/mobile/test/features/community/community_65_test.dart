import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/club_goals.dart';
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

  /* --------------------------------------------------- K2: the challenge -- */

  ClubChallenge challenge({
    ChallengeMetric metric = ChallengeMetric.sessions,
    int target = 200,
    num total = 143,
    num? mine = 12,
    bool reached = false,
    bool closed = false,
    bool endedEarly = false,
    int daysLeft = 11,
    bool started = true,
    String id = 'ch-1',
    String month = '2026-11',
  }) =>
      ClubChallenge(
        id: id,
        metric: metric,
        target: target,
        month: month,
        title: '$target ${metric.unit} together in ${monthName(month)}',
        total: total,
        mine: mine,
        reachedAt: reached ? DateTime.utc(2026, 11, 20) : null,
        closedAt: closed ? DateTime.utc(2026, 11, 2) : null,
        endedEarly: endedEarly,
        daysLeft: daysLeft,
        started: started,
      );

  test('counts as shown; next month across the year', () {
    expect(countText(143), '143');
    expect(countText(12.3), '12.3');
    expect(countText(12.0), '12');
    expect(monthKey(DateTime(2026, 12, 31)), '2026-12');
    expect(nextMonthKey(DateTime(2026, 12, 31)), '2027-01');
    expect(monthName('2027-01'), 'January');
    expect(challenge(total: 250).progress, 1);
    expect(challenge().countLine, '143 of 200 sessions');
  });

  testWidgets(
      'a member sees the club’s bar, the days left, their part and '
      'the last ones finished; nothing to change', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club]
      ..challenges = {
        club.id: ClubChallengeView(
          current: challenge(),
          history: [
            challenge(
              id: 'ch-0',
              month: '2026-10',
              target: 150,
              total: 162,
              mine: null,
              reached: true,
              closed: true,
            ),
            challenge(
              id: 'ch-9',
              month: '2026-09',
              metric: ChallengeMetric.distance,
              target: 300,
              total: 120.5,
              mine: null,
              closed: true,
              endedEarly: true,
            ),
          ],
          suggested: null,
        ),
      };
    await tester
        .pumpWidget(app(initial: Routes.communityClub(club.id), extra: club));
    await tester.pumpAndSettle();
    expect(find.text('200 sessions together in November'), findsOneWidget);
    expect(find.text('143 of 200 sessions · 11 days left'), findsOneWidget);
    expect(find.text('Your part: 12 sessions'), findsOneWidget);
    expect(
      find.text('150 sessions together in October · 162 · reached'),
      findsOneWidget,
    );
    expect(
      find.text('300 km together in September · 120.5 · ended early'),
      findsOneWidget,
    );
    expect(key('challenge.change'), findsNothing);
    expect(key('challenge.end'), findsNothing);
  });

  testWidgets('nothing set: members see nothing', (tester) async {
    api = FakeCommunityApi(profile: me())..myClubs = [club];
    await tester
        .pumpWidget(app(initial: Routes.communityClub(club.id), extra: club));
    await tester.pumpAndSettle();
    expect(key('challenge.card'), findsNothing);
  });

  testWidgets(
      'the owner sets one: a metric, the suggestion, a target in '
      'range; then ends it after a confirmation', (tester) async {
    const mineClub = Club(
      id: 'club-2',
      name: 'Hostel A',
      code: 'WXYZ2345',
      members: 12,
      mine: true,
    );
    api = FakeCommunityApi(profile: me())
      ..myClubs = [mineClub]
      ..challenges = {
        mineClub.id: const ClubChallengeView(
          current: null,
          history: [],
          suggested: {
            ChallengeMetric.sessions: 125,
            ChallengeMetric.distance: 440,
            ChallengeMetric.activeDays: 60,
          },
        ),
      }
      ..onSetChallenge = (m, t, month) => ClubChallengeView(
            current: challenge(metric: m, target: t, total: 0, mine: 0),
            history: const [],
            suggested: null,
          );
    await tester.pumpWidget(
      app(initial: Routes.communityClub(mineClub.id), extra: mineClub),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'challenge.set');
    expect(find.text('125'), findsOneWidget);
    await tap(tester, 'challenge.metric.distance');
    expect(find.text('440'), findsOneWidget);
    expect(
      find.text('Suggested: 440, the club’s last 4 weeks plus 10%'),
      findsOneWidget,
    );
    await tester.enterText(key('challenge.target'), '9');
    await tap(tester, 'challenge.save');
    expect(find.text('A target is 10 to 100000.'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('set-challenge')), isEmpty);
    await tester.enterText(key('challenge.target'), '50');
    await tap(tester, 'challenge.save');
    expect(api.calls, contains('set-challenge club-2 distance 50 '));
    expect(key('challenge.save'), findsNothing);
    expect(find.text('0 of 50 km · 11 days left'), findsOneWidget);

    await tap(tester, 'challenge.end');
    await tap(tester, 'challenge.end.confirm');
    expect(api.calls, contains('end-challenge club-2'));
    expect(key('challenge.set'), findsOneWidget);
  });
}
