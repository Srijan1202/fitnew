import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../domain/entities/profile.dart';

/// /v1/user/* — profile and goal. Thin; the server owns every decision.
abstract class ProfileRepository {
  Future<Result<UserProfileDetail>> getProfile();
  Future<Result<GoalResponse>> getGoal();
  Future<Result<GoalResponse>> putGoal(PutGoalRequest request);
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
    final profile = await _repo.getProfile();
    final goal = await _repo.getGoal();
    return ProfileView(
      profile: profile.when(ok: (p) => p, err: (f) => throw f),
      goal: goal.when(ok: (g) => g, err: (f) => throw f),
    );
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
