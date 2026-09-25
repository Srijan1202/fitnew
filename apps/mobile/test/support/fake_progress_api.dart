import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/progress/data/progress_api.dart';
import 'package:fitos/features/progress/domain/progress.dart';

/// A scripted Progress server (Phase 12). It computes nothing: tests put the
/// summary the real server would send in [summaries]; without one it answers
/// with an empty history for [today].
class FakeProgressApi implements ProgressApi {
  FakeProgressApi({this.today = '2026-09-21'});

  String today;
  final Map<ProgressWindow, ProgressSummary> summaries = {};

  /// Every call fails with this, when set (e.g. `Offline()`).
  Failure? failure;

  /// How long the summary takes to answer (to observe loading).
  Duration delay = Duration.zero;

  final List<String> calls = [];
  final List<Map<String, dynamic>> writes = [];

  static ProgressSummary empty(
    String today, [
    ProgressWindow w = ProgressWindow.d30,
  ]) =>
      ProgressSummary(
        window: w,
        today: today,
        from: DateTime.parse(today)
            .subtract(Duration(days: w == ProgressWindow.d30 ? 29 : 89))
            .toIso8601String()
            .substring(0, 10),
        weight: const WeightProgress(
          points: [],
          currentTrendKg: null,
          weeklyChangeKg: null,
          daysOfData: 0,
          isReliable: false,
          windowChangeKg: null,
          windowChangeDays: null,
        ),
        measurements: const [],
        prs: const [],
        bestLifts: const [],
        adherence: const Adherence(
          protein: AdherenceCount(met: 0, of: 0, percent: null),
          calories: AdherenceCount(met: 0, of: 0, percent: null),
          loggedDays: 0,
          daysWithoutTarget: 0,
        ),
        consistency: const Consistency(
          weeks: [],
          completed: 0,
          planned: null,
          percent: null,
        ),
      );

  @override
  Future<Result<ProgressSummary>> summary(ProgressWindow window) async {
    calls.add('summary ${window.wire}');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final f = failure;
    if (f != null) return Err(f);
    return Ok(summaries[window] ?? empty(today, window));
  }

  @override
  Future<Result<SavedReading>> logWeight(LogWeightRequest request) async {
    calls.add('weight');
    final f = failure;
    if (f != null) return Err(f);
    writes.add(request.toJson());
    return Ok(
      SavedReading(date: request.date ?? today, value: request.weightKg),
    );
  }

  @override
  Future<Result<SavedReading>> logMeasurement(
    LogMeasurementRequest request,
  ) async {
    calls.add('measurement');
    final f = failure;
    if (f != null) return Err(f);
    writes.add(request.toJson());
    return Ok(
      SavedReading(
        date: request.date ?? today,
        value: request.valueCm,
        site: request.site,
      ),
    );
  }
}
