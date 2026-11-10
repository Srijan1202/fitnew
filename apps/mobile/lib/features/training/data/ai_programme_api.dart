import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Beta 6.1 (premium): a week FITOS AI built and FITOS checked
/// (`POST /v1/training/program/ai-draft`). Nothing is saved until the
/// person uses it (the ordinary custom programme route).
class AiProgrammeDraft {
  const AiProgrammeDraft({
    required this.name,
    required this.why,
    required this.days,
    required this.adjustments,
  });

  factory AiProgrammeDraft.fromJson(Map<String, dynamic> j) => AiProgrammeDraft(
        name: j['name'] as String,
        why: j['why'] as String,
        days: [
          for (final d in j['days'] as List<dynamic>)
            (
              name: (d as Map<String, dynamic>)['sessionName'] as String,
              exercises: [
                for (final x in d['exercises'] as List<dynamic>)
                  AiDraftExercise.fromJson(x as Map<String, dynamic>),
              ],
            ),
        ],
        adjustments: (j['adjustments'] as List<dynamic>).cast<String>(),
      );

  final String name;
  final String why;
  final List<({String name, List<AiDraftExercise> exercises})> days;

  /// What FITOS changed in the model's plan, in plain lines.
  final List<String> adjustments;
}

class AiDraftExercise {
  const AiDraftExercise({
    required this.exerciseId,
    required this.name,
    required this.setCount,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
  });

  factory AiDraftExercise.fromJson(Map<String, dynamic> j) => AiDraftExercise(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        setCount: j['setCount'] as int,
        repMin: j['repMin'] as int,
        repMax: j['repMax'] as int,
        targetRir: j['targetRir'] as int,
      );

  final String exerciseId;
  final String name;
  final int setCount;
  final int repMin;
  final int repMax;
  final int targetRir;
}

abstract class AiProgrammeApi {
  Future<Result<AiProgrammeDraft>> draft({
    required int sessions,
    required int minutes,
    required List<String> focus,
    required List<String> avoid,
    String? note,
  });
}

class DioAiProgrammeApi implements AiProgrammeApi {
  DioAiProgrammeApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<AiProgrammeDraft>> draft({
    required int sessions,
    required int minutes,
    required List<String> focus,
    required List<String> avoid,
    String? note,
  }) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/v1/training/program/ai-draft',
        data: {
          'sessions': sessions,
          'minutes': minutes,
          'focus': focus,
          'avoid': avoid,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
        // The model takes a while with a whole library to read.
        // Up to 60 s for the model, and once more if it is busy (audit 2026-11-10).
        options: Options(receiveTimeout: const Duration(seconds: 150)),
      );
      return Ok(AiProgrammeDraft.fromJson(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
