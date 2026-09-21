import 'package:freezed_annotation/freezed_annotation.dart';

part 'health.freezed.dart';
part 'health.g.dart';

/// Phase 6.5 — the normalized health model the Home screen and the
/// suggestion engine consume. Nothing here is Health Connect specific: a
/// provider (Health Connect today, HealthKit or another source later)
/// fills it, and every metric states how it came to be — a value, or the
/// honest reason there is none. There is no "0" for missing data.

/// Why a metric has, or does not have, a value.
enum HealthAvailability {
  /// A value from the provider, for the stated range.
  @JsonValue('available')
  available,

  /// The provider is not connected (no permission has ever been granted).
  @JsonValue('not_connected')
  notConnected,

  /// The permission for this metric is missing or was revoked.
  @JsonValue('permission_denied')
  permissionDenied,

  /// Permission is granted; the provider had nothing in the range.
  @JsonValue('no_data')
  noData,

  /// The provider errored or timed out; try again later.
  @JsonValue('temporarily_unavailable')
  temporarilyUnavailable,

  /// The device or provider cannot supply this metric at all.
  @JsonValue('unsupported')
  unsupported,
}

/// The ten metrics FITOS reads, grouped as the permission screen shows
/// them (owner: Activity / Recovery / Body).
enum HealthMetricKind {
  @JsonValue('steps')
  steps('steps', HealthCategory.activity, 'Steps'),
  @JsonValue('distance')
  distance('distance', HealthCategory.activity, 'Distance'),
  @JsonValue('activeCalories')
  activeCalories('activeCalories', HealthCategory.activity, 'Active calories'),
  @JsonValue('totalCalories')
  totalCalories('totalCalories', HealthCategory.activity, 'Total calories'),
  @JsonValue('exercise')
  exercise('exercise', HealthCategory.activity, 'Exercise sessions'),
  @JsonValue('sleep')
  sleep('sleep', HealthCategory.recovery, 'Sleep'),
  @JsonValue('restingHeartRate')
  restingHeartRate(
    'restingHeartRate',
    HealthCategory.recovery,
    'Resting heart rate',
  ),
  @JsonValue('weight')
  weight('weight', HealthCategory.body, 'Weight'),
  @JsonValue('bodyFat')
  bodyFat('bodyFat', HealthCategory.body, 'Body fat'),
  @JsonValue('bmr')
  bmr('bmr', HealthCategory.body, 'Basal metabolic rate');

  const HealthMetricKind(this.wire, this.category, this.label);

  /// The key the platform channel uses.
  final String wire;
  final HealthCategory category;
  final String label;

  static List<HealthMetricKind> inCategory(HealthCategory c) =>
      values.where((k) => k.category == c).toList();
}

enum HealthCategory {
  activity('Activity'),
  recovery('Recovery'),
  body('Body');

  const HealthCategory(this.label);
  final String label;
}

/// Whether the provider itself can be used on this device.
enum HealthSdkStatus {
  available,

  /// Installed but must be updated before it can be used (Android 9–13 APK).
  updateRequired,

  /// Not on this device at all.
  unavailable,
}

/// One number with its provenance. `start`/`end` bound the range it
/// describes (a day for a total, an instant for a measurement).
@freezed
abstract class HealthMetric with _$HealthMetric {
  const HealthMetric._();

  const factory HealthMetric({
    required HealthMetricKind kind,
    required HealthAvailability availability,
    required double? value,
    required String unit,
    required String? start,
    required String? end,

    /// Provider package names that contributed (internal; never on the
    /// primary UI).
    @Default(<String>[]) List<String> sources,

    /// When the provider was asked (ISO-8601 UTC).
    required String? updatedAt,
  }) = _HealthMetric;

  factory HealthMetric.fromJson(Map<String, dynamic> json) =>
      _$HealthMetricFromJson(json);

  factory HealthMetric.unavailable(
    HealthMetricKind kind,
    HealthAvailability availability, {
    String unit = '',
    String? updatedAt,
  }) =>
      HealthMetric(
        kind: kind,
        availability: availability,
        value: null,
        unit: unit,
        start: null,
        end: null,
        updatedAt: updatedAt,
      );

  bool get isAvailable =>
      availability == HealthAvailability.available && value != null;
}

/// One exercise session the provider knows about (from any app).
@freezed
abstract class HealthExerciseSession with _$HealthExerciseSession {
  const factory HealthExerciseSession({
    required String start,
    required String end,

    /// Health Connect's exercise type code; kept for later mapping.
    required int type,
    required String? title,
    required String source,
  }) = _HealthExerciseSession;

  factory HealthExerciseSession.fromJson(Map<String, dynamic> json) =>
      _$HealthExerciseSessionFromJson(json);
}

