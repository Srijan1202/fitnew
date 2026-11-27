/// Beta 6.5 (Clubs together): a club's monthly challenge (K2) and club vs
/// club (K3). The server counts; the phone only shows.
library;

/// What a challenge counts.
enum ChallengeMetric {
  sessions('sessions', 'Sessions', 'sessions'),
  distance('distance', 'Run km', 'km'),
  activeDays('active-days', 'Active days', 'active days');

  const ChallengeMetric(this.wire, this.label, this.unit);
  final String wire;
  final String label;

  /// After a number: "200 sessions", "50 km".
  final String unit;

  static ChallengeMetric fromWire(String w) =>
      values.firstWhere((m) => m.wire == w, orElse: () => sessions);
}

/// The limits the server keeps to.
const int kChallengeTargetMin = 10;
const int kChallengeTargetMax = 100000;

/// A count as shown: whole numbers plain, kilometres to 0.1.
String countText(num n) =>
    n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

/// "2026-12" for a date's month.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// The month after `d`'s.
String nextMonthKey(DateTime d) => monthKey(DateTime(d.year, d.month + 1));

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "December" for "2026-12".
String monthName(String month) => _months[int.parse(month.substring(5, 7)) - 1];

class ClubChallenge {
  const ClubChallenge({
    required this.id,
    required this.metric,
    required this.target,
    required this.month,
    required this.title,
    required this.total,
    required this.mine,
    required this.reachedAt,
    required this.closedAt,
    required this.endedEarly,
    required this.daysLeft,
    required this.started,
  });

  factory ClubChallenge.fromJson(Map<String, dynamic> j) => ClubChallenge(
        id: j['id'] as String,
        metric: ChallengeMetric.fromWire(j['metric'] as String),
        target: (j['target'] as num).toInt(),
        month: j['month'] as String,
        title: j['title'] as String,
        total: j['total'] as num,
        mine: j['mine'] as num?,
        reachedAt: j['reachedAt'] == null
            ? null
            : DateTime.parse(j['reachedAt'] as String),
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.parse(j['closedAt'] as String),
        endedEarly: j['endedEarly'] as bool,
        daysLeft: (j['daysLeft'] as num).toInt(),
        started: j['started'] as bool,
      );

  final String id;
  final ChallengeMetric metric;
  final int target;
  final String month;

  /// Made from the numbers: "200 sessions together in December".
  final String title;

  /// The club's count, in the target's unit.
  final num total;

  /// Your part; null on a finished one.
  final num? mine;
  final DateTime? reachedAt;
  final DateTime? closedAt;
  final bool endedEarly;

  /// In your month, today included; 0 once over.
  final int daysLeft;

  /// The month has begun where you are (one can be set for next month).
  final bool started;

  bool get reached => reachedAt != null;

  /// How full the bar is, 0 to 1.
  double get progress =>
      target == 0 ? 0 : (total / target).clamp(0, 1).toDouble();

  /// "143 of 200 sessions".
  String get countLine => '${countText(total)} of $target ${metric.unit}';
}

class ClubChallengeView {
  const ClubChallengeView({
    required this.current,
    required this.history,
    required this.suggested,
  });

  factory ClubChallengeView.fromJson(Map<String, dynamic> j) {
    final s = j['suggested'] as Map<String, dynamic>?;
    return ClubChallengeView(
      current: j['current'] == null
          ? null
          : ClubChallenge.fromJson(j['current'] as Map<String, dynamic>),
      history: [
        for (final c in j['history'] as List<dynamic>)
          ClubChallenge.fromJson(c as Map<String, dynamic>),
      ],
      suggested: s == null
          ? null
          : {
              for (final m in ChallengeMetric.values)
                if (s[m.wire] != null) m: (s[m.wire] as num).toInt(),
            },
    );
  }

  final ClubChallenge? current;

  /// The last three finished, newest first.
  final List<ClubChallenge> history;

  /// For the club's owner: a target for each metric; null for others.
  final Map<ChallengeMetric, int>? suggested;
}

/* ------------------------------------------------- K3: club vs club -- */

enum MatchStatus { pending, accepted, finished }

