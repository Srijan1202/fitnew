// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConsentGrant _$ConsentGrantFromJson(Map<String, dynamic> json) =>
    _ConsentGrant(
      policyVersion: json['policyVersion'] as String,
      types: (json['types'] as List<dynamic>)
          .map((e) => $enumDecode(_$ConsentTypeEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$ConsentGrantToJson(_ConsentGrant instance) =>
    <String, dynamic>{
      'policyVersion': instance.policyVersion,
      'types': instance.types.map((e) => _$ConsentTypeEnumMap[e]!).toList(),
    };

const _$ConsentTypeEnumMap = {
  ConsentType.privacyPolicy: 'privacy-policy',
  ConsentType.healthDataProcessing: 'health-data-processing',
};

GoalAnswer _$GoalAnswerFromJson(Map<String, dynamic> json) => GoalAnswer(
      goalType: $enumDecode(_$GoalTypeEnumMap, json['goalType']),
      $type: json['step'] as String?,
    );

Map<String, dynamic> _$GoalAnswerToJson(GoalAnswer instance) =>
    <String, dynamic>{
      'goalType': _$GoalTypeEnumMap[instance.goalType]!,
      'step': instance.$type,
    };

const _$GoalTypeEnumMap = {
  GoalType.muscleGain: 'muscle-gain',
  GoalType.fatLoss: 'fat-loss',
  GoalType.recomposition: 'recomposition',
  GoalType.strength: 'strength',
  GoalType.general: 'general',
  GoalType.maintenance: 'maintenance',
};

AboutAnswer _$AboutAnswerFromJson(Map<String, dynamic> json) => AboutAnswer(
      displayName: json['displayName'] as String,
      sex: $enumDecode(_$SexEnumMap, json['sex']),
      birthDate: json['birthDate'] as String,
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      consent: ConsentGrant.fromJson(json['consent'] as Map<String, dynamic>),
      $type: json['step'] as String?,
    );

Map<String, dynamic> _$AboutAnswerToJson(AboutAnswer instance) =>
    <String, dynamic>{
      'displayName': instance.displayName,
      'sex': _$SexEnumMap[instance.sex]!,
      'birthDate': instance.birthDate,
      'heightCm': instance.heightCm,
      'weightKg': instance.weightKg,
      'consent': instance.consent,
      'step': instance.$type,
    };

const _$SexEnumMap = {
  Sex.male: 'male',
  Sex.female: 'female',
};

ExperienceAnswer _$ExperienceAnswerFromJson(Map<String, dynamic> json) =>
    ExperienceAnswer(
      experienceLevel:
          $enumDecode(_$ExperienceLevelEnumMap, json['experienceLevel']),
      trainingDaysPerWeek: (json['trainingDaysPerWeek'] as num).toInt(),
      activityLevel: $enumDecode(_$ActivityLevelEnumMap, json['activityLevel']),
      $type: json['step'] as String?,
    );

Map<String, dynamic> _$ExperienceAnswerToJson(ExperienceAnswer instance) =>
    <String, dynamic>{
      'experienceLevel': _$ExperienceLevelEnumMap[instance.experienceLevel]!,
      'trainingDaysPerWeek': instance.trainingDaysPerWeek,
      'activityLevel': _$ActivityLevelEnumMap[instance.activityLevel]!,
      'step': instance.$type,
    };

const _$ExperienceLevelEnumMap = {
  ExperienceLevel.beginner: 'beginner',
  ExperienceLevel.intermediate: 'intermediate',
  ExperienceLevel.advanced: 'advanced',
};

const _$ActivityLevelEnumMap = {
  ActivityLevel.sedentary: 'sedentary',
  ActivityLevel.light: 'light',
  ActivityLevel.moderate: 'moderate',
  ActivityLevel.high: 'high',
};

TrainingAnswer _$TrainingAnswerFromJson(Map<String, dynamic> json) =>
    TrainingAnswer(
      trainingLocation:
          $enumDecode(_$TrainingLocationEnumMap, json['trainingLocation']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
      $type: json['step'] as String?,
    );

Map<String, dynamic> _$TrainingAnswerToJson(TrainingAnswer instance) =>
    <String, dynamic>{
      'trainingLocation': _$TrainingLocationEnumMap[instance.trainingLocation]!,
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'step': instance.$type,
    };

const _$TrainingLocationEnumMap = {
  TrainingLocation.commercialGym: 'commercial-gym',
  TrainingLocation.campusGym: 'campus-gym',
  TrainingLocation.home: 'home',
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

FoodAnswer _$FoodAnswerFromJson(Map<String, dynamic> json) => FoodAnswer(
      dietType: $enumDecode(_$DietTypeEnumMap, json['dietType']),
      allergies: (json['allergies'] as List<dynamic>)
          .map((e) => Allergy.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['step'] as String?,
    );

Map<String, dynamic> _$FoodAnswerToJson(FoodAnswer instance) =>
    <String, dynamic>{
      'dietType': _$DietTypeEnumMap[instance.dietType]!,
      'allergies': instance.allergies,
      'step': instance.$type,
    };

const _$DietTypeEnumMap = {
  DietType.vegetarian: 'vegetarian',
  DietType.eggetarian: 'eggetarian',
  DietType.nonVegetarian: 'non-vegetarian',
};

VitAnswer _$VitAnswerFromJson(Map<String, dynamic> json) => VitAnswer(
      isVitStudent: json['isVitStudent'] as bool,
      mess: json['mess'] == null
          ? null
          : MessRef.fromJson(json['mess'] as Map<String, dynamic>),
      $type: json['step'] as String?,
    );

Map<String, dynamic> _$VitAnswerToJson(VitAnswer instance) => <String, dynamic>{
      'isVitStudent': instance.isVitStudent,
      'mess': instance.mess,
      'step': instance.$type,
    };

_OnboardingState _$OnboardingStateFromJson(Map<String, dynamic> json) =>
    _OnboardingState(
      stage: $enumDecode(_$OnboardingStageEnumMap, json['stage']),
      completed: json['completed'] as bool,
      answered: (json['answered'] as List<dynamic>)
          .map((e) => $enumDecode(_$OnboardingStageEnumMap, e))
          .toList(),
      missing: (json['missing'] as List<dynamic>)
          .map((e) => $enumDecode(_$OnboardingStageEnumMap, e))
          .toList(),
      profile:
          UserProfileDetail.fromJson(json['profile'] as Map<String, dynamic>),
      goalType: $enumDecodeNullable(_$GoalTypeEnumMap, json['goalType']),
      dietType: $enumDecodeNullable(_$DietTypeEnumMap, json['dietType']),
      allergies: (json['allergies'] as List<dynamic>)
          .map((e) => Allergy.fromJson(e as Map<String, dynamic>))
          .toList(),
      policyVersion: json['policyVersion'] as String,
    );

Map<String, dynamic> _$OnboardingStateToJson(_OnboardingState instance) =>
    <String, dynamic>{
      'stage': _$OnboardingStageEnumMap[instance.stage]!,
      'completed': instance.completed,
      'answered':
          instance.answered.map((e) => _$OnboardingStageEnumMap[e]!).toList(),
      'missing':
          instance.missing.map((e) => _$OnboardingStageEnumMap[e]!).toList(),
      'profile': instance.profile,
      'goalType': _$GoalTypeEnumMap[instance.goalType],
      'dietType': _$DietTypeEnumMap[instance.dietType],
      'allergies': instance.allergies,
      'policyVersion': instance.policyVersion,
    };

const _$OnboardingStageEnumMap = {
  OnboardingStage.goal: 'goal',
  OnboardingStage.about: 'about',
  OnboardingStage.experience: 'experience',
  OnboardingStage.training: 'training',
  OnboardingStage.food: 'food',
  OnboardingStage.vit: 'vit',
  OnboardingStage.complete: 'complete',
};

_OnboardingCompleteResponse _$OnboardingCompleteResponseFromJson(
        Map<String, dynamic> json) =>
    _OnboardingCompleteResponse(
      profile:
          UserProfileDetail.fromJson(json['profile'] as Map<String, dynamic>),
      goal: Goal.fromJson(json['goal'] as Map<String, dynamic>),
      targets:
          NutritionTargets.fromJson(json['targets'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OnboardingCompleteResponseToJson(
        _OnboardingCompleteResponse instance) =>
    <String, dynamic>{
      'profile': instance.profile,
      'goal': instance.goal,
      'targets': instance.targets,
    };
