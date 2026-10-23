import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../support/fake_health_provider.dart';

/// Beta 3.2 (ADR-008 amendment): today's sessions only (in the user's zone),
/// each workout's window asked of Health Connect, and the day combined
/// without counting the same minutes twice.
void main() {
  late tz.Location kolkata;
  setUpAll(() {
    tzdata.initializeTimeZones();
    kolkata = tz.getLocation('Asia/Kolkata');
  });

  SessionListItem session({
    required String name,
    required String start,
    required String? end,
    int? seconds,
    int sets = 18,
    SessionStatus status = SessionStatus.completed,
  }) =>
      SessionListItem(
        id: name,
        status: status,
        name: name,
        startedAt: start,
        completedAt: end,
        durationSeconds: seconds,
        exerciseCount: 6,
        workingSets: sets,
        tonnageKg: 1800,
        prCount: 0,
      );

  test(
      'only sessions completed today in the user’s zone; each window asked of Health Connect',
      () async {
    final health =
        FakeHealthProvider(connection: HealthConnectionState.disconnected);
    final asked = <(DateTime, DateTime)>[];
    health.activeBetween = (s, e) {
      asked.add((s, e));
      return 40;
    };
    final e = await activeEnergyFor(
      date: '2026-10-24',
      location: kolkata,
      sessions: [
        // 19:00–20:00 IST on the 24th: today.
        session(
          name: 'Push',
          start: '2026-10-24T13:30:00.000Z',
          end: '2026-10-24T14:30:00.000Z',
          seconds: 3600,
        ),
        // 04:00 IST on the 25th (22:30 UTC on the 24th): not today in Kolkata.
        session(
          name: 'Late',
          start: '2026-10-24T21:30:00.000Z',
          end: '2026-10-24T22:30:00.000Z',
          seconds: 3600,
        ),
        // Yesterday, an abandoned one, an unfinished one.
        session(
          name: 'Pull',
          start: '2026-10-23T13:30:00.000Z',
          end: '2026-10-23T14:30:00.000Z',
          seconds: 3600,
        ),
        session(
          name: 'Gone',
          start: '2026-10-24T08:00:00.000Z',
          end: '2026-10-24T08:30:00.000Z',
          status: SessionStatus.abandoned,
        ),
        session(
          name: 'Open',
          start: '2026-10-24T09:00:00.000Z',
          end: null,
          status: SessionStatus.active,
        ),
      ],
      bodyWeightKg: 70,
      healthDayKcal: 280,
      health: health,
    );
    expect(e.workouts.map((w) => w.name), ['Push']);
    expect(asked, [
      (DateTime.utc(2026, 10, 24, 13, 30), DateTime.utc(2026, 10, 24, 14, 30)),
    ]);
    // 2.5 × 70 × 1 h = 175; Health Connect saw 40 → +135.
    expect(e.workouts.single.estimateKcal, 175);
    expect(e.fromWorkouts, 135);
    expect(e.total, 415);
  });

  test(
      'no duration stored: the start and finish give it; no Health Connect: the estimate alone',
      () async {
    final e = await activeEnergyFor(
      date: '2026-10-24',
      location: kolkata,
      sessions: [
        session(
          name: 'Legs',
          start: '2026-10-24T10:00:00.000Z',
          end: '2026-10-24T10:45:00.000Z',
          sets: 15,
        ),
      ],
      bodyWeightKg: 80,
      healthDayKcal: null,
      health: FakeHealthProvider(),
    );
    // 45 min, 15 sets = 20 an hour: 4 × 80 × 0.75 = 240.
    expect(e.workouts.single.estimateKcal, 240);
    expect(e.fromHealth, isNull);
    expect(e.total, 240);
  });
}
