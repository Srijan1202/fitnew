import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/recovery/data/recovery_api.dart';
import 'package:fitos/features/recovery/domain/recovery.dart';

/// A scripted Recovery server (Phase 13). It computes nothing: a test puts
/// the view the real server would send in [current] (and the readiness a
/// check-in would produce in [readinessAfterCheckIn]); without one it
/// answers "nothing logged today" for [date].
class FakeRecoveryApi implements RecoveryApi {
  FakeRecoveryApi({this.date = '2026-09-21'});

  String date;
  RecoveryToday? current;

  /// What `/recovery/today` carries after the next successful check-in.
  Readiness? readinessAfterCheckIn;

  /// Every call fails with this, when set (e.g. `Offline()`).
  Failure? failure;

  final List<String> calls = [];
  final List<Map<String, dynamic>> writes = [];

  @override
  Future<Result<RecoveryToday>> today() async {
    calls.add('today');
    final f = failure;
    if (f != null) return Err(f);
    return Ok(current ?? RecoveryToday(date: date));
  }

  @override
  Future<Result<SavedCheckIn>> log(LogRecoveryRequest request) async {
    calls.add('log');
    final f = failure;
    if (f != null) return Err(f);
    writes.add(request.toJson());
    final log = RecoveryLog(
      date: request.date ?? date,
      sleepHours: request.sleepHours,
      sleepQuality: request.sleepQuality,
      soreness: request.soreness,
      energy: request.energy,
      stress: request.stress,
    );
    final created = current?.log == null;
    current = RecoveryToday(
      date: date,
      log: log,
      readiness: readinessAfterCheckIn ?? current?.readiness,
    );
    return Ok(SavedCheckIn(log: log, created: created));
  }
}
