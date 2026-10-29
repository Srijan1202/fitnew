import 'dart:async';
import 'dart:typed_data';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/running/data/location_source.dart';
import 'package:fitos/features/running/data/run_voice.dart';
import 'package:fitos/features/running/data/running_api.dart';
import 'package:fitos/features/running/domain/efforts.dart';
import 'package:fitos/features/running/domain/gps_filter.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/run_math.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/domain/workout.dart';
import 'package:fitos/features/running/presentation/screens/share_run_screen.dart';
import 'package:fitos/features/running/presentation/widgets/route_snapshot.dart';

/// Beta 4.0: a scripted running server. It works runs out with the app's
/// own port of core's rules (the parity test holds them equal), so a saved
/// run comes back as the real server would answer.
class FakeRunningApi implements RunningApi {
  final Map<String, Map<String, dynamic>> stored = {};
  final List<String> calls = [];

  /// Every request answers this failure while set.
  Failure? failWith;

  /// Beta 4.1: the active plan, as the server would send it (null: none).
  Map<String, dynamic>? plan;
  final List<Map<String, dynamic>> createdPlans = [];
  Map<String, dynamic> presets = {'zones': null, 'presets': <Object>[]};

  /// Beta 4.2: the records as the server would send them (none yet).
  Map<String, dynamic> recordsJson = {
    'records': [
      for (final k in EffortKey.values) {'key': k.wire, 'best': <Object>[]},
    ],
    'pending': 0,
  };

