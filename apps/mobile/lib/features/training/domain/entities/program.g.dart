// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannedSet _$PlannedSetFromJson(Map<String, dynamic> json) => _PlannedSet(
      setIndex: (json['setIndex'] as num).toInt(),
      repsMin: (json['repsMin'] as num).toInt(),
      repsMax: (json['repsMax'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      rir: (json['rir'] as num).toInt(),
    );

Map<String, dynamic> _$PlannedSetToJson(_PlannedSet instance) =>
    <String, dynamic>{
      'setIndex': instance.setIndex,
      'repsMin': instance.repsMin,
      'repsMax': instance.repsMax,
      'weightKg': instance.weightKg,
      'rir': instance.rir,
    };

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
      sets: (json['sets'] as List<dynamic>)
          .map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      'sets': instance.sets,
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
      templateSlug: json['templateSlug'] as String?,
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
      'templateSlug': instance.templateSlug,
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
  SplitType.broSplit: 'bro-split',
  SplitType.upperLower6: 'upper-lower-6',
  SplitType.fullBody2: 'full-body-2',
  SplitType.pushPull: 'push-pull',
  SplitType.twoMuscle: 'two-muscle',
  SplitType.bodybuilding5: 'bodybuilding-5',
  SplitType.fullBody3: 'full-body-3',
  SplitType.upperLower4: 'upper-lower-4',
  SplitType.pushPullLegs6: 'push-pull-legs-6',
  SplitType.custom: 'custom',
};

const _$ProgramSourceEnumMap = {
  ProgramSource.generated: 'generated',
  ProgramSource.template: 'template',
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

_CustomSet _$CustomSetFromJson(Map<String, dynamic> json) => _CustomSet(
      repsMin: (json['repsMin'] as num).toInt(),
      repsMax: (json['repsMax'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      rir: (json['rir'] as num).toInt(),
    );

Map<String, dynamic> _$CustomSetToJson(_CustomSet instance) =>
    <String, dynamic>{
      'repsMin': instance.repsMin,
      'repsMax': instance.repsMax,
      'weightKg': instance.weightKg,
      'rir': instance.rir,
    };

_CustomExercise _$CustomExerciseFromJson(Map<String, dynamic> json) =>
    _CustomExercise(
      id: json['id'] as String?,
      exerciseId: json['exerciseId'] as String,
      setCount: (json['setCount'] as num).toInt(),
      repMin: (json['repMin'] as num).toInt(),
      repMax: (json['repMax'] as num).toInt(),
      targetRir: (json['targetRir'] as num).toInt(),
      incrementKg: (json['incrementKg'] as num?)?.toDouble(),
      startingWeightKg: (json['startingWeightKg'] as num?)?.toDouble(),
      sets: (json['sets'] as List<dynamic>?)
          ?.map((e) => CustomSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CustomExerciseToJson(_CustomExercise instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exerciseId': instance.exerciseId,
      'setCount': instance.setCount,
      'repMin': instance.repMin,
      'repMax': instance.repMax,
      'targetRir': instance.targetRir,
      'incrementKg': instance.incrementKg,
      'startingWeightKg': instance.startingWeightKg,
      'sets': instance.sets,
    };

_CustomDay _$CustomDayFromJson(Map<String, dynamic> json) => _CustomDay(
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      sessionName: json['sessionName'] as String,
      focus: (json['focus'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => CustomExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CustomDayToJson(_CustomDay instance) =>
    <String, dynamic>{
      'dayOfWeek': instance.dayOfWeek,
      'sessionName': instance.sessionName,
      'focus': instance.focus?.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
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
      focus: (json['focus'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      exercises: (json['exercises'] as List<dynamic>?)
          ?.map((e) => CustomExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PatchProgramDayRequestToJson(
        _PatchProgramDayRequest instance) =>
    <String, dynamic>{
      'sessionName': instance.sessionName,
      'focus': instance.focus?.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'exercises': instance.exercises,
    };

_TemplateDay _$TemplateDayFromJson(Map<String, dynamic> json) => _TemplateDay(
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      sessionName: json['sessionName'] as String,
      muscles: (json['muscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$TemplateDayToJson(_TemplateDay instance) =>
    <String, dynamic>{
      'dayOfWeek': instance.dayOfWeek,
      'sessionName': instance.sessionName,
      'muscles': instance.muscles.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
    };

_ProgramTemplate _$ProgramTemplateFromJson(Map<String, dynamic> json) =>
    _ProgramTemplate(
      slug: json['slug'] as String,
      name: json['name'] as String,
      daysPerWeek: (json['daysPerWeek'] as num).toInt(),
      level: $enumDecode(_$TemplateLevelEnumMap, json['level']),
      approxMinutes: (json['approxMinutes'] as num).toInt(),
      summary: json['summary'] as String,
      days: (json['days'] as List<dynamic>)
          .map((e) => TemplateDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProgramTemplateToJson(_ProgramTemplate instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'name': instance.name,
      'daysPerWeek': instance.daysPerWeek,
      'level': _$TemplateLevelEnumMap[instance.level]!,
      'approxMinutes': instance.approxMinutes,
      'summary': instance.summary,
      'days': instance.days,
    };

const _$TemplateLevelEnumMap = {
  TemplateLevel.beginner: 'beginner',
  TemplateLevel.intermediate: 'intermediate',
  TemplateLevel.advanced: 'advanced',
  TemplateLevel.any: 'any',
};

_PreviewExercise _$PreviewExerciseFromJson(Map<String, dynamic> json) =>
    _PreviewExercise(
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
      sets: (json['sets'] as List<dynamic>)
          .map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PreviewExerciseToJson(_PreviewExercise instance) =>
    <String, dynamic>{
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
      'sets': instance.sets,
    };

_PreviewDay _$PreviewDayFromJson(Map<String, dynamic> json) => _PreviewDay(
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      sessionName: json['sessionName'] as String,
      focus: (json['focus'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      isRest: json['isRest'] as bool,
      estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => PreviewExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PreviewDayToJson(_PreviewDay instance) =>
    <String, dynamic>{
      'dayOfWeek': instance.dayOfWeek,
      'sessionName': instance.sessionName,
      'focus': instance.focus.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'isRest': instance.isRest,
      'estimatedMinutes': instance.estimatedMinutes,
      'exercises': instance.exercises,
    };

_TemplatePreview _$TemplatePreviewFromJson(Map<String, dynamic> json) =>
    _TemplatePreview(
      template:
          ProgramTemplate.fromJson(json['template'] as Map<String, dynamic>),
      days: (json['days'] as List<dynamic>)
          .map((e) => PreviewDay.fromJson(e as Map<String, dynamic>))
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

Map<String, dynamic> _$TemplatePreviewToJson(_TemplatePreview instance) =>
    <String, dynamic>{
      'template': instance.template,
      'days': instance.days,
      'weeklyVolume': instance.weeklyVolume,
      'rationale': instance.rationale,
      'shortfalls': instance.shortfalls,
    };
