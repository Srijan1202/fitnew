import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/health/domain/health_data_provider.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:riverpod/misc.dart' show Override;

/// A scripted [HealthDataProvider] for widget tests: the connection and
/// the snapshot are whatever the test sets; permission requests grant
/// what `grantOnRequest` says.
class FakeHealthProvider implements HealthDataProvider {
  FakeHealthProvider({
    HealthConnectionState? connection,
    HealthSnapshot? snapshot,
  })  : connection_ = connection ?? HealthConnectionState.disconnected,
        snapshot_ = snapshot;

  HealthConnectionState connection_;
  HealthSnapshot? snapshot_;
  Set<HealthMetricKind> grantOnRequest = {};
  final calls = <String>[];

  static const fetchedAt = '2026-09-22T06:00:00.000Z';

  @override
  Future<HealthConnectionState> connection() async {
    calls.add('connection');
    return connection_;
  }

  @override
  Future<HealthConnectionState> requestPermissions(
    Set<HealthMetricKind> kinds,
  ) async {
    calls.add('request:${kinds.map((k) => k.wire).join(',')}');
    connection_ = HealthConnectionState(
      sdk: connection_.sdk,
      granted: {...connection_.granted, ...kinds.intersection(grantOnRequest)},
    );
    return connection_;
  }

  @override
  Future<HealthSnapshot> snapshot({
    required String date,
    required String timezone,
  }) async {
    calls.add('snapshot:$date');
    return snapshot_ ??
        HealthSnapshot.empty(
          date: date,
          timezone: timezone,
          availability: connection_.sdk == HealthSdkStatus.available
              ? (connection_.granted.isEmpty
                  ? HealthAvailability.notConnected
                  : HealthAvailability.noData)
              : HealthAvailability.unsupported,
          fetchedAt: fetchedAt,
        );
  }

  @override
  Future<bool> openSettings() async {
    calls.add('openSettings');
    return true;
  }
}

/// A metric with a value, for scripting snapshots.
HealthMetric metricOf(
  HealthMetricKind k,
  double value, {
  String unit = '',
  String? at,
}) =>
    HealthMetric(
      kind: k,
      availability: HealthAvailability.available,
      value: value,
      unit: unit,
      start: at,
      end: at,
      updatedAt: FakeHealthProvider.fetchedAt,
    );

List<Override> healthOverrides(FakeHealthProvider provider) => [
      healthDataProviderProvider.overrideWithValue(provider),
    ];
