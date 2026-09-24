import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';

import 'fake_onboarding_repository.dart';

/// Scripted ProfileRepository: Persona C, three days a week, no session
/// length set — the generate screen's prefill source.
class FakeProfileRepository implements ProfileRepository {
  Result<UserProfileDetail> nextProfile = Ok(
    midwayProfile.copyWith(
      displayName: 'Persona',
      onboardingStage: 'complete',
      trainingDaysPerWeek: 3,
    ),
  );
  Result<GoalResponse> nextGoal = Ok(
    GoalResponse(goal: personaCGoal, targets: personaCTargets),
  );

  final calls = <String>[];

  @override
  Future<Result<UserProfileDetail>> getProfile() async {
    calls.add('getProfile');
    return nextProfile;
  }

  @override
  Future<Result<UserProfileDetail>> setDisplayName(String displayName) async {
    calls.add('setDisplayName:$displayName');
    final p = nextProfile;
    if (p is Ok<UserProfileDetail>) {
      nextProfile = Ok(p.value.copyWith(displayName: displayName));
    }
    return nextProfile;
  }

  final personalChanges = <Map<String, dynamic>>[];

  /// When set, the next personal-details save fails with it.
  Failure? failPersonalDetails;

  @override
  Future<Result<UserProfileDetail>> updatePersonalDetails(
    PersonalDetailsChange change,
  ) async {
    calls.add('updatePersonalDetails');
    personalChanges.add(change.toJson());
    final f = failPersonalDetails;
    if (f != null) return Err(f);
    final p = nextProfile;
    if (p is Ok<UserProfileDetail>) {
      nextProfile = Ok(
        p.value.copyWith(
          displayName: change.displayName ?? p.value.displayName,
          sex: change.sex ?? p.value.sex,
          heightCm: change.heightCm ?? p.value.heightCm,
          latestWeightKg: change.weightKg ?? p.value.latestWeightKg,
          activityLevel: change.activityLevel ?? p.value.activityLevel,
        ),
      );
    }
    return nextProfile;
  }

  @override
  Future<Result<GoalResponse>> getGoal() async {
    calls.add('getGoal');
    return nextGoal;
  }

  @override
  Future<Result<GoalResponse>> putGoal(PutGoalRequest request) async =>
      nextGoal;

  /// Phase 9: the mess saves; [failMess] makes the next one fail.
  final messChanges = <MessRef?>[];
  Failure? failMess;

  @override
  Future<Result<UserProfileDetail>> setMess(MessRef? mess) async {
    calls.add('setMess');
    messChanges.add(mess);
    final f = failMess;
    if (f != null) return Err(f);
    final p = nextProfile;
    if (p is Ok<UserProfileDetail>) {
      nextProfile =
          Ok(p.value.copyWith(isVitStudent: mess != null, mess: mess));
    }
    return nextProfile;
  }
}
