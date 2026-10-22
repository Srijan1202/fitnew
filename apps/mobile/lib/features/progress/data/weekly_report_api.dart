import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Phase 19 (ADR-027, premium): one ISO week on one page, as the server
/// built it (`GET /v1/progress/weekly`). The app shows it; it decides nothing.
class WeeklyReport {
  const WeeklyReport({
    required this.isoWeek,
    required this.from,
    required this.to,
    required this.complete,
    required this.weeks,
    required this.sessionsCompleted,
    required this.sessionsPlanned,
    required this.totalHardSets,
    required this.productive,
    required this.below,
    required this.above,
    required this.prCount,
    required this.prLifts,
    required this.loggedDays,
    required this.judgedDays,
    required this.proteinMet,
    required this.caloriesOn,
    required this.weightChangeKg,
    required this.highlights,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> j) {
    final training = j['training'] as Map<String, dynamic>;
    final volume = j['volume'] as Map<String, dynamic>;
    final prs = j['prs'] as Map<String, dynamic>;
    final nutrition = j['nutrition'] as Map<String, dynamic>;
    final weight = j['weight'] as Map<String, dynamic>?;
    List<String> strings(Object? v) => (v as List<dynamic>).cast<String>();
    return WeeklyReport(
      isoWeek: j['isoWeek'] as String,
      from: j['from'] as String,
      to: j['to'] as String,
      complete: j['complete'] as bool,
      weeks: strings(j['weeks']),
      sessionsCompleted: training['completed'] as int,
      sessionsPlanned: training['planned'] as int?,
      totalHardSets: (volume['totalHardSets'] as num).toDouble(),
      productive: strings(volume['productive']),
      below: strings(volume['below']),
      above: strings(volume['above']),
      prCount: prs['count'] as int,
      prLifts: strings(prs['lifts']),
      loggedDays: nutrition['loggedDays'] as int,
      judgedDays: nutrition['judgedDays'] as int,
      proteinMet: nutrition['proteinMet'] as int,
      caloriesOn: nutrition['caloriesOn'] as int,
      weightChangeKg: (weight?['changeKg'] as num?)?.toDouble(),
      highlights: strings(j['highlights']),
    );
  }

  final String isoWeek;
  final String from;
  final String to;
  final bool complete;
  final List<String> weeks;
  final int sessionsCompleted;
  final int? sessionsPlanned;
  final double totalHardSets;
  final List<String> productive;
  final List<String> below;
  final List<String> above;
  final int prCount;
  final List<String> prLifts;
  final int loggedDays;
  final int judgedDays;
  final int proteinMet;
  final int caloriesOn;
  final double? weightChangeKg;
  final List<String> highlights;
}

abstract class WeeklyReportApi {
  Future<Result<WeeklyReport>> report({String? week});
}

class DioWeeklyReportApi implements WeeklyReportApi {
  DioWeeklyReportApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<WeeklyReport>> report({String? week}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/v1/progress/weekly',
        queryParameters: {if (week != null) 'week': week},
      );
      return Ok(WeeklyReport.fromJson(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
