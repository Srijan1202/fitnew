import 'run_math.dart';
import 'track.dart';

/// Beta 4.2 (owner 2026-10-29): best efforts — the fastest stretch of each
/// distance inside a run, on moving time — and the distance firsts. A port
/// of packages/core `running/efforts.ts`, so the phone can say "New record"
/// the moment a run ends, offline too; the server's figures stand once the
/// run syncs. Same rules, same keys.

enum EffortKey {
  m400('400m', 400, '400 m', 43),
  k1('1k', 1000, '1 km', 131),
  mile('1mile', mileM, '1 mile', 223),
  k5('5k', 5000, '5 km', 755),
  k10('10k', 10000, '10 km', 1571),
  half('half', 21097.5, 'Half marathon', 3400),
  marathon('marathon', 42195, 'Marathon', 7200);

  const EffortKey(this.wire, this.metres, this.label, this.recordSeconds);

  final String wire;
  final double metres;
  final String label;

  /// The world record, rounded down: anything faster is not a run.
  final int recordSeconds;

  static EffortKey? parse(String? s) {
    for (final k in values) {
      if (k.wire == s) return k;
    }
    return null;
  }
}

/// One distance in one run; [rank] among all the runner's (1 = the record,
/// 2, 3; null below or not known).
class BestEffort {
  const BestEffort({
    required this.key,
    required this.seconds,
    required this.startM,
    this.rank,
  });

  /// Null for a key this build does not know (a newer server).
  static BestEffort? fromJson(Map<String, dynamic> j) {
    final key = EffortKey.parse(j['key'] as String?);
    if (key == null) return null;
    return BestEffort(
      key: key,
      seconds: (j['seconds'] as num).toDouble(),
      startM: (j['startM'] as num).toDouble(),
      rank: (j['rank'] as num?)?.toInt(),
    );
  }

  final EffortKey key;
  final double seconds;
  final double startM;
  final int? rank;
}

/// The fastest stretch of [metres] on distances [d] and moving times [m]
/// from the start; null when the run is shorter. It always starts or ends
/// on a point, so both are tried, the other end interpolated.
({double seconds, double startM})? fastest(
  List<double> d,
  List<double> m,
  double metres,
) {
  final n = d.length;
  if (n < 2 || d[n - 1] < metres) return null;
  double timeAt(int j, double target) {
    final f = (target - d[j - 1]) / (d[j] - d[j - 1]);
    return m[j - 1] + f * (m[j] - m[j - 1]);
  }

  var best = double.infinity;
  var bestStart = 0.0;
  var j = 1;
  for (var i = 0; i < n; i++) {
    final target = d[i] + metres;
    if (target > d[n - 1]) break;
    while (d[j] < target) {
      j++;
    }
    final end = d[j] == target ? m[j] : timeAt(j, target);
    if (end - m[i] < best) {
      best = end - m[i];
      bestStart = d[i];
    }
  }
  var k = 1;
  for (var e = 0; e < n; e++) {
    final target = d[e] - metres;
    if (target < 0) continue;
    while (d[k] < target) {
      k++;
    }
    final start = d[k] == target ? m[k] : timeAt(k, target);
    if (m[e] - start < best) {
      best = m[e] - start;
      bestStart = target;
    }
  }
  return (seconds: best, startM: bestStart);
}

/// Every distance the run covers, at its fastest; faster than the world
/// record (a GPS jump) is left out for that distance.
List<BestEffort> bestEfforts(Track track) {
  final d = <double>[];
  final m = <double>[];
  var dist = 0.0;
  var moving = 0.0;
  for (final segment in track.segments) {
    for (var i = 0; i < segment.length; i++) {
      if (i > 0) {
        dist += distanceBetween(segment[i - 1], segment[i]);
        moving += segment[i].t - segment[i - 1].t;
      }
      d.add(dist);
      m.add(moving);
    }
  }
  return [
    for (final key in EffortKey.values)
      if (fastest(d, m, key.metres) case final f?)
        if (f.seconds >= key.recordSeconds)
          BestEffort(
            key: key,
            seconds: round1(f.seconds),
            startM: round1(f.startM),
          ),
  ];
}

/// The efforts in [run] faster than the runner's records [records] (the
/// best time at each distance; a missing distance has none yet).
List<BestEffort> newRecords(
  List<BestEffort> run,
  Map<EffortKey, double> records,
) =>
    [
      for (final e in run)
        if (records[e.key] == null || e.seconds < records[e.key]!) e,
    ];