enum MatchResult { won, lost, drew }

/// One club in a match: the other shows only its name and its average.
class ClubMatchSide {
  const ClubMatchSide({
    required this.clubId,
    required this.name,
    required this.score,
  });

  factory ClubMatchSide.fromJson(Map<String, dynamic> j) => ClubMatchSide(
        clubId: j['clubId'] as String,
        name: j['name'] as String,
        score: j['score'] as num?,
      );

  final String clubId;
  final String name;

  /// The average per member, to 0.1; null before the week starts.
  final num? score;
}

/// Beta 6.5 (K3, owner Q3): a week, Monday to Sunday, between two clubs.
class ClubMatch {
  const ClubMatch({
    required this.id,
    required this.metric,
    required this.weekFrom,
    required this.weekTo,
    required this.status,
    required this.challenger,
    required this.us,
    required this.them,
    required this.members,
    required this.daysLeft,
    required this.result,
  });

  factory ClubMatch.fromJson(Map<String, dynamic> j) => ClubMatch(
        id: j['id'] as String,
        metric: ChallengeMetric.fromWire(j['metric'] as String),
        weekFrom: j['weekFrom'] as String,
        weekTo: j['weekTo'] as String,
        status: MatchStatus.values.byName(j['status'] as String),
        challenger: j['challenger'] as bool,
        us: ClubMatchSide.fromJson(j['us'] as Map<String, dynamic>),
        them: ClubMatchSide.fromJson(j['them'] as Map<String, dynamic>),
        members: (j['members'] as num?)?.toInt(),
        daysLeft: (j['daysLeft'] as num).toInt(),
        result: j['result'] == null
            ? null
            : MatchResult.values.byName(j['result'] as String),
      );

  final String id;
  final ChallengeMetric metric;
  final String weekFrom;
  final String weekTo;
  final MatchStatus status;

  /// This club challenged.
  final bool challenger;
  final ClubMatchSide us;
  final ClubMatchSide them;

  /// This club's members counted; null before the week starts.
  final int? members;
  final int daysLeft;
  final MatchResult? result;

  bool get live => status == MatchStatus.accepted && members != null;

  /// Waiting or on: the club cannot take another that week.
  bool get open => status != MatchStatus.finished;

  /// "sessions per member".
  String get perMemberUnit => '${metric.unit} per member';
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _short = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Mon 30 Nov" for "2026-11-30".
String dayLabel(String date) {
  final d = DateTime.parse(date);
  return '${_days[d.weekday - 1]} ${d.day} ${_short[d.month - 1]}';
}

/* --------------------------------------------------- L1: the league -- */

/// "1st", "2nd", "3rd", "11th", "22nd".
String ordinalOf(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final end = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$end';
}

/// Beta 6.6 (L1): one club's row in the league table: names and results,
/// never members.
class LeagueRow {
  const LeagueRow({
    required this.place,
    required this.clubId,
    required this.name,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.byes,
    required this.points,
    required this.mine,
  });

  factory LeagueRow.fromJson(Map<String, dynamic> j) => LeagueRow(
        place: (j['place'] as num).toInt(),
        clubId: j['clubId'] as String,
        name: j['name'] as String,
        played: (j['played'] as num).toInt(),
        won: (j['won'] as num).toInt(),
        drawn: (j['drawn'] as num).toInt(),
        lost: (j['lost'] as num).toInt(),
        byes: (j['byes'] as num).toInt(),
        points: (j['points'] as num).toInt(),
        mine: j['mine'] as bool,
      );

  final int place;
  final String clubId;
  final String name;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int byes;
  final int points;

  /// This club.
  final bool mine;
}

/// Beta 6.6 (L1, owner 2026-11-25): a club in the league.
class ClubLeague {
  const ClubLeague({
    required this.entered,
    required this.leaving,
    required this.canEnter,
    required this.seasonFrom,
    required this.seasonTo,
    required this.seasonFinished,
    required this.me,
    required this.table,
    required this.clubs,
  });

