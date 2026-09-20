// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessRef _$MessRefFromJson(Map<String, dynamic> json) => _MessRef(
      providerId: json['providerId'] as String,
      hostelId: json['hostelId'] as String,
      messId: json['messId'] as String,
    );

Map<String, dynamic> _$MessRefToJson(_MessRef instance) => <String, dynamic>{
      'providerId': instance.providerId,
      'hostelId': instance.hostelId,
      'messId': instance.messId,
    };

_UserProfileDetail _$UserProfileDetailFromJson(Map<String, dynamic> json) =>
    _UserProfileDetail(
      sex: $enumDecodeNullable(_$SexEnumMap, json['sex']),
      birthDate: json['birthDate'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      experienceLevel: $enumDecodeNullable(
          _$ExperienceLevelEnumMap, json['experienceLevel']),
      trainingDaysPerWeek: (json['trainingDaysPerWeek'] as num?)?.toInt(),
      activityLevel:
          $enumDecodeNullable(_$ActivityLevelEnumMap, json['activityLevel']),
      preferredSessionMinutes:
          (json['preferredSessionMinutes'] as num?)?.toInt(),
      trainingLocation: $enumDecodeNullable(
          _$TrainingLocationEnumMap, json['trainingLocation']),
      equipment: (json['equipment'] as List<dynamic>)
          .map((e) => $enumDecode(_$EquipmentEnumMap, e))
          .toList(),
      latestWeightKg: (json['latestWeightKg'] as num?)?.toDouble(),
      timezone: json['timezone'] as String,
      locale: json['locale'] as String,
      onboardingStage: json['onboardingStage'] as String,
      mess: json['mess'] == null
          ? null
          : MessRef.fromJson(json['mess'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserProfileDetailToJson(_UserProfileDetail instance) =>
    <String, dynamic>{
      'sex': _$SexEnumMap[instance.sex],
      'birthDate': instance.birthDate,
      'heightCm': instance.heightCm,
      'experienceLevel': _$ExperienceLevelEnumMap[instance.experienceLevel],
      'trainingDaysPerWeek': instance.trainingDaysPerWeek,
      'activityLevel': _$ActivityLevelEnumMap[instance.activityLevel],
      'preferredSessionMinutes': instance.preferredSessionMinutes,
      'trainingLocation': _$TrainingLocationEnumMap[instance.trainingLocation],
      'equipment':
          instance.equipment.map((e) => _$EquipmentEnumMap[e]!).toList(),
      'latestWeightKg': instance.latestWeightKg,
      'timezone': instance.timezone,
      'locale': instance.locale,
      'onboardingStage': instance.onboardingStage,
      'mess': instance.mess,
    };

const _$SexEnumMap = {
  Sex.male: 'male',
  Sex.female: 'female',
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

_Goal _$GoalFromJson(Map<String, dynamic> json) => _Goal(
      id: json['id'] as String,
      goalType: $enumDecode(_$GoalTypeEnumMap, json['goalType']),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      startedAt: DateTime.parse(json['startedAt'] as String),
    );

Map<String, dynamic> _$GoalToJson(_Goal instance) => <String, dynamic>{
      'id': instance.id,
      'goalType': _$GoalTypeEnumMap[instance.goalType]!,
      'targetWeightKg': instance.targetWeightKg,
      'startedAt': instance.startedAt.toIso8601String(),
    };

const _$GoalTypeEnumMap = {
  GoalType.muscleGain: 'muscle-gain',
  GoalType.fatLoss: 'fat-loss',
  GoalType.recomposition: 'recomposition',
  GoalType.strength: 'strength',
  GoalType.general: 'general',
  GoalType.maintenance: 'maintenance',
};

_Allergy _$AllergyFromJson(Map<String, dynamic> json) => _Allergy(
      allergen: $enumDecode(_$AllergenEnumMap, json['allergen']),
      severity: $enumDecode(_$AllergySeverityEnumMap, json['severity']),
    );

Map<String, dynamic> _$AllergyToJson(_Allergy instance) => <String, dynamic>{
      'allergen': _$AllergenEnumMap[instance.allergen]!,
      'severity': _$AllergySeverityEnumMap[instance.severity]!,
    };

const _$AllergenEnumMap = {
  Allergen.peanut: 'peanut',
  Allergen.treeNut: 'tree-nut',
  Allergen.milk: 'milk',
  Allergen.egg: 'egg',
  Allergen.soy: 'soy',
  Allergen.wheat: 'wheat',
  Allergen.fish: 'fish',
  Allergen.shellfish: 'shellfish',
  Allergen.sesame: 'sesame',
  Allergen.mustard: 'mustard',
};

const _$AllergySeverityEnumMap = {
  AllergySeverity.mild: 'mild',
  AllergySeverity.moderate: 'moderate',
  AllergySeverity.severe: 'severe',
};

_DietPreferences _$DietPreferencesFromJson(Map<String, dynamic> json) =>
    _DietPreferences(
      dietType: $enumDecode(_$DietTypeEnumMap, json['dietType']),
      allergies: (json['allergies'] as List<dynamic>)
          .map((e) => Allergy.fromJson(e as Map<String, dynamic>))
          .toList(),
      excludedDishIds: (json['excludedDishIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      budgetTier: $enumDecodeNullable(_$BudgetTierEnumMap, json['budgetTier']),
    );

Map<String, dynamic> _$DietPreferencesToJson(_DietPreferences instance) =>
    <String, dynamic>{
      'dietType': _$DietTypeEnumMap[instance.dietType]!,
      'allergies': instance.allergies,
      'excludedDishIds': instance.excludedDishIds,
      'budgetTier': _$BudgetTierEnumMap[instance.budgetTier],
    };

const _$DietTypeEnumMap = {
  DietType.vegetarian: 'vegetarian',
  DietType.eggetarian: 'eggetarian',
  DietType.nonVegetarian: 'non-vegetarian',
};

const _$BudgetTierEnumMap = {
  BudgetTier.low: 'low',
  BudgetTier.medium: 'medium',
  BudgetTier.high: 'high',
};

_NutritionTargets _$NutritionTargetsFromJson(Map<String, dynamic> json) =>
    _NutritionTargets(
      effectiveFrom: json['effectiveFrom'] as String,
      kcal: (json['kcal'] as num).toInt(),
      proteinG: (json['proteinG'] as num).toInt(),
      carbG: (json['carbG'] as num).toInt(),
      fatG: (json['fatG'] as num).toInt(),
      fiberG: (json['fiberG'] as num).toInt(),
      bmr: (json['bmr'] as num).toInt(),
      tdeeEstimate: (json['tdeeEstimate'] as num).toInt(),
      rationale:
          (json['rationale'] as List<dynamic>).map((e) => e as String).toList(),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$NutritionTargetsToJson(_NutritionTargets instance) =>
    <String, dynamic>{
      'effectiveFrom': instance.effectiveFrom,
      'kcal': instance.kcal,
      'proteinG': instance.proteinG,
      'carbG': instance.carbG,
      'fatG': instance.fatG,
      'fiberG': instance.fiberG,
      'bmr': instance.bmr,
      'tdeeEstimate': instance.tdeeEstimate,
      'rationale': instance.rationale,
      'reason': instance.reason,
    };

_GoalResponse _$GoalResponseFromJson(Map<String, dynamic> json) =>
    _GoalResponse(
      goal: Goal.fromJson(json['goal'] as Map<String, dynamic>),
      targets: json['targets'] == null
          ? null
          : NutritionTargets.fromJson(json['targets'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GoalResponseToJson(_GoalResponse instance) =>
    <String, dynamic>{
      'goal': instance.goal,
      'targets': instance.targets,
    };

_PutGoalRequest _$PutGoalRequestFromJson(Map<String, dynamic> json) =>
    _PutGoalRequest(
      goalType: $enumDecode(_$GoalTypeEnumMap, json['goalType']),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$PutGoalRequestToJson(_PutGoalRequest instance) =>
    <String, dynamic>{
      'goalType': _$GoalTypeEnumMap[instance.goalType]!,
      'targetWeightKg': instance.targetWeightKg,
    };