/// One of the best three at a distance.
class RecordEntry {
  const RecordEntry({
    required this.runId,
    required this.name,
    required this.startedAt,
    required this.seconds,
  });

  factory RecordEntry.fromJson(Map<String, dynamic> j) => RecordEntry(
        runId: j['runId'] as String,
        name: j['name'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        seconds: (j['seconds'] as num).toDouble(),
      );

  final String runId;
  final String name;
  final DateTime startedAt;
  final double seconds;
}

/// GET /running/records: the best three at each distance (none yet: empty).
class RunningRecords {
  const RunningRecords({
    required this.best,
    required this.pending,
    this.longestM,
    this.totalM,
  });

  factory RunningRecords.fromJson(Map<String, dynamic> j) => RunningRecords(
        best: {
          for (final r in j['records'] as List)
            if (EffortKey.parse((r as Map<String, dynamic>)['key'] as String?)
                case final key?)
              key: [
                for (final e in r['best'] as List)
                  RecordEntry.fromJson(e as Map<String, dynamic>),
              ],
        },
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        longestM: (j['longestM'] as num?)?.toDouble(),
        totalM: (j['totalM'] as num?)?.toDouble(),
      );

  static const empty = RunningRecords(best: {}, pending: 0);

  final Map<EffortKey, List<RecordEntry>> best;

  /// Older runs the server has not worked out yet.
  final int pending;

  /// Beta 4.3: the longest single run, metres; null from a 4.2 server.
  final double? longestM;

  /// Beta 4.5: every run added up, metres; null from an older server.
  final double? totalM;

  /// The record time at each distance that has one.
  Map<EffortKey, double> get recordTimes => {
        for (final MapEntry(:key, :value) in best.entries)
          if (value.isNotEmpty) key: value.first.seconds,
      };
}

/* ---------------------------------------------------------------- badges -- */

/// A run shown as "5.00 km" (4.995 km and up) reads as 5 km.
const double badgeSlackM = 5;

/// Beta 4.5: what kind of badge.
enum BadgeGroup {
  distance('Distance firsts'),
  speed('Speed'),
  lifetime('Lifetime distance'),
  consistency('Consistency');

  const BadgeGroup(this.label);
  final String label;
}

/// The running badges (owner): the distance firsts (beta 4.2), and speed,
/// lifetime and consistency (beta 4.5). Five unlock a reward.
enum RunBadge {
  firstRun('first-run', BadgeGroup.distance, 'First run', metres: 0),
  first5k('first-5k', BadgeGroup.distance, 'First 5K', metres: 5000),
  first10k(
    'first-10k',
    BadgeGroup.distance,
    'First 10K',
    metres: 10000,
    unlocks: 'the Finisher app icon',
  ),
  firstHalf(
    'first-half',
    BadgeGroup.distance,
    'First half marathon',
    metres: 21097.5,
    unlocks: 'the Road theme',
  ),
  firstMarathon(
    'first-marathon',
    BadgeGroup.distance,
    'First marathon',
    metres: 42195,
    unlocks: 'the gold 42 app icon',
  ),
  speed5k30(
    'speed-5k-30',
    BadgeGroup.speed,
    '5K under 30 min',
    effort: EffortKey.k5,
    underSeconds: 1800,
  ),
  speed5k25(
    'speed-5k-25',
    BadgeGroup.speed,
    '5K under 25 min',
    effort: EffortKey.k5,
    underSeconds: 1500,
  ),
  speed5k20(
    'speed-5k-20',
    BadgeGroup.speed,
    '5K under 20 min',
    effort: EffortKey.k5,
    underSeconds: 1200,
    unlocks: 'the Bolt app icon',
  ),
  speed10k60(
    'speed-10k-60',
    BadgeGroup.speed,
    '10K under 60 min',
    effort: EffortKey.k10,
    underSeconds: 3600,
  ),
  speed10k50(
    'speed-10k-50',
    BadgeGroup.speed,
    '10K under 50 min',
    effort: EffortKey.k10,
    underSeconds: 3000,
  ),
  speedHalf2h(
    'speed-half-2h',
    BadgeGroup.speed,
    'Half marathon under 2 h',
    effort: EffortKey.half,
    underSeconds: 7200,
  ),
  speedMarathon4h(
    'speed-marathon-4h',
    BadgeGroup.speed,
    'Marathon under 4 h',
    effort: EffortKey.marathon,
    underSeconds: 14400,
  ),
  total50('total-50k', BadgeGroup.lifetime, '50 km run', totalM: 50000),
  total100('total-100k', BadgeGroup.lifetime, '100 km run', totalM: 100000),
  total250('total-250k', BadgeGroup.lifetime, '250 km run', totalM: 250000),
  total500('total-500k', BadgeGroup.lifetime, '500 km run', totalM: 500000),
  total1000(
    'total-1000k',
    BadgeGroup.lifetime,
    '1,000 km run',
    totalM: 1000000,
    unlocks: 'the Mileage theme',
  ),
  weeks4('weeks-4', BadgeGroup.consistency, 'Four weeks in a row'),
  threeInAWeek(
    'three-in-a-week',
    BadgeGroup.consistency,
    'Three runs in a week',
  ),
  planFinished('plan-finished', BadgeGroup.consistency, 'Plan finished');

