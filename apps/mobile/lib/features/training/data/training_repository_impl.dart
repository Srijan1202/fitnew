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
                  if (d.focus != null)
                    'focus': [for (final m in d.focus!) m.wire],
                  'exercises': [
                    for (final x in d.exercises) _exerciseJson(x),
                  ],
                },
            ],
          },
        ),
        Program.fromJson,
      );

  /// A custom exercise as the server reads it: no nulls, nested sets encoded.
  static Map<String, dynamic> _exerciseJson(CustomExercise x) => withoutNulls({
        'id': x.id,
        'exerciseId': x.exerciseId,
        'setCount': x.setCount,
        'repMin': x.repMin,
        'repMax': x.repMax,
        'targetRir': x.targetRir,
        'incrementKg': x.incrementKg,
        'startingWeightKg': x.startingWeightKg,
        if (x.sets != null)
          'sets': [
            for (final s in x.sets!)
              {
                'repsMin': s.repsMin,
                'repsMax': s.repsMax,
                'weightKg': s.weightKg,
                'rir': s.rir,
              },
          ],
      });

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
            if (request.focus != null)
              'focus': [for (final m in request.focus!) m.wire],
            if (request.exercises != null)
              'exercises': [
                for (final x in request.exercises!) _exerciseJson(x),
              ],
          }),
        ),
        Program.fromJson,
      );

  @override
  Future<Result<Program>> rename(String name) => _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/training/program',
          data: {'name': name},
        ),
        Program.fromJson,
      );

  @override
  Future<Result<List<ProgramTemplate>>> listTemplates() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/training/templates'),
        (json) => [
          for (final item in json['items'] as List<dynamic>)
            ProgramTemplate.fromJson(item as Map<String, dynamic>),
        ],
      );

  @override
  Future<Result<TemplatePreview>> previewTemplate(
    String slug,
    GenerateProgramRequest request,
  ) =>
      _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/training/templates/$slug',
          queryParameters:
              withoutNulls(request.toJson()).map((k, v) => MapEntry(k, '$v')),
        ),
        TemplatePreview.fromJson,
      );

  @override
  Future<Result<Program>> applyTemplate(
    String slug,
    GenerateProgramRequest request,
  ) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/program/from-template/$slug',
          data: withoutNulls(request.toJson()),
        ),
        Program.fromJson,
      );
}
