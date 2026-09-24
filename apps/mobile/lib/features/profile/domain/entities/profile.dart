import 'package:freezed_annotation/freezed_annotation.dart';

import 'vocabulary.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// Wire shapes of `@fitos/contracts` profile.ts. These are what the backend
/// owns; the client renders them and never computes from them (§7.3).

@freezed
abstract class MessRef with _$MessRef {
  const factory MessRef({
    required String providerId,
    required String hostelId,
    required String messId,
  }) = _MessRef;

  factory MessRef.fromJson(Map<String, dynamic> json) =>
      _$MessRefFromJson(json);
}

@freezed
abstract class UserProfileDetail with _$UserProfileDetail {
  const factory UserProfileDetail({
    /// Phase 6.6: what the app calls the user; null until answered.
    @Default(null) String? displayName,
    required Sex? sex,
    required String? birthDate,
    required double? heightCm,
    required ExperienceLevel? experienceLevel,
    required int? trainingDaysPerWeek,
    required ActivityLevel? activityLevel,
    required int? preferredSessionMinutes,
    required TrainingLocation? trainingLocation,
    required List<Equipment> equipment,
    required double? latestWeightKg,
    required String timezone,
    required String locale,
    required String onboardingStage,

    /// Screen 6's answer; null before it is answered (Phase 9 on the wire).
    @Default(null) bool? isVitStudent,
    required MessRef? mess,
  }) = _UserProfileDetail;

  factory UserProfileDetail.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDetailFromJson(json);
}

@freezed
abstract class Goal with _$Goal {
  const factory Goal({
    required String id,
    required GoalType goalType,
    required double? targetWeightKg,
    required DateTime startedAt,
  }) = _Goal;

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);
}

@freezed
abstract class Allergy with _$Allergy {
  const factory Allergy({
    required Allergen allergen,
    required AllergySeverity severity,
  }) = _Allergy;

  factory Allergy.fromJson(Map<String, dynamic> json) =>
      _$AllergyFromJson(json);
}

@freezed
abstract class DietPreferences with _$DietPreferences {
  const factory DietPreferences({
    required DietType dietType,
    required List<Allergy> allergies,
    required List<String> excludedDishIds,
    required BudgetTier? budgetTier,
  }) = _DietPreferences;

  factory DietPreferences.fromJson(Map<String, dynamic> json) =>
      _$DietPreferencesFromJson(json);
}

/// Every number here is `calculated` by packages/core (§6.5). `rationale` is
/// the engine's own explanation and is shown verbatim — the client never
/// paraphrases a number it did not compute.
@freezed
abstract class NutritionTargets with _$NutritionTargets {
  const factory NutritionTargets({
    required String effectiveFrom,
    required int kcal,
    required int proteinG,
    required int carbG,
    required int fatG,
    required int fiberG,
    required int bmr,
    required int tdeeEstimate,
    required List<String> rationale,
    required String reason,
  }) = _NutritionTargets;

  factory NutritionTargets.fromJson(Map<String, dynamic> json) =>
      _$NutritionTargetsFromJson(json);
}

@freezed
abstract class GoalResponse with _$GoalResponse {
  const factory GoalResponse({
    required Goal goal,
    required NutritionTargets? targets,
  }) = _GoalResponse;

  factory GoalResponse.fromJson(Map<String, dynamic> json) =>
      _$GoalResponseFromJson(json);
}

@freezed
abstract class PutGoalRequest with _$PutGoalRequest {
  const factory PutGoalRequest({
    required GoalType goalType,
    double? targetWeightKg,
  }) = _PutGoalRequest;

  factory PutGoalRequest.fromJson(Map<String, dynamic> json) =>
      _$PutGoalRequestFromJson(json);
}