  const RunBadge(
    this.id,
    this.group,
    this.label, {
    this.metres,
    this.effort,
    this.underSeconds,
    this.totalM,
    this.unlocks,
  });

  final String id;
  final BadgeGroup group;
  final String label;

  /// A distance first: one run of at least this far (0: any run).
  final double? metres;

  /// A speed badge: the best effort at [effort] under [underSeconds].
  final EffortKey? effort;
  final double? underSeconds;

  /// A lifetime badge: all runs added up to this far.
  final double? totalM;

  /// What it unlocks, in words; null for none.
  final String? unlocks;

  static RunBadge? byId(String? id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// "Run a 10K in one go to earn it."
  String get howToEarn => switch (group) {
        BadgeGroup.distance => metres == 0
            ? 'Save your first run to earn it.'
            : 'Run ${_distance()} in one go to earn it.',
        BadgeGroup.speed =>
          'Run ${effort!.label == 'Half marathon' || effort!.label == 'Marathon' ? 'a ${effort!.label.toLowerCase()}' : effort!.label} in under ${_time(underSeconds!)} to earn it.',
        BadgeGroup.lifetime => 'Run ${_km(totalM!)} km in total to earn it.',
        BadgeGroup.consistency => switch (this) {
            weeks4 => 'Run at least once a week, 4 weeks in a row.',
            threeInAWeek => 'Run 3 times in one week (Monday to Sunday).',
            _ => 'Finish a running plan: its race run done.',
          },
      };

  /// "Run your first 10K to unlock the Finisher app icon."
  String? get unlockHowTo => unlocks == null
      ? null
      : switch (group) {
          BadgeGroup.distance =>
            'Run your first ${_distance(article: false)} to unlock $unlocks.',
          BadgeGroup.speed =>
            'Run ${effort!.label} in under ${_time(underSeconds!)} to unlock $unlocks.',
          BadgeGroup.lifetime =>
            'Run ${_km(totalM!)} km in total to unlock $unlocks.',
          BadgeGroup.consistency => null,
        };

  String _distance({bool article = true}) => switch (this) {
        first5k => article ? 'a 5K' : '5K',
        first10k => article ? 'a 10K' : '10K',
        firstHalf => article ? 'a half marathon' : 'half marathon',
        firstMarathon => article ? 'a marathon' : 'marathon',
        _ => 'a run',
      };

  static String _time(double s) =>
      s >= 3600 ? '${(s / 3600).round()} h' : '${(s / 60).round()} min';

  static String _km(double m) {
    final km = (m / 1000).round();
    return km >= 1000
        ? '${km ~/ 1000},${(km % 1000).toString().padLeft(3, '0')}'
        : '$km';
  }
}

/// The distance firsts one run of [distanceM] earns.
List<RunBadge> badgesFor(double distanceM) => [
      for (final b in RunBadge.values)
        if (b.metres != null &&
            (b.metres == 0 || distanceM >= b.metres! - badgeSlackM))
          b,
    ];

/// Beta 4.5: the speed badges a run's efforts earn.
List<RunBadge> speedBadgesFor(List<BestEffort> efforts) => [
      for (final b in RunBadge.values)
        if (b.group == BadgeGroup.speed &&
            efforts
                .any((e) => e.key == b.effort && e.seconds < b.underSeconds!))
          b,
    ];

/// Beta 4.5: the lifetime badges a total of [totalM] reaches.
List<RunBadge> lifetimeBadgesFor(double totalM) => [
      for (final b in RunBadge.values)
        if (b.totalM != null && totalM >= b.totalM!) b,
    ];
