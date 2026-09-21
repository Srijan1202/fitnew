import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';

import 'fake_onboarding_repository.dart';

/// Scripted ProfileRepository: Persona C, three days a week, no session
/// length set — the generate screen's prefill source.
class FakeProfileRepository implements ProfileRepository {
  Result<UserProfileDetail> nextProfile = Ok(
    midwayProfile.copyWith(onboardingStage: 'complete', trainingDaysPerWeek: 3),
  );
  Result<GoalResponse> nextGoal = Ok(
    GoalResponse(goal: personaCGoal, targets: personaCTargets),
  );

  @override
  Future<Result<UserProfileDetail>> getProfile() async => nextProfile;

  @override
  Future<Result<GoalResponse>> getGoal() async => nextGoal;

  @override
  Future<Result<GoalResponse>> putGoal(PutGoalRequest request) async =>
      nextGoal;
}