  /// A run's efforts (the phone's port of core's rules), ranked against
  /// the runs stored before it, as the server ranks them.
  List<Map<String, dynamic>> _efforts(Map<String, dynamic> body) {
    if (body['kind'] != 'outdoor') return const [];
    final track = decodeTrack(
      EncodedTrack.fromJson(body['track'] as Map<String, dynamic>),
    );
    return [
      for (final e in bestEfforts(track))
        {
          'key': e.key.wire,
          'seconds': e.seconds,
          'startM': e.startM,
          'rank': () {
            final faster = stored.values
                .expand((r) => (r['efforts'] as List?) ?? const [])
                .where(
                  (x) =>
                      (x as Map)['key'] == e.key.wire &&
                      (x['seconds'] as num) <= e.seconds,
                )
                .length;
            return faster < 3 ? faster + 1 : null;
          }(),
        },
    ];
  }

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
      'workout': body['workout'],
      'laps': [
        for (final m in (body['laps'] as List?) ?? const [])
          {
            'step': (m as Map)['step'],
            'distanceM': 100.0,
            'seconds': ((m['endT'] as num) - (m['startT'] as num)).toDouble(),
            'pace': 300.0,
          },
      ],
      'plannedRunId': _link(body),
      'efforts': _efforts(body),
      'recordKeys': [
        for (final e in _efforts(body))
          if (e['rank'] == 1) e['key'],
      ],
    };
  }

  /// A run does the plan's run it names, else today's still-planned one.
  String? _link(Map<String, dynamic> body) {
    final runs = (plan?['runs'] as List?)?.cast<Map<String, dynamic>>();
    if (runs == null) return null;
    final named = body['plannedRunId'] as String?;
    final date = (body['startedAt'] as String).substring(0, 10);
    for (final r in runs) {
      final hit = named != null ? r['id'] == named : r['date'] == date;
      if (hit && r['status'] == 'planned') {
        r['status'] = 'done';
        r['runId'] = body['clientRunId'];
        return r['id'] as String;
      }
    }
    return null;
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
  Future<Result<Map<String, dynamic>>> currentPlan() async {
    calls.add('plan');
    if (failWith != null) return Err(failWith!);
    return Ok({'plan': plan});
  }

  @override
  Future<Result<RunningPlan>> createPlan(Map<String, dynamic> body) async {
    calls.add('createPlan');
    if (failWith != null) return Err(failWith!);
    createdPlans.add(body);
    plan ??= planJson(runs: const []);
    return Ok(RunningPlan.fromJson(plan!));
  }

  @override
  Future<Result<void>> stopPlan() async {
    calls.add('stopPlan');
    if (failWith != null) return Err(failWith!);
    plan = null;
    return const Ok(null);
  }

  @override
  Future<Result<PlannedRun>> patchPlanned(
    String id,
    Map<String, dynamic> body,
  ) async {
    calls.add('patchPlanned $id ${body['action']}');
    if (failWith != null) return Err(failWith!);
    final runs = (plan?['runs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final r = runs.firstWhere((x) => x['id'] == id);
    switch (body['action']) {
      case 'skip':
        r['status'] = 'skipped';
      case 'unskip':
        r['status'] = 'planned';
      case 'move':
        r['movedFrom'] = r['date'];
        r['date'] = body['date'];
    }
    return Ok(PlannedRun.fromJson(r));
  }

  @override
  Future<Result<Map<String, dynamic>>> records() async {
    calls.add('records');
    if (failWith != null) return Err(failWith!);
    return Ok(recordsJson);
  }

  @override
  Future<Result<WorkoutPresets>> workouts() async {
    calls.add('workouts');
    if (failWith != null) return Err(failWith!);
    return Ok(WorkoutPresets.fromJson(presets));
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

/// Beta 4.1.1: the share picture's map; [image] null is "could not make it"
/// (offline), and the card then keeps the drawn route.
class FakeRouteSnapshotter implements RouteSnapshotter {
  Uint8List? image = onePixelPng;
  final List<List<List<(double, double)>>> taken = [];

  @override
  Future<Uint8List?> take(List<List<(double, double)>> segments) async {
    taken.add(segments);
    return image;
  }
}

/// A valid 1×1 PNG.
final onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x04, 0x00, 0x00, 0x00, 0xB5, 0x1C, 0x0C, 0x02, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0x64, 0x60, 0x00, 0x00,
  0x00, 0x06, 0x00, 0x02, 0x30, 0x81, 0xD0, 0x2F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Beta 4.1: a planned run as the server sends it.
Map<String, dynamic> plannedRunJson({
  required String id,
  required String date,
  String kind = 'easy',
  String title = 'Easy 5 km',
  double? distanceM = 5000,
  int? seconds,
  Map<String, int>? pace = const {'fast': 330, 'slow': 370},
  List<WorkoutStep>? steps,
  String status = 'planned',
  int week = 1,
}) =>
    {
      'id': id,
      'date': date,
      'week': week,
      'kind': kind,
      'title': title,
      'distanceM': distanceM,
      'seconds': seconds,
      'pace': pace,
      'steps': steps == null ? null : [for (final s in steps) s.toJson()],
      'note': 'Conversational.',
      'status': status,
      'runId': null,
      'movedFrom': null,
    };

/// Beta 4.1: a plan as the server sends it.
Map<String, dynamic> planJson({
  required List<Map<String, dynamic>> runs,
  String goal = '10k',
  List<int> weekdays = const [2, 4, 7],
  List<int> gymOverlap = const [],
}) =>
    {
      'id': '7c0d3f1e-6f3c-4a8e-9d55-2f0c3c5a9b77',
      'goal': goal,
      'level': 'runner',
      'status': 'active',
      'daysPerWeek': weekdays.length,
      'weekdays': weekdays,
      'longRunWeekday': weekdays.last,
      'startDate': runs.isEmpty ? '2026-11-02' : runs.first['date'],
      'weeks': 8,
      'zones': {
        'vdot': 40.1,
        'easy': {'fast': 351, 'slow': 404},
        'marathon': 327,
        'threshold': 306,
        'interval': 281,
        'repetition': 263,
      },
      'predictedSeconds': 3001,
      'gymOverlap': gymOverlap,
      'runs': runs,
    };

class FakeRunVoice implements RunVoice {
  final List<String> said = [];

  @override
  Future<void> say(String text) async => said.add(text);

  @override
  Future<void> stop() async {}
}
