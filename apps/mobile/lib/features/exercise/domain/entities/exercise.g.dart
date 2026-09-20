// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExerciseSummary _$ExerciseSummaryFromJson(Map<String, dynamic> json) =>
    _ExerciseSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      movementPattern:
          $enumDecode(_$MovementPatternEnumMap, json['movementPattern']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      isUnilateral: json['isUnilateral'] as bool,
      primaryMuscles: (json['primaryMuscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$ExerciseSummaryToJson(_ExerciseSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'movementPattern': _$MovementPatternEnumMap[instance.movementPattern]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'isUnilateral': instance.isUnilateral,
      'primaryMuscles':
          instance.primaryMuscles.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
    };

const _$MovementPatternEnumMap = {
  MovementPattern.squat: 'squat',
  MovementPattern.hinge: 'hinge',
  MovementPattern.lunge: 'lunge',
  MovementPattern.horizontalPush: 'horizontal-push',
  MovementPattern.verticalPush: 'vertical-push',
  MovementPattern.horizontalPull: 'horizontal-pull',
  MovementPattern.verticalPull: 'vertical-pull',
  MovementPattern.elbowFlexion: 'elbow-flexion',
  MovementPattern.elbowExtension: 'elbow-extension',
  MovementPattern.shoulderIsolation: 'shoulder-isolation',
  MovementPattern.chestIsolation: 'chest-isolation',
  MovementPattern.legIsolation: 'leg-isolation',
  MovementPattern.calfRaise: 'calf-raise',
  MovementPattern.core: 'core',
  MovementPattern.carry: 'carry',
};

const _$EquipmentEnumMap = {
  Equipment.barbell: 'barbell',
  Equipment.dumbbell: 'dumbbell',
  Equipment.machine: 'machine',
  Equipment.cable: 'cable',
  Equipment.kettlebell: 'kettlebell',
  Equipment.resistanceBand: 'resistance-band',
  Equipment.pullUpBar: 'pull-up-bar',
  Equipment.bodyweight: 'bodyweight',
};

const _$DifficultyEnumMap = {
  Difficulty.beginner: 'beginner',
  Difficulty.intermediate: 'intermediate',
  Difficulty.advanced: 'advanced',
};

const _$MuscleGroupEnumMap = {
  MuscleGroup.chest: 'chest',
  MuscleGroup.back: 'back',
  MuscleGroup.quads: 'quads',
  MuscleGroup.hamstrings: 'hamstrings',
  MuscleGroup.glutes: 'glutes',
  MuscleGroup.shoulders: 'shoulders',
  MuscleGroup.biceps: 'biceps',
  MuscleGroup.triceps: 'triceps',
  MuscleGroup.calves: 'calves',
  MuscleGroup.abs: 'abs',
};

_ExerciseMuscle _$ExerciseMuscleFromJson(Map<String, dynamic> json) =>
    _ExerciseMuscle(
      muscleGroup: $enumDecode(_$MuscleGroupEnumMap, json['muscleGroup']),
      role: $enumDecode(_$MuscleRoleEnumMap, json['role']),
      contribution: (json['contribution'] as num).toDouble(),
    );

Map<String, dynamic> _$ExerciseMuscleToJson(_ExerciseMuscle instance) =>
    <String, dynamic>{
      'muscleGroup': _$MuscleGroupEnumMap[instance.muscleGroup]!,
      'role': _$MuscleRoleEnumMap[instance.role]!,
      'contribution': instance.contribution,
    };

const _$MuscleRoleEnumMap = {
  MuscleRole.primary: 'primary',
  MuscleRole.secondary: 'secondary',
};

_ExerciseAlternative _$ExerciseAlternativeFromJson(Map<String, dynamic> json) =>
    _ExerciseAlternative(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      reason: $enumDecode(_$AlternativeReasonEnumMap, json['reason']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$ExerciseAlternativeToJson(
        _ExerciseAlternative instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'reason': _$AlternativeReasonEnumMap[instance.reason]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
    };

const _$AlternativeReasonEnumMap = {
  AlternativeReason.equipment: 'equipment',
  AlternativeReason.injury: 'injury',
  AlternativeReason.preference: 'preference',
};

_ExerciseDetail _$ExerciseDetailFromJson(Map<String, dynamic> json) =>
    _ExerciseDetail(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      movementPattern:
          $enumDecode(_$MovementPatternEnumMap, json['movementPattern']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      isUnilateral: json['isUnilateral'] as bool,
      primaryMuscles: (json['primaryMuscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      defaultIncrementKg: (json['defaultIncrementKg'] as num).toDouble(),
      instructions: (json['instructions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      videoUrl: json['videoUrl'] as String?,
      muscles: (json['muscles'] as List<dynamic>)
          .map((e) => ExerciseMuscle.fromJson(e as Map<String, dynamic>))
          .toList(),
      alternatives: (json['alternatives'] as List<dynamic>)
          .map((e) => ExerciseAlternative.fromJson(e as Map<String, dynamic>))
          .toList(),
      contraindications: (json['contraindications'] as List<dynamic>)
          .map((e) => $enumDecode(_$BodyPartEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$ExerciseDetailToJson(_ExerciseDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'movementPattern': _$MovementPatternEnumMap[instance.movementPattern]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'isUnilateral': instance.isUnilateral,
      'primaryMuscles':
          instance.primaryMuscles.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'defaultIncrementKg': instance.defaultIncrementKg,
      'instructions': instance.instructions,
      'videoUrl': instance.videoUrl,
      'muscles': instance.muscles,
      'alternatives': instance.alternatives,
      'contraindications':
          instance.contraindications.map((e) => _$BodyPartEnumMap[e]!).toList(),
    };

const _$BodyPartEnumMap = {
  BodyPart.neck: 'neck',
  BodyPart.shoulder: 'shoulder',
  BodyPart.elbow: 'elbow',
  BodyPart.wrist: 'wrist',
  BodyPart.lowerBack: 'lower-back',
  BodyPart.hip: 'hip',
  BodyPart.knee: 'knee',
  BodyPart.ankle: 'ankle',
};

_ExerciseListResponse _$ExerciseListResponseFromJson(
        Map<String, dynamic> json) =>
    _ExerciseListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => ExerciseSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
    );

Map<String, dynamic> _$ExerciseListResponseToJson(
        _ExerciseListResponse instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
    };
