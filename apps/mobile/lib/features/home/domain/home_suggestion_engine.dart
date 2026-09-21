import '../../health/domain/entities/health.dart';
import '../../workout/domain/entities/workout.dart';
import 'home_context.dart';

/// Phase 6.5 — "what should I do next?", deterministically. Twelve rules
/// over [HomeContext], each with a fixed priority band taken from
/// MASTER-SPEC §16.1 so the ordering matches the Phase 11 engine's
/// intent; ties keep rule order. No LLM, no score shown to the user —
/// the priority only orders. Every suggestion carries the reason it
/// fired. Rules never fire on missing data: no steps → no movement card,
/// no sleep → no recovery card, nothing logged → no food card.
class HomeSuggestionEngine {
  const HomeSuggestionEngine();

  /// The sleep below which the recovery card appears (owner D5).
  static const lowSleepMinutes = 6 * 60;

  /// Movement (owner D4): under half the goal after 15:00, or under the
  /// goal after 19:00.
  static const moveAfterHour = 15;
  static const moveLateHour = 19;

  /// The whole ordered list; the screen splits it into the carousel and
  /// "More for you" with [carousel] / [more].
  List<Suggestion> evaluate(HomeContext c) {
    final out = <Suggestion>[
      ...?_deload(c),
      ...?_resume(c),
      ...?_start(c),
      ...?_protein(c),
      ...?_calories(c),
      ...?_done(c),
      ...?_neglect(c),
      ...?_recover(c),
      ...?_restDay(c),
      ...?_pr(c),
      ...?_volume(c),
      ...?_move(c),
      ...?_connect(c),
    ];
    // Stable: equal priorities keep the rule order above.
    final indexed = out.indexed.toList()
      ..sort((a, b) {
        final p = b.$2.priority.compareTo(a.$2.priority);
        return p != 0 ? p : a.$1.compareTo(b.$1);
      });
    return [for (final (_, s) in indexed) s];
  }

  /// The top of the list that belongs in the carousel (at most four).
  static List<Suggestion> carousel(List<Suggestion> all) =>
      all.where((s) => s.surface == SuggestionSurface.primary).take(4).toList();

  /// Everything else, for "More for you" (at most five).
  static List<Suggestion> more(List<Suggestion> all) {
    final shown = carousel(all).toSet();
    return all.where((s) => !shown.contains(s)).take(5).toList();
  }

  /* --------------------------------------------------------- rules -- */

  // 10. Deload offered → 95 (§16.1: never buried under a meal tip).
  List<Suggestion>? _deload(HomeContext c) {
    final d = c.today?.deload;
    if (d == null || d.state != DeloadStatus.offered) return null;
    return [
      Suggestion(
        id: 'deload',
        type: SuggestionType.deload,
        priority: 95,
        title: 'Take a lighter week?',
        subtitle: d.reason,
        reason:
            'A deload has been offered on your programme. It is never applied until you accept it.',
        action: SuggestionAction.viewPlan,
      ),
    ];
  }

  // 1. Active workout → resume.
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

  // 2. Scheduled workout not started → start (§16.1 90).
  List<Suggestion>? _start(HomeContext c) {
    final t = c.today;
    if (t == null || t.isRest || c.activeSession != null) return null;
    if (t.completedSessionId != null || c.completedToday != null) return null;
    final sets = t.exercises.fold<int>(0, (n, x) => n + x.targets.length);
    final minutes = (sets * 3.5).round();
    return [
      Suggestion(
        id: 'start',
        type: SuggestionType.startWorkout,
        priority: 90,
        title: '${t.sessionName ?? 'Session'} is ready',
        subtitle: '${t.exercises.length} movements · ~$minutes min',
        reason: "Today's session on your programme has not been started.",
        action: SuggestionAction.startWorkout,
      ),
    ];
  }

  // 4. Protein well below target with the day left → 88 (§16.1).
  List<Suggestion>? _protein(HomeContext c) {
    final n = c.nutrition;
    final target = c.targets?.proteinG;
    if (!n.logged || n.proteinG == null || target == null) return null;
    if (c.hourOfDay >= 22) return null;
    final left = target - n.proteinG!;
    if (n.proteinG! >= target * 0.75) return null;
    return [
      Suggestion(
        id: 'eat-protein',
        type: SuggestionType.eatProtein,
        priority: 88,
        title: '$left g protein left today',
        subtitle: 'Your next meal can close the gap',
        reason:
            'Protein logged is below 75% of your $target g target with the day still ahead.',
        action: SuggestionAction.logFood,
      ),
    ];
  }

  // 5. Calories left with protein on track → 75 (§16.1 eat-meal; XOR protein).
  List<Suggestion>? _calories(HomeContext c) {
    final n = c.nutrition;
    final t = c.targets;
    if (!n.logged || n.kcal == null || t == null) return null;
    if (c.hourOfDay >= 22) return null;
    final proteinOk = n.proteinG != null && n.proteinG! >= t.proteinG * 0.75;
    final left = t.kcal - n.kcal!;
    if (!proteinOk || left <= 250) return null;
    return [
      Suggestion(
        id: 'eat-meal',
        type: SuggestionType.eatCalories,
        priority: 75,
        title: '$left kcal left today',
        subtitle: 'Protein is on track — a normal meal fits',
        reason:
            'More than 250 kcal of your ${t.kcal} kcal target remain and protein is on track.',
        action: SuggestionAction.logFood,
      ),
    ];
  }

