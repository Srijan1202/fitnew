import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/health.dart';
import '../domain/health_data_provider.dart';
import 'health_connect_channel.dart';

/// Health Connect as a [HealthDataProvider] (owner D1). Normalizes the
/// channel's plain values into [HealthSnapshot]: explicit local-day and
/// local-night ranges in the user's calendar, `aggregate()` for every
/// cumulative metric (Health Connect de-duplicates across sources), the
/// latest record for point metrics, and an availability per metric that
/// says exactly why a value is missing. Permissions are re-read on every
/// snapshot, so a revocation shows up as `permissionDenied`, never as a
/// stale number.
class HealthConnectProvider implements HealthDataProvider {
  HealthConnectProvider(this._channel, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    tzdata.initializeTimeZones();
  }

  final HealthConnectChannel _channel;
  final DateTime Function() _now;

  /// Measurements are read back this far (Health Connect serves 30 days
  /// before the grant by default).
  static const lookback = Duration(days: 30);

  /// "Last night" for a local date D: D−1 18:00 → D 12:00.
  static const nightStartHour = 18;
  static const nightEndHour = 12;

  /* -------------------------------------------------------- connection -- */

  static HealthSdkStatus _status(String s) => switch (s) {
        'available' => HealthSdkStatus.available,
        'updateRequired' => HealthSdkStatus.updateRequired,
        _ => HealthSdkStatus.unavailable,
      };

  static Set<HealthMetricKind> _kinds(List<String> wires) => {
        for (final w in wires)
          for (final k in HealthMetricKind.values)
            if (k.wire == w) k,
      };

  @override
  Future<HealthConnectionState> connection() async {
    final sdk = _status(await _channel.sdkStatus());
    if (sdk != HealthSdkStatus.available) {
      return HealthConnectionState(sdk: sdk, granted: const {});
    }
    try {
      return HealthConnectionState(
        sdk: sdk,
        granted: _kinds(await _channel.grantedPermissions()),
      );
    } on HealthChannelException {
      return HealthConnectionState(sdk: sdk, granted: const {});
    }
  }

  @override
  Future<HealthConnectionState> requestPermissions(
    Set<HealthMetricKind> kinds,
  ) async {
    final sdk = _status(await _channel.sdkStatus());
    if (sdk != HealthSdkStatus.available) {
      return HealthConnectionState(sdk: sdk, granted: const {});
    }
    try {
      final granted = await _channel.requestPermissions(
        kinds.map((k) => k.wire).toList(),
      );
      return HealthConnectionState(sdk: sdk, granted: _kinds(granted));
    } on HealthChannelException {
      return connection();
    }
  }

  @override
  Future<bool> openSettings() => _channel.openSettings();

  /* ---------------------------------------------------------- snapshot -- */