/// One local calendar day of health context: today's totals, last
/// night's sleep, the latest measurements. `fetchedAt` is when the
/// provider answered; `fromCache` marks an answer read back from the
/// phone's store rather than the provider — the UI says so.
@freezed
abstract class HealthSnapshot with _$HealthSnapshot {
  const HealthSnapshot._();

  const factory HealthSnapshot({
    /// Local date yyyy-mm-dd in the user's calendar.
    required String date,
    required String timezone,
    required HealthMetric steps,
    required HealthMetric distance,
    required HealthMetric activeCalories,
    required HealthMetric totalCalories,
    required HealthMetric sleep,
    required HealthMetric restingHeartRate,
    required HealthMetric weight,
    required HealthMetric bodyFat,
    required HealthMetric bmr,
    @Default(<HealthExerciseSession>[])
    List<HealthExerciseSession> exerciseSessions,

    /// Exercise-session availability (the list alone cannot say "denied").
    required HealthAvailability exerciseAvailability,

    /// Steps per local day for the current week, Monday first; null = no
    /// data or not permitted that day.
    @Default(<double?>[]) List<double?> weekSteps,

    /// Sleep minutes per local night for the current week, Monday first.
    @Default(<double?>[]) List<double?> weekSleep,
    required String fetchedAt,
    @Default(false) bool fromCache,
  }) = _HealthSnapshot;

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) =>
      _$HealthSnapshotFromJson(json);

  /// Every metric, for iteration.
  List<HealthMetric> get metrics => [
        steps,
        distance,
        activeCalories,
        totalCalories,
        sleep,
        restingHeartRate,
        weight,
        bodyFat,
        bmr,
      ];

  HealthMetric metric(HealthMetricKind k) => switch (k) {
        HealthMetricKind.steps => steps,
        HealthMetricKind.distance => distance,
        HealthMetricKind.activeCalories => activeCalories,
        HealthMetricKind.totalCalories => totalCalories,
        HealthMetricKind.sleep => sleep,
        HealthMetricKind.restingHeartRate => restingHeartRate,
        HealthMetricKind.weight => weight,
        HealthMetricKind.bodyFat => bodyFat,
        HealthMetricKind.bmr => bmr,
        HealthMetricKind.exercise => HealthMetric(
            kind: HealthMetricKind.exercise,
            availability: exerciseAvailability,
            value: exerciseSessions.length.toDouble(),
            unit: 'sessions',
            start: null,
            end: null,
            updatedAt: fetchedAt,
          ),
      };

  /// A snapshot for a provider that cannot be used at all, or is not
  /// connected: every metric carries the same reason.
  factory HealthSnapshot.empty({
    required String date,
    required String timezone,
    required HealthAvailability availability,
    required String fetchedAt,
  }) {
    HealthMetric m(HealthMetricKind k, String unit) => HealthMetric.unavailable(
          k,
          availability,
          unit: unit,
          updatedAt: fetchedAt,
        );
    return HealthSnapshot(
      date: date,
      timezone: timezone,
      steps: m(HealthMetricKind.steps, 'steps'),
      distance: m(HealthMetricKind.distance, 'm'),
      activeCalories: m(HealthMetricKind.activeCalories, 'kcal'),
      totalCalories: m(HealthMetricKind.totalCalories, 'kcal'),
      sleep: m(HealthMetricKind.sleep, 'min'),
      restingHeartRate: m(HealthMetricKind.restingHeartRate, 'bpm'),
      weight: m(HealthMetricKind.weight, 'kg'),
      bodyFat: m(HealthMetricKind.bodyFat, '%'),
      bmr: m(HealthMetricKind.bmr, 'kcal/day'),
      exerciseAvailability: availability,
      fetchedAt: fetchedAt,
    );
  }
}

/// The provider's connection, per category, as the Health Data screen
/// shows it.
@freezed
abstract class HealthConnectionState with _$HealthConnectionState {
  const HealthConnectionState._();

  const factory HealthConnectionState({
    required HealthSdkStatus sdk,

    /// Metrics whose read permission is granted right now.
    required Set<HealthMetricKind> granted,
  }) = _HealthConnectionState;

  bool get isConnected =>
      sdk == HealthSdkStatus.available && granted.isNotEmpty;

  /// All / some / none of a category's permissions.
  CategoryGrant categoryGrant(HealthCategory c) {
    final kinds = HealthMetricKind.inCategory(c);
    final n = kinds.where(granted.contains).length;
    if (n == 0) return CategoryGrant.none;
    return n == kinds.length ? CategoryGrant.all : CategoryGrant.partial;
  }

  static const disconnected = HealthConnectionState(
    sdk: HealthSdkStatus.unavailable,
    granted: <HealthMetricKind>{},
  );
}

enum CategoryGrant { none, partial, all }
