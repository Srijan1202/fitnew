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