  factory ClubLeague.fromJson(Map<String, dynamic> j) {
    final s = j['season'] as Map<String, dynamic>?;
    return ClubLeague(
      entered: j['entered'] as bool,
      leaving: j['leaving'] as bool,
      canEnter: j['canEnter'] as bool,
      seasonFrom: s?['startsOn'] as String?,
      seasonTo: s?['endsOn'] as String?,
      seasonFinished: s?['finished'] as bool? ?? false,
      me: j['me'] == null
          ? null
          : LeagueRow.fromJson(j['me'] as Map<String, dynamic>),
      table: [
        for (final r in j['table'] as List<dynamic>)
          LeagueRow.fromJson(r as Map<String, dynamic>),
      ],
      clubs: (j['clubs'] as num).toInt(),
    );
  }

  final bool entered;

  /// Entered, and out after this week.
  final bool leaving;

  /// 3 members or more.
  final bool canEnter;

  /// The latest season's Monday and Sunday; null before the first.
  final String? seasonFrom;
  final String? seasonTo;
  final bool seasonFinished;
  final LeagueRow? me;

  /// The top 5 and this club (or every club).
  final List<LeagueRow> table;
  final int clubs;
}

/* ------------------------------------------------ M3: club in numbers -- */

/// Beta 6.6 (M3): the club this month, as totals only.
class ClubNumbers {
  const ClubNumbers({
    required this.month,
    required this.sessions,
    required this.runKm,
    required this.activeDays,
    required this.bestWeekFrom,
    required this.bestWeekSessions,
  });

  factory ClubNumbers.fromJson(Map<String, dynamic> j) {
    final b = j['bestWeek'] as Map<String, dynamic>?;
    return ClubNumbers(
      month: j['month'] as String,
      sessions: (j['sessions'] as num).toInt(),
      runKm: j['runKm'] as num,
      activeDays: (j['activeDays'] as num).toInt(),
      bestWeekFrom: b?['weekFrom'] as String?,
      bestWeekSessions: (b?['sessions'] as num?)?.toInt(),
    );
  }

  final String month;
  final int sessions;
  final num runKm;
  final int activeDays;

  /// The best week so far (by sessions); null before any.
  final String? bestWeekFrom;
  final int? bestWeekSessions;
}

/// Beta 6.7 (R5): one line of what's on in a club, for its card in the list:
/// this week's match while it's on, else this month's challenge once
/// started; null when nothing is.
sealed class ClubNow {
  const ClubNow({required this.metric, required this.daysLeft});

  static ClubNow? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final metric = ChallengeMetric.fromWire(raw['metric'] as String);
    final daysLeft = (raw['daysLeft'] as num).toInt();
    return switch (raw['kind']) {
      'match' => ClubNowMatch(
          metric: metric,
          daysLeft: daysLeft,
          opponent: raw['opponent'] as String,
          us: raw['us'] as num?,
          them: raw['them'] as num?,
        ),
      'challenge' => ClubNowChallenge(
          metric: metric,
          daysLeft: daysLeft,
          total: raw['total'] as num,
          target: (raw['target'] as num).toInt(),
        ),
      _ => null,
    };
  }

  final ChallengeMetric metric;
  final int daysLeft;

  String get daysText => daysLeft <= 1 ? 'last day' : '$daysLeft days left';

  /// "vs Gym B · 2.4 – 2.1 · 3 days left", "143 of 200 sessions · 4 days left".
  String get line;
}

class ClubNowMatch extends ClubNow {
  const ClubNowMatch({
    required super.metric,
    required super.daysLeft,
    required this.opponent,
    required this.us,
    required this.them,
  });

  final String opponent;
  final num? us;
  final num? them;

  @override
  String get line => [
        'vs $opponent',
        if (us != null && them != null)
          '${countText(us!)} – ${countText(them!)}',
        daysText,
      ].join(' · ');
}

class ClubNowChallenge extends ClubNow {
  const ClubNowChallenge({
    required super.metric,
    required super.daysLeft,
    required this.total,
    required this.target,
  });

  final num total;
  final int target;

  double get progress =>
      target <= 0 ? 0 : (total / target).clamp(0, 1).toDouble();

  @override
  String get line =>
      '${countText(total)} of $target ${metric.unit} · $daysText';
}
