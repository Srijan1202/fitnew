import 'dart:async';
import 'dart:typed_data';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/running/data/location_source.dart';
import 'package:fitos/features/running/data/running_api.dart';
import 'package:fitos/features/running/domain/gps_filter.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/run_math.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/presentation/screens/share_run_screen.dart';

/// Beta 4.0: a scripted running server. It works runs out with the app's
/// own port of core's rules (the parity test holds them equal), so a saved
/// run comes back as the real server would answer.
class FakeRunningApi implements RunningApi {
  final Map<String, Map<String, dynamic>> stored = {};
  final List<String> calls = [];

  /// Every request answers this failure while set.
  Failure? failWith;

  Map<String, dynamic> _detail(Map<String, dynamic> body) {
    final outdoor = body['kind'] == 'outdoor';
    final duration = body['durationSeconds'] as int;
    final f = outdoor
        ? summarizeTrack(
            decodeTrack(
              EncodedTrack.fromJson(body['track'] as Map<String, dynamic>),
            ),
            duration,
            null,
          )
        : summarizeTreadmill(
            (body['distanceM'] as num).toDouble(),
            duration,
            null,
          );
    Map<String, dynamic> split(RunSplit s) => {
          'index': s.index,
          'distanceM': s.distanceM,
          'seconds': s.seconds,
          'pace': s.pace,
          'elevationChangeM': s.elevationChangeM,
        };
    return {
      'id': body['clientRunId'],
      'kind': body['kind'],
      'name': body['name'],
      'startedAt': body['startedAt'],
      'endedAt': body['endedAt'],
      'durationSeconds': duration,
      'distanceM': f.distanceM,
      'avgPaceSecPerKm': f.avgPaceSecPerKm,
      'elevationGainM': f.elevationGainM,
      'calories': f.calories,
      'effort': body['effort'],
      'outline': [
        for (final p in f.outline) [p.$1, p.$2],
      ],
      'note': body['note'],
      'goal': body['goal'],
      'track': outdoor ? body['track'] : null,
      'splitsKm': [for (final s in f.splitsKm) split(s)],
      'splitsMi': [for (final s in f.splitsMi) split(s)],
      'series': [
        for (final p in f.series)
          {'distanceM': p.distanceM, 'pace': p.pace, 'ele': p.ele},
      ],
    };
  }

  @override
  Future<Result<Map<String, dynamic>>> createRun(
    Map<String, dynamic> body,
  ) async {
    final id = body['clientRunId'] as String;
    calls.add('create $id');
    if (failWith != null) return Err(failWith!);
    return Ok(stored[id] ??= _detail(body));
  }

  @override
  Future<Result<Map<String, dynamic>>> patchRun(
    String id,
    Map<String, dynamic> body,
  ) async {
    calls.add('patch $id');
    if (failWith != null) return Err(failWith!);
    final run = stored[id];
    if (run == null) return const Err(NotFound());
    run.addAll(body);
    return Ok(run);
  }

  @override
  Future<Result<void>> deleteRun(String id) async {
    calls.add('delete $id');
    if (failWith != null) return Err(failWith!);
    return stored.remove(id) == null ? const Err(NotFound()) : const Ok(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> run(String id) async {
    calls.add('get $id');
    if (failWith != null) return Err(failWith!);
    final run = stored[id];
    return run == null ? const Err(NotFound()) : Ok(run);
  }

  @override
  Future<Result<RunList>> runs({String? before}) async {
    calls.add('list');
    if (failWith != null) return Err(failWith!);
    final rows = stored.values.toList()
      ..sort(
        (a, b) =>
            (b['startedAt'] as String).compareTo(a['startedAt'] as String),
      );
    final distance = rows.fold<double>(
      0,
      (s, r) => s + (r['distanceM'] as num).toDouble(),
    );
    final time = rows.fold<int>(0, (s, r) => s + (r['durationSeconds'] as int));
    final totals = {
      'runs': rows.length,
      'distanceM': distance,
      'durationSeconds': time,
    };
    return Ok(
      RunList.fromJson({
        'runs': rows,
        'nextBefore': null,
        'totals': {'week': totals, 'month': totals},
      }),
    );
  }
}

/// GPS the test sends itself.
class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.access = LocationAccess.granted});

  LocationAccess access;
  StreamController<GpsFix>? _fixes;
  int listens = 0;
  int openedSettings = 0;

  bool get listening => _fixes != null && !_fixes!.isClosed;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Stream<GpsFix> fixes() {
    listens++;
    final c = StreamController<GpsFix>(
      onCancel: () => _fixes = null,
    );
    _fixes = c;
    return c.stream;
  }

  void send(GpsFix fix) => _fixes?.add(fix);

  @override
  Future<void> openAppSettings() async => openedSettings++;

  @override
  Future<void> openLocationSettings() async => openedSettings++;
}

/// A straight run north from VIT at [speed] m/s, one fix a second.
List<GpsFix> runNorth({
  required DateTime from,
  required int seconds,
  double speed = 3,
  double accuracy = 5,
  double lat0 = 12.9692,
  double ele = 216,
}) {
  const mPerDeg = 6371008.8 * 3.141592653589793 / 180;
  return [
    for (var i = 0; i < seconds; i++)
      GpsFix(
        at: from.add(Duration(seconds: i)),
        lat: lat0 + i * speed / mPerDeg,
        lon: 79.1559,
        accuracyM: accuracy,
        altitudeM: ele,
        speedMs: speed,
      ),
  ];
}

class FakeRunNotification implements RunNotification {
  final List<String> shown = [];

  @override
  Future<void> show({
    required String title,
    required String body,
    DateTime? runningSince,
  }) async =>
      shown.add('$title | $body');
}

class FakeBatteryAccess implements BatteryAccess {
  FakeBatteryAccess({this.unrestricted = true});

  bool unrestricted;
  int opened = 0;

  @override
  Future<bool> isUnrestricted() async => unrestricted;

  @override
  Future<void> openSettings() async => opened++;
}

class FakeRunSharer implements RunSharer {
  final List<(String, String, Uint8List)> shared = [];

  @override
  Future<void> share(Uint8List bytes, String fileName, String mimeType) async =>
      shared.add((fileName, mimeType, bytes));
}
