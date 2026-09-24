/// Wire shapes of `@fitos/contracts` today.ts (Phase 11, ADR-017). The
/// server decides every TODAY action with its deterministic engine — kind,
/// rank, reason, words. The app draws them, records how the user responded
/// and never decides an action itself (§30). Hand-written (ADR-004); the
/// conformance test keeps them in step with the OpenAPI document.
library;

/// The ten server-owned kinds, in the engine's order (§16.1).
enum TodayKind {
  deload('deload'),
  injuredLimitation('injured-limitation'),
  startWorkout('start-workout'),
  eatProtein('eat-protein'),
  eatMeal('eat-meal'),
  progressLoad('progress-load'),
  muscleNeglected('muscle-neglected'),
  restDay('rest-day'),
  celebratePr('celebrate-pr'),
  logWeight('log-weight');

  const TodayKind(this.wire);
  final String wire;

  static TodayKind? fromWire(String w) {
    for (final k in values) {
      if (k.wire == w) return k;
    }
    return null;
  }

  /// P4: informational actions can be accepted or dismissed, never completed.
  bool get completable => switch (this) {
        TodayKind.restDay ||
        TodayKind.celebratePr ||
        TodayKind.injuredLimitation =>
          false,
        _ => true,
      };
}

enum ActionBasis {
  logged('logged'),
  calculated('calculated'),
  estimated('estimated');

  const ActionBasis(this.wire);
  final String wire;

  static ActionBasis fromWire(String w) =>
      values.firstWhere((b) => b.wire == w, orElse: () => calculated);

  /// Said in the "why" sheet (§16: every decision says where it came from).
  String get label => switch (this) {
        ActionBasis.logged => 'From what you logged',
        ActionBasis.calculated => 'Calculated from your plan and logs',
        ActionBasis.estimated => 'Estimated',
      };
}

enum ActionTarget {
  train('train'),
  eat('eat'),
  progress('progress'),
  today('today');

  const ActionTarget(this.wire);
  final String wire;

  static ActionTarget fromWire(String w) =>
      values.firstWhere((t) => t.wire == w, orElse: () => today);
}

/// §9.2's five events (D7).
enum TodayEventName {
  shown('shown'),
  opened('opened'),
  accepted('accepted'),
  dismissed('dismissed'),
  completed('completed');

  const TodayEventName(this.wire);
  final String wire;

  static TodayEventName fromWire(String w) =>
      values.firstWhere((e) => e.wire == w);
}

/// The machine-readable reason: the source of truth (D3). [values] are
/// exactly the server's, per code.
class TodayReason {
  const TodayReason(this.code, this.values);

  factory TodayReason.fromJson(Map<String, dynamic> json) => TodayReason(
        json['code'] as String,
        Map<String, dynamic>.from(json['values'] as Map),
      );

  final String code;
  final Map<String, dynamic> values;

  Map<String, dynamic> toJson() => {'code': code, 'values': values};
}

class TodayAction {
  const TodayAction({
    required this.id,
    required this.kindWire,
    required this.subjectKey,
    required this.rank,
    required this.priority,
    required this.basis,
    required this.target,
    required this.reason,
    required this.headline,
    required this.detail,
  });

  factory TodayAction.fromJson(Map<String, dynamic> json) => TodayAction(
        id: json['id'] as String,
        kindWire: json['kind'] as String,
        subjectKey: json['subjectKey'] as String,
        rank: json['rank'] as int,
        priority: json['priority'] as int,
        basis: ActionBasis.fromWire(json['basis'] as String),
        target: ActionTarget.fromWire(json['target'] as String),
        reason: TodayReason.fromJson(json['reason'] as Map<String, dynamic>),
        headline: json['headline'] as String,
        detail: json['detail'] as String,
      );

  /// The persisted recommendation's id — stable while its content is (D4).
  final String id;
  final String kindWire;
  final String subjectKey;

  /// The CURRENT rank (P5); the order the server put it in.
  final int rank;

  /// Orders only; never shown.
  final int priority;
  final ActionBasis basis;
  final ActionTarget target;
  final TodayReason reason;
  final String headline;
  final String detail;

  /// Null for a kind this build does not know (a newer server): not drawn.
  TodayKind? get kind => TodayKind.fromWire(kindWire);

  ActionRef get ref =>
      ActionRef(id: id, kindWire: kindWire, subjectKey: subjectKey);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kindWire,
        'subjectKey': subjectKey,
        'rank': rank,
        'priority': priority,
        'basis': basis.wire,
        'target': target.wire,
        'reason': reason.toJson(),
        'headline': headline,
        'detail': detail,
      };
}

/// `GET /v1/today`.
class TodayPlan {
  const TodayPlan({
    required this.date,
    required this.generatedAt,
    required this.engineVersion,
    required this.actions,
  });

