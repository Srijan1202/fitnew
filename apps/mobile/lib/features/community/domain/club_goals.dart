/// Beta 6.5 (Clubs together): a club's monthly challenge (K2). The server
/// counts; the phone only shows.
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