  @override
  Future<HealthSnapshot> snapshot({
    required String date,
    required String timezone,
  }) async {
    final fetchedAt = _now().toUtc().toIso8601String();
    final conn = await connection();
    if (conn.sdk != HealthSdkStatus.available) {
      return HealthSnapshot.empty(
        date: date,
        timezone: timezone,
        availability: HealthAvailability.unsupported,
        fetchedAt: fetchedAt,
      );
    }
    if (conn.granted.isEmpty) {
      return HealthSnapshot.empty(
        date: date,
        timezone: timezone,
        availability: HealthAvailability.notConnected,
        fetchedAt: fetchedAt,
      );
    }
    final cal = _Calendar(timezone, date);
    final granted = conn.granted;

    // Today's totals, one aggregate call, only for granted metrics.
    final dayKinds = [
      HealthMetricKind.steps,
      HealthMetricKind.distance,
      HealthMetricKind.activeCalories,
      HealthMetricKind.totalCalories,
    ].where(granted.contains).toList();
    final day = await _aggregate(cal.dayStart, cal.dayEnd, dayKinds);

    // Last night's sleep and today's resting heart rate.
    final night = granted.contains(HealthMetricKind.sleep)
        ? await _aggregate(
            cal.nightStart,
            cal.nightEnd,
            [HealthMetricKind.sleep],
          )
        : const _Aggregate.none();
    final rhrToday = granted.contains(HealthMetricKind.restingHeartRate)
        ? await _aggregate(
            cal.dayStart,
            cal.dayEnd,
            [HealthMetricKind.restingHeartRate],
          )
        : const _Aggregate.none();

    HealthMetric total(
      HealthMetricKind k,
      String unit,
      _Aggregate a,
      DateTime s,
      DateTime e,
    ) {
      if (!granted.contains(k)) {
        return HealthMetric.unavailable(
          k,
          HealthAvailability.permissionDenied,
          unit: unit,
          updatedAt: fetchedAt,
        );
      }
      if (a.failure != null) {
        return HealthMetric.unavailable(
          k,
          a.failure!,
          unit: unit,
          updatedAt: fetchedAt,
        );
      }
      final v = a.values[k.wire];
      if (v == null) {
        return HealthMetric.unavailable(
          k,
          HealthAvailability.noData,
          unit: unit,
          updatedAt: fetchedAt,
        );
      }
      return HealthMetric(
        kind: k,
        availability: HealthAvailability.available,
        value: v,
        unit: unit,
        start: s.toUtc().toIso8601String(),
        end: e.toUtc().toIso8601String(),
        sources: a.sources,
        updatedAt: fetchedAt,
      );
    }

    // Resting heart rate: today's average, else the latest reading in
    // the look-back with its own time (so "last recorded" is honest).
    HealthMetric rhr = total(
      HealthMetricKind.restingHeartRate,
      'bpm',
      rhrToday,
      cal.dayStart,
      cal.dayEnd,
    );
    if (rhr.availability == HealthAvailability.noData) {
      rhr = await _latest(
        HealthMetricKind.restingHeartRate,
        'bpm',
        cal,
        fetchedAt,
      );
    }

    final weight = granted.contains(HealthMetricKind.weight)
        ? await _latest(HealthMetricKind.weight, 'kg', cal, fetchedAt)
        : HealthMetric.unavailable(
            HealthMetricKind.weight,
            HealthAvailability.permissionDenied,
            unit: 'kg',
            updatedAt: fetchedAt,
          );
    final bodyFat = granted.contains(HealthMetricKind.bodyFat)
        ? await _latest(HealthMetricKind.bodyFat, '%', cal, fetchedAt)
        : HealthMetric.unavailable(
            HealthMetricKind.bodyFat,
            HealthAvailability.permissionDenied,
            unit: '%',
            updatedAt: fetchedAt,
          );
    final bmr = granted.contains(HealthMetricKind.bmr)
        ? await _latest(HealthMetricKind.bmr, 'kcal/day', cal, fetchedAt)
        : HealthMetric.unavailable(
            HealthMetricKind.bmr,
            HealthAvailability.permissionDenied,
            unit: 'kcal/day',
            updatedAt: fetchedAt,
          );

    // Exercise sessions today, from any app.
    var exerciseAvailability = HealthAvailability.permissionDenied;
    var sessions = const <HealthExerciseSession>[];
    if (granted.contains(HealthMetricKind.exercise)) {
      try {
        final rows = await _channel.exerciseSessions(
          start: cal.dayStart,
          end: cal.dayEnd,
        );
        sessions = [
          for (final r in rows)
            HealthExerciseSession(
              start: DateTime.fromMillisecondsSinceEpoch(
                (r['start']! as num).toInt(),
                isUtc: true,
              ).toIso8601String(),
              end: DateTime.fromMillisecondsSinceEpoch(
                (r['end']! as num).toInt(),
                isUtc: true,
              ).toIso8601String(),
              type: (r['type'] as num?)?.toInt() ?? 0,
              title: r['title'] as String?,
              source: (r['source'] as String?) ?? '',
            ),
        ];
        exerciseAvailability = sessions.isEmpty
            ? HealthAvailability.noData
            : HealthAvailability.available;
      } on HealthChannelException catch (e) {
        exerciseAvailability = _failure(e);
      }
    }

    // This week, per local day (Monday first): steps and last-night sleep.
    final weekSteps = <double?>[];
    final weekSleep = <double?>[];
    for (var i = 0; i < 7; i++) {
      final d = cal.weekDay(i);
      if (granted.contains(HealthMetricKind.steps)) {
        final a = await _aggregate(
          d.dayStart,
          d.dayEnd,
          const [HealthMetricKind.steps],
        );
        weekSteps.add(a.values['steps']);
      } else {
        weekSteps.add(null);
      }
      if (granted.contains(HealthMetricKind.sleep)) {
        final a = await _aggregate(
          d.nightStart,
          d.nightEnd,
          const [HealthMetricKind.sleep],
        );
        weekSleep.add(a.values['sleep']);
      } else {
        weekSleep.add(null);
      }
    }

    return HealthSnapshot(
      date: date,
      timezone: timezone,
      steps:
          total(HealthMetricKind.steps, 'steps', day, cal.dayStart, cal.dayEnd),
      distance:
          total(HealthMetricKind.distance, 'm', day, cal.dayStart, cal.dayEnd),
      activeCalories: total(
        HealthMetricKind.activeCalories,
        'kcal',
        day,
        cal.dayStart,
        cal.dayEnd,
      ),
      totalCalories: total(
        HealthMetricKind.totalCalories,
        'kcal',
        day,
        cal.dayStart,
        cal.dayEnd,
      ),
      sleep: total(
        HealthMetricKind.sleep,
        'min',
        night,
        cal.nightStart,
        cal.nightEnd,
      ),
      restingHeartRate: rhr,
      weight: weight,
      bodyFat: bodyFat,
      bmr: bmr,
      exerciseSessions: sessions,
      exerciseAvailability: exerciseAvailability,
      weekSteps: weekSteps,
      weekSleep: weekSleep,
      fetchedAt: fetchedAt,
    );
  }

