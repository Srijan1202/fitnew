import 'entities/health.dart';

/// Phase 6.5 — what FITOS needs from a health data source, independent of
/// which one (Health Connect today). Read only. Every answer is
/// normalized ([HealthSnapshot], [HealthConnectionState]); no provider
/// type crosses this line.
abstract class HealthDataProvider {
  /// Can this provider be used on this device, and what is granted.
  Future<HealthConnectionState> connection();

  /// Ask the user for the given metrics' read permissions (the provider's
  /// own sheet). Answers with the connection afterwards — which may be
  /// unchanged if they declined.
  Future<HealthConnectionState> requestPermissions(Set<HealthMetricKind> kinds);

  /// The local calendar day `date` (yyyy-mm-dd) in `timezone`: today's
  /// totals, last night's sleep, the latest measurements, this week's
  /// per-day steps and sleep. Never throws: a failure is a snapshot whose
  /// metrics say why.
  Future<HealthSnapshot> snapshot({
    required String date,
    required String timezone,
  });

  /// Open the provider's own settings / permission management, if any.
  Future<bool> openSettings();
}

/// The provider for platforms with no health source: honest
/// `unsupported` everywhere, nothing else.
class UnsupportedHealthProvider implements HealthDataProvider {
  const UnsupportedHealthProvider({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  @override
  Future<HealthConnectionState> connection() async =>
      HealthConnectionState.disconnected;

  @override
  Future<HealthConnectionState> requestPermissions(
    Set<HealthMetricKind> kinds,
  ) async =>
      HealthConnectionState.disconnected;

  @override
  Future<HealthSnapshot> snapshot({
    required String date,
    required String timezone,
  }) async =>
      HealthSnapshot.empty(
        date: date,
        timezone: timezone,
        availability: HealthAvailability.unsupported,
        fetchedAt: (_now?.call() ?? DateTime.now()).toUtc().toIso8601String(),
      );

  @override
  Future<bool> openSettings() async => false;
}
