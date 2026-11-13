/// Beta 5.8 (ADR-057): Community as the server sees it — the member's own
/// profile, other people (a handle, a picture and a country, never more),
/// clubs and the boards. Boards hold counts only: gym sessions and run
/// distance this week, and the streak; beta 6.2 adds active days, the plan
/// kept and last week; beta 6.3 the feed, kudos, nudges, suggestions and
/// month and all-time boards.
library;

/// A handle: 3–20 of a–z, 0–9 and _ (the server checks the rest).
final kHandlePattern = RegExp(r'^[a-z0-9_]{3,20}$');

/// What the person typed, as the server stores it: no @, lower case.
String normalizeHandle(String raw) =>
    raw.trim().replaceFirst(RegExp('^@'), '').toLowerCase();

/// Beta 6.3 (C1, owner Q1): what a member shares with friends in the feed,
/// each switched on separately; nothing until chosen.
enum FeedKind {
  session('session', 'Sessions I finish', 'The day\'s name, like Push'),
  run('run', 'Runs', 'The distance, never the route'),
  record('record', 'Records', 'The lift or the run distance, never the weight'),
  streak('streak', 'Streak milestones', '7, 14, 30 days and on');

  const FeedKind(this.wire, this.label, this.hint);
  final String wire;
  final String label;
  final String hint;

  static FeedKind? fromWire(String w) {
    for (final k in values) {
      if (k.wire == w) return k;
    }
    return null;
  }
}

class CommunityProfile {
  const CommunityProfile({
    required this.handle,
    required this.avatarId,
    required this.country,
    required this.onWorld,
    required this.joinedAt,
    this.feed = const {},
    this.suggest = true,
    this.notify = true,
  });

  factory CommunityProfile.fromJson(Map<String, dynamic> j) => CommunityProfile(
        handle: j['handle'] as String,
        avatarId: j['avatarId'] as String?,
        country: j['country'] as String?,
        onWorld: j['onWorld'] as bool,
        joinedAt: DateTime.parse(j['joinedAt'] as String),
        feed: {
          for (final k in (j['feed'] as List<dynamic>?) ?? const [])
            if (FeedKind.fromWire(k as String) case final f?) f,
        },
        suggest: j['suggest'] as bool? ?? true,
        notify: j['notify'] as bool? ?? true,
      );

  final String handle;
  final String? avatarId;
  final String? country;

  /// On the world board: a separate choice, off by default.
  final bool onWorld;
  final DateTime joinedAt;

  /// Beta 6.3 (C1): the kinds shared with friends (none at first).
  final Set<FeedKind> feed;

  /// Beta 6.3 (C16): suggested to friends of friends and club-mates.
  final bool suggest;

  /// Beta 6.3 (C2, C3): the evening kudos summary and nudges as notifications.
  final bool notify;
}

class CommunityMe {
  const CommunityMe({required this.profile, required this.incoming});

  factory CommunityMe.fromJson(Map<String, dynamic> j) => CommunityMe(
        profile: j['profile'] == null
            ? null
            : CommunityProfile.fromJson(j['profile'] as Map<String, dynamic>),
        incoming: (j['incoming'] as num).toInt(),
      );

  /// Null until the person joins.
  final CommunityProfile? profile;

  /// Friend requests waiting for an answer.
  final int incoming;

  bool get joined => profile != null;
}

/// Another member as anyone may see them.
class CommunityPerson {
  const CommunityPerson({
    required this.userId,
    required this.handle,
    required this.avatarId,
    required this.country,
  });

  factory CommunityPerson.fromJson(Map<String, dynamic> j) => CommunityPerson(
        userId: j['userId'] as String,
        handle: j['handle'] as String,
        avatarId: j['avatarId'] as String?,
        country: j['country'] as String?,
      );

  final String userId;
  final String handle;
  final String? avatarId;
  final String? country;
}

