import 'package:fitos/features/running/data/watch_background.dart';
import 'package:fitos/features/running/data/watch_import.dart';
import 'package:fitos/features/running/domain/coach.dart';
import 'package:fitos/features/running/domain/live_stats.dart';
import 'package:fitos/features/running/domain/race.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/run_math.dart';
import 'package:fitos/features/running/domain/units.dart';
import 'package:fitos/features/running/presentation/widgets/race_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_running.dart';

/// Beta 4.9 (owner 2026-10-30): race-day mode, the watch's cadence and the
/// watch runs imported with FITOS closed.
void main() {
  RunSplit km(int i, double seconds, [double metres = 1000]) => RunSplit(
        index: i,
        distanceM: metres,
        seconds: seconds,
        pace: seconds / (metres / 1000),
        elevationChangeM: null,
      );

  group('race plan', () {
    const even = RacePlan(
      distanceM: 5000,
      targetSeconds: 1500,
      split: RaceSplit.even,
    );
    const negative = RacePlan(
      distanceM: 5000,
      targetSeconds: 1500,
      split: RaceSplit.negative,
    );

    test('even: one pace; negative: 2 % slower then 2 % faster, same finish',
        () {
      expect(even.evenPace, 300);
      expect(even.paceAt(4000), 300);
      expect(negative.paceAt(1000), closeTo(306, 1e-9));
      expect(negative.paceAt(3000), closeTo(294, 1e-9));
      expect(negative.plannedAt(5000), closeTo(1500, 1e-9));
      expect(negative.plannedAt(2500), closeTo(765, 1e-9));
      expect(even.plannedAt(9000), 1500, reason: 'clamped to the race');
    });

    test('ahead or behind, and the projected finish from 200 m', () {
      expect(even.deltaAt(1000, 310), 10);
      expect(even.deltaAt(1000, 290), -10);
      expect(even.projectedFinish(150, 40), isNull);
      expect(even.projectedFinish(2500, 740), 1480);
    });

    test('km splits: whole km, the last one partial', () {
      const half = RacePlan(
        distanceM: 2500,
        targetSeconds: 750,
        split: RaceSplit.even,
      );
      expect(half.kmSplits(), [300, 300, 150]);
      expect(negative.kmSplits().first, closeTo(306, 1e-9));
      expect(negative.kmSplits().last, closeTo(294, 1e-9));
    });

    test('the finish from the splits: inside the split that crosses it', () {
      expect(
        even.finishFrom([for (var i = 1; i <= 5; i++) km(i, 296)]),
        1480,
      );
      // 5.2 km run: the 6th split's first 0 m — finish at 5 × 300.
      expect(
        even.finishFrom([
          for (var i = 1; i <= 5; i++) km(i, 300),
          km(6, 60, 200),
        ]),
        1500,
      );
      // 4.99 km (GPS short by 10 m): counted; 4.5 km: not finished.
      expect(
        even.finishFrom([
          for (var i = 1; i <= 4; i++) km(i, 300),
          km(5, 297, 990),
        ]),
        1497,
      );
      expect(
        even.finishFrom([
          for (var i = 1; i <= 4; i++) km(i, 300),
          km(5, 150, 500),
        ]),
        isNull,
      );
    });

    test('verdicts and names', () {
      expect(raceVerdict(1468, 1500), '32 s under target');
      expect(raceVerdict(1565, 1500), '1:05 over target');
      expect(raceVerdict(1501, 1500), 'On target');
      expect(raceName(5000), '5K');
      expect(raceName(21097), 'Half marathon');
      expect(raceName(15000), '15 km race');
      expect(raceName(7500), '7.5 km race');
    });

    test('only a race goal with a distance and a time has a plan', () {
      expect(RacePlan.of(const RunGoal(RunGoalKind.distance, 5000)), isNull);
      expect(RacePlan.of(const RunGoal(RunGoalKind.race, 5000)), isNull);
      final p =
          RacePlan.of(const RunGoal.race(10000, 3000, RaceSplit.negative));
      expect(p?.split, RaceSplit.negative);
      expect(p?.evenPace, 300);
    });
  });

  group('race goal', () {
    test('JSON: a race carries its target and split; others do not', () {
      const g = RunGoal.race(5000, 1500, RaceSplit.negative);
      expect(g.toJson(), {
        'kind': 'race',
        'value': 5000,
        'targetSeconds': 1500,
        'split': 'negative',
      });
      expect(RunGoal.fromJson(g.toJson()), g);
      expect(
        const RunGoal(RunGoalKind.distance, 5000).toJson(),
        {'kind': 'distance', 'value': 5000},
      );
    });

    test('from the phone columns: the split only for a race', () {
      expect(
        RunGoal.stored('race', 5000, 1500, 'even'),
        const RunGoal.race(5000, 1500, RaceSplit.even),
      );
      expect(
        RunGoal.stored('distance', 5000, 1500, 'even'),
        const RunGoal(RunGoalKind.distance, 5000),
      );
      expect(RaceSplit.parse('nonsense'), RaceSplit.even);
    });

    test('progress runs to the race distance', () {
      expect(
        goalProgress(
          goalKind: 'race',
          goalValue: 5000,
          distanceM: 2500,
          activeSeconds: 700,
        ),
        0.5,
      );
    });
  });

  group('race coach', () {
    CoachInput at(int seconds, double metres, int? delta) => CoachInput(
          activeSeconds: seconds,
          distanceM: metres,
          avgPaceSecPerKm: seconds / (metres / 1000),
          currentPaceSecPerKm: null,
          lastSplitSeconds: seconds.toDouble(),
          goalKind: 'race',
          goalValue: 5000,
          target: null,
          raceDeltaSec: delta,
        );

    test('each km says where the race stands against the plan', () {
      final c = Coach(settings: const CoachSettings(), unit: DistanceUnit.km);
      expect(
        c.tick(at(312, 1001, 12)).single,
        endsWith('12 seconds behind plan.'),
      );
      expect(
        c.tick(at(590, 2001, -10)).single,
        endsWith('10 seconds ahead of plan.'),
      );
      // Past halfway: the goal's line follows the split's.
      expect(c.tick(at(901, 3001, 1)).first, endsWith('On plan.'));
    });

    test('the target pace is the plan’s for where the runner is', () {
      const plan = RacePlan(
        distanceM: 5000,
        targetSeconds: 1500,
        split: RaceSplit.negative,
      );
      final first = targetPace(
        goalKind: 'race',
        goalValue: 5000,
        race: plan,
        distanceM: 1000,
      );
      final second = targetPace(
        goalKind: 'race',
        goalValue: 5000,
        race: plan,
        distanceM: 4000,
      );
      expect((first!.fast, first.slow), (301, 311));
      expect((second!.fast, second.slow), (289, 299));
    });
  });

  group('watch cadence and background import', () {
    WatchRun treadmill(String id, {double? avg, double? max}) => WatchRun(
          id: id,
          start: DateTime.utc(2026, 10, 29, 1),
          end: DateTime.utc(2026, 10, 29, 1, 26, 10),
          treadmill: true,
          pausedSeconds: 0,
          distanceM: 5200,
          cadenceAvg: avg,
          cadenceMax: max,
        );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('cadence is sent in range; a max under the average is left out',
        () async {
      final watch = FakeWatch()
        ..found = [
          treadmill('a', avg: 168.4, max: 181.6),
          treadmill('b', avg: 170, max: 150),
          treadmill('c', avg: 30, max: 400),
        ];
      final api = FakeRunningApi();
      final importer = WatchImporter(
        source: watch,
        api: api,
        userId: 'u1',
        now: () => DateTime.utc(2026, 10, 30, 12),
      );
      final r = await importer.run(const []);
      expect(r.imported, 3);
      expect(r.added.map((w) => w.id), ['a', 'b', 'c']);
      final bodies = {
        for (final b in api.stored.values) b['externalId']: b,
      };
      expect(bodies['a']!['cadenceAvg'], 168);
      expect(bodies['a']!['cadenceMax'], 182);
      expect(bodies['b']!['cadenceAvg'], 170);
      expect(bodies['b']!['cadenceMax'], isNull);
      expect(bodies['c']!['cadenceAvg'], isNull);
      expect(bodies['c']!['cadenceMax'], isNull);
    });

    test('the notification’s words', () {
      expect(
        WatchBackground.message([treadmill('a')], DistanceUnit.km),
        'Watch run added: 5.20 km · 26:10',
      );
      expect(
        WatchBackground.message(
          [treadmill('a'), treadmill('b')],
          DistanceUnit.km,
        ),
        '2 watch runs added',
      );
    });

    test('at most one notification a day', () async {
      final p = await SharedPreferences.getInstance();
      final day = DateTime(2026, 11, 2, 9);
      expect(await WatchBackground.takeToday(p, day), isTrue);
      expect(
        await WatchBackground.takeToday(p, day.add(const Duration(hours: 6))),
        isFalse,
      );
      expect(
        await WatchBackground.takeToday(p, day.add(const Duration(days: 1))),
        isTrue,
      );
    });

    test('runs only as the user Running last imported as, switch on, online',
        () async {
      final watch = FakeWatch()..found = [treadmill('a')];
      final api = FakeRunningApi();
      Future<WatchImportResult?> once(String? uid) =>
          WatchBackground.importOnce(
            source: watch,
            api: api,
            currentUid: () => uid,
          );

      // Nobody remembered yet.
      expect(await once('fb-1'), isNull);
      await WatchBackground.remember(userId: 'u1', firebaseUid: 'fb-1');
      // Someone else is signed in now.
      expect(await once('fb-2'), isNull);
      expect(api.stored, isEmpty);
      final r = await once('fb-1');
      expect(r?.imported, 1);
      // Not twice.
      expect((await once('fb-1'))?.imported, 0);

      // The switch off: nothing read.
      final p = await SharedPreferences.getInstance();
      await p.setBool('running.watchImport', false);
      expect(await once('fb-1'), isNull);
    });
  });

  testWidgets('the result: time against target, each km against plan',
      (tester) async {
    final start = DateTime.utc(2026, 11, 8, 1);
    final run = RunDetail(
      summary: RunSummary(
        id: 'r',
        kind: RunKind.outdoor,
        name: 'Race',
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 25)),
        durationSeconds: 1470,
        distanceM: 5000,
        avgPaceSecPerKm: 294,
        elevationGainM: null,
        calories: null,
        effort: null,
        outline: const [],
      ),
      note: null,
      goal: const RunGoal.race(5000, 1500, RaceSplit.even),
      track: null,
      splitsKm: [
        km(1, 310),
        km(2, 300),
        km(3, 290),
        km(4, 290),
        km(5, 280),
      ],
      splitsMi: const [],
      series: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RaceResult(run: run, plan: RacePlan.of(run.goal)!),
        ),
      ),
    );
    expect(find.text('5K · target 25:00'), findsOneWidget);
    expect(find.text('24:30'), findsOneWidget);
    expect(find.text('30 s under target'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('-20'), findsOneWidget);
    expect(find.byKey(const ValueKey('run.race.km.5')), findsOneWidget);
  });
}
