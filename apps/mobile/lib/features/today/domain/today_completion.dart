import 'today.dart';

/// What the phone can see the SERVER already holds for one local day — the
/// same facts the server checks before it accepts `completed` (ADR-017, D7).
/// Read only from server answers (the day's session, the server's food day,
/// a weight the server just saved, the deload state), never from something
/// still waiting in a queue, so a `completed` is sent only once it can be
/// proven.
class CompletionEvidence {
  const CompletionEvidence({
    required this.date,
    this.sessionCompleted = false,
    this.sessionExerciseIds = const {},
    this.sessionPrimaryMuscles = const {},
    this.loggedSlots = const {},
    this.weighed = false,
    this.deloadActive = false,
    this.targetAdjusted = false,
  });

  /// The local date these facts are for.
  final String date;

  /// A session completed on [date] (`/training/today` `completedSessionId`).
  final bool sessionCompleted;

  /// Exercises and primary muscles of the session completed on [date].
  final Set<String> sessionExerciseIds;
  final Set<String> sessionPrimaryMuscles;

  /// Meals with a log in the server's day for [date].
  final Set<String> loggedSlots;

  /// A weight the server saved on [date].
  final bool weighed;

  /// The offered deload week was activated (Phase 6 accept).
  final bool deloadActive;

  /// Phase 12: the server holds a target row a calorie-adjust acceptance
  /// created, effective on [date].
  final bool targetAdjusted;
}

/// The actions accepted on this phone for [CompletionEvidence.date], not yet
/// completed, whose downstream flow the server now records as finished —
/// each a `completed` to send (never merely because it was accepted).
/// Informational kinds never appear (P4).
List<ActionRef> dueCompletions(
  Iterable<LedgerEntry> ledger,
  CompletionEvidence evidence,
) {
  final byAction = <String, List<LedgerEntry>>{};
  for (final e in ledger) {
    if (e.localDate != evidence.date) continue;
    (byAction[e.recommendationId] ??= []).add(e);
  }
  final out = <ActionRef>[];
  for (final entry in byAction.entries) {
    final events = entry.value;
    final first = events.first;
    final kind = TodayKind.fromWire(first.kind);
    if (kind == null || !kind.completable) continue;
    // Accepted here and still standing (a refused `accepted` is not one).
    final accepted = events.any(
      (e) =>
          e.event == TodayEventName.accepted &&
          (e.status == 'queued' || e.status == 'sent'),
    );
    if (!accepted) continue;
    if (events.any(
      (e) =>
          e.event == TodayEventName.completed ||
          e.event == TodayEventName.dismissed,
    )) {
      continue;
    }
    final subject = first.subjectKey;
    final proven = switch (kind) {
      TodayKind.startWorkout => evidence.sessionCompleted,
      TodayKind.progressLoad => evidence.sessionExerciseIds.contains(subject),
      TodayKind.muscleNeglected =>
        evidence.sessionPrimaryMuscles.contains(subject),
      TodayKind.eatProtein ||
      TodayKind.eatMeal =>
        evidence.loggedSlots.contains(subject),
      TodayKind.logWeight => evidence.weighed,
      TodayKind.deload => evidence.deloadActive,
      TodayKind.calorieAdjust => evidence.targetAdjusted,
      TodayKind.injuredLimitation ||
      TodayKind.restDay ||
      TodayKind.celebratePr =>
        false,
    };
    if (proven) {
      out.add(
        ActionRef(id: entry.key, kindWire: first.kind, subjectKey: subject),
      );
    }
  }
  return out;
}
