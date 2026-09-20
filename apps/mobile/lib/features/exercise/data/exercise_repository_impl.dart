import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/exercise.dart';
import '../domain/repositories/exercise_repository.dart';

/// Two calls, envelope mapping, nothing else. Auth header is the interceptor's.
class DioExerciseRepository implements ExerciseRepository {
  DioExerciseRepository(this._dio);

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
  Future<Result<ExerciseListResponse>> list(ExerciseQuery query) => _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/exercises',
          queryParameters: query.toQueryParameters(),
        ),
        ExerciseListResponse.fromJson,
      );

  @override
  Future<Result<ExerciseDetail>> detail(String id) => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/exercises/$id'),
        ExerciseDetail.fromJson,
      );
}
