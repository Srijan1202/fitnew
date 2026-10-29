import 'dart:math' as math;

import 'package:fitos/features/running/domain/efforts.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/run_math.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 4.2 (owner 2026-10-29): the phone's port of core's best-effort and
/// badge rules (packages/core running/efforts.ts) — the same cases as
/// packages/core/test/running-4-2.test.ts, so both say the same.

/// Metres per degree of latitude (the haversine's own radius).
const mPerDeg = (math.pi / 180) * 6371008.8;

/// A straight run north: [pace] seconds per km at each point, a point every
/// [stepM] metres, from [t0] seconds and [m0] metres.
List<TrackPoint> run(
  double totalM,
  double stepM,
  double Function(double atM) pace, {
  double t0 = 0,
  double m0 = 0,
}) {
  final pts = <TrackPoint>[];
  var t = t0;
  for (var m = 0.0; m <= totalM + 1e-9; m += stepM) {
    if (m > 0) t += (stepM / 1000) * pace(m0 + m - stepM / 2);
    pts.add(TrackPoint(t: t, lat: (m0 + m) / mPerDeg, lon: 0));
  }
  return pts;
}

BestEffort? effort(Track track, EffortKey key) {
  for (final e in bestEfforts(track)) {
    if (e.key == key) return e;
  }
  return null;
}