class FriendLists {
  const FriendLists({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  factory FriendLists.fromJson(Map<String, dynamic> j) {
    List<CommunityPerson> list(String k) => [
          for (final p in j[k] as List<dynamic>)
            CommunityPerson.fromJson(p as Map<String, dynamic>),
        ];
    return FriendLists(
      friends: list('friends'),
      incoming: list('incoming'),
      outgoing: list('outgoing'),
    );
  }

  final List<CommunityPerson> friends;

  /// Asked you; waiting for your answer.
  final List<CommunityPerson> incoming;

  /// You asked; waiting for theirs.
  final List<CommunityPerson> outgoing;
}

class Club {
  const Club({
    required this.id,
    required this.name,
    required this.code,
    required this.members,
    required this.mine,
  });

  factory Club.fromJson(Map<String, dynamic> j) => Club(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        members: (j['members'] as num).toInt(),
        mine: j['mine'] as bool,
      );

  final String id;
  final String name;

  /// 8 letters and numbers, shown as two fours.
  final String code;
  final int members;

  /// You made it.
  final bool mine;

  String get shownCode =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}

/// Beta 6.3 (C13, owner Q4): this week, this month, or since joining.
enum BoardPeriod {
  week('week', 'Week'),
  month('month', 'Month'),
  all('all', 'All time');

  const BoardPeriod(this.wire, this.label);
  final String wire;
  final String label;

  static BoardPeriod fromWire(String w) =>
      values.firstWhere((p) => p.wire == w, orElse: () => week);
}

/// What a board ranks by. Beta 6.2 (C11): the streak, active days and
/// the plan kept as well.
enum BoardMetric {
  sessions('sessions', 'Gym sessions'),
  distance('distance', 'Run km'),
  streak('streak', 'Streak'),
  activeDays('active-days', 'Active days'),
  plan('plan', 'Kept my plan');

  const BoardMetric(this.wire, this.label);
  final String wire;
  final String label;

  static BoardMetric fromWire(String w) =>
      values.firstWhere((m) => m.wire == w, orElse: () => sessions);
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// The number a board row shows for its metric.
String boardValue(BoardRow r, BoardMetric m) => switch (m) {
      BoardMetric.sessions => _plural(r.sessions, 'session', 'sessions'),
      BoardMetric.distance => kmOf(r.runM),
      BoardMetric.streak => _plural(r.streak, 'day', 'days'),
      BoardMetric.activeDays => _plural(r.activeDays, 'day', 'days'),
      BoardMetric.plan => r.keptPct == null ? '–' : '${r.keptPct}%',
    };

/// The smaller line under a row: what else counted.
String? boardOther(BoardRow r, BoardMetric m) {
  final parts = <String>[
    if (m != BoardMetric.streak && r.streak > 0) '${r.streak}-day streak',
    if (m != BoardMetric.sessions && r.sessions > 0)
      _plural(r.sessions, 'session', 'sessions'),
    if (m != BoardMetric.distance && r.runM > 0) kmOf(r.runM),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "1st", "2nd", "3rd", "4th"…
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

/// Beta 6.2 (C12): last week on a board.
class LastWeek {
  const LastWeek({
    required this.weekFrom,
    required this.podium,
    required this.myRank,
    required this.moved,
  });

  factory LastWeek.fromJson(Map<String, dynamic> j) => LastWeek(
        weekFrom: j['weekFrom'] as String,
        podium: [
          for (final r in j['podium'] as List<dynamic>)
            BoardRow.fromJson(r as Map<String, dynamic>),
        ],
        myRank: (j['myRank'] as num?)?.toInt(),
        moved: (j['moved'] as num?)?.toInt(),
      );

  final String weekFrom;

  /// The top three (ties share a place).
  final List<BoardRow> podium;

  /// Your place last week; null when you were not on it.
  final int? myRank;

  /// Places gained since the week before (negative: lost).
  final int? moved;

  /// "You were 3rd last week · up 2", or null.
  String? get myLine {
    final rank = myRank;
    if (rank == null) return null;
    final m = moved;
    final change = m == null || m == 0
        ? ''
        : m > 0
            ? ' · up $m'
            : ' · down ${-m}';
    return 'You were ${ordinal(rank)} last week$change';
  }
}

/// Beta 6.2 (C4): one week's counts on a profile.
class WeekCounts {
  const WeekCounts({
    required this.weekFrom,
    required this.sessions,
    required this.runM,
    required this.activeDays,
    required this.keptPct,
  });

  factory WeekCounts.fromJson(Map<String, dynamic> j) => WeekCounts(
        weekFrom: j['weekFrom'] as String,
        sessions: (j['sessions'] as num).toInt(),
        runM: (j['runM'] as num).toInt(),
        activeDays: (j['activeDays'] as num).toInt(),
        keptPct: (j['keptPct'] as num?)?.toInt(),
      );

  final String weekFrom;
  final int sessions;
  final int runM;
  final int activeDays;

  /// Sessions done of those planned, in per cent; null without a plan.
  final int? keptPct;
}

/// Beta 6.2 (C4, owner 2026-11-11): a friend's or club-mate's board data.
class PersonProfile {
  const PersonProfile({
    required this.person,
    required this.friend,
    required this.friendsSince,
    required this.streak,
    required this.thisWeek,
    required this.weeks,
    required this.clubsInCommon,
    this.nudge,
  });

  factory PersonProfile.fromJson(Map<String, dynamic> j) => PersonProfile(
        person: CommunityPerson.fromJson(j['person'] as Map<String, dynamic>),
        friend: j['relation'] == 'friend',
        friendsSince: j['friendsSince'] == null
            ? null
            : DateTime.parse(j['friendsSince'] as String),
        streak: (j['streak'] as num).toInt(),
        thisWeek: WeekCounts.fromJson(j['thisWeek'] as Map<String, dynamic>),
        weeks: [
          for (final w in j['weeks'] as List<dynamic>)
            WeekCounts.fromJson(w as Map<String, dynamic>),
        ],
        clubsInCommon: [
          for (final c in j['clubsInCommon'] as List<dynamic>)
            (
              id: (c as Map<String, dynamic>)['id'] as String,
              name: c['name'] as String,
            ),
        ],
        nudge: switch (j['nudge']) {
          'can' => NudgeState.can,
          'active' => NudgeState.active,
          'sent' => NudgeState.sent,
          _ => null,
        },
      );

  final CommunityPerson person;

  /// A friend; otherwise someone in a club with you.
  final bool friend;
  final DateTime? friendsSince;
  final int streak;
  final WeekCounts thisWeek;

  /// The weeks before this one, oldest first.
  final List<WeekCounts> weeks;
  final List<({String id, String name})> clubsInCommon;

  /// Beta 6.3 (C3): whether you can nudge them; null for a club-mate.
  final NudgeState? nudge;
}

/// Beta 6.3 (C3): a friend can be nudged, trained in the last 3 days, or was
/// nudged by you this week.
enum NudgeState { can, active, sent }

/* ------------------------------------------------ beta 6.3: the feed -- */

/// A post's kind: a counted session, a counted run, a lift's record, a run
/// distance's record, a streak milestone.
enum PostKind {
  session('session'),
  run('run'),
  liftRecord('lift-record'),
  runRecord('run-record'),
  streak('streak');

  const PostKind(this.wire);
  final String wire;

  static PostKind fromWire(String w) =>
      values.firstWhere((k) => k.wire == w, orElse: () => session);
}

/// The run distances a record can be for, as people say them.
const kEffortLabels = <String, String>{
  '400m': '400 m',
  '1k': '1K',
  '1mile': '1 mile',
  '5k': '5K',
  '10k': '10K',
  'half': 'half marathon',
  'marathon': 'marathon',
};

class FeedPost {
  const FeedPost({
    required this.id,
    required this.person,
    required this.kind,
    required this.title,
    required this.value,
    required this.at,
    required this.kudos,
    required this.cheered,
    required this.mine,
    this.cheeredBy = const [],
  });

  factory FeedPost.fromJson(Map<String, dynamic> j) => FeedPost(
        id: j['id'] as String,
        person: CommunityPerson.fromJson(j['person'] as Map<String, dynamic>),
        kind: PostKind.fromWire(j['kind'] as String),
        title: j['title'] as String?,
        value: (j['value'] as num?)?.toInt(),
        at: DateTime.parse(j['at'] as String),
        kudos: (j['kudos'] as num).toInt(),
        cheered: j['cheered'] as bool,
        mine: j['mine'] as bool,
        cheeredBy: [
          for (final p in (j['cheeredBy'] as List<dynamic>?) ?? const [])
            CommunityPerson.fromJson(p as Map<String, dynamic>),
        ],
      );

  final String id;
  final CommunityPerson person;
  final PostKind kind;

  /// session: the day's name; lift-record: the lift; run-record: the distance.
  final String? title;

  /// run: metres; streak: days; lift-record: other lifts with a record.
  final int? value;
  final DateTime at;
  final int kudos;
  final bool cheered;
  final bool mine;

  /// On your own posts: who cheered, newest first.
  final List<CommunityPerson> cheeredBy;

  FeedPost cheer({required bool on, required int kudos}) => FeedPost(
        id: id,
        person: person,
        kind: kind,
        title: title,
        value: value,
        at: at,
        kudos: kudos,
        cheered: on,
        mine: mine,
        cheeredBy: cheeredBy,
      );
}

/// What a post says after the handle: "finished Push", "ran 5.2 km",
/// "set a record on Bench press and 2 more", "set a 5K record", "hit a
/// 30-day streak".
String postLine(FeedPost p) {
  switch (p.kind) {
    case PostKind.session:
      return 'finished ${p.title ?? 'a session'}';
    case PostKind.run:
      return 'ran ${kmOf(p.value ?? 0)}';
    case PostKind.liftRecord:
      final more = p.value ?? 0;
      return 'set a record on ${p.title ?? 'a lift'}'
          '${more > 0 ? ' and $more more' : ''}';
    case PostKind.runRecord:
      return 'set a ${kEffortLabels[p.title] ?? p.title ?? 'run'} record';
    case PostKind.streak:
      return 'hit a ${p.value ?? 0}-day streak';
  }
}

/// "Cheered by @asha", "Cheered by @asha and @ravi", "Cheered by @asha and 3
/// others".
String? cheeredLine(FeedPost p) {
  final by = p.cheeredBy;
  if (by.isEmpty) return null;
  final first = '@${by[0].handle}';
  final rest = p.kudos - 1;
  if (rest <= 0) return 'Cheered by $first';
  if (rest == 1 && by.length >= 2) {
    return 'Cheered by $first and @${by[1].handle}';
  }
  return 'Cheered by $first and $rest ${rest == 1 ? 'other' : 'others'}';
}

/// "just now", "12 min ago", "3 h ago", "yesterday", "4 days ago".
String agoOf(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 2) return 'yesterday';
  return '${d.inDays} days ago';
}

/// Beta 6.3 (C3): a nudge you received.
class Nudge {
  const Nudge({required this.person, required this.at});

  factory Nudge.fromJson(Map<String, dynamic> j) => Nudge(
        person: CommunityPerson.fromJson(j['person'] as Map<String, dynamic>),
        at: DateTime.parse(j['at'] as String),
      );

  final CommunityPerson person;
  final DateTime at;
}

class Feed {
  const Feed({required this.items, required this.next, required this.nudges});

  factory Feed.fromJson(Map<String, dynamic> j) => Feed(
        items: [
          for (final p in j['items'] as List<dynamic>)
            FeedPost.fromJson(p as Map<String, dynamic>),
        ],
        next: j['next'] == null ? null : DateTime.parse(j['next'] as String),
        nudges: [
          for (final n in (j['nudges'] as List<dynamic>?) ?? const [])
            Nudge.fromJson(n as Map<String, dynamic>),
        ],
      );

  final List<FeedPost> items;

  /// Pass as `before` for older posts; null at the end.
  final DateTime? next;
  final List<Nudge> nudges;
}

/// Beta 6.3 (C16, owner Q3): someone you may know — a count of friends in
/// common or a club you share, never which friends.
class Suggestion {
  const Suggestion({
    required this.person,
    required this.mutualFriends,
    required this.club,
  });

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        person: CommunityPerson.fromJson(j['person'] as Map<String, dynamic>),
        mutualFriends: (j['mutualFriends'] as num).toInt(),
        club: j['club'] as String?,
      );

  final CommunityPerson person;
  final int mutualFriends;
  final String? club;

  /// "2 friends in common · In Gym Bros".
  String get why => [
        if (mutualFriends > 0)
          '$mutualFriends ${mutualFriends == 1 ? 'friend' : 'friends'} in common',
        if (club != null) 'In $club',
      ].join(' · ');
}

/// Beta 6.2 (C8, C15, owner Q1): the links that open FITOS (Android App Links).
String clubInviteUrl(String code) => 'https://tryfitos.me/c/$code';
String friendInviteUrl(String handle) => 'https://tryfitos.me/u/$handle';

/// What an opened link asks for.
sealed class InviteLink {
  const InviteLink();

  /// A tryfitos.me club or friend link; null for anything else.
  static InviteLink? parse(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https' || uri.host != 'tryfitos.me') {
      return null;
    }
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length != 2) return null;
    if (parts[0] == 'c') {
      final code = parts[1].toUpperCase();
      return RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)
          ? ClubInvite(code)
          : null;
    }
    if (parts[0] == 'u') {
      final handle = parts[1].toLowerCase();
      return kHandlePattern.hasMatch(handle) ? FriendInvite(handle) : null;
    }
    return null;
  }
}

