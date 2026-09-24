import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/today/data/today_api.dart';
import 'package:fitos/features/today/domain/today.dart';

/// A scripted TODAY server (Phase 11). It never decides anything: tests put
/// the plan the real server would send in [plan] and script event answers.
/// Without a plan it answers with no actions for [date] (the first-day case).
class FakeTodayApi implements TodayApi {
  FakeTodayApi({this.plan, this.date = '2026-09-22'});

  TodayPlan? plan;
  String date;

  /// Every GET fails with this, when set (e.g. `Offline()`).
  Failure? todayFailure;

  /// Answers for event posts, consumed in order; after them, Ok.
  final List<Failure?> eventAnswers = [];

  /// When set, every event post fails with this (a persistent state).
  Failure? eventFailure;

  final List<({String id, TodayEventRequest request})> events = [];
  int todayCalls = 0;

  @override
  Future<Result<TodayPlan>> today() async {
    todayCalls++;
    final f = todayFailure;
    if (f != null) return Err(f);
    return Ok(
      plan ??
          TodayPlan(
            date: date,
            generatedAt: '${date}T06:30:00.000Z',
            engineVersion: 'today-1',
            actions: const [],
          ),
    );
  }

  @override
  Future<Result<TodayEventRecord>> event(
    String recommendationId,
    TodayEventRequest request,
  ) async {
    events.add((id: recommendationId, request: request));
    final scripted = eventAnswers.isNotEmpty ? eventAnswers.removeAt(0) : null;
    final f = scripted ?? eventFailure;
    if (f != null) return Err(f);
    return Ok(
      TodayEventRecord(
        id: 'ev-${events.length}',
        recommendationId: recommendationId,
        event: request.event,
        clientEventId: request.clientEventId,
        occurredAt: request.occurredAt,
        receivedAt: request.occurredAt,
      ),
    );
  }

  /// What reached the server, as `id:event`.
  List<String> get sent =>
      [for (final e in events) '${e.id}:${e.request.event.wire}'];

  static TodayAction action(
    TodayKind kind, {
    String? id,
    String subjectKey = '',
    int rank = 1,
    int? priority,
    ActionBasis basis = ActionBasis.calculated,
    ActionTarget target = ActionTarget.train,
    TodayReason? reason,
    String? headline,
    String? detail,
  }) =>
      TodayAction(
        id: id ?? '00000000-0000-4000-8000-00000000000${kind.index}',
        kindWire: kind.wire,
        subjectKey: subjectKey,
        rank: rank,
        priority: priority ?? _priority[kind]!,
        basis: basis,
        target: target,
        reason: reason ?? TodayReason(_code[kind]!, const {}),
        headline: headline ?? '${kind.wire} headline',
        detail: detail ?? '${kind.wire} detail',
      );

  static const _priority = {
    TodayKind.deload: 95,
    TodayKind.injuredLimitation: 91,
    TodayKind.startWorkout: 90,
    TodayKind.eatProtein: 80,
    TodayKind.eatMeal: 75,
    TodayKind.progressLoad: 72,
    TodayKind.muscleNeglected: 68,
    TodayKind.restDay: 60,
    TodayKind.celebratePr: 50,
    TodayKind.logWeight: 45,
  };

  static const _code = {
    TodayKind.deload: 'deload-offered',
    TodayKind.injuredLimitation: 'exercise-contraindicated',
    TodayKind.startWorkout: 'session-scheduled',
    TodayKind.eatProtein: 'protein-behind',
    TodayKind.eatMeal: 'meal-remaining',
    TodayKind.progressLoad: 'load-increase-due',
    TodayKind.muscleNeglected: 'muscle-untrained',
    TodayKind.restDay: 'rest-day',
    TodayKind.celebratePr: 'pr-today',
    TodayKind.logWeight: 'weigh-in-due',
  };
}
