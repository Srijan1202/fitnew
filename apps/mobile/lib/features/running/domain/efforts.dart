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
      );

  static const empty = RunningRecords(best: {}, pending: 0);

  final Map<EffortKey, List<RecordEntry>> best;

  /// Older runs the server has not worked out yet.
  final int pending;

  /// Beta 4.3: the longest single run, metres; null from a 4.2 server.
  final double? longestM;

  /// The record time at each distance that has one.
  Map<EffortKey, double> get recordTimes => {
        for (final MapEntry(:key, :value) in best.entries)
          if (value.isNotEmpty) key: value.first.seconds,
      };
}

/* ---------------------------------------------------------------- badges -- */

/// A run shown as "5.00 km" (4.995 km and up) reads as 5 km.
const double badgeSlackM = 5;

/// The distance firsts (owner): three unlock a reward.
enum DistanceBadge {
  firstRun('first-run', 0, 'First run', null),
  first5k('first-5k', 5000, 'First 5K', null),
  first10k('first-10k', 10000, 'First 10K', 'the Finisher app icon'),
  firstHalf('first-half', 21097.5, 'First half marathon', 'the Road theme'),
  firstMarathon(
    'first-marathon',
    42195,
    'First marathon',
    'the gold 42 app icon',
  );

  const DistanceBadge(this.id, this.metres, this.label, this.unlocks);

  final String id;
  final double metres;
  final String label;

  /// What it unlocks, in words; null for none.
  final String? unlocks;

  static DistanceBadge? byId(String? id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// "Run a 10K in one go to earn it."
  String get howToEarn => metres == 0
      ? 'Save your first run to earn it.'
      : 'Run ${_distance()} in one go to earn it.';

  /// "Run your first 10K to unlock the Finisher app icon."
  String? get unlockHowTo => unlocks == null
      ? null
      : 'Run your first ${_distance(article: false)} to unlock $unlocks.';

  String _distance({bool article = true}) => switch (this) {
        first5k => article ? 'a 5K' : '5K',
        first10k => article ? 'a 10K' : '10K',
        firstHalf => article ? 'a half marathon' : 'half marathon',
        firstMarathon => article ? 'a marathon' : 'marathon',
        firstRun => 'a run',
      };
}

/// The badges one run of [distanceM] earns.
List<DistanceBadge> badgesFor(double distanceM) => [
      for (final b in DistanceBadge.values)
        if (b.metres == 0 || distanceM >= b.metres - badgeSlackM) b,
    ];
