import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../profile/domain/entities/profile.dart';
import '../../../profile/domain/entities/vocabulary.dart';

part 'onboarding.freezed.dart';
part 'onboarding.g.dart';

/// Wire shapes of `@fitos/contracts` onboarding.ts.

@freezed
abstract class ConsentGrant with _$ConsentGrant {
  const factory ConsentGrant({
    required String policyVersion,
    required List<ConsentType> types,
  }) = _ConsentGrant;

  factory ConsentGrant.fromJson(Map<String, dynamic> json) =>
      _$ConsentGrantFromJson(json);
}

/// One answer per screen. Serialises with a `step` discriminator exactly as
/// the server's `z.discriminatedUnion('step', ...)` expects — this is what
/// openapi-generator could not model (ADR-004) and freezed does natively.
@Freezed(unionKey: 'step', unionValueCase: FreezedUnionCase.kebab)
sealed class OnboardingAnswer with _$OnboardingAnswer {
  @FreezedUnionValue('goal')
  const factory OnboardingAnswer.goal({required GoalType goalType}) =
      GoalAnswer;

  @FreezedUnionValue('about')
  const factory OnboardingAnswer.about({
    required Sex sex,
    required String birthDate,
    required double heightCm,
    required double weightKg,
    required ConsentGrant consent,
  }) = AboutAnswer;

  @FreezedUnionValue('experience')
  const factory OnboardingAnswer.experience({
    required ExperienceLevel experienceLevel,
    required int trainingDaysPerWeek,
    required ActivityLevel activityLevel,
  }) = ExperienceAnswer;

  @FreezedUnionValue('training')
  const factory OnboardingAnswer.training({
    required TrainingLocation trainingLocation,
    required List<Equipment> equipment,
  }) = TrainingAnswer;

  @FreezedUnionValue('food')
  const factory OnboardingAnswer.food({
    required DietType dietType,
    required List<Allergy> allergies,
  }) = FoodAnswer;

  @FreezedUnionValue('vit')
  const factory OnboardingAnswer.vit({
    required bool isVitStudent,
    required MessRef? mess,
  }) = VitAnswer;

  factory OnboardingAnswer.fromJson(Map<String, dynamic> json) =>
      _$OnboardingAnswerFromJson(json);
}

/// GET /onboarding/state, and the response to every answer.
@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    /// Next unanswered step, or `complete` when all are answered (ready for screen 7).
    required OnboardingStage stage,

    /// True only once /onboarding/complete has computed targets.
    required bool completed,
    required List<OnboardingStage> answered,
    required List<OnboardingStage> missing,
    required UserProfileDetail profile,
    required GoalType? goalType,
    required DietType? dietType,
    required List<Allergy> allergies,
    required String policyVersion,
  }) = _OnboardingState;

  factory OnboardingState.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStateFromJson(json);
}

/// POST /onboarding/complete — screen 7. Targets are real engine output.
@freezed
abstract class OnboardingCompleteResponse with _$OnboardingCompleteResponse {
  const factory OnboardingCompleteResponse({
    required UserProfileDetail profile,
    required Goal goal,
    required NutritionTargets targets,
  }) = _OnboardingCompleteResponse;

  factory OnboardingCompleteResponse.fromJson(Map<String, dynamic> json) =>
      _$OnboardingCompleteResponseFromJson(json);
}
