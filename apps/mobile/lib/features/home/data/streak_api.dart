import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Beta 3.3 (ADR-018 amendment): the streak and the weekly goal ring, as the
/// server computed them (`GET /v1/progress/streak`). The app shows them.
class Streak {
  const Streak({
    required this.current,
    required this.best,
    required this.todayCounted,
    required this.weekDone,
    required this.weekPlanned,
  });

  factory Streak.fromJson(Map<String, dynamic> j) {
    final week = j['week'] as Map<String, dynamic>?;
    return Streak(
      current: j['current'] as int,
      best: j['best'] as int,
      todayCounted: j['todayCounted'] as bool,
      weekDone: week?['done'] as int?,
      weekPlanned: week?['planned'] as int?,
    );
  }

  /// Counted days in the run that is still going.
  final int current;
  final int best;

  /// Whether today already counts (else "log today to keep it").
  final bool todayCounted;

  /// Workouts done this week, and planned; null without a programme.
  final int? weekDone;
  final int? weekPlanned;
}

abstract class StreakApi {
  Future<Result<Streak>> streak();
}

class DioStreakApi implements StreakApi {
  DioStreakApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<Streak>> streak() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/v1/progress/streak');
      return Ok(Streak.fromJson(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
