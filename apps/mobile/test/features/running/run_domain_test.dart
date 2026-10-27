import 'dart:convert';
import 'dart:io';

import 'package:fitos/features/running/domain/gps_filter.dart';
import 'package:fitos/features/running/domain/gpx.dart';
import 'package:fitos/features/running/domain/live_stats.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/run_math.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/domain/units.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_running.dart';

/// Beta 4.0 (ADR-038): the phone's side of a run — cleaning GPS, auto-pause,
/// the live numbers, the privacy zone and GPX.
void main() {
  final t0 = DateTime.utc(2026, 10, 27, 1);

  group('GPS filter', () {
    test('a clean run is stored point by point, rounded, timed from the start',
        () {
      final f = GpsFilter(startedAt: t0);
      final stored = [
        for (final fix
            in runNorth(from: t0.add(const Duration(seconds: 2)), seconds: 20))
          f.add(fix).point,
      ].whereType<TrackPoint>().toList();
      // Smoothing lags at the start, so a few early steps fall under 3 m.
      expect(stored.length, greaterThanOrEqualTo(14));
      expect(stored.first.t, 2);
      expect(stored.first, stored.first.quantized());
      for (var i = 1; i < stored.length; i++) {
        expect(stored[i].t, greaterThan(stored[i - 1].t));
      }
    });

    test('a poor fix is dropped and gives no speed', () {
      final f = GpsFilter(startedAt: t0);
      final r = f.add(runNorth(from: t0, seconds: 1, accuracy: 35).single);
      expect(r.point, isNull);
      expect(r.speedMs, isNull);
    });

    test(
        'a jump is dropped; a run of them means the phone moved, and it starts again there',
        () {
      final f = GpsFilter(startedAt: t0);
      f.add(runNorth(from: t0, seconds: 1).single);
      // 1 km away a second later: 1,000 m/s.
      final far = runNorth(
        from: t0.add(const Duration(seconds: 1)),
        seconds: jumpResetAfter,
        speed: 1,
        lat0: 12.9782,
      );
      final results = [for (final fix in far) f.add(fix)];
      expect(
        results
            .take(jumpResetAfter - 1)
            .every((r) => r.point == null && r.speedMs == null),
        isTrue,
      );
      expect(results.last.point, isNotNull);
      expect(
        results.last.point!.lat,
        closeTo(12.9782 + (jumpResetAfter - 1) / 111195, 1e-4),
      );
    });

    test('standing still with jitter stores nothing new', () {
      final f = GpsFilter(startedAt: t0);
      final first = f.add(runNorth(from: t0, seconds: 1).single);
      expect(first.point, isNotNull);
      var stored = 0;
      for (var i = 1; i < 30; i++) {
        final jitter = (i.isEven ? 1 : -1) * 1.5 / 111195;
        final r = f.add(
          GpsFix(
            at: t0.add(Duration(seconds: i)),
            lat: 12.9692 + jitter,
            lon: 79.1559,
            accuracyM: 6,
            speedMs: 0,
          ),
        );
        if (r.point != null) stored++;
      }
      expect(stored, 0);
    });

    test('a new segment stores its first point even close to the last', () {
      final f = GpsFilter(startedAt: t0);
      f.add(runNorth(from: t0, seconds: 1).single);
      f.newSegment();
      final r = f.add(
        runNorth(
          from: t0.add(const Duration(seconds: 1)),
          seconds: 1,
          speed: 0.1,
        ).single,
      );
      expect(r.point, isNotNull);
    });

    test('a fix out of order, or before the start, is not stored', () {
      final f = GpsFilter(startedAt: t0);
      expect(
        f
            .add(
              runNorth(
                from: t0.subtract(const Duration(seconds: 5)),
                seconds: 1,
              ).single,
            )
            .point,
        isNull,
      );
      f.add(runNorth(from: t0, seconds: 1).single);
      expect(f.add(runNorth(from: t0, seconds: 1).single).point, isNull);
    });

    test('elevation is smoothed; a phone without altitude stores none', () {
      final f = GpsFilter(startedAt: t0);
      final a = f.add(runNorth(from: t0, seconds: 1).single).point!;
      expect(a.ele, 216);
      final b = f
          .add(
            GpsFix(
              at: t0.add(const Duration(seconds: 1)),
              lat: 12.96925,
              lon: 79.1559,
              accuracyM: 5,
              altitudeM: 226,
            ),
          )
          .point!;
      expect(b.ele, 218.5);
      final g = GpsFilter(startedAt: t0);
      final c = g
          .add(GpsFix(at: t0, lat: 12.9692, lon: 79.1559, accuracyM: 5))
          .point!;
      expect(c.ele, isNull);
    });

    test('speed: the receiver’s own when it gives one, else from the track',
        () {
      final f = GpsFilter(startedAt: t0);
      f.add(GpsFix(at: t0, lat: 12.9692, lon: 79.1559, accuracyM: 5));
      final r = f.add(
        GpsFix(
          at: t0.add(const Duration(seconds: 1)),
          lat: 12.96923,
          lon: 79.1559,
          accuracyM: 5,
        ),
      );
      expect(r.speedMs, greaterThan(0));
      final s = f.add(
        GpsFix(
          at: t0.add(const Duration(seconds: 2)),
          lat: 12.96926,
          lon: 79.1559,
          accuracyM: 5,
          speedMs: 2.5,
        ),
      );
      expect(s.speedMs, 2.5);
    });
  });

  group('auto-pause', () {
    test('slow for 8 s pauses; fast twice resumes; a single fast fix does not',
        () {
      final a = AutoPause();
      var changed = false;
      for (var i = 0; i <= 8; i++) {
        changed = a.add(t0.add(Duration(seconds: i)), 0.2);
      }
      expect(changed, isTrue);
      expect(a.paused, isTrue);
      expect(a.add(t0.add(const Duration(seconds: 9)), 2), isFalse);
      expect(a.add(t0.add(const Duration(seconds: 10)), 0.5), isFalse);
      expect(a.add(t0.add(const Duration(seconds: 11)), 2), isFalse);
      expect(a.add(t0.add(const Duration(seconds: 12)), 2), isTrue);
      expect(a.paused, isFalse);
    });

    test('a short stop does not pause, and no speed changes nothing', () {
      final a = AutoPause();
      for (var i = 0; i < 6; i++) {
        a.add(t0.add(Duration(seconds: i)), 0.1);
      }
      a.add(t0.add(const Duration(seconds: 6)), 3);
      for (var i = 7; i < 14; i++) {
        a.add(t0.add(Duration(seconds: i)), 0.1);
      }
      expect(a.paused, isFalse);
      expect(a.add(t0, null), isFalse);
      a.reset();
      expect(a.paused, isFalse);
    });
  });

  group('live numbers', () {
    final fixture = jsonDecode(
      File('../../packages/core/test/fixtures/running/intervals-with-pauses.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final track = decodeTrack(
      EncodedTrack.fromJson(fixture['track'] as Map<String, dynamic>),
    );

    test('added point by point they end where the summary does', () {
      final live = LiveTrack(weightKg: 60);
      for (final seg in track.segments) {
        for (var i = 0; i < seg.length; i++) {
          live.add(seg[i], newSegment: i == 0);
        }
      }
      final s = summarizeTrack(
        track,
        (fixture['durationSeconds'] as num).toInt(),
        60,
      );
      expect(live.distanceM, closeTo(s.distanceM, 0.05));
      expect(live.elevationGainM, s.elevationGainM);
      expect(live.calories, s.calories);
      expect(
        live.splitSeconds.length,
        s.splitsKm.where((x) => x.distanceM >= 999.9).length,
      );
      for (var i = 0; i < live.splitSeconds.length; i++) {
        expect(live.splitSeconds[i], closeTo(s.splitsKm[i].seconds, 0.05));
      }
      expect(
        live.splitSoFar.metres,
        closeTo(live.distanceM - 1000 * live.splitSeconds.length, 1e-6),
      );
    });

    test('the pace now: the last 30 s; none standing or at the start', () {
      final live = LiveTrack();
      expect(live.currentPaceSecPerKm, isNull);
      expect(live.calories, isNull);
      for (var i = 0; i < 60; i++) {
        live.add(
          TrackPoint(
            t: i.toDouble(),
            lat: 12.9692 + i * 3 / 111195,
            lon: 79.1559,
          ),
        );
      }
      expect(live.currentPaceSecPerKm, closeTo(1000 / 3, 2));
      expect(live.currentSpeedMs, closeTo(3, 0.02));
      final stand = LiveTrack()
        ..add(const TrackPoint(t: 0, lat: 12.9692, lon: 79.1559))
        ..add(const TrackPoint(t: 1, lat: 12.96921, lon: 79.1559));
      expect(stand.currentPaceSecPerKm, isNull);
      expect(stand.currentSpeedMs, isNull);
    });

    test('goal progress: distance and time, capped; none for free or pace', () {
      expect(
        goalProgress(
          goalKind: 'distance',
          goalValue: 5000,
          distanceM: 2500,
          activeSeconds: 0,
        ),
        0.5,
      );
      expect(
        goalProgress(
          goalKind: 'time',
          goalValue: 600,
          distanceM: 0,
          activeSeconds: 900,
        ),
        1,
      );
      expect(
        goalProgress(
          goalKind: 'pace',
          goalValue: 330,
          distanceM: 10,
          activeSeconds: 10,
        ),
        isNull,
      );
      expect(
        goalProgress(
          goalKind: 'free',
          goalValue: null,
          distanceM: 10,
          activeSeconds: 10,
        ),
        isNull,
      );
    });
  });

  group('privacy zone and GPX', () {
    Track line(int n, {double step = 10}) => Track([
          [
            for (var i = 0; i < n; i++)
              TrackPoint(
                t: i.toDouble(),
                lat: 12.9692 + i * step / 111195,
                lon: 79.1559,
                ele: 200 + i / 10,
              ),
          ],
        ]);

    test('the first and last 200 m are left out', () {
      final hidden = hideEnds(line(101));
      final all = hidden.segments.expand((s) => s).toList();
      expect(all.first.t, 20);
      expect(all.last.t, 80);
      expect(hideEnds(line(101), zoneM: 0).segments.single.length, 101);
    });

    test('a run shorter than both zones shares no route', () {
      expect(hideEnds(line(30)).isEmpty, isTrue);
    });

    test('pauses stay separate segments; a segment wholly inside a zone goes',
        () {
      final t = Track([
        line(10).segments.single,
        [
          for (var i = 0; i < 60; i++)
            TrackPoint(
              t: 100.0 + i,
              lat: 12.97 + i * 10 / 111195,
              lon: 79.1559,
            ),
        ],
      ]);
      expect(hideEnds(t).segments.length, 1);
    });

    test(
        'GPX: a segment per stretch, times from the start, elevation, escaped words',
        () {
      final gpx = toGpx(
        name: 'Hills & <dales>',
        startedAt: t0,
        note: 'Felt "good"',
        track: Track([line(3).segments.single, line(2).segments.single]),
      );
      expect('<trkseg>'.allMatches(gpx).length, 2);
      expect(gpx, contains('<name>Hills &amp; &lt;dales&gt;</name>'));
      expect(gpx, contains('<desc>Felt &quot;good&quot;</desc>'));
      expect(
        gpx,
        contains(
          '<trkpt lat="12.969200" lon="79.155900"><ele>200.0</ele><time>2026-10-27T01:00:00.000Z</time></trkpt>',
        ),
      );
      expect(gpx, contains('<time>2026-10-27T01:00:02.000Z</time>'));
      expect(
        toGpx(
          name: 'x',
          startedAt: t0,
          track: const Track([
            [TrackPoint(t: 0, lat: 1, lon: 2)],
          ]),
        ),
        isNot(contains('<ele>')),
      );
    });

    test('the file name is safe', () {
      expect(
        gpxFileName('Morning run: 5k/♥', DateTime(2026, 10, 27, 7)),
        'FITOS 2026-10-27 Morning run 5k.gpx',
      );
      expect(
        gpxFileName('♥', DateTime(2026, 10, 27)),
        'FITOS 2026-10-27 run.gpx',
      );
    });
  });

  group('words and numbers', () {
    test('formats', () {
      expect(formatDistance(5240, DistanceUnit.km), '5.24');
      expect(formatDistance(123456, DistanceUnit.km), '123.5');
      expect(formatDistance(1609.344, DistanceUnit.mi), '1.00');
      expect(formatDuration(1509), '25:09');
      expect(formatDuration(3909), '1:05:09');
      expect(formatDuration(-3), '0:00');
      expect(formatPace(342, DistanceUnit.km), '5:42');
      expect(formatPace(300, DistanceUnit.mi), '8:03');
      expect(formatPace(null, DistanceUnit.km), '–:––');
      expect(formatPace(7000, DistanceUnit.km), '–:––');
      expect(formatSpeed(3, DistanceUnit.km), '10.8');
      expect(formatSpeed(null, DistanceUnit.km), '–');
      expect(DistanceUnit.parse('mi'), DistanceUnit.mi);
      expect(DistanceUnit.parse(null), DistanceUnit.km);
    });

    test('a run’s name follows the time of day', () {
      expect(
        defaultRunName(DateTime(2026, 1, 1, 6), RunKind.outdoor),
        'Morning run',
      );
      expect(
        defaultRunName(DateTime(2026, 1, 1, 13), RunKind.outdoor),
        'Afternoon run',
      );
      expect(
        defaultRunName(DateTime(2026, 1, 1, 18), RunKind.outdoor),
        'Evening run',
      );
      expect(
        defaultRunName(DateTime(2026, 1, 1, 23), RunKind.outdoor),
        'Night run',
      );
      expect(
        defaultRunName(DateTime(2026, 1, 1, 6), RunKind.treadmill),
        'Treadmill run',
      );
    });
  });
}
