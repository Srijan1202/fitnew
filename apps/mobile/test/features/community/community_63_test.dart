import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/community_providers.dart';
import 'package:fitos/features/community/presentation/community_screen.dart';
import 'package:fitos/features/community/presentation/community_settings_screen.dart';
import 'package:fitos/features/community/presentation/person_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_community_api.dart';

/// Beta 6.3 (Community that talks): the feed with cheers and nudges, the
/// sharing settings, month and all-time boards, suggestions and nudging.
void main() {
  late FakeCommunityApi api;

  CommunityPerson person(String h) =>
      CommunityPerson(userId: 'u-$h', handle: h, avatarId: null, country: null);

  FeedPost post(
    String id,
    String h,
    PostKind kind, {
    String? title,
    int? value,
    int kudos = 0,
    bool cheered = false,
    bool mine = false,
    List<CommunityPerson> by = const [],
  }) =>
      FeedPost(
        id: id,
        person: person(h),
        kind: kind,
        title: title,
        value: value,
        at: DateTime.now().subtract(const Duration(hours: 3)),
        kudos: kudos,
        cheered: cheered,
        mine: mine,
        cheeredBy: by,
      );

  CommunityProfile me({Set<FeedKind> feed = const {}}) => CommunityProfile(
        handle: 'srijan',
        avatarId: null,
        country: 'IN',
        onWorld: false,
        joinedAt: DateTime.utc(2026, 11, 8),
        feed: feed,
      );

  setUp(() => api = FakeCommunityApi(profile: me()));

  Widget app({String initial = Routes.community}) {
    final router = GoRouter(
      initialLocation: initial,
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
              path: 'people/:id',
              builder: (_, s) =>
                  PersonProfileScreen(userId: s.pathParameters['id']!),
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

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  group('the rules on the phone', () {
    test('each post in words, never a weight', () {
      expect(
        postLine(post('1', 'a', PostKind.session, title: 'Push')),
        'finished Push',
      );
      expect(
        postLine(post('1', 'a', PostKind.run, value: 5200)),
        'ran 5.2 km',
      );
      expect(
        postLine(
          post('1', 'a', PostKind.liftRecord, title: 'Squat', value: 2),
        ),
        'set a record on Squat and 2 more',
      );
      expect(
        postLine(post('1', 'a', PostKind.liftRecord, title: 'Squat', value: 0)),
        'set a record on Squat',
      );
      expect(
        postLine(post('1', 'a', PostKind.runRecord, title: 'half')),
        'set a half marathon record',
      );
      expect(
        postLine(post('1', 'a', PostKind.streak, value: 30)),
        'hit a 30-day streak',
      );
    });

    test('who cheered, and how long ago', () {
      expect(cheeredLine(post('1', 'a', PostKind.run, kudos: 0)), isNull);
      expect(
        cheeredLine(post('1', 'a', PostKind.run, kudos: 1, by: [person('b')])),
        'Cheered by @b',
      );
      expect(
        cheeredLine(
          post(
            '1',
            'a',
            PostKind.run,
            kudos: 2,
            by: [person('b'), person('c')],
          ),
        ),
        'Cheered by @b and @c',
      );
      expect(
        cheeredLine(
          post('1', 'a', PostKind.run, kudos: 2, by: [person('b')]),
        ),
        'Cheered by @b and 1 other',
      );
      expect(
        cheeredLine(
          post(
            '1',
            'a',
            PostKind.run,
            kudos: 5,
            by: [person('b'), person('c')],
          ),
        ),
        'Cheered by @b and 4 others',
      );
      final now = DateTime(2026, 11, 12, 20);
      expect(agoOf(now.subtract(const Duration(seconds: 20)), now), 'just now');
      expect(
        agoOf(now.subtract(const Duration(minutes: 12)), now),
        '12 min ago',
      );
      expect(agoOf(now.subtract(const Duration(hours: 3)), now), '3 h ago');
      expect(agoOf(now.subtract(const Duration(hours: 30)), now), 'yesterday');
      expect(agoOf(now.subtract(const Duration(days: 4)), now), '4 days ago');
    });

    test('a suggestion says why, never who', () {
      Suggestion s(int n, String? club) =>
          Suggestion(person: person('x'), mutualFriends: n, club: club);
      expect(s(1, null).why, '1 friend in common');
      expect(s(2, 'Gym Bros').why, '2 friends in common · In Gym Bros');
      expect(s(0, 'Gym Bros').why, 'In Gym Bros');
    });

    test('older profiles without the 6.3 settings read as the defaults', () {
      final p = CommunityProfile.fromJson({
        'handle': 'a',
        'avatarId': null,
        'country': null,
        'onWorld': false,
        'joinedAt': '2026-11-08T10:00:00.000Z',
      });
      expect([p.feed, p.suggest, p.notify], [<FeedKind>{}, true, true]);
      expect(
        CommunityProfile.fromJson({
          'handle': 'a',
          'avatarId': null,
          'country': null,
          'onWorld': false,
          'joinedAt': '2026-11-08T10:00:00.000Z',
          'feed': ['run', 'weights'],
          'suggest': false,
          'notify': false,
        }).feed,
        {FeedKind.run},
      );
    });
  });

  testWidgets(
      'the feed: friends’ posts with a cheer, your own with who cheered, '
      'nudges on top, older posts', (tester) async {
    tall(tester);
    api
      ..profile = me(feed: {FeedKind.session})
      ..feedPage = Feed(
        items: [
          post('p1', 'ana', PostKind.session, title: 'Legs'),
          post(
            'p2',
            'srijan',
            PostKind.run,
            value: 5000,
            kudos: 2,
            mine: true,
            by: [person('ana'), person('ben')],
          ),
        ],
        next: DateTime.utc(2026, 11, 10),
        nudges: [Nudge(person: person('ben'), at: DateTime.now())],
      )
      ..older = Feed(
        items: [post('p0', 'ben', PostKind.streak, value: 14)],
        next: null,
        nudges: const [],
      );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.tab.feed');

    expect(key('feed.nudges'), findsOneWidget);
    expect(find.textContaining('@ben nudged you'), findsOneWidget);
    expect(key('feed.start'), findsNothing);
    expect(find.text('@ana finished Legs'), findsOneWidget);
    expect(find.text('You ran 5.0 km'), findsOneWidget);
    expect(
      find.textContaining('Cheered by @ana and @ben'),
      findsOneWidget,
    );
    // Your own post has no cheer button.
    expect(key('feed.cheer.p2'), findsNothing);
    expect(key('feed.kudos.p2'), findsOneWidget);

    await tap(tester, 'feed.cheer.p1');
    expect(api.calls, contains('cheer p1'));
    expect(
      find.descendant(of: key('feed.cheer.p1'), matching: find.text('1')),
      findsOneWidget,
    );
    await tap(tester, 'feed.cheer.p1');
    expect(api.calls, contains('uncheer p1'));

    await tap(tester, 'feed.more');
    expect(api.calls, contains('feed-older'));
    expect(find.text('@ben hit a 14-day streak'), findsOneWidget);
    expect(key('feed.more'), findsNothing);
  });

  testWidgets(
      'sharing nothing yet: a card leads to the settings, where each kind, '
      'suggestions and notifications switch', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.tab.feed');
    expect(key('feed.start'), findsOneWidget);
    expect(key('feed.empty'), findsOneWidget);
    await tap(tester, 'feed.start.choose');
    expect(find.text('Community settings'), findsOneWidget);

    await tap(tester, 'communitySettings.feedSwitch.run');
    expect(api.calls.last, 'update-share run  ');
    await tap(tester, 'communitySettings.feedSwitch.session');
    expect(api.calls.last, 'update-share session,run  ');
    await tap(tester, 'communitySettings.feedSwitch.run');
    expect(api.calls.last, 'update-share session  ');
    await tap(tester, 'communitySettings.suggestSwitch');
    expect(api.calls.last, 'update-share  false ');
    await tap(tester, 'communitySettings.notifySwitch');
    expect(api.calls.last, 'update-share   false');
    expect(api.profile!.feed, {FeedKind.session});
  });

  testWidgets('boards by week, month and all time', (tester) async {
    tall(tester);
    api.board = (metric, _) => Board(
          metric: metric,
          weekFrom: '2026-11-09',
          weekTo: '2026-11-15',
          rows: [row(1, 'srijan', sessions: 9, me: true)],
          me: null,
          total: 1,
          period: api.lastPeriod,
          periodFrom: switch (api.lastPeriod) {
            BoardPeriod.week => '2026-11-09',
            BoardPeriod.month => '2026-11-01',
            BoardPeriod.all => '2026-11-08',
          },
        );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('THIS WEEK'), findsOneWidget);
    await tap(tester, 'community.period.month');
    expect(api.calls, contains('friends-board sessions month'));
    expect(find.text('THIS MONTH · FROM 1 NOV'), findsOneWidget);
    await tap(tester, 'community.period.all');
    expect(api.calls, contains('friends-board sessions all'));
    expect(find.text('ALL TIME · SINCE JOINING COMMUNITY'), findsOneWidget);
    // The period holds on the world board too.
    await tap(tester, 'community.tab.world');
    expect(api.calls.last, startsWith('world-board sessions all all'));
  });

  testWidgets('people you may know: added, or hidden for good', (tester) async {
    tall(tester);
    api.suggested = [
      Suggestion(person: person('fof'), mutualFriends: 2, club: null),
      Suggestion(person: person('mate'), mutualFriends: 0, club: 'Gym Bros'),
    ];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(key('community.suggestions'), findsOneWidget);
    expect(find.text('2 friends in common'), findsOneWidget);
    expect(find.text('In Gym Bros'), findsOneWidget);
    await tap(tester, 'community.suggestion.hide.mate');
    expect(api.calls, contains('dismiss u-mate'));
    expect(key('community.suggestion.mate'), findsNothing);
    await tap(tester, 'community.suggestion.add.fof');
    expect(api.calls, contains('add fof'));
  });

  PersonProfile friendProfile(NudgeState? nudge) => PersonProfile(
        person: person('quiet'),
        friend: true,
        friendsSince: DateTime.utc(2026, 11, 1),
        streak: 0,
        thisWeek: const WeekCounts(
          weekFrom: '2026-11-09',
          sessions: 0,
          runM: 0,
          activeDays: 0,
          keptPct: null,
        ),
        weeks: const [],
        clubsInCommon: const [],
        nudge: nudge,
      );

  testWidgets(
      'a quiet friend can be nudged; an active one or a second time '
      'cannot', (tester) async {
    tall(tester);
    api.profileOf = friendProfile(NudgeState.can);
    await tester.pumpWidget(app(initial: Routes.communityPerson('u-quiet')));
    await tester.pumpAndSettle();
    expect(find.text('Nudge @quiet'), findsOneWidget);
    await tap(tester, 'person.nudge');
    expect(api.calls, contains('nudge u-quiet'));
    expect(find.text('Nudge sent.'), findsOneWidget);

    api.profileOf = friendProfile(NudgeState.active);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(initial: Routes.communityPerson('u-quiet')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ButtonStyleButton>(key('person.nudge')).onPressed,
      isNull,
    );
    expect(find.text('They trained in the last 3 days.'), findsOneWidget);

    api.profileOf = friendProfile(null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(initial: Routes.communityPerson('u-quiet')));
    await tester.pumpAndSettle();
    expect(key('person.nudge'), findsNothing);

    // A refusal from the server shows as it is.
    api
      ..profileOf = friendProfile(NudgeState.can)
      ..nudgeFailure = const Conflict('You nudged them this week.');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(initial: Routes.communityPerson('u-quiet')));
    await tester.pumpAndSettle();
    await tap(tester, 'person.nudge');
    expect(find.text('You nudged them this week.'), findsOneWidget);
  });
}
