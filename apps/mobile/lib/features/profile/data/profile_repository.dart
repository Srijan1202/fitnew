import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../domain/entities/profile.dart';
import '../domain/entities/vocabulary.dart';

/// /v1/user/* — profile and goal. Thin; the server owns every decision.
abstract class ProfileRepository {
  Future<Result<UserProfileDetail>> getProfile();
  Future<Result<GoalResponse>> getGoal();
  Future<Result<GoalResponse>> putGoal(PutGoalRequest request);

  /// Phase 6.6: `PATCH /user/profile { displayName }`.
  Future<Result<UserProfileDetail>> setDisplayName(String displayName);

  /// Phase 6.6 Gate 7: Profile → Personal details. One `PATCH /user/profile`
  /// with only the fields that changed. The server stores them, records a
  /// weight as today's reading, and recomputes targets itself when a
  /// formula input changed — the app never computes or writes a target.
  Future<Result<UserProfileDetail>> updatePersonalDetails(
    PersonalDetailsChange change,
  );
}

class DioProfileRepository implements ProfileRepository {
  DioProfileRepository(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data == null) return const Err(Unknown());
      return Ok(parse(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<UserProfileDetail>> getProfile() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/user/profile'),
        UserProfileDetail.fromJson,
      );

  @override
  Future<Result<GoalResponse>> getGoal() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/user/goal'),
        GoalResponse.fromJson,
      );

  @override
  Future<Result<UserProfileDetail>> setDisplayName(String displayName) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/user/profile',
          data: {'displayName': displayName},
        ),
        UserProfileDetail.fromJson,
      );

  @override
  Future<Result<UserProfileDetail>> updatePersonalDetails(
    PersonalDetailsChange change,
  ) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/user/profile',
          data: change.toJson(),
        ),
        UserProfileDetail.fromJson,
      );

  @override
  Future<Result<GoalResponse>> putGoal(PutGoalRequest request) => _guard(
        () => _dio.put<Map<String, dynamic>>(
          '/v1/user/goal',
          data: request.toJson()..removeWhere((_, Object? v) => v == null),
        ),
        GoalResponse.fromJson,
      );
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return DioProfileRepository(ref.watch(dioProvider));
});

/// What the Personal details editor changed. Only non-null fields are
/// sent (`.strict()` on the server); the wire names are the contract's.
class PersonalDetailsChange {
  const PersonalDetailsChange({
    this.displayName,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
  });

  final String? displayName;
  final Sex? sex;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activityLevel;

  bool get isEmpty =>
      displayName == null &&
      sex == null &&
      heightCm == null &&
      weightKg == null &&
      activityLevel == null;

  /// Height, weight, sex or activity feed the targets formula.
  bool get touchesTargets =>
      sex != null ||
      heightCm != null ||
      weightKg != null ||
      activityLevel != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (displayName != null) 'displayName': displayName,
        if (sex != null) 'sex': sex!.wire,
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        if (activityLevel != null) 'activityLevel': activityLevel!.wire,
      };
}

/// Profile + goal + targets, loaded together for the profile screen.
class ProfileView {
  const ProfileView({required this.profile, required this.goal});
  final UserProfileDetail profile;
  final GoalResponse goal;
}

class ProfileController extends AsyncNotifier<ProfileView> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileView> build() async {
    // Rebuilds whenever the session changes; never shows another session's
    // data or error (see sessionUserIdProvider).
    requireSession(ref);
    final profile = await _repo.getProfile();
    final goal = await _repo.getGoal();
    return ProfileView(
      profile: profile.when(ok: (p) => p, err: (f) => throw f),
      goal: goal.when(ok: (g) => g, err: (f) => throw f),
    );
  }

  /// Phase 6.6: rename; the profile in state takes the server's answer.
  Future<Failure?> setDisplayName(String displayName) async {
    final result = await _repo.setDisplayName(displayName);
    return result.when<Failure?>(
      ok: (profile) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(ProfileView(profile: profile, goal: current.goal));
        }
        return null;
      },
      err: (f) => f,
    );
  }

  /// Phase 6.6 Gate 7: save the Personal details editor. When a formula
  /// input changed, the goal (with the targets the server recomputed) is
  /// re-read so Profile shows the new numbers; nothing is computed here.
  Future<Failure?> savePersonalDetails(PersonalDetailsChange change) async {
    if (change.isEmpty) return null;
    final result = await _repo.updatePersonalDetails(change);
    switch (result) {
      case Err<UserProfileDetail>(:final failure):
        return failure;
      case Ok<UserProfileDetail>(:final value):
        var goal = state.value?.goal;
        if (change.touchesTargets || goal == null) {
          final g = await _repo.getGoal();
          if (g case Ok<GoalResponse>(value: final fresh)) goal = fresh;
        }
        if (goal != null) {
          state = AsyncData(ProfileView(profile: value, goal: goal));
        } else {
          ref.invalidateSelf();
        }
        return null;
    }
  }

  /// PUT the goal; on success the new goal and recomputed targets replace
  /// the old in state. Returns the failure for inline display, or null.
  Future<Failure?> changeGoal(PutGoalRequest request) async {
    final result = await _repo.putGoal(request);
    return result.when<Failure?>(
      ok: (goal) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(ProfileView(profile: current.profile, goal: goal));
        }
        return null;
      },
      err: (f) => f,
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileView>(
  ProfileController.new,
  // See onboardingControllerProvider: no silent back-off, show the failure.
  retry: (_, __) => null,
);