  factory TodayPlan.fromJson(Map<String, dynamic> json) => TodayPlan(
        date: json['date'] as String,
        generatedAt: json['generatedAt'] as String,
        engineVersion: json['engineVersion'] as String,
        actions: [
          for (final a in json['actions'] as List<dynamic>)
            TodayAction.fromJson(a as Map<String, dynamic>),
        ],
      );

  /// The user's local date the actions are for (the server's stored zone).
  final String date;
  final String generatedAt;
  final String engineVersion;

  /// At most four, ranked.
  final List<TodayAction> actions;

  Map<String, dynamic> toJson() => {
        'date': date,
        'generatedAt': generatedAt,
        'engineVersion': engineVersion,
        'actions': [for (final a in actions) a.toJson()],
      };
}

/// `POST /v1/today/actions/{id}/event` body.
class TodayEventRequest {
  const TodayEventRequest({
    required this.clientEventId,
    required this.event,
    required this.occurredAt,
  });

  factory TodayEventRequest.fromJson(Map<String, dynamic> json) =>
      TodayEventRequest(
        clientEventId: json['clientEventId'] as String,
        event: TodayEventName.fromWire(json['event'] as String),
        occurredAt: json['occurredAt'] as String,
      );

  /// Minted once per event on this phone and reused for every retry (D9).
  final String clientEventId;
  final TodayEventName event;

  /// When it happened here (UTC ISO), not when it was delivered.
  final String occurredAt;

  Map<String, dynamic> toJson() => {
        'clientEventId': clientEventId,
        'event': event.wire,
        'occurredAt': occurredAt,
      };
}

/// The stored event the server answers with (201 new, 200 replay).
class TodayEventRecord {
  const TodayEventRecord({
    required this.id,
    required this.recommendationId,
    required this.event,
    required this.clientEventId,
    required this.occurredAt,
    required this.receivedAt,
  });

  factory TodayEventRecord.fromJson(Map<String, dynamic> json) {
    final e = (json['event'] as Map<String, dynamic>?) ?? json;
    return TodayEventRecord(
      id: e['id'] as String,
      recommendationId: e['recommendationId'] as String,
      event: TodayEventName.fromWire(e['event'] as String),
      clientEventId: e['clientEventId'] as String,
      occurredAt: e['occurredAt'] as String,
      receivedAt: e['receivedAt'] as String,
    );
  }

  final String id;
  final String recommendationId;
  final TodayEventName event;
  final String clientEventId;
  final String occurredAt;
  final String receivedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recommendationId': recommendationId,
        'event': event.wire,
        'clientEventId': clientEventId,
        'occurredAt': occurredAt,
        'receivedAt': receivedAt,
      };
}

/// What an event is about: the action's id, kind and subject.
class ActionRef {
  const ActionRef({
    required this.id,
    required this.kindWire,
    required this.subjectKey,
  });

  final String id;
  final String kindWire;
  final String subjectKey;

  TodayKind? get kind => TodayKind.fromWire(kindWire);
}

/// One event recorded on this phone for one action (the ledger).
class LedgerEntry {
  const LedgerEntry({
    required this.recommendationId,
    required this.event,
    required this.kind,
    required this.subjectKey,
    required this.localDate,
    required this.status,
  });

  final String recommendationId;
  final TodayEventName event;
  final String kind;
  final String subjectKey;
  final String localDate;

  /// `queued` | `sent` | `rejected` | `failed`.
  final String status;
}

/// Whether [next] may be recorded on this phone, given the events already
/// recorded here for the same action — the approved P2 state machine. Only
/// a guard against sending what the server would refuse; the server decides.
enum LocalTransition { record, duplicate, invalid }

LocalTransition localTransition(
  TodayKind kind,
  Set<TodayEventName> recorded,
  TodayEventName next,
) {
  bool has(TodayEventName e) => recorded.contains(e);
  if (has(next)) return LocalTransition.duplicate;
  if (next != TodayEventName.shown && !has(TodayEventName.shown)) {
    return LocalTransition.invalid;
  }
  switch (next) {
    case TodayEventName.shown:
      return LocalTransition.record;
    case TodayEventName.opened:
      return has(TodayEventName.dismissed)
          ? LocalTransition.invalid
          : LocalTransition.record;
    case TodayEventName.accepted:
      return has(TodayEventName.dismissed)
          ? LocalTransition.invalid
          : LocalTransition.record;
    case TodayEventName.dismissed:
      return has(TodayEventName.accepted) || has(TodayEventName.completed)
          ? LocalTransition.invalid
          : LocalTransition.record;
    case TodayEventName.completed:
      if (!kind.completable) return LocalTransition.invalid;
      if (has(TodayEventName.dismissed)) return LocalTransition.invalid;
      return has(TodayEventName.accepted)
          ? LocalTransition.record
          : LocalTransition.invalid;
  }
}
