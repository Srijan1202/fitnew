import 'dart:convert';
import 'dart:io';

import 'package:fitos/features/running/domain/run_math.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 4.0 (ADR-038): the phone's run maths against the server's. The
/// fixtures are packages/core's own (core checks the same files), so the
/// live numbers and the offline summary agree with the record the server
/// keeps.
void main() {
  final dir = Directory('../../packages/core/test/fixtures/running');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are shared fixtures', () {
    expect(files.length, greaterThanOrEqualTo(3));
  });

  for (final file in files) {
    final f = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final expected = f['expected'] as Map<String, dynamic>;
    group(f['name'] as String, () {
      final encoded = EncodedTrack.fromJson(f['track'] as Map<String, dynamic>);
      final track = decodeTrack(encoded);
      final weight = (f['weightKg'] as num?)?.toDouble();
      final got = summarizeTrack(
        track,
        (f['durationSeconds'] as num).toInt(),
        weight,
      );

      test('encodes back to the same string', () {
        final again = encodeTrack(track);
        expect(again.points, encoded.points);
        expect(again.breaks, encoded.breaks);
        expect(again.elevation, encoded.elevation);
      });

      test('distance, pace, elevation and calories match the server', () {
        expect(got.distanceM, closeTo(expected['distanceM'] as num, 0.05));
        expect(
          got.avgPaceSecPerKm,
          closeTo(expected['avgPaceSecPerKm'] as num, 0.05),
        );
        if (expected['elevationGainM'] == null) {
          expect(got.elevationGainM, isNull);
        } else {
          expect(
            got.elevationGainM,
            closeTo(expected['elevationGainM'] as num, 0.05),
          );
        }
        expect(got.calories, expected['calories']);
      });

      for (final key in ['splitsKm', 'splitsMi']) {
        test('$key match the server', () {
          final want = [
            for (final s in expected[key] as List)
              RunSplit.fromJson(s as Map<String, dynamic>),
          ];
          final have = key == 'splitsKm' ? got.splitsKm : got.splitsMi;
          expect(have.length, want.length);
          for (var i = 0; i < want.length; i++) {
            expect(have[i].index, want[i].index);
            expect(have[i].distanceM, closeTo(want[i].distanceM, 0.05));
            expect(have[i].seconds, closeTo(want[i].seconds, 0.05));
            expect(have[i].pace, closeTo(want[i].pace, 0.05));
            if (want[i].elevationChangeM == null) {
              expect(have[i].elevationChangeM, isNull);
            } else {
              expect(
                have[i].elevationChangeM,
                closeTo(want[i].elevationChangeM!, 0.05),
              );
            }
          }
        });
      }

      test('the chart and the outline match the server', () {
        final want = [
          for (final s in expected['series'] as List)
            SeriesPoint.fromJson(s as Map<String, dynamic>),
        ];
        expect(got.series.length, want.length);
        for (var i = 0; i < want.length; i++) {
          expect(got.series[i].distanceM, closeTo(want[i].distanceM, 0.05));
          expect(got.series[i].pace, closeTo(want[i].pace, 0.05));
        }
        final outline = expected['outline'] as List;
        expect(got.outline.length, outline.length);
        for (var i = 0; i < outline.length; i++) {
          final pair = outline[i] as List;
          expect(got.outline[i].$1, closeTo(pair[0] as num, 1e-9));
          expect(got.outline[i].$2, closeTo(pair[1] as num, 1e-9));
        }
      });
    });
  }

  group('the encoding guards', () {
    test('a point keeps the encoding precision', () {
      const p = TrackPoint(t: 1.26, lat: 1.23456789, lon: -2.00000049);
      expect(p.quantized(), const TrackPoint(t: 1.3, lat: 1.234568, lon: -2));
    });

    test('malformed tracks throw', () {
      final good = encodeTrack(
        const Track([
          [
            TrackPoint(t: 0, lat: 1, lon: 1),
            TrackPoint(t: 1, lat: 1.0001, lon: 1),
          ],
        ]),
      );
      Track bad(String points, [List<int> breaks = const []]) => decodeTrack(
            EncodedTrack(points: points, breaks: breaks, elevation: false),
          );
      expect(
        () => bad('${good.points}_'),
        throwsA(isA<TrackFormatException>()),
      );
      expect(
        () => bad('${good.points} '),
        throwsA(isA<TrackFormatException>()),
      );
      expect(
        () => bad('${good.points}?'),
        throwsA(isA<TrackFormatException>()),
      );
      expect(() => bad(good.points, [5]), throwsA(isA<TrackFormatException>()));
      expect(bad('').segments, isEmpty);
    });

    test('a treadmill run: an even pace, no splits', () {
      final s = summarizeTreadmill(5000, 1500, 70);
      expect(s.avgPaceSecPerKm, 300);
      expect(s.calories, jsRound(kcalAt(200, 1500, 70)));
      expect(summarizeTreadmill(0, 0, null).calories, isNull);
    });
  });
}
