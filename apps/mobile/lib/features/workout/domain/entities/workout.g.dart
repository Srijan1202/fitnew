// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetLog _$SetLogFromJson(Map<String, dynamic> json) => _SetLog(
      id: json['id'] as String,
      clientSetId: json['clientSetId'] as String,
      setIndex: (json['setIndex'] as num).toInt(),
      setType: $enumDecode(_$SetTypeEnumMap, json['setType']),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      reps: (json['reps'] as num).toInt(),
      rir: (json['rir'] as num?)?.toInt(),
      isPr: json['isPr'] as bool,
      loggedAt: json['loggedAt'] as String,
      plannedSetId: json['plannedSetId'] as String?,
    );

Map<String, dynamic> _$SetLogToJson(_SetLog instance) => <String, dynamic>{
      'id': instance.id,
      'clientSetId': instance.clientSetId,
      'setIndex': instance.setIndex,
      'setType': _$SetTypeEnumMap[instance.setType]!,
      'weightKg': instance.weightKg,
      'reps': instance.reps,
      'rir': instance.rir,
      'isPr': instance.isPr,
      'loggedAt': instance.loggedAt,
      'plannedSetId': instance.plannedSetId,
    };

const _$SetTypeEnumMap = {
  SetType.warmup: 'warmup',
  SetType.working: 'working',
  SetType.drop: 'drop',
  SetType.backoff: 'backoff',
};

