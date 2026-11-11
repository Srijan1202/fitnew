import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/community/data/community_api.dart';
import 'package:fitos/features/community/domain/community.dart';

/// Beta 5.8 (ADR-057): Community in memory — not joined until [join]; the
/// calls made are recorded; boards are what the test sets.
class FakeCommunityApi implements CommunityApi {
  FakeCommunityApi({this.profile, this.failure});

  /// Joined already (as this profile).
  CommunityProfile? profile;

  /// Every call fails with this (the admin's switch off, offline).
  Failure? failure;

  FriendLists lists =
      const FriendLists(friends: [], incoming: [], outgoing: []);
  List<Club> myClubs = [];
  List<CommunityPerson> found = [];
  List<CommunityPerson> blockedPeople = [];
  final calls = <String>[];

  /// The board every board call returns (friends, club and world alike).
  Board Function(BoardMetric metric, String? country)? board;

  /// What join answers instead of joining (a taken handle, say).
  Failure? joinFailure;

  Result<T> _r<T>(T value) => failure == null ? Ok(value) : Err(failure!);

  CommunityMe get _me =>
      CommunityMe(profile: profile, incoming: lists.incoming.length);

  @override
  Future<Result<CommunityMe>> me() async => _r(_me);

  @override
  Future<Result<CommunityMe>> join({
    required String handle,
    required String? country,
    required bool onWorld,
    required String policyVersion,
  }) async {
    calls.add('join $handle $country $onWorld $policyVersion');
    if (joinFailure != null) return Err(joinFailure!);
    profile = CommunityProfile(
      handle: handle,
      avatarId: null,
      country: country,
      onWorld: onWorld,
      joinedAt: DateTime.utc(2026, 11, 8),
    );
    return _r(_me);
  }

  @override
  Future<Result<CommunityMe>> update({
    String? handle,
    String? country,
    bool clearCountry = false,
    bool? onWorld,
  }) async {
    calls.add(
      'update ${handle ?? ''} ${clearCountry ? 'none' : country ?? ''} ${onWorld ?? ''}',
    );
    final p = profile!;
    profile = CommunityProfile(
      handle: handle ?? p.handle,
      avatarId: p.avatarId,
      country: clearCountry ? null : country ?? p.country,
      onWorld: onWorld ?? p.onWorld,
      joinedAt: p.joinedAt,
    );
    return _r(_me);
  }

  @override
  Future<Result<void>> leave() async {
    calls.add('leave');
    profile = null;
    return _r(null);
  }

  @override
  Future<Result<List<CommunityPerson>>> search(String q) async {
    calls.add('search $q');
    return _r(found.where((p) => p.handle.startsWith(q)).toList());
  }

  @override
  Future<Result<FriendLists>> friends() async => _r(lists);

  @override
  Future<Result<String>> addFriend(String handle) async {
    calls.add('add $handle');
    return _r('requested');
  }

  @override
  Future<Result<void>> accept(String userId) async {
    calls.add('accept $userId');
    final p = lists.incoming.firstWhere((x) => x.userId == userId);
    lists = FriendLists(
      friends: [...lists.friends, p],
      incoming: lists.incoming.where((x) => x.userId != userId).toList(),
      outgoing: lists.outgoing,
    );
    return _r(null);
  }

  @override
  Future<Result<void>> unfriend(String userId) async {
    calls.add('unfriend $userId');
    return _r(null);
  }

  @override
  Future<Result<List<CommunityPerson>>> blocked() async => _r(blockedPeople);

  @override
  Future<Result<void>> block(String userId) async {
    calls.add('block $userId');
    return _r(null);
  }

  @override
  Future<Result<void>> unblock(String userId) async {
    calls.add('unblock $userId');
    blockedPeople = blockedPeople.where((p) => p.userId != userId).toList();
    return _r(null);
  }

  @override
  Future<Result<List<Club>>> clubs() async => _r(myClubs);

  @override
  Future<Result<Club>> createClub(String name) async {
    calls.add('club $name');
    final c = Club(
      id: 'club-1',
      name: name,
      code: 'ABCD2345',
      members: 1,
      mine: true,
    );
    myClubs = [...myClubs, c];
    return _r(c);
  }

