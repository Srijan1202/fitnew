import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../nutrition/domain/entities/food_log.dart';
import '../domain/mess.dart';
import '../domain/recommendation.dart';

/// Beta 6.1 (premium): a week of mess meals as the server planned it
/// (`GET /v1/mess/week-plan`) — FITOS's own recommender, not the AI. The
/// app draws it; only today's plates can be logged.
class MessWeekPlan {
  const MessWeekPlan({
    required this.mess,
    required this.today,
    required this.hasTargets,
    required this.days,
  });

  factory MessWeekPlan.fromJson(Map<String, dynamic> j) => MessWeekPlan(
        mess: Mess.fromJson(j['mess'] as Map<String, dynamic>),
        today: j['today'] as String,
        hasTargets: j['hasTargets'] as bool,
        days: (j['days'] as List<dynamic>)
            .map((d) => MessWeekDay.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  final Mess mess;
  final String today;
  final bool hasTargets;
  final List<MessWeekDay> days;
}

class MessWeekDay {
  const MessWeekDay({
    required this.date,
    required this.inferred,
    required this.hasMenu,
    required this.meals,
    required this.totals,
  });

  factory MessWeekDay.fromJson(Map<String, dynamic> j) {
    final basis = j['basis'] as String?;
    return MessWeekDay(
      date: j['date'] as String,
      inferred: basis == 'inferred',
      hasMenu: basis != null,
      meals: (j['meals'] as List<dynamic>)
          .map((m) => MessWeekMeal.fromJson(m as Map<String, dynamic>))
          .toList(),
      totals: Macros.fromJson(j['totals'] as Map<String, dynamic>),
    );
  }

  final String date;

  /// The menu is the mess's usual one for that day, not yet published.
  final bool inferred;
  final bool hasMenu;
  final List<MessWeekMeal> meals;
  final Macros totals;
}

class MessWeekMeal {
  const MessWeekMeal({
    required this.slot,
    required this.status,
    required this.plate,
  });

  factory MessWeekMeal.fromJson(Map<String, dynamic> j) => MessWeekMeal(
        slot: MealSlot.fromWire(j['slot'] as String),
        status: RecommendationStatus.fromWire(j['status'] as String),
        plate: j['plate'] == null
            ? null
            : Plate.fromJson(j['plate'] as Map<String, dynamic>),
      );

  final MealSlot slot;
  final RecommendationStatus status;
  final Plate? plate;
}

abstract class MessWeekApi {
  Future<Result<MessWeekPlan>> week();
}

class DioMessWeekApi implements MessWeekApi {
  DioMessWeekApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<MessWeekPlan>> week() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/v1/mess/week-plan');
      return Ok(MessWeekPlan.fromJson(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
