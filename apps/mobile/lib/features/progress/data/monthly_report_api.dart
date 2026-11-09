import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Beta 6.1 (premium): one calendar month, as the server built it
/// (`GET /v1/progress/monthly`). The phone shows it and draws the PDF; it
/// decides nothing.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.from,
    required this.to,
    required this.complete,
    required this.months,
    required this.sessionsCompleted,
    required this.sessionsPlanned,
    required this.percent,
    required this.hardSets,
    required this.tonnageKg,
    required this.topMuscles,
    required this.prCount,
    required this.prLifts,
    required this.runs,
    required this.km,
    required this.loggedDays,
    required this.judgedDays,
    required this.proteinMet,
    required this.caloriesOn,
    required this.averageKcal,
    required this.waterDays,
    required this.waterDaysAtTarget,
    required this.waterTargetMl,
    required this.checkIns,
    required this.averageSleepHours,
    required this.weightStartKg,
    required this.weightEndKg,
    required this.weightChangeKg,
    required this.highlights,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> j) {
    final t = j['training'] as Map<String, dynamic>;
    final prs = j['prs'] as Map<String, dynamic>;
    final run = j['running'] as Map<String, dynamic>;
    final n = j['nutrition'] as Map<String, dynamic>;
    final w = j['water'] as Map<String, dynamic>;
    final r = j['recovery'] as Map<String, dynamic>;
    final weight = j['weight'] as Map<String, dynamic>?;
    List<String> strings(Object? v) => (v as List<dynamic>).cast<String>();
    double? d(Object? v) => (v as num?)?.toDouble();
    return MonthlyReport(
      month: j['month'] as String,
      from: j['from'] as String,
      to: j['to'] as String,
      complete: j['complete'] as bool,
      months: strings(j['months']),
      sessionsCompleted: t['completed'] as int,
      sessionsPlanned: t['planned'] as int?,
      percent: t['percent'] as int?,
      hardSets: d(t['hardSets'])!,
      tonnageKg: d(t['tonnageKg'])!,
      topMuscles: [
        for (final m in t['topMuscles'] as List<dynamic>)
          (
            (m as Map<String, dynamic>)['muscle'] as String,
            d(m['hardSets'])!,
          ),
      ],
      prCount: prs['count'] as int,
      prLifts: strings(prs['lifts']),
      runs: run['runs'] as int,
      km: d(run['km'])!,
      loggedDays: n['loggedDays'] as int,
      judgedDays: n['judgedDays'] as int,
      proteinMet: n['proteinMet'] as int,
      caloriesOn: n['caloriesOn'] as int,
      averageKcal: n['averageKcal'] as int?,
      waterDays: w['loggedDays'] as int,
      waterDaysAtTarget: w['daysAtTarget'] as int,
      waterTargetMl: w['targetMl'] as int,
      checkIns: r['checkIns'] as int,
      averageSleepHours: d(r['averageSleepHours']),
      weightStartKg: d(weight?['startKg']),
      weightEndKg: d(weight?['endKg']),
      weightChangeKg: d(weight?['changeKg']),
      highlights: strings(j['highlights']),
    );
  }

  final String month;
  final String from;
  final String to;
  final bool complete;
  final List<String> months;
  final int sessionsCompleted;
  final int? sessionsPlanned;
  final int? percent;
  final double hardSets;
  final double tonnageKg;
  final List<(String, double)> topMuscles;
  final int prCount;
  final List<String> prLifts;
  final int runs;
  final double km;
  final int loggedDays;
  final int judgedDays;
  final int proteinMet;
  final int caloriesOn;
  final int? averageKcal;
  final int waterDays;
  final int waterDaysAtTarget;
  final int waterTargetMl;
  final int checkIns;
  final double? averageSleepHours;
  final double? weightStartKg;
  final double? weightEndKg;
  final double? weightChangeKg;
  final List<String> highlights;

  /// "October 2026".
  static String monthName(String month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final parts = month.split('-');
    return '${names[int.parse(parts[1]) - 1]} ${parts[0]}';
  }
}

abstract class MonthlyReportApi {
  Future<Result<MonthlyReport>> report({String? month});
}

class DioMonthlyReportApi implements MonthlyReportApi {
  DioMonthlyReportApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<MonthlyReport>> report({String? month}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/v1/progress/monthly',
        queryParameters: {if (month != null) 'month': month},
      );
      return Ok(MonthlyReport.fromJson(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
