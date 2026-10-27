import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/run.dart';
import '../domain/workout.dart';

/// Beta 4.0 (ADR-038): the /v1/running endpoints. Envelope mapping only; the
/// server computes every figure.
abstract class RunningApi {
  /// The finished run, sent as is (201 the first time, 200 on a replay).
  /// Answers the server's JSON so it can be cached unchanged.
  Future<Result<Map<String, dynamic>>> createRun(Map<String, dynamic> body);
  Future<Result<Map<String, dynamic>>> patchRun(
    String id,
    Map<String, dynamic> body,
  );
  Future<Result<void>> deleteRun(String id);
  Future<Result<Map<String, dynamic>>> run(String id);
  Future<Result<RunList>> runs({String? before});

  /// Beta 4.1: `{"plan": …}` as the server sent it (cached as is); `plan`
  /// is null without one.
  Future<Result<Map<String, dynamic>>> currentPlan();
  Future<Result<RunningPlan>> createPlan(Map<String, dynamic> body);
  Future<Result<void>> stopPlan();

  /// `skip` | `unskip` | `move` (with `date`).
  Future<Result<PlannedRun>> patchPlanned(String id, Map<String, dynamic> body);
  Future<Result<WorkoutPresets>> workouts();
}

class DioRunningApi implements RunningApi {
  DioRunningApi(this._dio);

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

  static Map<String, dynamic> _same(Map<String, dynamic> j) => j;

  @override
  Future<Result<Map<String, dynamic>>> createRun(Map<String, dynamic> body) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>('/v1/running/runs', data: body),
        _same,
      );

  @override
  Future<Result<Map<String, dynamic>>> patchRun(
    String id,
    Map<String, dynamic> body,
  ) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/running/runs/$id',
          data: body,
        ),
        _same,
      );

  @override
  Future<Result<void>> deleteRun(String id) async {
    try {
      await _dio.delete<void>('/v1/running/runs/$id');
      return const Ok(null);
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> run(String id) => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/running/runs/$id'),
        _same,
      );

  @override
  Future<Result<RunList>> runs({String? before}) => _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/running/runs',
          queryParameters: {if (before != null) 'before': before},
        ),
        RunList.fromJson,
      );

  @override
  Future<Result<Map<String, dynamic>>> currentPlan() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/running/plans/current'),
        _same,
      );

  @override
  Future<Result<RunningPlan>> createPlan(Map<String, dynamic> body) => _guard(
        () => _dio.post<Map<String, dynamic>>('/v1/running/plans', data: body),
        RunningPlan.fromJson,
      );

  @override
  Future<Result<void>> stopPlan() async {
    try {
      await _dio.delete<void>('/v1/running/plans/current');
      return const Ok(null);
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<PlannedRun>> patchPlanned(
    String id,
    Map<String, dynamic> body,
  ) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/running/planned/$id',
          data: body,
        ),
        PlannedRun.fromJson,
      );

  @override
  Future<Result<WorkoutPresets>> workouts() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/running/workouts'),
        WorkoutPresets.fromJson,
      );
}
