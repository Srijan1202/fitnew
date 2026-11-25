import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/club_screen.dart';
import 'package:fitos/features/community/presentation/club_settings_screen.dart';
import 'package:fitos/features/community/presentation/community_providers.dart';
import 'package:fitos/features/community/presentation/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_community_api.dart';

/// Beta 6.6 (Leagues and co-owners): co-owners (L2).
void main() {
  late FakeCommunityApi api;

  CommunityProfile me() => CommunityProfile(
        handle: 'srijan',
        avatarId: null,
        country: 'IN',
        onWorld: false,
        joinedAt: DateTime.utc(2026, 11, 8),
        feed: const {...FeedKind.values},
      );

  BoardRow row(String handle, int rank, {bool me = false}) => BoardRow(
        rank: rank,
        userId: 'u-$handle',
        handle: handle,
        avatarId: null,
        country: null,
        sessions: 3,
        runM: 0,
        streak: 0,
        activeDays: 3,
        keptPct: null,
        me: me,
      );

  Club club({required ClubRole role, List<String> coOwners = const []}) => Club(
        id: 'club-1',
        name: 'Hostel A',
        code: 'ABCD2345',
        members: 4,
        mine: role == ClubRole.owner,
        ownerId: role == ClubRole.owner ? 'u-srijan' : 'u-owner',
        coOwners: coOwners,
        role: role,
      );

  Widget app({required String initial, Object? extra}) {
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

  void board(List<BoardRow> rows) => api.board = (_, __) => Board(
        metric: BoardMetric.sessions,
        weekFrom: '2026-11-23',
        weekTo: '2026-11-29',
        rows: rows,
        me: null,
        total: rows.length,
        lastWeek: null,
        period: BoardPeriod.week,
      );

  test('a club knows who runs it', () {
    final c = club(role: ClubRole.coOwner, coOwners: ['u-srijan', 'u-b']);
    expect(c.runs, isTrue);
    expect(c.tagOf('u-owner'), 'Owner');
    expect(c.tagOf('u-b'), 'Co-owner');
    expect(c.tagOf('u-c'), isNull);
    expect(club(role: ClubRole.member).runs, isFalse);
    final j = Club.fromJson({
      'id': 'c',
      'name': 'n',
      'code': 'ABCD2345',
      'members': 3,
      'mine': false,
      'createdAt': '2026-11-01T00:00:00Z',
      'ownerId': 'o',
      'coOwners': ['x'],
      'role': 'co-owner',
      'seasonWinner': true,
    });
    expect([
      j.role,
      j.coOwners,
      j.seasonWinner,
    ], [
      ClubRole.coOwner,
      ['x'],
      true,
    ]);
  });

  testWidgets(
      'the owner names a co-owner and drops one; the board says who '
      'runs the club', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.owner)];
    board([row('srijan', 1, me: true), row('ananya', 2), row('kabir', 3)]);
    await tester.pumpWidget(
      app(initial: Routes.communityClubSettings('club-1')),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'clubSettings.member.ananya.menu');
    await tap(tester, 'clubSettings.coOwner.ananya');
    expect(api.calls, contains('co-owner club-1 u-ananya'));
    expect(key('clubSettings.member.ananya.tag'), findsOneWidget);
    await tap(tester, 'clubSettings.member.ananya.menu');
    expect(key('clubSettings.notCoOwner.ananya'), findsOneWidget);
    await tap(tester, 'clubSettings.notCoOwner.ananya');
    expect(api.calls, contains('not-co-owner club-1 u-ananya'));
    expect(key('clubSettings.member.ananya.tag'), findsNothing);
  });

  testWidgets(
      'a co-owner gets the club settings and the owner’s cards, '
      'removes plain members only, and never names co-owners or passes the '
      'club', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    api = FakeCommunityApi(profile: me())
      ..myClubs = [
        club(role: ClubRole.coOwner, coOwners: ['u-srijan', 'u-kabir']),
      ];
    board([
      row('owner', 1),
      row('srijan', 2, me: true),
      row('kabir', 3),
      row('ananya', 4),
    ]);
    await tester.pumpWidget(
      app(
        initial: Routes.communityClub('club-1'),
        extra: api.myClubs.first,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Owner'), findsWidgets);
    expect(find.textContaining('Co-owner'), findsWidgets);
    expect(key('challenge.set'), findsOneWidget);
    expect(key('match.challenge'), findsOneWidget);
    await tap(tester, 'club.menu');
    await tap(tester, 'club.settings');
    expect(key('clubSettings.member.owner.menu'), findsNothing);
    expect(key('clubSettings.member.kabir.menu'), findsNothing);
    await tap(tester, 'clubSettings.member.ananya.menu');
    expect(key('clubSettings.remove.ananya'), findsOneWidget);
    expect(key('clubSettings.coOwner.ananya'), findsNothing);
    expect(key('clubSettings.owner.ananya'), findsNothing);
  });

  testWidgets('a plain member gets neither', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.member)];
    board([row('owner', 1), row('srijan', 2, me: true)]);
    await tester.pumpWidget(
      app(
        initial: Routes.communityClub('club-1'),
        extra: api.myClubs.first,
      ),
    );
    await tester.pumpAndSettle();
    expect(key('challenge.set'), findsNothing);
    expect(key('match.challenge'), findsNothing);
    await tap(tester, 'club.menu');
    expect(key('club.settings'), findsNothing);
  });
}
