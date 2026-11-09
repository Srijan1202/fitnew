import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Beta 6.1 (E3): one lift's whole history, as the server built it
/// (`GET /v1/training/exercises/{id}/history`), newest first. The estimate
/// is Epley, for display only.
class LiftHistory {
  const LiftHistory({
    required this.exerciseId,
    required this.name,
    required this.sessions,
    required this.bestKg,
    required this.bestDate,
    required this.truncated,
  });

  factory LiftHistory.fromJson(Map<String, dynamic> j) {
    final best = j['best'] as Map<String, dynamic>?;
    return LiftHistory(
      exerciseId: j['exerciseId'] as String,
      name: j['name'] as String,
      sessions: (j['sessions'] as List<dynamic>)
          .map((s) => LiftSession.fromJson(s as Map<String, dynamic>))
          .toList(),
      bestKg: (best?['estimated1RmKg'] as num?)?.toDouble(),
      bestDate: best?['date'] as String?,
      truncated: j['truncated'] as bool,
    );
  }

  final String exerciseId;
  final String name;
  final List<LiftSession> sessions;
  final double? bestKg;
  final String? bestDate;
  final bool truncated;
}

class LiftSet {
  const LiftSet({required this.weightKg, required this.reps, this.rir});

  factory LiftSet.fromJson(Map<String, dynamic> j) => LiftSet(
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        reps: j['reps'] as int,
        rir: j['rir'] as int?,
      );

  final double? weightKg;
  final int reps;
  final int? rir;
}

class LiftSession {
  const LiftSession({
    required this.sessionId,
    required this.date,
    required this.sets,
    required this.topWeightKg,
    required this.topReps,
    required this.estimated1RmKg,
    required this.volumeKg,
    required this.reps,
    required this.record,
  });

  factory LiftSession.fromJson(Map<String, dynamic> j) {
    final top = j['topSet'] as Map<String, dynamic>?;
    return LiftSession(
      sessionId: j['sessionId'] as String,
      date: j['date'] as String,
      sets: (j['sets'] as List<dynamic>)
          .map((s) => LiftSet.fromJson(s as Map<String, dynamic>))
          .toList(),
      topWeightKg: (top?['weightKg'] as num?)?.toDouble(),
      topReps: top?['reps'] as int?,
      estimated1RmKg: (j['estimated1RmKg'] as num?)?.toDouble(),
      volumeKg: (j['volumeKg'] as num).toDouble(),
      reps: j['reps'] as int,
      record: j['record'] as bool,
    );
  }

  final String sessionId;
  final String date;
  final List<LiftSet> sets;
  final double? topWeightKg;
  final int? topReps;
  final double? estimated1RmKg;
  final double volumeKg;
  final int reps;
  final bool record;
}

abstract class LiftHistoryApi {
  Future<Result<LiftHistory>> history(String exerciseId);
}

class DioLiftHistoryApi implements LiftHistoryApi {
  DioLiftHistoryApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<LiftHistory>> history(String exerciseId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/v1/training/exercises/$exerciseId/history',
      );
      return Ok(LiftHistory.fromJson(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