  // 3. Workout completed → summary / recovery context.
  List<Suggestion>? _done(HomeContext c) {
    final s = c.completedToday;
    final id = s?.id ?? c.today?.completedSessionId;
    if (id == null || c.activeSession != null) return null;
    final prs = s?.summary?.prs.length ?? 0;
    return [
      Suggestion(
        id: 'done',
        type: SuggestionType.workoutDone,
        priority: 70,
        title: '${s?.name ?? c.today?.sessionName ?? 'Session'} done',
        subtitle: s?.summary == null
            ? 'See the summary'
            : '${s!.summary!.workingSets} sets · ${_kg(s.summary!.tonnageKg)} kg moved${prs > 0 ? ' · $prs record${prs == 1 ? '' : 's'}' : ''}',
        reason: "Today's session is complete; the rest of the day is recovery.",
        action: SuggestionAction.viewSummary,
        metadata: {'sessionId': id},
      ),
    ];
  }

  // 9. Neglected muscles → 68 (§16.1 muscle-neglected).
  List<Suggestion>? _neglect(HomeContext c) {
    final n = c.today?.neglected ?? const [];
    if (n.isEmpty) return null;
    final first = n.first;
    final names = n.map((m) => m.muscle.label).join(', ');
    return [
      Suggestion(
        id: 'neglect',
        type: SuggestionType.neglect,
        priority: 68,
        title: n.length == 1
            ? '${first.muscle.label} has been waiting'
            : '$names have been waiting',
        subtitle: first.daysSince == null
            ? 'No working set yet this block'
            : '${first.daysSince} days since a working set',
        reason:
            'Muscles your programme owns have had no working set in six days.',
        action: SuggestionAction.viewPlan,
      ),
    ];
  }

  // 7. Sleep available and meaningfully low → 65 (owner D5, advisory).
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

  // §16.2: a rest day is never a shrug → 60.
  List<Suggestion>? _restDay(HomeContext c) {
    final t = c.today;
    if (t == null || !t.isRest || c.activeSession != null) return null;
    // §16.1: deload suppresses rest-day.
    if (t.deload.state == DeloadStatus.offered) return null;
    return [
      Suggestion(
        id: 'rest-day',
        type: SuggestionType.restDay,
        priority: 60,
        title: 'Rest day',
        subtitle: t.programId == null
            ? 'No programme yet'
            : 'Recovery is part of the programme',
        reason: 'Nothing is scheduled today.',
        action: SuggestionAction.viewPlan,
      ),
    ];
  }

  // 11. New PR today → 50 (§16.1 celebrate-pr).
  List<Suggestion>? _pr(HomeContext c) {
    final prs = c.completedToday?.summary?.prs ?? const <PersonalRecord>[];
    if (prs.isEmpty) return null;
    final best = prs.first;
    return [
      Suggestion(
        id: 'pr',
        type: SuggestionType.celebratePr,
        priority: 50,
        title: 'New record on ${best.exerciseName}',
        subtitle: best.reason,
        reason: '${prs.length} record${prs.length == 1 ? '' : 's'} set today.',
        action: SuggestionAction.viewSummary,
        metadata: {'sessionId': c.completedToday!.id},
      ),
    ];
  }

  // 12. Volume needs attention → 45.
  List<Suggestion>? _volume(HomeContext c) {
    final v = c.volume;
    if (v == null || v.weeks.isEmpty) return null;
    final week = v.weeks.last;
    MuscleWeek? pick(LandmarkStatus s) {
      for (final m in week.muscles) {
        if (m.owned && m.status == s) return m;
      }
      return null;
    }

    final atMrv = pick(LandmarkStatus.atMrv);
    if (atMrv != null) {
      return [
        Suggestion(
          id: 'volume',
          type: SuggestionType.volume,
          priority: 45,
          title: '${atMrv.muscle.label} is at its ceiling',
          subtitle: '${_sets(atMrv.hardSets)} sets this week',
          reason:
              'A muscle your programme owns is at its maximum recoverable volume.',
          action: SuggestionAction.viewVolume,
          surface: SuggestionSurface.secondary,
        ),
      ];
    }
    return null;
  }

  // 6. Steps well below the goal late in the day → 40 (§16.1 add-steps).
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

  // 8. Health Connect available but not connected → 35.
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
        surface: SuggestionSurface.secondary,
      ),
    ];
  }

  /* -------------------------------------------------------- format -- */

  static String _hm(int minutes) =>
      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  static String _sets(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
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
  deload,
  resumeWorkout,
  startWorkout,
  workoutDone,
  eatProtein,
  eatCalories,
  neglect,
  recover,
  restDay,
  celebratePr,
  volume,
  move,
  connectHealth,
}

/// Where a suggestion can sit: the carousel, or only "More for you".
enum SuggestionSurface { primary, secondary }

enum SuggestionAction {
  resumeWorkout,
  startWorkout,
  viewSummary,
  viewPlan,
  logFood,
  viewActivity,
  viewRecovery,
  viewVolume,
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
    this.surface = SuggestionSurface.primary,
    this.metadata = const {},
  });

  final String id;
  final SuggestionType type;

  /// Orders only; never shown.
  final int priority;
  final String title;
  final String subtitle;

  /// Why it fired — always present.
  final String reason;
  final SuggestionAction action;
  final SuggestionSurface surface;
  final Map<String, String> metadata;

  @override
  String toString() => 'Suggestion($id, $priority)';
}