  static HealthAvailability _failure(HealthChannelException e) =>
      switch (e.code) {
        'permissionDenied' => HealthAvailability.permissionDenied,
        'unavailable' => HealthAvailability.unsupported,
        _ => HealthAvailability.temporarilyUnavailable,
      };

  Future<_Aggregate> _aggregate(
    DateTime start,
    DateTime end,
    List<HealthMetricKind> kinds,
  ) async {
    if (kinds.isEmpty) return const _Aggregate.none();
    try {
      final r = await _channel.aggregate(
        start: start,
        end: end,
        metrics: kinds.map((k) => k.wire).toList(),
      );
      final values = <String, double>{};
      for (final k in kinds) {
        final v = r[k.wire];
        if (v is num) values[k.wire] = v.toDouble();
      }
      final sources =
          (r['sources'] as List<Object?>?)?.cast<String>() ?? const <String>[];
      return _Aggregate(values: values, sources: sources);
    } on HealthChannelException catch (e) {
      return _Aggregate(
        values: const {},
        sources: const [],
        failure: _failure(e),
      );
    }
  }

  Future<HealthMetric> _latest(
    HealthMetricKind k,
    String unit,
    _Calendar cal,
    String fetchedAt,
  ) async {
    try {
      final r = await _channel.latest(
        type: k.wire,
        start: cal.dayEnd.subtract(lookback),
        end: cal.dayEnd,
      );
      if (r == null || r['value'] is! num) {
        return HealthMetric.unavailable(
          k,
          HealthAvailability.noData,
          unit: unit,
          updatedAt: fetchedAt,
        );
      }
      final at = DateTime.fromMillisecondsSinceEpoch(
        (r['time']! as num).toInt(),
        isUtc: true,
      ).toIso8601String();
      return HealthMetric(
        kind: k,
        availability: HealthAvailability.available,
        value: (r['value']! as num).toDouble(),
        unit: unit,
        start: at,
        end: at,
        sources: [if (r['source'] is String) r['source']! as String],
        updatedAt: fetchedAt,
      );
    } on HealthChannelException catch (e) {
      return HealthMetric.unavailable(
        k,
        _failure(e),
        unit: unit,
        updatedAt: fetchedAt,
      );
    }
  }
}

class _Aggregate {
  const _Aggregate({required this.values, required this.sources, this.failure});
  const _Aggregate.none()
      : values = const {},
        sources = const [],
        failure = null;
  final Map<String, double> values;
  final List<String> sources;
  final HealthAvailability? failure;
}

/// Explicit local-calendar ranges for one date in one zone.
class _Calendar {
  _Calendar(String timezone, String date)
      : location = tz.getLocation(timezone),
        y = int.parse(date.substring(0, 4)),
        m = int.parse(date.substring(5, 7)),
        d = int.parse(date.substring(8, 10));

  final tz.Location location;
  final int y;
  final int m;
  final int d;

  tz.TZDateTime _at(int dayOffset, int hour) =>
      tz.TZDateTime(location, y, m, d + dayOffset, hour);

  DateTime get dayStart => _at(0, 0);
  DateTime get dayEnd => _at(1, 0);
  DateTime get nightStart => _at(-1, HealthConnectProvider.nightStartHour);
  DateTime get nightEnd => _at(0, HealthConnectProvider.nightEndHour);

  /// The i-th day (0 = Monday) of this date's local week.
  _Calendar weekDay(int i) {
    final monday = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final day =
        tz.TZDateTime(location, monday.year, monday.month, monday.day + i);
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return _Calendar(location.name, '${day.year}-$mm-$dd');
  }
}