_LastSet _$LastSetFromJson(Map<String, dynamic> json) => _LastSet(
      setIndex: (json['setIndex'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      reps: (json['reps'] as num).toInt(),
      rir: (json['rir'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LastSetToJson(_LastSet instance) => <String, dynamic>{
      'setIndex': instance.setIndex,
      'weightKg': instance.weightKg,
      'reps': instance.reps,
      'rir': instance.rir,
    };

_LastPerformance _$LastPerformanceFromJson(Map<String, dynamic> json) =>
    _LastPerformance(
      sessionId: json['sessionId'] as String,
      completedAt: json['completedAt'] as String,
      sets: (json['sets'] as List<dynamic>)
          .map((e) => LastSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LastPerformanceToJson(_LastPerformance instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'completedAt': instance.completedAt,
      'sets': instance.sets,
    };

_SetPrefill _$SetPrefillFromJson(Map<String, dynamic> json) => _SetPrefill(
      setIndex: (json['setIndex'] as num).toInt(),
      reps: (json['reps'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      rir: (json['rir'] as num).toInt(),
      weightSource: json['weightSource'] as String,
    );

Map<String, dynamic> _$SetPrefillToJson(_SetPrefill instance) =>
    <String, dynamic>{
      'setIndex': instance.setIndex,
      'reps': instance.reps,
      'weightKg': instance.weightKg,
      'rir': instance.rir,
      'weightSource': instance.weightSource,
    };

_ProgressionRecommendation _$ProgressionRecommendationFromJson(
        Map<String, dynamic> json) =>
    _ProgressionRecommendation(
      action: $enumDecode(_$ProgressionActionEnumMap, json['action']),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      repTarget: json['repTarget'] as String,
      targetRir: (json['targetRir'] as num).toInt(),
      reason: json['reason'] as String,
      basis: json['basis'] as String,
      sessionsConsidered: (json['sessionsConsidered'] as num).toInt(),
    );

Map<String, dynamic> _$ProgressionRecommendationToJson(
        _ProgressionRecommendation instance) =>
    <String, dynamic>{
      'action': _$ProgressionActionEnumMap[instance.action]!,
      'weightKg': instance.weightKg,
      'repTarget': instance.repTarget,
      'targetRir': instance.targetRir,
      'reason': instance.reason,
      'basis': instance.basis,
      'sessionsConsidered': instance.sessionsConsidered,
    };

const _$ProgressionActionEnumMap = {
  ProgressionAction.increaseLoad: 'increase-load',
  ProgressionAction.addReps: 'add-reps',
  ProgressionAction.hold: 'hold',
  ProgressionAction.reduceLoad: 'reduce-load',
  ProgressionAction.deload: 'deload',
  ProgressionAction.establishBaseline: 'establish-baseline',
};

_PriorBest _$PriorBestFromJson(Map<String, dynamic> json) => _PriorBest(
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      repsAtBestWeight: (json['repsAtBestWeight'] as num?)?.toInt(),
      estimated1rm: (json['estimated1rm'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$PriorBestToJson(_PriorBest instance) =>
    <String, dynamic>{
      'weightKg': instance.weightKg,
      'repsAtBestWeight': instance.repsAtBestWeight,
      'estimated1rm': instance.estimated1rm,
    };

_SubstitutionAlternative _$SubstitutionAlternativeFromJson(
        Map<String, dynamic> json) =>
    _SubstitutionAlternative(
      exerciseId: json['exerciseId'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$SubstitutionAlternativeToJson(
        _SubstitutionAlternative instance) =>
    <String, dynamic>{
      'exerciseId': instance.exerciseId,
      'slug': instance.slug,
      'name': instance.name,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
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

_Substitution _$SubstitutionFromJson(Map<String, dynamic> json) =>
    _Substitution(
      trigger: $enumDecode(_$SubstitutionTriggerEnumMap, json['trigger']),
      alternative: json['alternative'] == null
          ? null
          : SubstitutionAlternative.fromJson(
              json['alternative'] as Map<String, dynamic>),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$SubstitutionToJson(_Substitution instance) =>
    <String, dynamic>{
      'trigger': _$SubstitutionTriggerEnumMap[instance.trigger]!,
      'alternative': instance.alternative,
      'reason': instance.reason,
    };

const _$SubstitutionTriggerEnumMap = {
  SubstitutionTrigger.equipment: 'equipment',
  SubstitutionTrigger.limitation: 'limitation',
  SubstitutionTrigger.rejected: 'rejected',
};

_DeloadState _$DeloadStateFromJson(Map<String, dynamic> json) => _DeloadState(
      state: $enumDecode(_$DeloadStatusEnumMap, json['state']),
      trigger: $enumDecodeNullable(_$DeloadTriggerEnumMap, json['trigger']),
      reason: json['reason'] as String,
      endsOn: json['endsOn'] as String?,
    );

Map<String, dynamic> _$DeloadStateToJson(_DeloadState instance) =>
    <String, dynamic>{
      'state': _$DeloadStatusEnumMap[instance.state]!,
      'trigger': _$DeloadTriggerEnumMap[instance.trigger],
      'reason': instance.reason,
      'endsOn': instance.endsOn,
    };

const _$DeloadStatusEnumMap = {
  DeloadStatus.none: 'none',
  DeloadStatus.offered: 'offered',
  DeloadStatus.active: 'active',
};

const _$DeloadTriggerEnumMap = {
  DeloadTrigger.fatigue: 'fatigue',
  DeloadTrigger.mrv: 'mrv',
};

_NeglectedMuscle _$NeglectedMuscleFromJson(Map<String, dynamic> json) =>
    _NeglectedMuscle(
      muscle: $enumDecode(_$MuscleGroupEnumMap, json['muscle']),
      daysSince: (json['daysSince'] as num?)?.toInt(),
    );

Map<String, dynamic> _$NeglectedMuscleToJson(_NeglectedMuscle instance) =>
    <String, dynamic>{
      'muscle': _$MuscleGroupEnumMap[instance.muscle]!,
      'daysSince': instance.daysSince,
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

_SessionExercise _$SessionExerciseFromJson(Map<String, dynamic> json) =>
    _SessionExercise(
      id: json['id'] as String,
      clientExerciseId: json['clientExerciseId'] as String,
      exerciseId: json['exerciseId'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      movementPattern:
          $enumDecode(_$MovementPatternEnumMap, json['movementPattern']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      primaryMuscles: (json['primaryMuscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      incrementKg: (json['incrementKg'] as num).toDouble(),
      orderIndex: (json['orderIndex'] as num).toInt(),
      supersetGroup: (json['supersetGroup'] as num?)?.toInt(),
      plannedExerciseId: json['plannedExerciseId'] as String?,
      targets: (json['targets'] as List<dynamic>)
          .map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      prefill: (json['prefill'] as List<dynamic>?)
              ?.map((e) => SetPrefill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SetPrefill>[],
      lastPerformance: json['lastPerformance'] == null
          ? null
          : LastPerformance.fromJson(
              json['lastPerformance'] as Map<String, dynamic>),
      recommendation: json['recommendation'] == null
          ? null
          : ProgressionRecommendation.fromJson(
              json['recommendation'] as Map<String, dynamic>),
      priorBest: json['priorBest'] == null
          ? PriorBest.none
          : PriorBest.fromJson(json['priorBest'] as Map<String, dynamic>),
      originalTargets: (json['originalTargets'] as List<dynamic>?)
              ?.map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          null,
      sets: (json['sets'] as List<dynamic>)
          .map((e) => SetLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SessionExerciseToJson(_SessionExercise instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientExerciseId': instance.clientExerciseId,
      'exerciseId': instance.exerciseId,
      'slug': instance.slug,
      'name': instance.name,
      'movementPattern': _$MovementPatternEnumMap[instance.movementPattern]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'primaryMuscles':
          instance.primaryMuscles.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'secondaryMuscles': instance.secondaryMuscles
          .map((e) => _$MuscleGroupEnumMap[e]!)
          .toList(),
      'incrementKg': instance.incrementKg,
      'orderIndex': instance.orderIndex,
      'supersetGroup': instance.supersetGroup,
      'plannedExerciseId': instance.plannedExerciseId,
      'targets': instance.targets,
      'prefill': instance.prefill,
      'lastPerformance': instance.lastPerformance,
      'recommendation': instance.recommendation,
      'priorBest': instance.priorBest,
      'originalTargets': instance.originalTargets,
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

const _$DifficultyEnumMap = {
  Difficulty.beginner: 'beginner',
  Difficulty.intermediate: 'intermediate',
  Difficulty.advanced: 'advanced',
};

_PersonalRecord _$PersonalRecordFromJson(Map<String, dynamic> json) =>
    _PersonalRecord(
      prType: $enumDecode(_$PrTypeEnumMap, json['prType']),
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      value: (json['value'] as num).toDouble(),
      previous: (json['previous'] as num).toDouble(),
      setLogId: json['setLogId'] as String,
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$PersonalRecordToJson(_PersonalRecord instance) =>
    <String, dynamic>{
      'prType': _$PrTypeEnumMap[instance.prType]!,
      'exerciseId': instance.exerciseId,
      'exerciseName': instance.exerciseName,
      'value': instance.value,
      'previous': instance.previous,
      'setLogId': instance.setLogId,
      'reason': instance.reason,
    };

const _$PrTypeEnumMap = {
  PrType.oneRmEst: '1rm_est',
  PrType.weight: 'weight',
  PrType.reps: 'reps',
  PrType.volume: 'volume',
};

_SessionSummary _$SessionSummaryFromJson(Map<String, dynamic> json) =>
    _SessionSummary(
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      totalSets: (json['totalSets'] as num).toInt(),
      workingSets: (json['workingSets'] as num).toInt(),
      tonnageKg: (json['tonnageKg'] as num).toDouble(),
      hardSetsByMuscle: (json['hardSetsByMuscle'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      exercisesCompleted: (json['exercisesCompleted'] as num).toInt(),
      exercisesSkipped: (json['exercisesSkipped'] as num).toInt(),
      prs: (json['prs'] as List<dynamic>)
          .map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SessionSummaryToJson(_SessionSummary instance) =>
    <String, dynamic>{
      'durationSeconds': instance.durationSeconds,
      'totalSets': instance.totalSets,
      'workingSets': instance.workingSets,
      'tonnageKg': instance.tonnageKg,
      'hardSetsByMuscle': instance.hardSetsByMuscle,
      'exercisesCompleted': instance.exercisesCompleted,
      'exercisesSkipped': instance.exercisesSkipped,
      'prs': instance.prs,
    };

_WorkoutSession _$WorkoutSessionFromJson(Map<String, dynamic> json) =>
    _WorkoutSession(
      id: json['id'] as String,
      clientSessionId: json['clientSessionId'] as String,
      status: $enumDecode(_$SessionStatusEnumMap, json['status']),
      programId: json['programId'] as String?,
      programDayId: json['programDayId'] as String?,
      name: json['name'] as String,
      startedAt: json['startedAt'] as String,
      completedAt: json['completedAt'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] == null
          ? null
          : SessionSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WorkoutSessionToJson(_WorkoutSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientSessionId': instance.clientSessionId,
      'status': _$SessionStatusEnumMap[instance.status]!,
      'programId': instance.programId,
      'programDayId': instance.programDayId,
      'name': instance.name,
      'startedAt': instance.startedAt,
      'completedAt': instance.completedAt,
      'durationSeconds': instance.durationSeconds,
      'notes': instance.notes,
      'exercises': instance.exercises,
      'summary': instance.summary,
    };

const _$SessionStatusEnumMap = {
  SessionStatus.active: 'active',
  SessionStatus.completed: 'completed',
  SessionStatus.abandoned: 'abandoned',
};

_SessionListItem _$SessionListItemFromJson(Map<String, dynamic> json) =>
    _SessionListItem(
      id: json['id'] as String,
      status: $enumDecode(_$SessionStatusEnumMap, json['status']),
      name: json['name'] as String,
      startedAt: json['startedAt'] as String,
      completedAt: json['completedAt'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      exerciseCount: (json['exerciseCount'] as num).toInt(),
      workingSets: (json['workingSets'] as num).toInt(),
      tonnageKg: (json['tonnageKg'] as num).toDouble(),
      prCount: (json['prCount'] as num).toInt(),
    );

Map<String, dynamic> _$SessionListItemToJson(_SessionListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$SessionStatusEnumMap[instance.status]!,
      'name': instance.name,
      'startedAt': instance.startedAt,
      'completedAt': instance.completedAt,
      'durationSeconds': instance.durationSeconds,
      'exerciseCount': instance.exerciseCount,
      'workingSets': instance.workingSets,
      'tonnageKg': instance.tonnageKg,
      'prCount': instance.prCount,
    };

_SessionListResponse _$SessionListResponseFromJson(Map<String, dynamic> json) =>
    _SessionListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => SessionListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextBefore: json['nextBefore'] as String?,
    );

Map<String, dynamic> _$SessionListResponseToJson(
        _SessionListResponse instance) =>
    <String, dynamic>{
      'items': instance.items,
      'nextBefore': instance.nextBefore,
    };

_TodayExercise _$TodayExerciseFromJson(Map<String, dynamic> json) =>
    _TodayExercise(
      plannedExerciseId: json['plannedExerciseId'] as String,
      exerciseId: json['exerciseId'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      movementPattern:
          $enumDecode(_$MovementPatternEnumMap, json['movementPattern']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      primaryMuscles: (json['primaryMuscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      orderIndex: (json['orderIndex'] as num).toInt(),
      incrementKg: (json['incrementKg'] as num).toDouble(),
      targets: (json['targets'] as List<dynamic>)
          .map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      prefill: (json['prefill'] as List<dynamic>?)
              ?.map((e) => SetPrefill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SetPrefill>[],
      lastPerformance: json['lastPerformance'] == null
          ? null
          : LastPerformance.fromJson(
              json['lastPerformance'] as Map<String, dynamic>),
      recommendation: json['recommendation'] == null
          ? null
          : ProgressionRecommendation.fromJson(
              json['recommendation'] as Map<String, dynamic>),
      priorBest: json['priorBest'] == null
          ? PriorBest.none
          : PriorBest.fromJson(json['priorBest'] as Map<String, dynamic>),
      originalTargets: (json['originalTargets'] as List<dynamic>?)
              ?.map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          null,
      substitution: json['substitution'] == null
          ? null
          : Substitution.fromJson(json['substitution'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TodayExerciseToJson(_TodayExercise instance) =>
    <String, dynamic>{
      'plannedExerciseId': instance.plannedExerciseId,
      'exerciseId': instance.exerciseId,
      'slug': instance.slug,
      'name': instance.name,
      'movementPattern': _$MovementPatternEnumMap[instance.movementPattern]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'primaryMuscles':
          instance.primaryMuscles.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'secondaryMuscles': instance.secondaryMuscles
          .map((e) => _$MuscleGroupEnumMap[e]!)
          .toList(),
      'orderIndex': instance.orderIndex,
      'incrementKg': instance.incrementKg,
      'targets': instance.targets,
      'prefill': instance.prefill,
      'lastPerformance': instance.lastPerformance,
      'recommendation': instance.recommendation,
      'priorBest': instance.priorBest,
      'originalTargets': instance.originalTargets,
      'substitution': instance.substitution,
    };

_TodayResponse _$TodayResponseFromJson(Map<String, dynamic> json) =>
    _TodayResponse(
      date: json['date'] as String,
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      programId: json['programId'] as String?,
      programDayId: json['programDayId'] as String?,
      sessionName: json['sessionName'] as String?,
      isRest: json['isRest'] as bool,
      focus: (json['focus'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => TodayExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeSession: json['activeSession'] == null
          ? null
          : WorkoutSession.fromJson(
              json['activeSession'] as Map<String, dynamic>),
      completedSessionId: json['completedSessionId'] as String?,
      mesocycleWeek: (json['mesocycleWeek'] as num?)?.toInt() ?? null,
      deload: json['deload'] == null
          ? DeloadState.none
          : DeloadState.fromJson(json['deload'] as Map<String, dynamic>),
      neglected: (json['neglected'] as List<dynamic>?)
              ?.map((e) => NeglectedMuscle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <NeglectedMuscle>[],
    );

Map<String, dynamic> _$TodayResponseToJson(_TodayResponse instance) =>
    <String, dynamic>{
      'date': instance.date,
      'dayOfWeek': instance.dayOfWeek,
      'programId': instance.programId,
      'programDayId': instance.programDayId,
      'sessionName': instance.sessionName,
      'isRest': instance.isRest,
      'focus': instance.focus.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'exercises': instance.exercises,
      'activeSession': instance.activeSession,
      'completedSessionId': instance.completedSessionId,
      'mesocycleWeek': instance.mesocycleWeek,
      'deload': instance.deload,
      'neglected': instance.neglected,
    };

_VolumeLandmarks _$VolumeLandmarksFromJson(Map<String, dynamic> json) =>
    _VolumeLandmarks(
      mv: (json['mv'] as num).toDouble(),
      mev: (json['mev'] as num).toDouble(),
      mavLow: (json['mavLow'] as num).toDouble(),
      mavHigh: (json['mavHigh'] as num).toDouble(),
      mrv: (json['mrv'] as num).toDouble(),
    );

Map<String, dynamic> _$VolumeLandmarksToJson(_VolumeLandmarks instance) =>
    <String, dynamic>{
      'mv': instance.mv,
      'mev': instance.mev,
      'mavLow': instance.mavLow,
      'mavHigh': instance.mavHigh,
      'mrv': instance.mrv,
    };

_MuscleWeek _$MuscleWeekFromJson(Map<String, dynamic> json) => _MuscleWeek(
      muscle: $enumDecode(_$MuscleGroupEnumMap, json['muscle']),
      hardSets: (json['hardSets'] as num).toDouble(),
      tonnageKg: (json['tonnageKg'] as num).toDouble(),
      status: $enumDecode(_$LandmarkStatusEnumMap, json['status']),
      landmarks:
          VolumeLandmarks.fromJson(json['landmarks'] as Map<String, dynamic>),
      owned: json['owned'] as bool,
    );

Map<String, dynamic> _$MuscleWeekToJson(_MuscleWeek instance) =>
    <String, dynamic>{
      'muscle': _$MuscleGroupEnumMap[instance.muscle]!,
      'hardSets': instance.hardSets,
      'tonnageKg': instance.tonnageKg,
      'status': _$LandmarkStatusEnumMap[instance.status]!,
      'landmarks': instance.landmarks,
      'owned': instance.owned,
    };

const _$LandmarkStatusEnumMap = {
  LandmarkStatus.none: 'none',
  LandmarkStatus.belowMv: 'below-mv',
  LandmarkStatus.belowMev: 'below-mev',
  LandmarkStatus.mevToMav: 'mev-to-mav',
  LandmarkStatus.aboveMav: 'above-mav',
  LandmarkStatus.atMrv: 'at-mrv',
};

_VolumeWeek _$VolumeWeekFromJson(Map<String, dynamic> json) => _VolumeWeek(
      isoWeek: json['isoWeek'] as String,
      muscles: (json['muscles'] as List<dynamic>)
          .map((e) => MuscleWeek.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VolumeWeekToJson(_VolumeWeek instance) =>
    <String, dynamic>{
      'isoWeek': instance.isoWeek,
      'muscles': instance.muscles,
    };

_VolumeResponse _$VolumeResponseFromJson(Map<String, dynamic> json) =>
    _VolumeResponse(
      weeks: (json['weeks'] as List<dynamic>)
          .map((e) => VolumeWeek.fromJson(e as Map<String, dynamic>))
          .toList(),
      owned: (json['owned'] as List<dynamic>)
          .map((e) => $enumDecode(_$MuscleGroupEnumMap, e))
          .toList(),
      neglected: (json['neglected'] as List<dynamic>)
          .map((e) => NeglectedMuscle.fromJson(e as Map<String, dynamic>))
          .toList(),
      mesocycleWeek: (json['mesocycleWeek'] as num?)?.toInt(),
      deload: DeloadState.fromJson(json['deload'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$VolumeResponseToJson(_VolumeResponse instance) =>
    <String, dynamic>{
      'weeks': instance.weeks,
      'owned': instance.owned.map((e) => _$MuscleGroupEnumMap[e]!).toList(),
      'neglected': instance.neglected,
      'mesocycleWeek': instance.mesocycleWeek,
      'deload': instance.deload,
    };

_ProgressionTarget _$ProgressionTargetFromJson(Map<String, dynamic> json) =>
    _ProgressionTarget(
      repMin: (json['repMin'] as num).toInt(),
      repMax: (json['repMax'] as num).toInt(),
      targetRir: (json['targetRir'] as num).toInt(),
      sets: (json['sets'] as num).toInt(),
      incrementKg: (json['incrementKg'] as num).toDouble(),
    );

Map<String, dynamic> _$ProgressionTargetToJson(_ProgressionTarget instance) =>
    <String, dynamic>{
      'repMin': instance.repMin,
      'repMax': instance.repMax,
      'targetRir': instance.targetRir,
      'sets': instance.sets,
      'incrementKg': instance.incrementKg,
    };

_ProgressionHistorySet _$ProgressionHistorySetFromJson(
        Map<String, dynamic> json) =>
    _ProgressionHistorySet(
      setIndex: (json['setIndex'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      reps: (json['reps'] as num).toInt(),
      rir: (json['rir'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ProgressionHistorySetToJson(
        _ProgressionHistorySet instance) =>
    <String, dynamic>{
      'setIndex': instance.setIndex,
      'weightKg': instance.weightKg,
      'reps': instance.reps,
      'rir': instance.rir,
    };

_ProgressionHistoryEntry _$ProgressionHistoryEntryFromJson(
        Map<String, dynamic> json) =>
    _ProgressionHistoryEntry(
      sessionId: json['sessionId'] as String,
      date: json['date'] as String,
      sets: (json['sets'] as List<dynamic>)
          .map((e) => ProgressionHistorySet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProgressionHistoryEntryToJson(
        _ProgressionHistoryEntry instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'date': instance.date,
      'sets': instance.sets,
    };

_ProgressionDetail _$ProgressionDetailFromJson(Map<String, dynamic> json) =>
    _ProgressionDetail(
      exerciseId: json['exerciseId'] as String,
      name: json['name'] as String,
      target: json['target'] == null
          ? null
          : ProgressionTarget.fromJson(json['target'] as Map<String, dynamic>),
      recommendation: ProgressionRecommendation.fromJson(
          json['recommendation'] as Map<String, dynamic>),
      history: (json['history'] as List<dynamic>)
          .map((e) =>
              ProgressionHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProgressionDetailToJson(_ProgressionDetail instance) =>
    <String, dynamic>{
      'exerciseId': instance.exerciseId,
      'name': instance.name,
      'target': instance.target,
      'recommendation': instance.recommendation,
      'history': instance.history,
    };

_SeededExercise _$SeededExerciseFromJson(Map<String, dynamic> json) =>
    _SeededExercise(
      clientExerciseId: json['clientExerciseId'] as String,
      exerciseId: json['exerciseId'] as String,
      plannedExerciseId: json['plannedExerciseId'] as String?,
      orderIndex: (json['orderIndex'] as num).toInt(),
    );

Map<String, dynamic> _$SeededExerciseToJson(_SeededExercise instance) =>
    <String, dynamic>{
      'clientExerciseId': instance.clientExerciseId,
      'exerciseId': instance.exerciseId,
      'plannedExerciseId': instance.plannedExerciseId,
      'orderIndex': instance.orderIndex,
    };

_StartSessionRequest _$StartSessionRequestFromJson(Map<String, dynamic> json) =>
    _StartSessionRequest(
      clientSessionId: json['clientSessionId'] as String,
      programDayId: json['programDayId'] as String?,
      startedAt: json['startedAt'] as String,
      exercises: (json['exercises'] as List<dynamic>?)
          ?.map((e) => SeededExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$StartSessionRequestToJson(
        _StartSessionRequest instance) =>
    <String, dynamic>{
      'clientSessionId': instance.clientSessionId,
      'programDayId': instance.programDayId,
      'startedAt': instance.startedAt,
      'exercises': instance.exercises,
    };

_LogSetInput _$LogSetInputFromJson(Map<String, dynamic> json) => _LogSetInput(
      clientSetId: json['clientSetId'] as String,
      clientExerciseId: json['clientExerciseId'] as String,
      setIndex: (json['setIndex'] as num).toInt(),
      setType: $enumDecode(_$SetTypeEnumMap, json['setType']),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      reps: (json['reps'] as num).toInt(),
      rir: (json['rir'] as num?)?.toInt(),
      loggedAt: json['loggedAt'] as String,
      plannedSetId: json['plannedSetId'] as String?,
    );

Map<String, dynamic> _$LogSetInputToJson(_LogSetInput instance) =>
    <String, dynamic>{
      'clientSetId': instance.clientSetId,
      'clientExerciseId': instance.clientExerciseId,
      'setIndex': instance.setIndex,
      'setType': _$SetTypeEnumMap[instance.setType]!,
      'weightKg': instance.weightKg,
      'reps': instance.reps,
      'rir': instance.rir,
      'loggedAt': instance.loggedAt,
      'plannedSetId': instance.plannedSetId,
    };

_LogSetsRequest _$LogSetsRequestFromJson(Map<String, dynamic> json) =>
    _LogSetsRequest(
      sets: (json['sets'] as List<dynamic>)
          .map((e) => LogSetInput.fromJson(e as Map<String, dynamic>))
          .toList(),
      merge: json['merge'] as bool? ?? false,
    );

Map<String, dynamic> _$LogSetsRequestToJson(_LogSetsRequest instance) =>
    <String, dynamic>{
      'sets': instance.sets,
      'merge': instance.merge,
    };

_PatchSetRequest _$PatchSetRequestFromJson(Map<String, dynamic> json) =>
    _PatchSetRequest(
      setType: $enumDecodeNullable(_$SetTypeEnumMap, json['setType']),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      weightCleared: json['weightCleared'] as bool? ?? false,
      reps: (json['reps'] as num?)?.toInt(),
      rir: (json['rir'] as num?)?.toInt(),
      rirCleared: json['rirCleared'] as bool? ?? false,
    );

Map<String, dynamic> _$PatchSetRequestToJson(_PatchSetRequest instance) =>
    <String, dynamic>{
      'setType': _$SetTypeEnumMap[instance.setType],
      'weightKg': instance.weightKg,
      'weightCleared': instance.weightCleared,
      'reps': instance.reps,
      'rir': instance.rir,
      'rirCleared': instance.rirCleared,
    };

_AddSessionExerciseRequest _$AddSessionExerciseRequestFromJson(
        Map<String, dynamic> json) =>
    _AddSessionExerciseRequest(
      clientExerciseId: json['clientExerciseId'] as String,
      exerciseId: json['exerciseId'] as String,
      plannedExerciseId: json['plannedExerciseId'] as String?,
      orderIndex: (json['orderIndex'] as num?)?.toInt(),
      supersetGroup: (json['supersetGroup'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AddSessionExerciseRequestToJson(
        _AddSessionExerciseRequest instance) =>
    <String, dynamic>{
      'clientExerciseId': instance.clientExerciseId,
      'exerciseId': instance.exerciseId,
      'plannedExerciseId': instance.plannedExerciseId,
      'orderIndex': instance.orderIndex,
      'supersetGroup': instance.supersetGroup,
    };

_PatchSessionExerciseRequest _$PatchSessionExerciseRequestFromJson(
        Map<String, dynamic> json) =>
    _PatchSessionExerciseRequest(
      orderIndex: (json['orderIndex'] as num?)?.toInt(),
      supersetGroup: (json['supersetGroup'] as num?)?.toInt(),
      supersetCleared: json['supersetCleared'] as bool? ?? false,
      exerciseId: json['exerciseId'] as String?,
      removed: json['removed'] as bool? ?? false,
    );

Map<String, dynamic> _$PatchSessionExerciseRequestToJson(
        _PatchSessionExerciseRequest instance) =>
    <String, dynamic>{
      'orderIndex': instance.orderIndex,
      'supersetGroup': instance.supersetGroup,
      'supersetCleared': instance.supersetCleared,
      'exerciseId': instance.exerciseId,
      'removed': instance.removed,
    };

_CompleteSessionRequest _$CompleteSessionRequestFromJson(
        Map<String, dynamic> json) =>
    _CompleteSessionRequest(
      completedAt: json['completedAt'] as String,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$CompleteSessionRequestToJson(
        _CompleteSessionRequest instance) =>
    <String, dynamic>{
      'completedAt': instance.completedAt,
      'notes': instance.notes,
    };
