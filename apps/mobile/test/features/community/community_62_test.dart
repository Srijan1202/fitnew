import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/club_screen.dart';
import 'package:fitos/features/community/presentation/club_settings_screen.dart';
import 'package:fitos/features/community/presentation/community_providers.dart';
import 'package:fitos/features/community/presentation/community_screen.dart';
import 'package:fitos/features/community/presentation/community_settings_screen.dart';
import 'package:fitos/features/community/presentation/invite_qr.dart';
import 'package:fitos/features/community/presentation/invite_screen.dart';
import 'package:fitos/features/community/presentation/person_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_community_api.dart';

/// Beta 6.2 (Community that moves): the five boards, last week's podium,
/// a friend's week, a club owner's settings, invite links and the QR code.
void main() {
  late FakeCommunityApi api;

  const club = Club(
    id: 'club-1',
    name: 'VIT Lifters',
    code: 'ABCD2345',
    members: 3,
    mine: true,
  );

  setUp(
    () => api = FakeCommunityApi(
      profile: CommunityProfile(
        handle: 'srijan',
        avatarId: null,
        country: 'IN',
        onWorld: false,
        joinedAt: DateTime.utc(2026, 11, 8),
      ),
    ),
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
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (_, s) =>
                      ClubSettingsScreen(clubId: s.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: 'people/:id',
              builder: (_, s) => PersonProfileScreen(
                userId: s.pathParameters['id']!,
                handle: s.extra is String ? s.extra! as String : null,
              ),
            ),
            GoRoute(
              path: 'invite',
              builder: (_, s) => InviteScreen(invite: s.extra! as InviteLink),
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
    test('ordinals, last week in words, and each metric’s number', () {
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 103].map(ordinal), [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '103rd',
      ]);
      LastWeek lw(int? rank, int? moved) => LastWeek(
            weekFrom: '2026-11-02',
            podium: const [],
            myRank: rank,
            moved: moved,
          );
      expect(lw(3, 2).myLine, 'You were 3rd last week · up 2');
      expect(lw(1, -1).myLine, 'You were 1st last week · down 1');
      expect(lw(2, 0).myLine, 'You were 2nd last week');
      expect(lw(2, null).myLine, 'You were 2nd last week');
      expect(lw(null, null).myLine, isNull);

      final r = row(
        1,
        'a',
        sessions: 1,
        runM: 5200,
        streak: 1,
        activeDays: 4,
        keptPct: 75,
      );
      expect(BoardMetric.values.map((m) => boardValue(r, m)), [
        '1 session',
        '5.2 km',
        '1 day',
        '4 days',
        '75%',
      ]);
      expect(boardValue(row(1, 'b'), BoardMetric.plan), '–');
      expect(boardOther(r, BoardMetric.streak), '1 session · 5.2 km');
      expect(boardOther(row(1, 'c'), BoardMetric.sessions), isNull);
      expect(BoardMetric.fromWire('active-days'), BoardMetric.activeDays);
    });

    test('invite links: only tryfitos.me club codes and handles', () {
      expect(clubInviteUrl('ABCD2345'), 'https://tryfitos.me/c/ABCD2345');
      expect(friendInviteUrl('srijan'), 'https://tryfitos.me/u/srijan');
      expect(
        (InviteLink.parse('https://tryfitos.me/c/abcd2345/')! as ClubInvite)
            .code,
        'ABCD2345',
      );
      expect(
        (InviteLink.parse('https://tryfitos.me/u/Srijan')! as FriendInvite)
            .handle,
        'srijan',
      );
      for (final bad in [
        'http://tryfitos.me/c/ABCD2345',
        'https://evil.example/c/ABCD2345',
        'https://tryfitos.me/c/ABCD234O',
        'https://tryfitos.me/u/a b',
        'https://tryfitos.me/p/K7Q2XM',
        'https://tryfitos.me/c/ABCD2345/more',
        'fitos://widget/food',
        '::not a link',
      ]) {
        expect(InviteLink.parse(bad), isNull, reason: bad);
      }
    });
  });

  testWidgets(
      'five boards; the plan board shows the plan kept; last week’s podium and your place',
      (tester) async {
    tall(tester);
    api
      ..lists = FriendLists(
        friends: [person('ana')],
        incoming: const [],
        outgoing: const [],
      )
      ..board = (metric, _) => Board(
            metric: metric,
            weekFrom: '2026-11-09',
            weekTo: '2026-11-15',
            rows: [
              row(
                1,
                'ana',
                sessions: 3,
                streak: 9,
                activeDays: 4,
                keptPct: 100,
              ),
              row(
                2,
                'srijan',
                sessions: 2,
                me: true,
                activeDays: 2,
                keptPct: 67,
              ),
            ],
            me: null,
            total: 2,
            lastWeek: LastWeek(
              weekFrom: '2026-11-02',
              podium: [
                row(1, 'ana', sessions: 5),
                row(2, 'srijan', sessions: 4, me: true),
              ],
              myRank: 2,
              moved: 1,
            ),
          );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final m in BoardMetric.values) {
      expect(key('community.metric.${m.wire}'), findsOneWidget);
    }
    expect(key('community.lastWeek'), findsOneWidget);
    expect(key('community.podium.ana'), findsOneWidget);
    expect(
      tester.widget<Text>(key('community.lastWeek.me')).data,
      'You were 2nd last week · up 1',
    );

    await tap(tester, 'community.metric.plan');
    expect(api.calls, contains('friends-board plan'));
    expect(tester.widget<Text>(key('community.value.ana')).data, '100%');
    expect(tester.widget<Text>(key('community.value.srijan')).data, '67%');
    await tap(tester, 'community.metric.active-days');
    expect(tester.widget<Text>(key('community.value.ana')).data, '4 days');
  });

  testWidgets(
      'a friend on the board opens their week; someone else’s is not shown',
      (tester) async {
    tall(tester);
    api
      ..lists = FriendLists(
        friends: [person('ana')],
        incoming: const [],
        outgoing: const [],
      )
      ..board = (metric, _) => Board(
            metric: metric,
            weekFrom: '2026-11-09',
            weekTo: '2026-11-15',
            rows: [row(1, 'ana', sessions: 3)],
            me: null,
            total: 1,
          );
    api.profileOf = PersonProfile(
      person: person('ana'),
      friend: true,
      friendsSince: DateTime.utc(2026, 11, 3),
      streak: 9,
      thisWeek: const WeekCounts(
        weekFrom: '2026-11-09',
        sessions: 3,
        runM: 5200,
        activeDays: 4,
        keptPct: 75,
      ),
      weeks: const [
        WeekCounts(
          weekFrom: '2026-10-12',
          sessions: 0,
          runM: 0,
          activeDays: 0,
          keptPct: null,
        ),
        WeekCounts(
          weekFrom: '2026-10-19',
          sessions: 2,
          runM: 0,
          activeDays: 2,
          keptPct: 50,
        ),
        WeekCounts(
          weekFrom: '2026-10-26',
          sessions: 3,
          runM: 1000,
          activeDays: 3,
          keptPct: 75,
        ),
        WeekCounts(
          weekFrom: '2026-11-02',
          sessions: 4,
          runM: 3000,
          activeDays: 5,
          keptPct: 100,
        ),
      ],
      clubsInCommon: const [],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tap(tester, 'community.row.ana');
    expect(api.calls, contains('profile u-ana'));
    expect(find.text('Friends since 3 Nov'), findsOneWidget);
    expect(tester.widget<Text>(key('person.stat.streak')).data, '9 days');
    expect(tester.widget<Text>(key('person.stat.plan')).data, '75%');
    expect(key('person.week.2026-11-02'), findsOneWidget);
    expect(find.textContaining('5 active days'), findsOneWidget);
    expect(key('person.add'), findsNothing);

    // Unfriending from their page.
    await tap(tester, 'person.menu');
    await tap(tester, 'person.unfriend');
    expect(api.calls, contains('unfriend u-ana'));

    // Not a friend or club-mate (or blocked): the server says no, the phone says why.
    api.profileOf = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(initial: Routes.communityPerson('u-zed'), extra: 'zed'),
    );
    await tester.pumpAndSettle();
    expect(key('person.problem'), findsOneWidget);
  });

  testWidgets(
      'the owner’s settings: rename, a new code, remove, let back, pass on',
      (tester) async {
    tall(tester);
    api
      ..myClubs = [club]
      ..removed = [person('old')]
      ..board = (metric, _) => Board(
            metric: metric,
            weekFrom: '2026-11-09',
            weekTo: '2026-11-15',
            rows: [row(1, 'srijan', me: true), row(2, 'ana'), row(3, 'ben')],
            me: null,
            total: 3,
          );
    await tester
        .pumpWidget(app(initial: Routes.communityClub(club.id), extra: club));
    await tester.pumpAndSettle();
    await tap(tester, 'club.menu');
    await tap(tester, 'club.settings');
    expect(key('clubSettings.member.ana'), findsOneWidget);
    expect(key('clubSettings.member.srijan'), findsNothing);

    await tap(tester, 'clubSettings.rename');
    await tester.enterText(key('clubSettings.rename.field'), 'VIT Runners');
    await tap(tester, 'clubSettings.rename.ok');
    expect(api.calls, contains('rename-club club-1 VIT Runners'));

    await tap(tester, 'clubSettings.code');
    await tap(tester, 'clubSettings.code.ok');
    expect(api.calls, contains('new-code club-1'));
    expect(find.text('The new code is WXYZ-6789.'), findsOneWidget);

    await tap(tester, 'clubSettings.member.ana.menu');
    await tap(tester, 'clubSettings.remove.ana');
    await tap(tester, 'clubSettings.remove.ok');
    expect(api.calls, contains('remove club-1 u-ana'));

    await tap(tester, 'clubSettings.letBack.old');
    expect(api.calls, contains('let-back club-1 u-old'));

    await tap(tester, 'clubSettings.member.ben.menu');
    await tap(tester, 'clubSettings.owner.ben');
    await tap(tester, 'clubSettings.owner.ok');
    expect(api.calls, contains('pass-club club-1 u-ben'));
    // Back on the club, no longer its owner: no settings.
    await tap(tester, 'club.menu');
    expect(key('club.settings'), findsNothing);
  });

  testWidgets(
      'a club that is not yours has no settings; its QR and link carry only the code',
      (tester) async {
    tall(tester);
    api.myClubs = [
      const Club(
        id: 'club-2',
        name: 'Run Crew',
        code: 'WXYZ6789',
        members: 9,
        mine: false,
      ),
    ];
    await tester.pumpWidget(app(initial: Routes.communityClub('club-2')));
    await tester.pumpAndSettle();
    await tap(tester, 'club.menu');
    expect(key('club.settings'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tap(tester, 'club.qr');
    final qr = tester.widget<InviteQr>(find.byType(InviteQr));
    expect(qr.data, 'https://tryfitos.me/c/WXYZ6789');
  });

  testWidgets(
      'an invite link: join the club, or ask to be friends, only on a tap',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(
      app(
        initial: Routes.communityInvite,
        extra: const ClubInvite('ABCD2345'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Code ABCD-2345'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('join-club')), isEmpty);
    await tap(tester, 'invite.go');
    expect(api.calls, contains('join-club ABCD2345'));
    expect(key('invite.note'), findsOneWidget); // the fake has no such club

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(initial: Routes.communityInvite, extra: const FriendInvite('ana')),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'invite.go');
    expect(api.calls, contains('add ana'));
    expect(find.text('Request sent to @ana.'), findsOneWidget);

    // Not in Community yet: join first.
    api.profile = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(initial: Routes.communityInvite, extra: const FriendInvite('ana')),
    );
    await tester.pumpAndSettle();
    expect(key('invite.community'), findsOneWidget);
    expect(key('invite.go'), findsNothing);
  });

  testWidgets(
      'my QR code: the friend link with my handle, from settings and from Friends',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(app(initial: Routes.communitySettings));
    await tester.pumpAndSettle();
    await tap(tester, 'communitySettings.qr');
    expect(key('community.qr'), findsOneWidget);
    expect(
      tester.widget<InviteQr>(find.byType(InviteQr)).data,
      'https://tryfitos.me/u/srijan',
    );
    expect(
      find.descendant(
        of: key('community.qr'),
        matching: find.text('@srijan'),
      ),
      findsOneWidget,
    );
  });
}