class ClubInvite extends InviteLink {
  const ClubInvite(this.code);
  final String code;
}

class FriendInvite extends InviteLink {
  const FriendInvite(this.handle);
  final String handle;
}

class BoardRow {
  const BoardRow({
    required this.rank,
    required this.userId,
    required this.handle,
    required this.avatarId,
    required this.country,
    required this.sessions,
    required this.runM,
    required this.streak,
    required this.me,
    this.activeDays = 0,
    this.keptPct,
  });

  factory BoardRow.fromJson(Map<String, dynamic> j) => BoardRow(
        rank: (j['rank'] as num).toInt(),
        userId: j['userId'] as String,
        handle: j['handle'] as String,
        avatarId: j['avatarId'] as String?,
        country: j['country'] as String?,
        sessions: (j['sessions'] as num).toInt(),
        runM: (j['runM'] as num).toInt(),
        streak: (j['streak'] as num).toInt(),
        me: j['me'] as bool,
        activeDays: (j['activeDays'] as num?)?.toInt() ?? 0,
        keptPct: (j['keptPct'] as num?)?.toInt(),
      );

  final int rank;
  final String userId;
  final String handle;
  final String? avatarId;
  final String? country;
  final int sessions;
  final int runM;
  final int streak;
  final bool me;

  /// Beta 6.2: days this week with a counted session or run.
  final int activeDays;

