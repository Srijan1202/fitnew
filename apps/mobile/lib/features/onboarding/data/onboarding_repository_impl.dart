import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/onboarding.dart';
import '../domain/repositories/onboarding_repository.dart';

/// Thin: three calls, envelope mapping, nothing else. The auth header is added
/// by the interceptor.
class DioOnboardingRepository implements OnboardingRepository {
  DioOnboardingRepository(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await call();
      final data = response.data;
      if (data == null) return const Err(Unknown());
      return Ok(parse(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<OnboardingState>> getState() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/onboarding/state'),
        OnboardingState.fromJson,
      );

  @override
  Future<Result<OnboardingState>> answer(OnboardingAnswer answer) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/onboarding/answer',
          data: answer.toJson(),
        ),
        OnboardingState.fromJson,
      );

  @override
  Future<Result<OnboardingCompleteResponse>> complete() => _guard(
        () => _dio.post<Map<String, dynamic>>('/v1/onboarding/complete'),
        OnboardingCompleteResponse.fromJson,
      );
}