void main() {
  test('the seven distances, as core keys them', () {
    expect(
      EffortKey.values.map((k) => k.wire),
      ['400m', '1k', '1mile', '5k', '10k', 'half', 'marathon'],
    );
    expect(EffortKey.mile.metres, mileM);
    expect(EffortKey.parse('5k'), EffortKey.k5);
    expect(EffortKey.parse('3k'), isNull);
  });

  test('a steady 10 km at 5:00 /km: each distance at that pace', () {
    final track = Track([run(10010, 10, (_) => 300)]);
    expect(
      bestEfforts(track).map((e) => e.key),
      [
        EffortKey.m400,
        EffortKey.k1,
        EffortKey.mile,
        EffortKey.k5,
        EffortKey.k10,
      ],
    );
    expect(effort(track, EffortKey.m400)!.seconds, closeTo(120, 0.5));
    expect(effort(track, EffortKey.mile)!.seconds, closeTo(482.8, 0.5));
    expect(effort(track, EffortKey.k10)!.seconds, closeTo(3000, 0.5));
  });

  test('finds the fast kilometre in the middle, where it is', () {
    final track = Track([
      run(3000, 10, (m) => m >= 1000 && m < 2000 ? 240 : 360),
    ]);
    final km = effort(track, EffortKey.k1)!;
    expect(km.seconds, closeTo(240, 0.5));
    expect(km.startM, closeTo(1000, 10));
  });

  test('exact between points: interpolated at both ends', () {
    final track = Track([
      run(3000, 300, (m) => m >= 900 && m < 2100 ? 240 : 360),
    ]);
    expect(effort(track, EffortKey.k1)!.seconds, closeTo(240, 0.05));
  });

  test('a pause adds no time', () {
    final first = run(2510, 10, (_) => 300);
    final last = first.last;
    final second =
        run(2510, 10, (_) => 300, t0: last.t + 600, m0: 2510).sublist(1);
    final track = Track([
      first,
      [TrackPoint(t: last.t + 600, lat: last.lat, lon: last.lon), ...second],
    ]);
    expect(effort(track, EffortKey.k5)!.seconds, closeTo(1500, 0.5));
  });

  test('faster than the world record is left out; the rest kept', () {
    final pts = run(6000, 10, (_) => 300);
    final jumped = [
      for (final (i, p) in pts.indexed)
        i <= 300 ? p : TrackPoint(t: p.t - 116, lat: p.lat, lon: p.lon),
    ];
    final track = Track([jumped]);
    expect(effort(track, EffortKey.m400), isNull);
    expect(effort(track, EffortKey.k5), isNotNull);
  });

  test('shorter than a distance: none for it', () {
    expect(bestEfforts(Track([run(390, 10, (_) => 300)])), isEmpty);
    expect(bestEfforts(const Track([])), isEmpty);
  });

  test(
      'fastest on distances and times: exact points, standing still, too short',
      () {
    expect(
      fastest([0, 400, 800], [0, 100, 190], 400),
      (seconds: 90.0, startM: 400.0),
    );
    expect(
      fastest([0, 200, 400], [0, 60, 130], 400),
      (seconds: 130.0, startM: 0.0),
    );
    expect(
      fastest([0, 0, 500], [0, 20, 170], 400),
      (seconds: 120.0, startM: 0.0),
    );
    expect(fastest([0], [0], 400), isNull);
    expect(fastest([0, 300], [0, 90], 400), isNull);
  });

  test('new records: faster than the record, or the first at a distance', () {
    const run = [
      BestEffort(key: EffortKey.k1, seconds: 290, startM: 0),
      BestEffort(key: EffortKey.k5, seconds: 1600, startM: 0),
      BestEffort(key: EffortKey.mile, seconds: 470, startM: 0),
    ];
    final beaten = newRecords(run, {EffortKey.k1: 300, EffortKey.k5: 1500});
    expect(beaten.map((e) => e.key), [EffortKey.k1, EffortKey.mile]);
  });

  test('distance badges: any run is a first run; what reads as 5 km is 5 km',
      () {
    expect(badgesFor(0), [DistanceBadge.firstRun]);
    expect(badgesFor(5000 - badgeSlackM - 0.1), [DistanceBadge.firstRun]);
    expect(
      badgesFor(5000 - badgeSlackM),
      [DistanceBadge.firstRun, DistanceBadge.first5k],
    );
    expect(badgesFor(42195), DistanceBadge.values);
    expect(DistanceBadge.byId('first-half'), DistanceBadge.firstHalf);
    expect(DistanceBadge.byId('first-ultra'), isNull);
    expect(DistanceBadge.first5k.howToEarn, 'Run a 5K in one go to earn it.');
    expect(DistanceBadge.firstRun.howToEarn, 'Save your first run to earn it.');
    expect(DistanceBadge.first5k.unlockHowTo, isNull);
    expect(
      DistanceBadge.firstHalf.unlockHowTo,
      'Run your first half marathon to unlock the Road theme.',
    );
  });

  test(
      'the server\'s words: records, a run\'s efforts and record keys; unknown keys left out',
      () {
    final r = RunningRecords.fromJson({
      'records': [
        {
          'key': '5k',
          'best': [
            {
              'runId': 'r1',
              'name': 'Tempo',
              'startedAt': '2026-10-20T01:00:00Z',
              'seconds': 1350.0,
            },
          ],
        },
        {'key': '10k', 'best': <Object>[]},
        {'key': '3k', 'best': <Object>[]},
      ],
      'pending': 2,
    });
    expect(r.recordTimes, {EffortKey.k5: 1350.0});
    expect(r.pending, 2);
    expect(r.best.containsKey(EffortKey.k10), isTrue);
    expect(
      BestEffort.fromJson({'key': '3k', 'seconds': 1, 'startM': 0}),
      isNull,
    );
    final summary = RunSummary.fromJson({
      'id': 'r1',
      'kind': 'outdoor',
      'name': 'Tempo',
      'startedAt': '2026-10-20T01:00:00Z',
      'endedAt': '2026-10-20T01:30:00Z',
      'durationSeconds': 1800,
      'distanceM': 5000,
      'avgPaceSecPerKm': 360,
      'elevationGainM': null,
      'calories': null,
      'effort': null,
      'outline': <Object>[],
      'recordKeys': ['5k', '3k'],
    });
    expect(summary.recordKeys, [EffortKey.k5]);
  });
}