  /// Beta 6.2: sessions done of those planned up to today; null without a plan.
  final int? keptPct;
}

class Board {
  const Board({
    required this.metric,
    required this.weekFrom,
    required this.weekTo,
    required this.rows,
    required this.me,
    required this.total,
    this.lastWeek,
    this.period = BoardPeriod.week,
    this.periodFrom,
  });

  factory Board.fromJson(Map<String, dynamic> j) => Board(
        metric: BoardMetric.fromWire(j['metric'] as String),
        weekFrom: j['weekFrom'] as String,
        weekTo: j['weekTo'] as String,
        rows: [
          for (final r in j['rows'] as List<dynamic>)
            BoardRow.fromJson(r as Map<String, dynamic>),
        ],
        me: j['me'] == null
            ? null
            : BoardRow.fromJson(j['me'] as Map<String, dynamic>),
        total: (j['total'] as num).toInt(),
        lastWeek: j['lastWeek'] == null
            ? null
            : LastWeek.fromJson(j['lastWeek'] as Map<String, dynamic>),
        period: BoardPeriod.fromWire(j['period'] as String? ?? 'week'),
        periodFrom: j['periodFrom'] as String?,
      );

  final BoardMetric metric;
  final String weekFrom;
  final String weekTo;
  final List<BoardRow> rows;

