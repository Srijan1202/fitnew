// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannedExercise _$PlannedExerciseFromJson(Map<String, dynamic> json) =>
    _PlannedExercise(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
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
      orderIndex: (json['orderIndex'] as num).toInt(),
      setCount: (json['setCount'] as num).toInt(),
      repMin: (json['repMin'] as num).toInt(),
      repMax: (json['repMax'] as num).toInt(),
      targetRir: (json['targetRir'] as num).toInt(),
      incrementKg: (json['incrementKg'] as num).toDouble(),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$PlannedExerciseToJson(_PlannedExercise instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exerciseId': instance.exerciseId,
      'slug': instance.slug,
      'name': instance.name,
      'movementPattern': _$MovementPatternEnumMap[instance.movementPattern]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'isUnilateral': instance.isUnilateral,
      'primaryMuscles':
          instance.primaryMuscles.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'orderIndex': instance.orderIndex,
      'setCount': instance.setCount,
      'repMin': instance.repMin,
      'repMax': instance.repMax,
      'targetRir': instance.targetRir,
      'incrementKg': instance.incrementKg,
      'reason': instance.reason,
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

_ProgramDay _$ProgramDayFromJson(Map<String, dynamic> json) => _ProgramDay(
      id: json['id'] as String,
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      sessionName: json['sessionName'] as String,
      focus: (json['focus'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      isRest: json['isRest'] as bool,
      estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProgramDayToJson(_ProgramDay instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dayOfWeek': instance.dayOfWeek,
      'sessionName': instance.sessionName,
      'focus': instance.focus.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'isRest': instance.isRest,
      'estimatedMinutes': instance.estimatedMinutes,
      'exercises': instance.exercises,
    };

_VolumeShortfall _$VolumeShortfallFromJson(Map<String, dynamic> json) =>
    _VolumeShortfall(
      muscle: $enumDecode(_$MuscleGroupEnumMap, json['muscle']),
      targetSets: (json['targetSets'] as num).toDouble(),
      plannedSets: (json['plannedSets'] as num).toDouble(),
      reason: $enumDecode(_$ShortfallReasonEnumMap, json['reason']),
      detail: json['detail'] as String,
    );

Map<String, dynamic> _$VolumeShortfallToJson(_VolumeShortfall instance) =>
    <String, dynamic>{
      'muscle': _$MuscleGroupEnumMap[instance.muscle]!,
      'targetSets': instance.targetSets,
      'plannedSets': instance.plannedSets,
      'reason': _$ShortfallReasonEnumMap[instance.reason]!,
      'detail': instance.detail,
    };

const _$ShortfallReasonEnumMap = {
  ShortfallReason.noPerformableExercise: 'no-performable-exercise',
  ShortfallReason.sessionTime: 'session-time',
  ShortfallReason.limitation: 'limitation',
};

_Program _$ProgramFromJson(Map<String, dynamic> json) => _Program(
      id: json['id'] as String,
      name: json['name'] as String,
      splitType: $enumDecode(_$SplitTypeEnumMap, json['splitType']),
      daysPerWeek: (json['daysPerWeek'] as num).toInt(),
      source: $enumDecode(_$ProgramSourceEnumMap, json['source']),
      mesocycleWeek: (json['mesocycleWeek'] as num).toInt(),
      active: json['active'] as bool,
      createdAt: json['createdAt'] as String,
      days: (json['days'] as List<dynamic>)
          .map((e) => ProgramDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      weeklyVolume: (json['weeklyVolume'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      rationale:
          (json['rationale'] as List<dynamic>).map((e) => e as String).toList(),
      shortfalls: (json['shortfalls'] as List<dynamic>)
          .map((e) => VolumeShortfall.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProgramToJson(_Program instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'splitType': _$SplitTypeEnumMap[instance.splitType]!,
      'daysPerWeek': instance.daysPerWeek,
      'source': _$ProgramSourceEnumMap[instance.source]!,
      'mesocycleWeek': instance.mesocycleWeek,
      'active': instance.active,
      'createdAt': instance.createdAt,
      'days': instance.days,
      'weeklyVolume': instance.weeklyVolume,
      'rationale': instance.rationale,
      'shortfalls': instance.shortfalls,
    };

const _$SplitTypeEnumMap = {
  SplitType.fullBody: 'full-body',
  SplitType.upperLower: 'upper-lower',
  SplitType.pushPullLegs: 'push-pull-legs',
  SplitType.upperLowerFull: 'upper-lower-full',
  SplitType.pplUpperLower: 'ppl-upper-lower',
  SplitType.custom: 'custom',
};

const _$ProgramSourceEnumMap = {
  ProgramSource.generated: 'generated',
  ProgramSource.custom: 'custom',
};

_GenerateProgramRequest _$GenerateProgramRequestFromJson(
        Map<String, dynamic> json) =>
    _GenerateProgramRequest(
      daysPerWeek: (json['daysPerWeek'] as num?)?.toInt(),
      preferredSessionMinutes:
          (json['preferredSessionMinutes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GenerateProgramRequestToJson(
        _GenerateProgramRequest instance) =>
    <String, dynamic>{
      'daysPerWeek': instance.daysPerWeek,
      'preferredSessionMinutes': instance.preferredSessionMinutes,
    };

_CustomExercise _$CustomExerciseFromJson(Map<String, dynamic> json) =>
    _CustomExercise(
      exerciseId: json['exerciseId'] as String,
      setCount: (json['setCount'] as num).toInt(),
      repMin: (json['repMin'] as num).toInt(),
      repMax: (json['repMax'] as num).toInt(),
      targetRir: (json['targetRir'] as num).toInt(),
      incrementKg: (json['incrementKg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$CustomExerciseToJson(_CustomExercise instance) =>
    <String, dynamic>{
      'exerciseId': instance.exerciseId,
      'setCount': instance.setCount,
      'repMin': instance.repMin,
      'repMax': instance.repMax,
      'targetRir': instance.targetRir,
      'incrementKg': instance.incrementKg,
    };

_CustomDay _$CustomDayFromJson(Map<String, dynamic> json) => _CustomDay(
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      sessionName: json['sessionName'] as String,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => CustomExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CustomDayToJson(_CustomDay instance) =>
    <String, dynamic>{
      'dayOfWeek': instance.dayOfWeek,
      'sessionName': instance.sessionName,
      'exercises': instance.exercises,
    };

_PutProgramRequest _$PutProgramRequestFromJson(Map<String, dynamic> json) =>
    _PutProgramRequest(
      name: json['name'] as String,
      days: (json['days'] as List<dynamic>)
          .map((e) => CustomDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PutProgramRequestToJson(_PutProgramRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'days': instance.days,
    };

_PatchProgramDayRequest _$PatchProgramDayRequestFromJson(
        Map<String, dynamic> json) =>
    _PatchProgramDayRequest(
      sessionName: json['sessionName'] as String?,
      exercises: (json['exercises'] as List<dynamic>?)
          ?.map((e) => CustomExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PatchProgramDayRequestToJson(
        _PatchProgramDayRequest instance) =>
    <String, dynamic>{
      'sessionName': instance.sessionName,
      'exercises': instance.exercises,
    };
