import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';

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
          timezone: change.timezone ?? p.value.timezone,
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

  /// Phase 10: diet and allergies.
  DietPreferences diet = const DietPreferences(
    dietType: DietType.vegetarian,
    allergies: <Allergy>[],
    excludedDishIds: <String>[],
    budgetTier: null,
  );
  final dietChanges = <Map<String, dynamic>>[];
  Failure? failDiet;

  @override
  Future<Result<DietPreferences>> getDiet() async {
    calls.add('getDiet');
    return Ok(diet);
  }

  @override
  Future<Result<DietPreferences>> putDiet(
    DietType dietType,
    List<Allergy> allergies,
  ) async {
    calls.add('putDiet');
    dietChanges.add(<String, dynamic>{
      'dietType': dietType.wire,
      'allergies': [
        for (final a in allergies) '${a.allergen.wire}:${a.severity.wire}',
      ],
    });
    final f = failDiet;
    if (f != null) return Err(f);
    diet = diet.copyWith(dietType: dietType, allergies: allergies);
    return Ok(diet);
  }

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

  /* ---------------------------------------- your own targets (ADR-031) -- */

  /// The server's answer to a save: these warnings, the targets marked custom.
  List<String> customWarnings = const <String>[];
  Failure? failCustom;
  final customSaves = <(int, int)>[];
  int resets = 0;

  static const targetLimits = TargetLimits(
    kcalMin: 1200,
    kcalMax: 6000,
    proteinMinG: 35,
    proteinMaxG: 191,
  );
  static const suggestion = TargetsSuggestion(
    kcal: 2276,
    proteinG: 106,
    carbG: 337,
    fatG: 56,
    fiberG: 30,
  );

  NutritionTargets? get _current => switch (nextGoal) {
        Ok<GoalResponse>(:final value) => value.targets,
        _ => null,
      };

  void _setTargets(NutritionTargets t) {
    final g = nextGoal;
    if (g is Ok<GoalResponse>) nextGoal = Ok(g.value.copyWith(targets: t));
  }

  @override
  Future<Result<TargetsView>> getTargets() async {
    calls.add('getTargets');
    return Ok(
      TargetsView(
        current: _current,
        suggestion: suggestion,
        limits: targetLimits,
      ),
    );
  }

  @override
  Future<Result<CustomTargetsResponse>> setCustomTargets({
    required int kcal,
    required int proteinG,
  }) async {
    calls.add('setCustomTargets:$kcal:$proteinG');
    customSaves.add((kcal, proteinG));
    final f = failCustom;
    if (f != null) return Err(f);
    final t = personaCTargets.copyWith(
      kcal: kcal,
      proteinG: proteinG,
      reason: 'custom',
      source: 'custom',
    );
    _setTargets(t);
    return Ok(CustomTargetsResponse(targets: t, warnings: customWarnings));
  }

  @override
  Future<Result<TargetsView>> resetTargets() async {
    calls.add('resetTargets');
    resets += 1;
    const t = personaCTargets;
    _setTargets(t.copyWith(reason: 'reset-to-fitos'));
    return Ok(
      TargetsView(
        current: _current,
        suggestion: suggestion,
        limits: targetLimits,
      ),
    );
  }
}
