import '../../health/domain/entities/health.dart';
import '../../today/domain/today.dart';
import 'home_context.dart';

/// Phase 6.5, shrunk by Phase 11 (ADR-017, D2/D13): the rules that need data
/// only this phone has — the session open here, Health Connect sleep and
/// steps, the Health Connect connection. Every other "what next?" decision
/// (deload, start, eat, progress, neglect, rest day, records, weigh-in,
/// injured limitation) is the SERVER's TODAY plan; the old device copies of
/// those, and the Home-only "done" and "volume" cards, are gone (P6).
/// Deterministic, no LLM; the priority only orders and is never shown;
/// rules never fire on missing data.
class HomeSuggestionEngine {
  const HomeSuggestionEngine();

  /// The sleep below which the recovery card appears (owner D5).
  static const lowSleepMinutes = 6 * 60;

  /// Movement (owner D4): under half the goal after 15:00, or under the
  /// goal after 19:00.
  static const moveAfterHour = 15;
  static const moveLateHour = 19;

  /// The most "next move" cards Home shows (§16.1).
  static const maxCards = 4;

  /// The device-only suggestions, ordered by band (ties keep rule order).
  List<Suggestion> evaluate(HomeContext c) {
    final out = <Suggestion>[
      ...?_resume(c),
      ...?_recover(c),
      ...?_move(c),
      ...?_connect(c),
    ];
    final indexed = out.indexed.toList()
      ..sort((a, b) {
        final p = b.$2.priority.compareTo(a.$2.priority);
        return p != 0 ? p : a.$1.compareTo(b.$1);
      });
    return [for (final (_, s) in indexed) s];
  }

  /// "Your next move": the server's TODAY actions and the device-only
  /// suggestions in one list by band — ties to the server's actions first
  /// (in the server's rank order), then the device rules' order — capped at
  /// four (plan §6). While a session is open on this phone the server's
  /// "start" card gives way to "resume": the session it asks for is running.
  static List<Suggestion> merge(
    List<TodayAction> server,
    List<Suggestion> device, {
    required String planDate,
    bool cached = false,
  }) {
    final sessionOpen =
        device.any((s) => s.type == SuggestionType.resumeWorkout);
    final fromServer = <Suggestion>[
      for (final a in [...server]..sort((x, y) => x.rank.compareTo(y.rank)))
        if (a.kind != null &&
            !(sessionOpen && a.kind == TodayKind.startWorkout))
          Suggestion.today(a, planDate: planDate, cached: cached),
    ];
    final all = [
      for (final (i, s) in fromServer.indexed) (s, 0, i),
      for (final (i, s) in device.indexed) (s, 1, i),
    ]..sort((a, b) {
        final p = b.$1.priority.compareTo(a.$1.priority);
        if (p != 0) return p;
        final side = a.$2.compareTo(b.$2);
        return side != 0 ? side : a.$3.compareTo(b.$3);
      });
    return [for (final (s, _, _) in all) s].take(maxCards).toList();
  }

  /* --------------------------------------------------------- rules -- */

  // Active workout on this phone → resume (92).
  List<Suggestion>? _resume(HomeContext c) {
    final s = c.activeSession;
    if (s == null) return null;
    return [
      Suggestion(
        id: 'resume',
        type: SuggestionType.resumeWorkout,
        priority: 92,
        title: '${s.name} is in progress',
        subtitle: '${s.workingSetsLogged} sets logged',
        reason: 'A session is open on this phone.',
        action: SuggestionAction.resumeWorkout,
        metadata: {'clientSessionId': s.clientSessionId},
      ),
    ];
  }

  // Sleep available and meaningfully low → 65 (owner D5, advisory).
  List<Suggestion>? _recover(HomeContext c) {
    final sleep = c.health?.sleep;
    if (sleep == null || !sleep.isAvailable) return null;
    final minutes = sleep.value!.round();
    if (minutes >= lowSleepMinutes) return null;
    return [
      Suggestion(
        id: 'recover',
        type: SuggestionType.recover,
        priority: 65,
        title: 'Sleep was ${_hm(minutes)}',
        subtitle: c.today?.isRest == false
            ? "Keep today's session controlled"
            : 'An easy day is a good day',
        reason: 'Last night was under six hours.',
        action: SuggestionAction.viewRecovery,
      ),
    ];
  }

  // Steps well below the goal late in the day → 40 (device only: the
  // server never sees steps).
  List<Suggestion>? _move(HomeContext c) {
    final steps = c.health?.steps;
    if (steps == null || !steps.isAvailable) return null;
    final n = steps.value!.round();
    final goal = c.stepGoal;
    final late = c.hourOfDay >= moveLateHour && n < goal;
    final afternoon = c.hourOfDay >= moveAfterHour && n < goal / 2;
    if (!late && !afternoon) return null;
    final left = goal - n;
    final minutes = (left / 100).ceil(); // an easy walk, ~100 steps a minute
    return [
      Suggestion(
        id: 'move',
        type: SuggestionType.move,
        priority: 40,
        title: "You're ${_group(left)} steps from your goal",
        subtitle: 'An easy $minutes-minute walk gets you there',
        reason: '${_group(n)} of ${_group(goal)} steps by ${c.hourOfDay}:00.',
        action: SuggestionAction.viewActivity,
      ),
    ];
  }

  // Health Connect available but not connected → 35 (P6: competes by band).
  List<Suggestion>? _connect(HomeContext c) {
    final conn = c.connection;
    if (conn == null || conn.sdk != HealthSdkStatus.available) return null;
    if (conn.isConnected) return null;
    return [
      const Suggestion(
        id: 'connect-health',
        type: SuggestionType.connectHealth,
        priority: 35,
        title: 'Connect Health data',
        subtitle: 'Steps, sleep and weight next to your training',
        reason:
            'Health Connect is on this phone but FITOS has no permissions yet.',
        action: SuggestionAction.connectHealth,
      ),
    ];
  }

  /* -------------------------------------------------------- format -- */

  static String _hm(int minutes) =>
      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  static String _group(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

enum SuggestionType {
  /// One of the server's TODAY actions (its kind is on [Suggestion.today]).
  today,
  resumeWorkout,
  recover,
  move,
  connectHealth,
}

enum SuggestionAction {
  /// The server action's own destination (by kind).
  today,
  resumeWorkout,
  viewActivity,
  viewRecovery,
  connectHealth,
}

class Suggestion {
  const Suggestion({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.action,
    this.metadata = const {},
    this.today,
    this.planDate,
    this.cached = false,
  });

  /// A server TODAY action as a card: its kind is the id, its headline and
  /// detail the words, its priority the band.
  factory Suggestion.today(
    TodayAction a, {
    required String planDate,
    bool cached = false,
  }) =>
      Suggestion(
        id: a.kindWire,
        type: SuggestionType.today,
        priority: a.priority,
        title: a.headline,
        subtitle: a.detail,
        reason: a.detail,
        action: SuggestionAction.today,
        today: a,
        planDate: planDate,
        cached: cached,
      );

  final String id;
  final SuggestionType type;

  /// Orders only; never shown.
  final int priority;
  final String title;
  final String subtitle;

  /// Why it fired — always present.
  final String reason;
  final SuggestionAction action;
  final Map<String, String> metadata;

  /// The server action this card draws; null for a device-only card.
  final TodayAction? today;

  /// The server plan's local date (events belong to it).
  final String? planDate;

  /// From the cached plan, shown while offline (D8 as amended): labelled so.
  final bool cached;

  bool get isServer => today != null;

  @override
  String toString() => 'Suggestion($id, $priority)';
}
