import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/water/data/water_api.dart';
import 'package:fitos/features/water/domain/water.dart';

/// Beta 6.0 (ADR-059): water in memory — the day totals the phone sent,
/// against [targetMl]; [failure] makes every call fail (offline, switched
/// off).
class FakeWaterApi implements WaterApi {
  FakeWaterApi({this.date = '2026-11-08', this.targetMl = 2750});

  String date;
  int targetMl;
  Failure? failure;
  final Map<String, int> days = {};
  final List<String> calls = [];

  WaterDay _day(String d) => WaterDay(
        date: d,
        ml: days[d] ?? 0,
        targetMl: targetMl,
        fromWeight: true,
      );

  @override
  Future<Result<WaterDay>> today() async {
    calls.add('today');
    final f = failure;
    if (f != null) return Err(f);
    return Ok(_day(date));
  }

  @override
  Future<Result<WaterDay>> set(String d, int ml) async {
    calls.add('set:$d:$ml');
    final f = failure;
    if (f != null) return Err(f);
    days[d] = ml;
    return Ok(_day(d));
  }
}
