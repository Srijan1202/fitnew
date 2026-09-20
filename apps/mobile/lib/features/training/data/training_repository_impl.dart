import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/program.dart';
import '../domain/repositories/training_repository.dart';

/// Four calls, envelope mapping, nothing else. Auth header is the interceptor's.
class DioTrainingRepository implements TrainingRepository {
  DioTrainingRepository(this._dio);

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
  Future<Result<Program?>> getProgram() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/v1/training/program');
      final data = response.data;
      if (data == null) return const Err(Unknown());
      return Ok(Program.fromJson(data));
    } on DioException catch (e) {
      // "No programme yet" is a state, not a failure.
      if (e.response?.statusCode == 404) return const Ok(null);
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<Program>> generate(GenerateProgramRequest request) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/program/generate',
          data: withoutNulls(request.toJson()),
        ),
        Program.fromJson,
      );

  @override
  Future<Result<Program>> putProgram(PutProgramRequest request) => _guard(
        () => _dio.put<Map<String, dynamic>>(
          '/v1/training/program',
          data: {
            'name': request.name,
            'days': [
              for (final d in request.days)
                {
                  'dayOfWeek': d.dayOfWeek,
                  'sessionName': d.sessionName,
                  'exercises': [
                    for (final x in d.exercises) withoutNulls(x.toJson()),
                  ],
                },
            ],
          },
        ),
        Program.fromJson,
      );

  @override
  Future<Result<Program>> patchDay(
    String dayId,
    PatchProgramDayRequest request,
  ) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/training/program/days/$dayId',
          data: withoutNulls({
            'sessionName': request.sessionName,
            if (request.exercises != null)
              'exercises': [
                for (final x in request.exercises!) withoutNulls(x.toJson()),
              ],
          }),
        ),
        Program.fromJson,
      );
}
