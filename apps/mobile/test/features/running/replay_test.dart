import 'package:fitos/features/running/domain/replay.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/presentation/widgets/route_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 4.4 (owner 2026-10-29): pace colours along the route, and the replay.

const mPerDeg = 111195.08;

/// North from [m0] metres and [t0] seconds, a point every 10 m, [pace] s/km.
List<TrackPoint> north(
  double metres,
  double Function(double atM) pace, {
  double m0 = 0,
  double t0 = 0,
}) {
  final pts = <TrackPoint>[];
  var t = t0;
  for (var m = 0.0; m <= metres + 1e-9; m += 10) {
    if (m > 0) t += 0.01 * pace(m0 + m);
    pts.add(TrackPoint(t: t, lat: (m0 + m) / mPerDeg, lon: 0));
  }
  return pts;
}

void main() {
  group('pace colours', () {
    test('a steady run is all "your average"', () {
      final s = paceStretches(Track([north(1000, (_) => 300)]));
      expect(s.length, greaterThan(10));
      expect(s.every((x) => x.relative.abs() < 0.05), isTrue);
    });

    test('a fast middle is faster (green), the slow ends slower (warm)', () {
      final s = paceStretches(
        Track([north(1500, (m) => m > 500 && m <= 1000 ? 240 : 360)]),
      );
      final mid = s[s.length ~/ 2];
      expect(mid.relative, lessThan(-0.5));
      expect(s.first.relative, greaterThan(0.3));
      expect(paceColour(mid.relative), isNot(kPaceAverage));
      expect(paceColour(-1), kPaceFast);
      expect(paceColour(1), kPaceSlow);
      expect(paceColour(0), kPaceAverage);
      expect(hexOf(const Color(0xFF2FBF71)), '#2fbf71');
    });

    test('stretches never cross a pause, and join up', () {
      final a = north(300, (_) => 300);
      final b = north(300, (_) => 300, m0: 300, t0: a.last.t + 500);
      final s = paceStretches(Track([a, b]));
      // The pause adds no time: the second half is not "slower".
      expect(s.every((x) => x.relative.abs() < 0.05), isTrue);
      for (var i = 1; i < s.length; i++) {
        final gap = (s[i].points.first.$1 - s[i - 1].points.last.$1).abs();
        expect(gap * mPerDeg, lessThan(0.5));
      }
    });

    test('too short to compare: none', () {
      expect(paceStretches(Track([north(30, (_) => 300)])), isEmpty);
      expect(paceStretches(const Track([])), isEmpty);
    });
  });

  group('the replay', () {
    final timeline = ReplayTimeline(Track([north(2000, (_) => 300)]));

    test('runs along the moving time: start, half, end', () {
      expect(timeline.isEmpty, isFalse);
      expect(timeline.totalSeconds, closeTo(600, 1));
      final start = timeline.at(0);
      expect(start.distanceM, 0);
      expect(start.paceSecPerKm, isNull);
      final half = timeline.at(0.5);
      expect(half.seconds, closeTo(300, 1));
      expect(half.distanceM, closeTo(1000, 15));
      expect(half.paceSecPerKm, closeTo(300, 5));
      final end = timeline.at(1);
      expect(end.distanceM, closeTo(timeline.totalDistanceM, 0.01));
      expect(timeline.at(2).seconds, closeTo(600, 1));
    });

    test('the route so far ends at the dot; a pause is a gap', () {
      final a = north(500, (_) => 300);
      final b = north(500, (_) => 300, m0: 600, t0: a.last.t + 120);
      final t2 = ReplayTimeline(Track([a, b]));
      expect(t2.routeTo(0.25), hasLength(1));
      final all = t2.routeTo(1);
      expect(all, hasLength(2));
      final dot = t2.at(0.75).position;
      expect(t2.routeTo(0.75).last.last, dot);
      // A pause takes no replay time: halfway is the end of the first part.
      expect(t2.at(0.5).distanceM, closeTo(t2.totalDistanceM / 2, 15));
    });

    test('too short to replay', () {
      expect(ReplayTimeline(const Track([])).isEmpty, isTrue);
    });
  });
}
