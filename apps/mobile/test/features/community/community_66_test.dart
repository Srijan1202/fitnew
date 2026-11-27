import 'dart:typed_data';

import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/community/domain/club_goals.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/club_screen.dart';
import 'package:fitos/features/community/presentation/club_settings_screen.dart';
import 'package:fitos/features/community/presentation/community_providers.dart';
import 'package:fitos/features/community/presentation/community_screen.dart';
import 'package:fitos/features/community/presentation/people_screen.dart';
import 'package:fitos/features/community/presentation/share_result.dart';
import 'package:fitos/features/running/presentation/screens/share_run_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_community_api.dart';

/// Beta 6.6 (Leagues and co-owners): co-owners (L2) and the league (L1).
class _RecordingSharer implements RunSharer {
  final shared = <(int, String, String)>[];

  @override
  Future<void> share(Uint8List bytes, String fileName, String mimeType) async =>
      shared.add((bytes.length, fileName, mimeType));
}

void main() {
  late FakeCommunityApi api;
  final sharer = _RecordingSharer();

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
              path: 'people',
              builder: (_, __) => const PeopleScreen(),
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
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        communityApiProvider.overrideWithValue(api),
        runSharerProvider.overrideWithValue(sharer),
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
  /* ---------------------------------------------------- L1: the league -- */

  LeagueRow lrow(int place, String name, int points, {bool mine = false}) =>
      LeagueRow(
        place: place,
        clubId: 'c-$name',
        name: name,
        played: 3,
        won: points ~/ 3,
        drawn: points % 3,
        lost: 0,
        byes: 0,
        points: points,
        mine: mine,
      );

  ClubLeague league({
    bool entered = true,
    bool leaving = false,
    bool canEnter = true,
    LeagueRow? me,
    List<LeagueRow> table = const [],
    int clubs = 0,
  }) =>
      ClubLeague(
        entered: entered,
        leaving: leaving,
        canEnter: canEnter,
        seasonFrom: entered ? '2026-11-30' : null,
        seasonTo: entered ? '2026-12-27' : null,
        seasonFinished: false,
        me: me,
        table: table,
        clubs: clubs,
      );

  Future<void> openClub(WidgetTester tester, Club c) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    board([row('srijan', 1, me: true)]);
    await tester.pumpWidget(app(initial: Routes.communityClub(c.id), extra: c));
    await tester.pumpAndSettle();
  }

  test('places in words', () {
    expect(
      [1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 111].map(ordinalOf),
      [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '23rd',
        '111th',
      ],
    );
  });

  testWidgets(
      'the owner enters the club; the first match is paired on '
      'Saturday', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.owner)]
      ..leagues = {'club-1': league(entered: false)};
    await openClub(tester, api.myClubs.first);
    expect(find.textContaining('never who is in it'), findsOneWidget);
    await tap(tester, 'league.enter');
    expect(api.calls, contains('enter-league club-1'));
    expect(
      find.text('Your first match is paired on Saturday.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'too small to enter; a plain member sees nothing until the club '
      'is in', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.coOwner)]
      ..leagues = {'club-1': league(entered: false, canEnter: false)};
    await openClub(tester, api.myClubs.first);
    expect(key('league.tooSmall'), findsOneWidget);
    expect(key('league.enter'), findsNothing);

    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.member)]
      ..leagues = {'club-1': league(entered: false)};
    await openClub(tester, api.myClubs.first);
    expect(key('league.card'), findsNothing);
  });

  testWidgets(
      'in the league: the place, the season, the top of the table and '
      'the whole table; a co-owner takes the club out after the week',
      (tester) async {
    final mine = lrow(2, 'Hostel A', 7, mine: true);
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.coOwner)]
      ..leagues = {
        'club-1': league(
          me: mine,
          table: [lrow(1, 'Gym B', 9), mine, lrow(3, 'Hostel C', 4)],
          clubs: 6,
        ),
      }
      ..fullTable = [
        lrow(1, 'Gym B', 9),
        mine,
        lrow(3, 'Hostel C', 4),
        lrow(4, 'Club D', 3),
        lrow(5, 'Club E', 1),
        lrow(6, 'Club F', 0),
      ];
    await openClub(tester, api.myClubs.first);
    expect(find.text('2nd of 6 · 7 points'), findsOneWidget);
    expect(
      find.text('This season: Mon 30 Nov to Sun 27 Dec'),
      findsOneWidget,
    );
    expect(key('league.row.c-Gym B'), findsOneWidget);
    await tap(tester, 'league.all');
    expect(api.calls, contains('league club-1 all'));
    expect(find.text('Club F'), findsOneWidget);
    Navigator.of(tester.element(key('league.full'))).pop();
    await tester.pumpAndSettle();

    await tap(tester, 'league.leave');
    await tap(tester, 'league.leave.confirm');
    expect(api.calls, contains('leave-league club-1'));
    expect(key('league.leaving'), findsOneWidget);
    expect(key('league.stay'), findsOneWidget);
  });

  testWidgets('the last season’s winner is marked by its name', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [
        const Club(
          id: 'club-1',
          name: 'Hostel A',
          code: 'ABCD2345',
          members: 4,
          mine: false,
          seasonWinner: true,
        ),
      ];
    await openClub(tester, api.myClubs.first);
    expect(key('club.winner'), findsOneWidget);
  });
  /* --------------------------------------------- M3: club in numbers -- */

  testWidgets(
      'the club this month in totals and its best week; nothing while '
      'the month is empty', (tester) async {
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.member)]
      ..numbers = {
        'club-1': const ClubNumbers(
          month: '2026-11',
          sessions: 143,
          runKm: 212.4,
          activeDays: 260,
          bestWeekFrom: '2026-11-16',
          bestWeekSessions: 41,
        ),
      };
    await openClub(tester, api.myClubs.first);
    expect(find.text('NOVEMBER, TOGETHER'), findsOneWidget);
    expect(find.text('143'), findsOneWidget);
    expect(find.text('212.4'), findsOneWidget);
    expect(find.text('260'), findsOneWidget);
    expect(
      find.text('Best week: 41 sessions, the week of Mon 16 Nov'),
      findsOneWidget,
    );

    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.member)];
    await openClub(tester, api.myClubs.first);
    expect(key('numbers.card'), findsNothing);
  });
  /* --------------------------------------------- M2: share a result -- */

  ClubMatch finished() => const ClubMatch(
        id: 'm0',
        metric: ChallengeMetric.activeDays,
        weekFrom: '2026-11-30',
        weekTo: '2026-12-06',
        status: MatchStatus.finished,
        challenger: true,
        us: ClubMatchSide(clubId: 'club-1', name: 'Hostel A', score: 3),
        them: ClubMatchSide(clubId: 'club-9', name: 'Gym B', score: 2.5),
        members: 12,
        daysLeft: 0,
        result: MatchResult.won,
      );

  test('a shared result names clubs, never members', () {
    final m = ResultCardText.match(finished());
    expect([
      m.title,
      m.big,
      m.line,
      m.fileName,
    ], [
      'Hostel A won',
      'Hostel A 3 · 2.5 Gym B',
      'active days per member · the week of Mon 30 Nov',
      'fitos-match-2026-11-30.png',
    ]);
    final l = ResultCardText.league(
      'Hostel A',
      league(me: lrow(2, 'Hostel A', 7, mine: true), clubs: 14),
    );
    expect([
      l.title,
      l.big,
      l.line,
    ], [
      'Hostel A is 2nd',
      '2nd of 14 · 7 points',
      'FITOS club league · Mon 30 Nov to Sun 27 Dec',
    ]);
  });

  testWidgets('a finished match shares as a picture through the share sheet',
      (tester) async {
    sharer.shared.clear();
    api = FakeCommunityApi(profile: me())
      ..myClubs = [club(role: ClubRole.member)]
      ..matches = {
        'club-1': [finished()],
      };
    await openClub(tester, api.myClubs.first);
    await tap(tester, 'match.share.m0');
    expect(key('shareResult.card'), findsOneWidget);
    expect(find.text('Hostel A 3 · 2.5 Gym B'), findsWidgets);
    await tester.runAsync(() async {
      await tester.tap(key('shareResult.share'));
      for (var i = 0; i < 50 && sharer.shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    expect(sharer.shared.single.$2, 'fitos-match-2026-11-30.png');
    expect(sharer.shared.single.$3, 'image/png');
    expect(sharer.shared.single.$1, greaterThan(0));
  });
}
