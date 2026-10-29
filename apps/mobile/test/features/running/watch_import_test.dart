import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/running/data/watch_import.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_running.dart';

/// Beta 4.5 (owner 2026-10-30): Galaxy Watch runs, from Health Connect.

final t0 = DateTime.utc(2026, 10, 29, 1);

/// A watch run north at 5:00 /km with a point every 10 s.
WatchRun routed(String id, {DateTime? start, int minutes = 30}) {
  final s = start ?? t0;
  return WatchRun(
    id: id,
    start: s,
    end: s.add(Duration(minutes: minutes)),
    treadmill: false,
    pausedSeconds: 60,
    distanceM: 6000,
    hrAvg: 151.6,
    hrMax: 300,
    route: [
      for (var i = 0; i <= minutes * 6; i++)
        (
          s.millisecondsSinceEpoch + i * 10000,
          12.97 + i * 33.3 / 111195,
          79.16,
          null,
        ),
      // The same moment twice: dropped.
      (s.millisecondsSinceEpoch + minutes * 60000, 13.0, 79.16, null),
    ],
  );
}

RunSummary phoneRun(DateTime start, Duration length) => RunSummary(
      id: 'p',
      kind: RunKind.outdoor,
      name: 'Phone',
      startedAt: start,
      endedAt: start.add(length),
      durationSeconds: length.inSeconds,
      distanceM: 5000,
      avgPaceSecPerKm: 300,
      elevationGainM: null,
      calories: null,
      effort: null,
      outline: const [],
    );

void main() {
  late FakeWatch watch;
  late FakeRunningApi api;
  late WatchImporter importer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    watch = FakeWatch();
    api = FakeRunningApi();
    importer = WatchImporter(
      source: watch,
      api: api,
      userId: 'u1',
      now: () => DateTime.utc(2026, 10, 30, 12),
    );
  });

  test(
      'a run with its route: sent once as the watch’s, heart rate kept (and checked)',
      () async {
    watch.found = [routed('hc-1')];
    final r = await importer.run(const []);
    expect(r.imported, 1);
    final body = api.stored.values.single;
    expect(body['source'], 'watch');
    expect(body['externalId'], 'hc-1');
    expect(body['kind'], 'outdoor');
    expect(body['track'], isNotNull);
    // The server works the distance out from the route.
    expect(body['distanceM'], greaterThan(5000));
    expect(body['durationSeconds'], 30 * 60 - 60);
    expect(body['hrAvg'], 152);
    // 300 bpm is not a heart rate: left out.
    expect(body['hrMax'], isNull);
    expect(body['id'], importer.clientIdFor('hc-1'));
    // The next time: nothing new.
    expect((await importer.run(const [])).imported, 0);
    expect(api.stored, hasLength(1));
    // The id is the same on another phone (or after a reinstall).
    final again = WatchImporter(source: watch, api: api, userId: 'u1');
    expect(again.clientIdFor('hc-1'), importer.clientIdFor('hc-1'));
    expect(
      WatchImporter(source: watch, api: api, userId: 'u2').clientIdFor('hc-1'),
      isNot(importer.clientIdFor('hc-1')),
    );
  });

  test(
      'without a route: the watch’s distance; on a treadmill: treadmill; neither: skipped',
      () async {
    watch.found = [
      WatchRun(
        id: 'hc-2',
        start: t0,
        end: t0.add(const Duration(minutes: 20)),
        treadmill: false,
        pausedSeconds: 0,
        distanceM: 4000,
      ),
      WatchRun(
        id: 'hc-3',
        start: t0.add(const Duration(hours: 3)),
        end: t0.add(const Duration(hours: 3, minutes: 20)),
        treadmill: true,
        pausedSeconds: 0,
        distanceM: 3500,
      ),
      WatchRun(
        id: 'hc-4',
        start: t0.add(const Duration(hours: 6)),
        end: t0.add(const Duration(hours: 7)),
        treadmill: false,
        pausedSeconds: 0,
      ),
    ];
    expect((await importer.run(const [])).imported, 2);
    final byId = {for (final b in api.stored.values) b['externalId']: b};
    expect(byId['hc-2']!['kind'], 'outdoor');
    expect(byId['hc-2']!['distanceM'], 4000);
    expect(byId['hc-3']!['kind'], 'treadmill');
    expect(byId.containsKey('hc-4'), isFalse);
  });

  test('a run the phone also recorded (more than half its time) is not doubled',
      () async {
    watch.found = [routed('hc-5')];
    final r = await importer.run([
      phoneRun(t0.add(const Duration(minutes: 5)), const Duration(minutes: 30)),
    ]);
    expect(r.imported, 0);
    expect(api.stored, isEmpty);
    // Overlapping a little only: it comes in.
    watch.found = [routed('hc-6', start: t0.add(const Duration(days: 1)))];
    final r2 = await importer.run([
      phoneRun(
        t0.add(const Duration(days: 1, minutes: 25)),
        const Duration(minutes: 30),
      ),
    ]);
    expect(r2.imported, 1);
  });

  test('offline: stops, and the rest comes in next time', () async {
    watch.found = [routed('hc-7')];
    api.failWith = const Offline();
    final r = await importer.run(const []);
    expect(r.offline, isTrue);
    expect(r.imported, 0);
    api.failWith = null;
    expect((await importer.run(const [])).imported, 1);
  });

  test(
      'not allowed: nothing read; the first look is 30 days, later ones from the last less 2 days',
      () async {
    watch.allowed = false;
    expect((await importer.run(const [])).imported, 0);
    expect(watch.windows, isEmpty);
    watch.allowed = true;
    await importer.run(const []);
    expect(watch.windows.last.$1, DateTime.utc(2026, 9, 30, 12));
    await importer.run(const []);
    expect(watch.windows.last.$1, DateTime.utc(2026, 10, 28, 12));
  });

  test('the channel’s words: a session, or nothing for a bad one', () {
    final w = WatchRun.fromChannel({
      'id': 'hc-9',
      'start': t0.millisecondsSinceEpoch,
      'end': t0.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      'treadmill': false,
      'pausedSeconds': 30,
      'distanceM': 2000.5,
      'hrAvg': 140.2,
      'hrMax': 160,
      'route': [
        [t0.millisecondsSinceEpoch, 12.97, 79.16, 900.0],
        [t0.millisecondsSinceEpoch + 10000, 12.971, 79.16, null],
      ],
    })!;
    expect(w.movingSeconds, 570);
    expect(w.track!.segments.single, hasLength(2));
    expect(w.track!.segments.single.first.ele, 900);
    expect(WatchRun.fromChannel({'id': 'x', 'start': 10, 'end': 5}), isNull);
    expect(WatchRun.fromChannel({'start': 1, 'end': 5}), isNull);
    // One point is no route.
    expect(
      WatchRun(
        id: 'a',
        start: t0,
        end: t0.add(const Duration(minutes: 1)),
        treadmill: false,
        pausedSeconds: 999,
        route: [(t0.millisecondsSinceEpoch, 1, 1, null)],
      ).track,
      isNull,
    );
    expect(
      WatchRun(
        id: 'a',
        start: t0,
        end: t0.add(const Duration(minutes: 1)),
        treadmill: false,
        pausedSeconds: 999,
      ).movingSeconds,
      60,
    );
  });
}
