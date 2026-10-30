import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Beta 4.4: how the streak saw one day (core streakDays).
enum StreakDayStatus {
  logged,
  rest,
  skipped,
  missed,
  today,
  before;

  static StreakDayStatus parse(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => before);
}

class StreakDay {
  const StreakDay(this.date, this.status);

  /// yyyy-mm-dd, the user's local day.
  final String date;
  final StreakDayStatus status;
}

/// Beta 3.3 (ADR-018 amendment): the streak and the weekly goal ring, as the
/// server computed them (`GET /v1/progress/streak`). The app shows them.
class Streak {
  const Streak({
    required this.current,
    required this.best,
    required this.todayCounted,
    this.todayRest = false,
    required this.weekDone,
    required this.weekPlanned,
    this.newRewards = const [],
    this.days = const [],
    this.calendar = const [],
  });

  factory Streak.fromJson(Map<String, dynamic> j) {
    final week = j['week'] as Map<String, dynamic>?;
    return Streak(
      current: j['current'] as int,
      best: j['best'] as int,
      todayCounted: j['todayCounted'] as bool,
      // Beta 3.8; absent from an older server.
      todayRest: j['todayRest'] as bool? ?? false,
      weekDone: week?['done'] as int?,
      weekPlanned: week?['planned'] as int?,
      newRewards: [
        for (final id in (j['newRewards'] as List<dynamic>? ?? const []))
          id as String,
      ],
      days: _daysOf(j['days']),
      // Beta 4.8; absent from an older server.
      calendar: _daysOf(j['calendar']),
    );
  }

  static List<StreakDay> _daysOf(Object? list) => [
        for (final d in (list as List<dynamic>? ?? const []))
          StreakDay(
            (d as Map<String, dynamic>)['date'] as String,
            StreakDayStatus.parse(d['status'] as String?),
          ),
      ];

  /// Counted days in the run that is still going.
  final int current;
  final int best;

  /// Whether today already counts (else "log today to keep it").
  final bool todayCounted;

  /// Beta 3.8: today is a planned rest day, which counts by itself once a
  /// run is going.
  final bool todayRest;

  /// Workouts done this week, and planned; null without a programme.
  final int? weekDone;
  final int? weekPlanned;

  /// Beta 3.4: streak reward ids earned by this read (celebrated once).
  final List<String> newRewards;

  /// Beta 4.4: the last 28 days, oldest first; empty from an older server.
  final List<StreakDay> days;

  /// Beta 4.8 (owner): the month calendar — every day from the first of the
  /// joining month (a year at most) to today, oldest first; empty from an
  /// older server.
  final List<StreakDay> calendar;
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
