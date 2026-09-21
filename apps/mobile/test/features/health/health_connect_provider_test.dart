import 'dart:convert';

import 'package:fitos/features/health/data/health_connect_provider.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/domain/health_data_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_health_channel.dart';

/// Phase 6.5 — HealthConnectProvider normalization (Part J): every
/// metric, every availability, local day / night / week boundaries in
/// the user's calendar, and no double counting across sources.
void main() {
  late FakeHealthChannel channel;
  late HealthConnectProvider provider;
  final now = DateTime.utc(2026, 9, 22, 6, 30);

  const all = [
    'steps',
    'distance',
    'activeCalories',
    'totalCalories',
    'exercise',
    'sleep',
    'restingHeartRate',
    'weight',
    'bodyFat',
    'bmr',
  ];

  setUp(() {
    channel = FakeHealthChannel();
    provider = HealthConnectProvider(channel, now: () => now);
  });

  Future<HealthSnapshot> snap() =>
      provider.snapshot(date: '2026-09-22', timezone: 'Asia/Kolkata');

  group('connection', () {
    test('sdk unavailable → unsupported, no grants read', () async {
      channel.sdk = 'unavailable';
      final c = await provider.connection();
      expect(c.sdk, HealthSdkStatus.unavailable);
      expect(c.granted, isEmpty);
      expect(channel.calls, ['sdkStatus']);
      final s = await snap();
      expect(s.steps.availability, HealthAvailability.unsupported);
      expect(s.weight.availability, HealthAvailability.unsupported);
      expect(s.exerciseAvailability, HealthAvailability.unsupported);
    });

    test('update required is its own state', () async {
      channel.sdk = 'updateRequired';
      expect((await provider.connection()).sdk, HealthSdkStatus.updateRequired);
    });

    test('available, nothing granted → not connected everywhere', () async {
      final c = await provider.connection();
      expect(c.isConnected, isFalse);
      final s = await snap();
      for (final m in s.metrics) {
        expect(
          m.availability,
          HealthAvailability.notConnected,
          reason: m.kind.name,
        );
        expect(m.value, isNull);
      }
      // No reads were attempted.
      expect(channel.calls.where((c) => c.startsWith('aggregate')), isEmpty);
    });

    test('requestPermissions answers with what is granted afterwards',
        () async {
      channel.grantOnRequest = ['steps', 'sleep'];
      final c = await provider.requestPermissions({
        HealthMetricKind.steps,
        HealthMetricKind.distance,
        HealthMetricKind.sleep,
      });
      expect(c.granted, {HealthMetricKind.steps, HealthMetricKind.sleep});
      expect(c.categoryGrant(HealthCategory.activity), CategoryGrant.partial);
      expect(c.categoryGrant(HealthCategory.recovery), CategoryGrant.partial);
      expect(c.categoryGrant(HealthCategory.body), CategoryGrant.none);
      expect(channel.calls.last, 'requestPermissions:steps,distance,sleep');
    });
  });

  group('activity totals', () {
    test(
        'steps, distance, active and total calories with units, the local day range and sources',
        () async {
      channel.granted = [
        'steps',
        'distance',
        'activeCalories',
        'totalCalories',
      ];
      channel.stepsAggregate = 6842;
      channel.rawStepsBySource = {'com.phone': 6842, 'com.watch': 6500};
      channel.totals = {
        'distance': 5120.5,
        'activeCalories': 482,
        'totalCalories': 2010,
      };
      final s = await snap();
      expect(s.steps.isAvailable, isTrue);
      expect(s.steps.value, 6842);
      expect(s.steps.unit, 'steps');
      expect(s.distance.value, 5120.5);
      expect(s.distance.unit, 'm');
      expect(s.activeCalories.value, 482);
      expect(s.activeCalories.unit, 'kcal');
      expect(s.totalCalories.value, 2010);
      expect(s.steps.sources, ['com.phone', 'com.watch']);
      expect(s.steps.updatedAt, now.toIso8601String());
      // 22 Sep in Kolkata (UTC+5:30) is 21 Sep 18:30Z → 22 Sep 18:30Z.
      expect(s.steps.start, '2026-09-21T18:30:00.000Z');
      expect(s.steps.end, '2026-09-22T18:30:00.000Z');
      // One aggregate call covers the four totals.
      final agg = channel.ranges
          .firstWhere((r) => r.$1.startsWith('aggregate:steps,distance'));
      expect(agg.$2.toUtc(), DateTime.utc(2026, 9, 21, 18, 30));
      expect(agg.$3.toUtc(), DateTime.utc(2026, 9, 22, 18, 30));
    });

    test('multiple step sources are never summed: the aggregate is the answer',
        () async {
      channel.granted = ['steps'];
      channel.rawStepsBySource = {'com.phone': 4000, 'com.watch': 4000};
      channel.stepsAggregate = 4200; // Health Connect de-duplicates the overlap
      final s = await snap();
      expect(s.steps.value, 4200);
      expect(s.steps.value, isNot(8000));
    });

    test('granted but nothing in the range → no data, not zero', () async {
      channel.granted = ['steps', 'distance'];
      final s = await snap();
      expect(s.steps.availability, HealthAvailability.noData);
      expect(s.steps.value, isNull);
      expect(s.distance.availability, HealthAvailability.noData);
    });

    test('only steps granted → the rest of activity is permission denied',
        () async {
      channel.granted = ['steps'];
      channel.stepsAggregate = 100;
      final s = await snap();
      expect(s.steps.isAvailable, isTrue);
      expect(s.distance.availability, HealthAvailability.permissionDenied);
      expect(
        s.activeCalories.availability,
        HealthAvailability.permissionDenied,
      );
      expect(s.sleep.availability, HealthAvailability.permissionDenied);
      expect(s.weight.availability, HealthAvailability.permissionDenied);
      expect(s.exerciseAvailability, HealthAvailability.permissionDenied);
      // Only the granted metric was asked for.
      expect(
        channel.calls.where((c) => c.startsWith('aggregate:')).first,
        'aggregate:steps',
      );
    });
  });

  group('recovery', () {
    test(
        'sleep is last night: 18:00 the day before → 12:00 today, local; minutes',
        () async {
      channel.granted = ['sleep'];
      channel.totals = {'sleep': 372};
      final s = await snap();
      expect(s.sleep.value, 372);
      expect(s.sleep.unit, 'min');
      final r = channel.ranges.firstWhere((r) => r.$1 == 'aggregate:sleep');
      // 21 Sep 18:00 IST = 12:30Z; 22 Sep 12:00 IST = 06:30Z.
      expect(r.$2.toUtc(), DateTime.utc(2026, 9, 21, 12, 30));
      expect(r.$3.toUtc(), DateTime.utc(2026, 9, 22, 6, 30));
    });

    test(
        "resting heart rate: today's average, else the latest reading with its own time",
        () async {
      channel.granted = ['restingHeartRate'];
      channel.totals = {'restingHeartRate': 62};
      var s = await snap();
      expect(s.restingHeartRate.value, 62);
      expect(s.restingHeartRate.unit, 'bpm');
      // No reading today → the latest within the look-back, dated.
      channel.totals = {};
      channel.latestByType = {
        'restingHeartRate': {
          'value': 58,
          'time': DateTime.utc(2026, 9, 18, 2).millisecondsSinceEpoch,
          'source': 'com.watch',
        },
      };
      s = await snap();
      expect(s.restingHeartRate.value, 58);
      expect(s.restingHeartRate.start, '2026-09-18T02:00:00.000Z');
      final r =
          channel.ranges.firstWhere((r) => r.$1 == 'latest:restingHeartRate');
      expect(r.$3.difference(r.$2), HealthConnectProvider.lookback);
    });
  });

  group('body', () {
    test('weight, body fat and BMR are the latest records with time and source',
        () async {
      channel.granted = ['weight', 'bodyFat', 'bmr'];
      channel.latestByType = {
        'weight': {
          'value': 60.5,
          'time': DateTime.utc(2026, 9, 18, 1).millisecondsSinceEpoch,
          'source': 'com.scale',
        },
        'bodyFat': {
          'value': 17.5,
          'time': DateTime.utc(2026, 9, 18, 1).millisecondsSinceEpoch,
          'source': 'com.scale',
        },
        'bmr': null,
      };
      final s = await snap();
      expect(s.weight.value, 60.5);
      expect(s.weight.unit, 'kg');
      expect(s.weight.start, '2026-09-18T01:00:00.000Z');
      expect(s.weight.sources, ['com.scale']);
      expect(s.bodyFat.value, 17.5);
      expect(s.bodyFat.unit, '%');
      expect(s.bmr.availability, HealthAvailability.noData);
    });
  });

  group('exercise sessions', () {
    test("today's sessions from any app; none → no data", () async {
      channel.granted = ['exercise'];
      var s = await snap();
      expect(s.exerciseAvailability, HealthAvailability.noData);
      channel.sessions = [
        {
          'start': DateTime.utc(2026, 9, 22, 1).millisecondsSinceEpoch,
          'end': DateTime.utc(2026, 9, 22, 2).millisecondsSinceEpoch,
          'type': 56,
          'title': 'Run',
          'source': 'com.watch',
        },
      ];
      s = await snap();
      expect(s.exerciseAvailability, HealthAvailability.available);
      expect(s.exerciseSessions.single.title, 'Run');
      expect(s.exerciseSessions.single.start, '2026-09-22T01:00:00.000Z');
    });
  });

  group('failures', () {
    test(
        'a permission revoked between the grant check and the read → permission denied, no stale value',
        () async {
      channel.granted = ['steps'];
      channel.stepsAggregate = 1000;
      channel.failWith = 'permissionDenied';
      final s = await snap();
      expect(s.steps.availability, HealthAvailability.permissionDenied);
      expect(s.steps.value, isNull);
    });

    test('a provider error → temporarily unavailable', () async {
      channel.granted = ['steps', 'weight'];
      channel.failWith = 'temporarilyUnavailable';
      final s = await snap();
      expect(s.steps.availability, HealthAvailability.temporarilyUnavailable);
      expect(s.weight.availability, HealthAvailability.temporarilyUnavailable);
    });
  });

  group('week boundaries', () {
    test('seven local days Monday first, in the user\'s zone', () async {
      channel.granted = ['steps', 'sleep'];
      channel.stepsAggregate = 10;
      channel.totals = {'sleep': 400};
      final s = await snap();
      expect(s.weekSteps, List.filled(7, 10.0));
      expect(s.weekSleep, List.filled(7, 400.0));
      // The first steps call is today's total; the seven after it are the week.
      final steps =
          channel.ranges.where((r) => r.$1 == 'aggregate:steps').toList();
      final days = steps.sublist(steps.length - 7);
      // The week of Tue 22 Sep 2026 starts Mon 21 Sep 00:00 IST = 20 Sep 18:30Z.
      expect(days.first.$2.toUtc(), DateTime.utc(2026, 9, 20, 18, 30));
      expect(days.last.$2.toUtc(), DateTime.utc(2026, 9, 26, 18, 30));
      expect(days.last.$3.toUtc(), DateTime.utc(2026, 9, 27, 18, 30));
      expect(days.length, 7);
    });

    test('a zone west of UTC keeps the local date: 22 Sep in Los Angeles',
        () async {
      channel.granted = ['steps'];
      channel.stepsAggregate = 1;
      final s = await provider.snapshot(
        date: '2026-09-22',
        timezone: 'America/Los_Angeles',
      );
      // PDT is UTC−7: local midnight is 07:00Z.
      expect(s.steps.start, '2026-09-22T07:00:00.000Z');
      expect(s.steps.end, '2026-09-23T07:00:00.000Z');
    });
  });

  test('the unsupported provider says so and nothing else', () async {
    const p = UnsupportedHealthProvider();
    final s = await p.snapshot(date: '2026-09-22', timezone: 'UTC');
    expect(
      s.metrics.every((m) => m.availability == HealthAvailability.unsupported),
      isTrue,
    );
    expect((await p.connection()).isConnected, isFalse);
    expect(await p.openSettings(), isFalse);
  });

  test('a snapshot round-trips through JSON (the phone cache)', () async {
    channel.granted = all;
    channel.stepsAggregate = 5;
    channel.totals = {'sleep': 300};
    final s = await snap();
    final back = HealthSnapshot.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(back, s);
    expect(back.copyWith(fromCache: true).fromCache, isTrue);
  });
}
