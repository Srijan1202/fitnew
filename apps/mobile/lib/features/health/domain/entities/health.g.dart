// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthMetric _$HealthMetricFromJson(Map<String, dynamic> json) =>
    _HealthMetric(
      kind: $enumDecode(_$HealthMetricKindEnumMap, json['kind']),
      availability:
          $enumDecode(_$HealthAvailabilityEnumMap, json['availability']),
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] as String,
      start: json['start'] as String?,
      end: json['end'] as String?,
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$HealthMetricToJson(_HealthMetric instance) =>
    <String, dynamic>{
      'kind': _$HealthMetricKindEnumMap[instance.kind]!,
      'availability': _$HealthAvailabilityEnumMap[instance.availability]!,
      'value': instance.value,
      'unit': instance.unit,
      'start': instance.start,
      'end': instance.end,
      'sources': instance.sources,
      'updatedAt': instance.updatedAt,
    };

const _$HealthMetricKindEnumMap = {
  HealthMetricKind.steps: 'steps',
  HealthMetricKind.distance: 'distance',
  HealthMetricKind.activeCalories: 'activeCalories',
  HealthMetricKind.totalCalories: 'totalCalories',
  HealthMetricKind.exercise: 'exercise',
  HealthMetricKind.sleep: 'sleep',
  HealthMetricKind.restingHeartRate: 'restingHeartRate',
  HealthMetricKind.weight: 'weight',
  HealthMetricKind.bodyFat: 'bodyFat',
  HealthMetricKind.bmr: 'bmr',
};

const _$HealthAvailabilityEnumMap = {
  HealthAvailability.available: 'available',
  HealthAvailability.notConnected: 'not_connected',
  HealthAvailability.permissionDenied: 'permission_denied',
  HealthAvailability.noData: 'no_data',
  HealthAvailability.temporarilyUnavailable: 'temporarily_unavailable',
  HealthAvailability.unsupported: 'unsupported',
};

_HealthExerciseSession _$HealthExerciseSessionFromJson(
        Map<String, dynamic> json) =>
    _HealthExerciseSession(
      start: json['start'] as String,
      end: json['end'] as String,
      type: (json['type'] as num).toInt(),
      title: json['title'] as String?,
      source: json['source'] as String,
    );

Map<String, dynamic> _$HealthExerciseSessionToJson(
        _HealthExerciseSession instance) =>
    <String, dynamic>{
      'start': instance.start,
      'end': instance.end,
      'type': instance.type,
      'title': instance.title,
      'source': instance.source,
    };

_HealthSnapshot _$HealthSnapshotFromJson(Map<String, dynamic> json) =>
    _HealthSnapshot(
      date: json['date'] as String,
      timezone: json['timezone'] as String,
      steps: HealthMetric.fromJson(json['steps'] as Map<String, dynamic>),
      distance: HealthMetric.fromJson(json['distance'] as Map<String, dynamic>),
      activeCalories:
          HealthMetric.fromJson(json['activeCalories'] as Map<String, dynamic>),
      totalCalories:
          HealthMetric.fromJson(json['totalCalories'] as Map<String, dynamic>),
      sleep: HealthMetric.fromJson(json['sleep'] as Map<String, dynamic>),
      restingHeartRate: HealthMetric.fromJson(
          json['restingHeartRate'] as Map<String, dynamic>),
      weight: HealthMetric.fromJson(json['weight'] as Map<String, dynamic>),
      bodyFat: HealthMetric.fromJson(json['bodyFat'] as Map<String, dynamic>),
      bmr: HealthMetric.fromJson(json['bmr'] as Map<String, dynamic>),
      exerciseSessions: (json['exerciseSessions'] as List<dynamic>?)
              ?.map((e) =>
                  HealthExerciseSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <HealthExerciseSession>[],
      exerciseAvailability: $enumDecode(
          _$HealthAvailabilityEnumMap, json['exerciseAvailability']),
      weekSteps: (json['weekSteps'] as List<dynamic>?)
              ?.map((e) => (e as num?)?.toDouble())
              .toList() ??
          const <double?>[],
      weekSleep: (json['weekSleep'] as List<dynamic>?)
              ?.map((e) => (e as num?)?.toDouble())
              .toList() ??
          const <double?>[],
      fetchedAt: json['fetchedAt'] as String,
      fromCache: json['fromCache'] as bool? ?? false,
    );

Map<String, dynamic> _$HealthSnapshotToJson(_HealthSnapshot instance) =>
    <String, dynamic>{
      'date': instance.date,
      'timezone': instance.timezone,
      'steps': instance.steps,
      'distance': instance.distance,
      'activeCalories': instance.activeCalories,
      'totalCalories': instance.totalCalories,
      'sleep': instance.sleep,
      'restingHeartRate': instance.restingHeartRate,
      'weight': instance.weight,
      'bodyFat': instance.bodyFat,
      'bmr': instance.bmr,
      'exerciseSessions': instance.exerciseSessions,
      'exerciseAvailability':
          _$HealthAvailabilityEnumMap[instance.exerciseAvailability]!,
      'weekSteps': instance.weekSteps,
      'weekSleep': instance.weekSleep,
      'fetchedAt': instance.fetchedAt,
      'fromCache': instance.fromCache,
    };
