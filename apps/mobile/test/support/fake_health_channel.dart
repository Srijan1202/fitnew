import 'package:fitos/features/health/data/health_connect_channel.dart';

/// A scripted Health Connect channel. Holds "raw records" per source so a
/// test can prove the provider never sums them itself: `aggregate` answers
/// the de-duplicated total the way Health Connect does, and the test
/// checks that total — not the raw sum — reaches the snapshot.
class FakeHealthChannel implements HealthConnectChannel {
  String sdk = 'available';
  List<String> granted = [];
  List<String> grantOnRequest = [];

  /// Raw step records per source, e.g. {'phone': 4000, 'watch': 4000}:
  /// the de-duplicated aggregate is [stepsAggregate], not their sum.
  Map<String, double> rawStepsBySource = {};
  double? stepsAggregate;

  /// Aggregates by metric key for any range (null = no data).
  Map<String, double?> totals = {};

  /// Point records by type: value, time (UTC ms), source.
  Map<String, Map<String, Object?>?> latestByType = {};
  List<Map<String, Object?>> sessions = [];

  /// Throw this code from every read.
  String? failWith;

  /// Every call with its arguments, in order.
  final calls = <String>[];
  final ranges = <(String, DateTime, DateTime)>[];

  void _maybeFail() {
    if (failWith != null) throw HealthChannelException(failWith!);
  }

  @override
  Future<String> sdkStatus() async {
    calls.add('sdkStatus');
    return sdk;
  }

  @override
  Future<List<String>> grantedPermissions() async {
    calls.add('grantedPermissions');
    return List.of(granted);
  }

  @override
  Future<List<String>> requestPermissions(List<String> metrics) async {
    calls.add('requestPermissions:${metrics.join(',')}');
    granted = [
      ...granted,
      for (final m in metrics)
        if (grantOnRequest.contains(m) && !granted.contains(m)) m,
    ];
    return List.of(granted);
  }

  @override
  Future<Map<String, Object?>> aggregate({
    required DateTime start,
    required DateTime end,
    required List<String> metrics,
  }) async {
    calls.add('aggregate:${metrics.join(',')}');
    ranges.add(('aggregate:${metrics.join(',')}', start, end));
    _maybeFail();
    final out = <String, Object?>{};
    for (final m in metrics) {
      if (m == 'steps' && stepsAggregate != null) {
        out['steps'] = stepsAggregate;
      } else if (totals[m] != null) {
        out[m] = totals[m];
      }
    }
    out['sources'] = rawStepsBySource.keys.toList();
    return out;
  }

  @override
  Future<Map<String, Object?>?> latest({
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    calls.add('latest:$type');
    ranges.add(('latest:$type', start, end));
    _maybeFail();
    return latestByType[type];
  }

  @override
  Future<List<Map<String, Object?>>> exerciseSessions({
    required DateTime start,
    required DateTime end,
  }) async {
    calls.add('exerciseSessions');
    ranges.add(('exerciseSessions', start, end));
    _maybeFail();
    return sessions;
  }

  @override
  Future<bool> openSettings() async {
    calls.add('openSettings');
    return true;
  }
}