  @override
  Future<Result<Club>> joinClub(String code) async {
    calls.add('join-club $code');
    return const Err(NotFound('No club has that code.'));
  }

  @override
  Future<Result<void>> leaveClub(String clubId) async {
    calls.add('leave-club $clubId');
    myClubs = myClubs.where((c) => c.id != clubId).toList();
    return _r(null);
  }

  /// Beta 6.2: the profile [personProfile] answers (404 when null).
  PersonProfile? profileOf;
  List<CommunityPerson> removed = [];

  @override
  Future<Result<PersonProfile>> personProfile(String userId) async {
    calls.add('profile $userId');
    final p = profileOf;
    return p == null ? const Err(NotFound('No such member.')) : _r(p);
  }

  Club _changed(String clubId, {String? name, String? code, bool? mine}) {
    final c = myClubs.firstWhere((x) => x.id == clubId);
    final next = Club(
      id: c.id,
      name: name ?? c.name,
      code: code ?? c.code,
      members: c.members,
      mine: mine ?? c.mine,
    );
    myClubs = [for (final x in myClubs) x.id == clubId ? next : x];
    return next;
  }

  @override
  Future<Result<Club>> renameClub(String clubId, String name) async {
    calls.add('rename-club $clubId $name');
    return _r(_changed(clubId, name: name));
  }

  @override
  Future<Result<Club>> newClubCode(String clubId) async {
    calls.add('new-code $clubId');
    return _r(_changed(clubId, code: 'WXYZ6789'));
  }

  @override
  Future<Result<Club>> passClub(String clubId, String userId) async {
    calls.add('pass-club $clubId $userId');
    return _r(_changed(clubId, mine: false));
  }

  @override
  Future<Result<void>> removeMember(String clubId, String userId) async {
    calls.add('remove $clubId $userId');
    return _r(null);
  }

  @override
  Future<Result<List<CommunityPerson>>> removedFrom(String clubId) async =>
      _r(removed);

  @override
  Future<Result<void>> letBack(String clubId, String userId) async {
    calls.add('let-back $clubId $userId');
    removed = removed.where((p) => p.userId != userId).toList();
    return _r(null);
  }

  Board _board(BoardMetric metric, String? country) =>
      board?.call(metric, country) ??
      Board(
        metric: metric,
        weekFrom: '2026-11-02',
        weekTo: '2026-11-08',
        rows: const [],
        me: null,
        total: 0,
      );

  @override
  Future<Result<Board>> friendsBoard(BoardMetric metric) async {
    calls.add('friends-board ${metric.wire}');
    return _r(_board(metric, null));
  }

  @override
  Future<Result<Board>> clubBoard(String clubId, BoardMetric metric) async {
    calls.add('club-board $clubId ${metric.wire}');
    return _r(_board(metric, null));
  }

  @override
  Future<Result<Board>> worldBoard(
    BoardMetric metric, {
    String? country,
  }) async {
    calls.add('world-board ${metric.wire} ${country ?? 'all'}');
    return _r(_board(metric, country));
  }

  @override
  Future<Result<void>> report({
    String? userId,
    String? clubId,
    required ReportReason reason,
    String? note,
  }) async {
    calls.add('report ${userId ?? clubId} ${reason.wire}');
    return _r(null);
  }
}

BoardRow row(
  int rank,
  String handle, {
  int sessions = 0,
  int runM = 0,
  int streak = 0,
  bool me = false,
  String? country,
  int activeDays = 0,
  int? keptPct,
}) =>
    BoardRow(
      rank: rank,
      userId: 'u-$handle',
      handle: handle,
      avatarId: null,
      country: country,
      sessions: sessions,
      runM: runM,
      streak: streak,
      me: me,
      activeDays: activeDays,
      keptPct: keptPct,
    );

CommunityPerson person(String handle) => CommunityPerson(
      userId: 'u-$handle',
      handle: handle,
      avatarId: null,
      country: null,
    );