  /// Your own row when it is below the top; null when you are not on it.
  final BoardRow? me;
  final int total;

  /// Beta 6.2 (C12): null when nobody here counted anything last week.
  final LastWeek? lastWeek;

  /// Beta 6.3 (C13): the period counted, and its first day (null: the week).
  final BoardPeriod period;
  final String? periodFrom;
}

/// Why a report is made.
enum ReportReason {
  handle('handle', 'Their handle'),
  clubName('club-name', 'The club name'),
  cheating('cheating', 'Cheating'),
  harassment('harassment', 'Harassment'),
  other('other', 'Something else');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

/// The flag of an ISO country code, from its regional indicator letters.
String flagOf(String? code) {
  if (code == null || code.length != 2) return '';
  final a = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final b = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCodes([a, b]);
}

/// "12.4 km" from metres.
String kmOf(int metres) {
  final km = metres / 1000;
  return '${km >= 100 ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
}

/// ISO 3166-1 alpha-2 codes with English names (the same list as the
/// contracts' COUNTRIES; a test keeps them in step).
const kCountries = <String, String>{
  'AD': 'Andorra',
  'AE': 'United Arab Emirates',
  'AF': 'Afghanistan',
  'AG': 'Antigua & Barbuda',
  'AI': 'Anguilla',
  'AL': 'Albania',
  'AM': 'Armenia',
  'AO': 'Angola',
  'AQ': 'Antarctica',
  'AR': 'Argentina',
  'AS': 'American Samoa',
  'AT': 'Austria',
  'AU': 'Australia',
  'AW': 'Aruba',
  'AX': 'Åland Islands',
  'AZ': 'Azerbaijan',
  'BA': 'Bosnia & Herzegovina',
  'BB': 'Barbados',
  'BD': 'Bangladesh',
  'BE': 'Belgium',
  'BF': 'Burkina Faso',
  'BG': 'Bulgaria',
  'BH': 'Bahrain',
  'BI': 'Burundi',
  'BJ': 'Benin',
  'BL': 'St. Barthélemy',
  'BM': 'Bermuda',
  'BN': 'Brunei',
  'BO': 'Bolivia',
  'BQ': 'Caribbean Netherlands',
  'BR': 'Brazil',
  'BS': 'Bahamas',
  'BT': 'Bhutan',
  'BV': 'Bouvet Island',
  'BW': 'Botswana',
  'BY': 'Belarus',
  'BZ': 'Belize',
  'CA': 'Canada',
  'CC': 'Cocos (Keeling) Islands',
  'CD': 'Congo - Kinshasa',
  'CF': 'Central African Republic',
  'CG': 'Congo - Brazzaville',
  'CH': 'Switzerland',
  'CI': 'Côte d’Ivoire',
  'CK': 'Cook Islands',
  'CL': 'Chile',
  'CM': 'Cameroon',
  'CN': 'China',
  'CO': 'Colombia',
  'CR': 'Costa Rica',
  'CU': 'Cuba',
  'CV': 'Cape Verde',
  'CW': 'Curaçao',
  'CX': 'Christmas Island',
  'CY': 'Cyprus',
  'CZ': 'Czechia',
  'DE': 'Germany',
  'DJ': 'Djibouti',
  'DK': 'Denmark',
  'DM': 'Dominica',
  'DO': 'Dominican Republic',
  'DY': 'Benin',
  'DZ': 'Algeria',
  'EC': 'Ecuador',
  'EE': 'Estonia',
  'EG': 'Egypt',
  'EH': 'Western Sahara',
  'ER': 'Eritrea',
  'ES': 'Spain',
  'ET': 'Ethiopia',
  'FI': 'Finland',
  'FJ': 'Fiji',
  'FK': 'Falkland Islands',
  'FM': 'Micronesia',
  'FO': 'Faroe Islands',
  'FR': 'France',
  'GA': 'Gabon',
  'GB': 'United Kingdom',
  'GD': 'Grenada',
  'GE': 'Georgia',
  'GF': 'French Guiana',
  'GG': 'Guernsey',
  'GH': 'Ghana',
  'GI': 'Gibraltar',
  'GL': 'Greenland',
  'GM': 'Gambia',
  'GN': 'Guinea',
  'GP': 'Guadeloupe',
  'GQ': 'Equatorial Guinea',
  'GR': 'Greece',
  'GS': 'South Georgia & South Sandwich Islands',
  'GT': 'Guatemala',
  'GU': 'Guam',
  'GW': 'Guinea-Bissau',
  'GY': 'Guyana',
  'HK': 'Hong Kong SAR China',
  'HM': 'Heard & McDonald Islands',
  'HN': 'Honduras',
  'HR': 'Croatia',
  'HT': 'Haiti',
  'HU': 'Hungary',
  'HV': 'Burkina Faso',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IM': 'Isle of Man',
  'IN': 'India',
  'IO': 'British Indian Ocean Territory',
  'IQ': 'Iraq',
  'IR': 'Iran',
  'IS': 'Iceland',
  'IT': 'Italy',
  'JE': 'Jersey',
  'JM': 'Jamaica',
  'JO': 'Jordan',
  'JP': 'Japan',
  'KE': 'Kenya',
  'KG': 'Kyrgyzstan',
  'KH': 'Cambodia',
  'KI': 'Kiribati',
  'KM': 'Comoros',
  'KN': 'St. Kitts & Nevis',
  'KP': 'North Korea',
  'KR': 'South Korea',
  'KW': 'Kuwait',
  'KY': 'Cayman Islands',
  'KZ': 'Kazakhstan',
  'LA': 'Laos',
  'LB': 'Lebanon',
  'LC': 'St. Lucia',
  'LI': 'Liechtenstein',
  'LK': 'Sri Lanka',
  'LR': 'Liberia',
  'LS': 'Lesotho',
  'LT': 'Lithuania',
  'LU': 'Luxembourg',
  'LV': 'Latvia',
  'LY': 'Libya',
  'MA': 'Morocco',
  'MC': 'Monaco',
  'MD': 'Moldova',
  'ME': 'Montenegro',
  'MF': 'St. Martin',
  'MG': 'Madagascar',
  'MH': 'Marshall Islands',
  'MK': 'North Macedonia',
  'ML': 'Mali',
  'MM': 'Myanmar (Burma)',
  'MN': 'Mongolia',
  'MO': 'Macao SAR China',
  'MP': 'Northern Mariana Islands',
  'MQ': 'Martinique',
  'MR': 'Mauritania',
  'MS': 'Montserrat',
  'MT': 'Malta',
  'MU': 'Mauritius',
  'MV': 'Maldives',
  'MW': 'Malawi',
  'MX': 'Mexico',
  'MY': 'Malaysia',
  'MZ': 'Mozambique',
  'NA': 'Namibia',
  'NC': 'New Caledonia',
  'NE': 'Niger',
  'NF': 'Norfolk Island',
  'NG': 'Nigeria',
  'NH': 'Vanuatu',
  'NI': 'Nicaragua',
  'NL': 'Netherlands',
  'NO': 'Norway',
  'NP': 'Nepal',
  'NR': 'Nauru',
  'NU': 'Niue',
  'NZ': 'New Zealand',
  'OM': 'Oman',
  'PA': 'Panama',
  'PE': 'Peru',
  'PF': 'French Polynesia',
  'PG': 'Papua New Guinea',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'PL': 'Poland',
  'PM': 'St. Pierre & Miquelon',
  'PN': 'Pitcairn Islands',
  'PR': 'Puerto Rico',
  'PS': 'Palestinian Territories',
  'PT': 'Portugal',
  'PW': 'Palau',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RE': 'Réunion',
  'RH': 'Zimbabwe',
  'RO': 'Romania',
  'RS': 'Serbia',
  'RU': 'Russia',
  'RW': 'Rwanda',
  'SA': 'Saudi Arabia',
  'SB': 'Solomon Islands',
  'SC': 'Seychelles',
  'SD': 'Sudan',
  'SE': 'Sweden',
  'SG': 'Singapore',
  'SH': 'St. Helena',
  'SI': 'Slovenia',
  'SJ': 'Svalbard & Jan Mayen',
  'SK': 'Slovakia',
  'SL': 'Sierra Leone',
  'SM': 'San Marino',
  'SN': 'Senegal',
  'SO': 'Somalia',
  'SR': 'Suriname',
  'SS': 'South Sudan',
  'ST': 'São Tomé & Príncipe',
  'SV': 'El Salvador',
  'SX': 'Sint Maarten',
  'SY': 'Syria',
  'SZ': 'Eswatini',
  'TC': 'Turks & Caicos Islands',
  'TD': 'Chad',
  'TF': 'French Southern Territories',
  'TG': 'Togo',
  'TH': 'Thailand',
  'TJ': 'Tajikistan',
  'TK': 'Tokelau',
  'TL': 'Timor-Leste',
  'TM': 'Turkmenistan',
  'TN': 'Tunisia',
  'TO': 'Tonga',
  'TR': 'Türkiye',
  'TT': 'Trinidad & Tobago',
  'TV': 'Tuvalu',
  'TW': 'Taiwan',
  'TZ': 'Tanzania',
  'UA': 'Ukraine',
  'UG': 'Uganda',
  'UK': 'United Kingdom',
  'UM': 'U.S. Outlying Islands',
  'US': 'United States',
  'UY': 'Uruguay',
  'UZ': 'Uzbekistan',
  'VA': 'Vatican City',
  'VC': 'St. Vincent & Grenadines',
  'VD': 'Vietnam',
  'VE': 'Venezuela',
  'VG': 'British Virgin Islands',
  'VI': 'U.S. Virgin Islands',
  'VN': 'Vietnam',
  'VU': 'Vanuatu',
  'WF': 'Wallis & Futuna',
  'WS': 'Samoa',
  'XK': 'Kosovo',
  'YE': 'Yemen',
  'YT': 'Mayotte',
  'ZA': 'South Africa',
  'ZM': 'Zambia',
  'ZW': 'Zimbabwe',
};
