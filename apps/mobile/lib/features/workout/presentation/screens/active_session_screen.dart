import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../../training/domain/entities/program.dart';
import '../../domain/entities/workout.dart';
import '../controllers/rest_timer.dart';
import '../controllers/workout_providers.dart';
import '../widgets/rest_bar.dart';
import '../widgets/recommendation_sheet.dart';
import '../widgets/session_exercise_card.dart';
import '../widgets/sync_pill.dart';

/// The workout in progress (Phase 5). Reads from the phone's database and
/// writes to it; nothing here waits for the network. One tap logs a set
/// with the numbers it opened with (the plan's target, last time's weight);
/// editing first is a tap on the steppers. Leaving keeps the session; only
/// Finish or Discard ends it.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({required this.clientSessionId, super.key});

  final String clientSessionId;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  static const _uuid = Uuid();

  final Set<String> _expanded = <String>{};
  bool _expandedInitialised = false;

  /// Pending (not yet logged) values per exercise + row key.
  final Map<String, PlannedSet> _pending = {};

  /// Extra rows added with "+ Add set" beyond the plan, per exercise.
  final Map<String, int> _extraRows = {};

  /// Pending drop sets per exercise, keyed by the working set they follow.
  final Map<String, Set<int>> _pendingDrops = {};

  /// Rows the user reverted to last time's weight (owner 12.1), so the
  /// revert survives a rebuild without touching the server's prefill.
  final Set<String> _usedLast = <String>{};

  /// Client set ids that beat the prior best when logged (PR moment).
  final Set<String> _prSets = <String>{};

  Timer? _clock;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /* ------------------------------------------------------------ rows -- */

  /// The rows of an exercise: planned targets (or extras) as pending rows
  /// unless a logged set fills that index; logged drop sets and pending
  /// drop rows follow their working set.
  List<SessionSetRow> _rowsFor(SessionExercise x) {
    final logged = <int, SetLog>{
      for (final s in x.sets)
        if (s.setType == SetType.working) s.setIndex: s,
    };
    final maxLoggedIndex = logged.keys.fold(0, (m, i) => i > m ? i : m);
    final count = [
      x.targets.length + (_extraRows[x.clientExerciseId] ?? 0),
      maxLoggedIndex,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final rows = <SessionSetRow>[];
    PlannedSet? previous;
    for (var i = 1; i <= count; i++) {
      final done = logged[i];
      if (done != null) {
        final values = PlannedSet(
          setIndex: i,
          repsMin: done.reps,
          repsMax: done.reps,
          weightKg: done.weightKg,
          rir: done.rir ?? 0,
        );
        rows.add(
          SessionSetRow(
            setIndex: i,
            setType: SetType.working,
            values: values,
            logged: done,
          ),
        );
        previous = values;
      } else {
        final key = '${x.clientExerciseId}.$i.working';
        final target = i <= x.targets.length ? x.targets[i - 1] : null;
        final prefill = i <= x.prefill.length ? x.prefill[i - 1] : null;
        final values = _pending[key] ??
            (prefill != null
                ? PlannedSet(
                    id: target?.id,
                    setIndex: i,
                    repsMin: prefill.reps,
                    repsMax: prefill.reps,
                    weightKg: prefill.weightKg,
                    rir: prefill.rir,
                  )
                : target != null
                    ? PlannedSet(
                        id: target.id,
                        setIndex: i,
                        repsMin: target.repsMax,
                        repsMax: target.repsMax,
                        weightKg: target.weightKg,
                        rir: target.rir,
                      )
                    // Beyond the plan: copy the row above.
                    : (previous ??
                            const PlannedSet(
                              setIndex: 1,
                              repsMin: 10,
                              repsMax: 10,
                              weightKg: null,
                              rir: 1,
                            ))
                        .copyWith(id: null, setIndex: i));
        rows.add(
          SessionSetRow(
            setIndex: i,
            setType: SetType.working,
            values: values,
            plannedSetId: target?.id,
          ),
        );
        previous = values;
      }
      // Drop sets under this working set.
      for (final d in x.sets
          .where((s) => s.setType == SetType.drop && s.setIndex == i)) {
        rows.add(
          SessionSetRow(
            setIndex: i,
            setType: SetType.drop,
            values: PlannedSet(
              setIndex: i,
              repsMin: d.reps,
              repsMax: d.reps,
              weightKg: d.weightKg,
              rir: d.rir ?? 0,
            ),
            logged: d,
          ),
        );
      }
      if (_pendingDrops[x.clientExerciseId]?.contains(i) ?? false) {
        final key = '${x.clientExerciseId}.$i.drop';
        final base = previous;
        rows.add(
          SessionSetRow(
            setIndex: i,
            setType: SetType.drop,
            values:
                _pending[key] ?? base.copyWith(id: null, setIndex: i, rir: 0),
          ),
        );
      }
    }
    return rows;
  }

  /* --------------------------------------------------------- actions -- */

  Future<void> _log(SessionExercise x, SessionSetRow row) async {
    final repo = ref.read(workoutRepositoryProvider);
    final v = row.values;
    final clientSetId = _uuid.v4();
    await repo.logSet(
      widget.clientSessionId,
      LogSetInput(
        clientSetId: clientSetId,
        clientExerciseId: x.clientExerciseId,
        setIndex: row.setIndex,
        setType: row.setType,
        weightKg: v.weightKg,
        reps: v.repsMax,
        rir: v.rir,
        loggedAt: DateTime.now().toUtc().toIso8601String(),
        plannedSetId: row.plannedSetId,
      ),
    );
    setState(() {
      _pending.remove('${x.clientExerciseId}.${row.key}');
      if (row.setType == SetType.drop) {
        _pendingDrops[x.clientExerciseId]?.remove(row.setIndex);
      }
    });
    final rest = ref.read(restDefaultsProvider).forExercise(x);
    ref.read(restTimerProvider.notifier).start(rest, exerciseName: x.name);
    if (row.setType == SetType.working) _prMoment(x, v, clientSetId);
  }

  /// Phase 6 PR moment (plan §6): a working set that beats the prior best
  /// — heavier, or more reps at the best weight — gets a star on its check
  /// and "PR" on the header the moment it is logged. A comparison against
  /// two server-supplied numbers; the earlier sets of this session count
  /// too, so a tie never celebrates. Records proper are the server's, on
  /// completion.
  void _prMoment(SessionExercise x, PlannedSet v, String clientSetId) {
    final w = v.weightKg;
    if (w == null || w <= 0) return;
    var bestW = x.priorBest.weightKg;
    var bestReps = x.priorBest.repsAtBestWeight ?? 0;
    if (bestW == null) return; // establishing a baseline: nothing to beat
    for (final s in x.sets) {
      if (s.setType != SetType.working || s.weightKg == null) continue;
      if (s.clientSetId == clientSetId) continue;
      if (s.weightKg! > bestW! || (s.weightKg == bestW && s.reps > bestReps)) {
        bestW = s.weightKg;
        bestReps = s.reps;
      }
    }
    final beats = w > bestW! || (w == bestW && v.repsMax > bestReps);
    if (!beats) return;
    setState(() => _prSets.add(clientSetId));
  }

  /// Owner 12.1: put last time's weight on every pending working row.
  void _useLastWeight(SessionExercise x) {
    final last = SessionExerciseCard.lastWeightOf(x);
    if (last == null) return;
    setState(() {
      _usedLast.add(x.clientExerciseId);
      for (final row in _rowsFor(x)) {
        if (row.logged != null || row.setType != SetType.working) continue;
        _pending['${x.clientExerciseId}.${row.key}'] =
            row.values.copyWith(weightKg: last);
      }
    });
  }

  Future<void> _replace(SessionExercise x) async {
    final picked = await context.push<ExerciseSummary>(Routes.exercisePicker);
    if (picked == null || !mounted) return;
    await ref.read(workoutRepositoryProvider).updateExercise(
          widget.clientSessionId,
          x.clientExerciseId,
          replaceWith: picked,
        );
  }

  Future<void> _add() async {
    final picked = await context.push<ExerciseSummary>(Routes.exercisePicker);
    if (picked == null || !mounted) return;
    final id = await ref
        .read(workoutRepositoryProvider)
        .addExercise(widget.clientSessionId, picked);
    setState(() => _expanded.add(id));
  }

  Future<void> _finish(WorkoutSession s) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    ref.read(restTimerProvider.notifier).skip();
    await ref.read(workoutRepositoryProvider).complete(widget.clientSessionId);
    if (!mounted) return;
    context.go(Routes.sessionSummary(widget.clientSessionId));
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.paper,
        title: const Text('Discard this session?'),
        content: const Text(
          'It stays in your history as abandoned and never counts toward a record.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            key: const ValueKey('session.discard.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    ref.read(restTimerProvider.notifier).skip();
    await ref.read(workoutRepositoryProvider).abandon(widget.clientSessionId);
    if (mounted) context.go(Routes.plan);
  }

  Future<void> _leave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.paper,
        title: const Text('Leave the session?'),
        content: const Text(
          'Your sets are saved. Resume from the plan or TODAY whenever you are ready.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            key: const ValueKey('session.leave.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) context.popOrHome();
  }

  /* ----------------------------------------------------------- build -- */

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(sessionProvider(widget.clientSessionId));
    final session = async.value;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.popOrHome()),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Text(
              async.isLoading ? '' : 'This session is no longer on this phone.',
              style: textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }
    if (session.status != SessionStatus.active) {
      // Completed or discarded elsewhere on this phone: show the outcome.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(
          session.status == SessionStatus.completed
              ? Routes.sessionSummary(widget.clientSessionId)
              : Routes.plan,
        );
      });
    }
    if (!_expandedInitialised && session.exercises.isNotEmpty) {
      _expandedInitialised = true;
      final firstOpen = session.exercises.firstWhere(
        (x) =>
            x.sets.where((s) => s.setType == SetType.working).length <
                x.targets.length ||
            x.targets.isEmpty,
        orElse: () => session.exercises.first,
      );
      _expanded.add(firstOpen.clientExerciseId);
    }

    final repo = ref.read(workoutRepositoryProvider);
    final elapsed =
        DateTime.now().difference(DateTime.parse(session.startedAt));
    final planned =
        session.exercises.fold<int>(0, (n, x) => n + x.targets.length);
    final done = session.workingSetsLogged;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                // A session started inside an accepted deload week carries
                // the plan's originals on its exercises (Phase 6).
                session.exercises.any((x) => x.originalTargets != null)
                    ? 'DELOAD WEEK'
                    : 'SESSION',
                key: const ValueKey('session.kind'),
                style: textTheme.labelSmall?.copyWith(
                  color: session.exercises.any((x) => x.originalTargets != null)
                      ? FitColors.amber
                      : null,
                ),
              ),
              Text(
                session.name,
                key: const ValueKey('session.title'),
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: <Widget>[
            const SyncPill(),
            PopupMenuButton<String>(
              key: const ValueKey('session.menu'),
              icon: const Icon(Icons.more_horiz, color: FitColors.ink),
              onSelected: (v) {
                switch (v) {
                  case 'add':
                    _add();
                  case 'discard':
                    _discard();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'add', child: Text('Add exercise')),
                PopupMenuItem(value: 'discard', child: Text('Discard session')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            key: const ValueKey('session.list'),
            padding: const EdgeInsets.only(bottom: FitSpacing.xl),
            children: <Widget>[
              if (session.exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(FitSpacing.screen),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Nothing planned', style: textTheme.displaySmall),
                      const SizedBox(height: FitSpacing.sm),
                      Text(
                        'Add an exercise and log it as you go.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: FitSpacing.md),
                      OutlinedButton(
                        key: const ValueKey('session.addFirst'),
                        onPressed: _add,
                        child: const Text('Add exercise'),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < session.exercises.length; i++)
                _card(session, i, repo),
              if (session.exercises.isNotEmpty) ...<Widget>[
                const Divider(color: FitColors.rule, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FitSpacing.screen,
                    FitSpacing.md,
                    FitSpacing.screen,
                    0,
                  ),
                  child: TextButton(
                    key: const ValueKey('session.addExercise'),
                    onPressed: _add,
                    child: const Text('+ Add exercise'),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SessionFooter(
          elapsed: elapsed,
          done: done,
          planned: planned,
          finishing: _finishing,
          onFinish: () => _finish(session),
        ),
      ),
    );
  }

  /// The revert is offered when the rows opened on a recommendation that
  /// differs from last time's load, and the user has not reverted yet.
  bool _canUseLast(SessionExercise x) {
    if (_usedLast.contains(x.clientExerciseId)) return false;
    final last = SessionExerciseCard.lastWeightOf(x);
    if (last == null) return false;
    final first = x.prefill.isEmpty ? null : x.prefill.first;
    return first != null &&
        first.weightSource == 'recommendation' &&
        first.weightKg != last;
  }

  Widget _card(WorkoutSession session, int i, dynamic repo) {
    final x = session.exercises[i];
    final next =
        i + 1 < session.exercises.length ? session.exercises[i + 1] : null;
    final supersetWithNext =
        x.supersetGroup != null && next?.supersetGroup == x.supersetGroup;
    final lastWorking = x.sets
        .where((s) => s.setType == SetType.working)
        .fold<int>(0, (m, s) => s.setIndex > m ? s.setIndex : m);
    return SessionExerciseCard(
      key: ValueKey('card.${x.clientExerciseId}'),
      index: i + 1,
      exercise: x,
      rows: _rowsFor(x),
      expanded: _expanded.contains(x.clientExerciseId),
      supersetWithNext: supersetWithNext,
      canSuperset: next != null,
      onToggle: () => setState(() {
        if (!_expanded.remove(x.clientExerciseId)) {
          _expanded.add(x.clientExerciseId);
        }
      }),
      onPendingChanged: (row, values) =>
          setState(() => _pending['${x.clientExerciseId}.${row.key}'] = values),
      onLog: (row) => _log(x, row),
      onLoggedChanged: (set, values) =>
          ref.read(workoutRepositoryProvider).updateSet(
                widget.clientSessionId,
                set.clientSetId,
                reps: values.repsMax,
                weightKg: values.weightKg,
                weightCleared: values.weightKg == null && set.weightKg != null,
                rir: values.rir,
              ),
      onDeleteLogged: (set) => ref
          .read(workoutRepositoryProvider)
          .deleteSet(widget.clientSessionId, set.clientSetId),
      onAddSet: () => setState(
        () => _extraRows[x.clientExerciseId] =
            (_extraRows[x.clientExerciseId] ?? 0) + 1,
      ),
      onDropSet: lastWorking == 0
          ? null
          : () => setState(
                () => (_pendingDrops[x.clientExerciseId] ??= <int>{})
                    .add(lastWorking),
              ),
      onSupersetToggle: () async {
        final r = ref.read(workoutRepositoryProvider);
        if (supersetWithNext) {
          await r.updateExercise(
            widget.clientSessionId,
            x.clientExerciseId,
            supersetCleared: true,
          );
          await r.updateExercise(
            widget.clientSessionId,
            next!.clientExerciseId,
            supersetCleared: true,
          );
        } else {
          final group = i + 1;
          await r.updateExercise(
            widget.clientSessionId,
            x.clientExerciseId,
            supersetGroup: group,
          );
          await r.updateExercise(
            widget.clientSessionId,
            next!.clientExerciseId,
            supersetGroup: group,
          );
        }
      },
      onReplace: () => _replace(x),
      onRemove: () => ref.read(workoutRepositoryProvider).updateExercise(
            widget.clientSessionId,
            x.clientExerciseId,
            removed: true,
          ),
      onUseLastWeight: _canUseLast(x) ? () => _useLastWeight(x) : null,
      onRecommendationTap: () => RecommendationSheet.show(
        context,
        x,
        onUseLastWeight: _canUseLast(x) ? () => _useLastWeight(x) : null,
      ),
      prSetIds: _prSets,
    );
  }
}
