import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../today/presentation/today_providers.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../../workout/domain/entities/workout.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../../workout/presentation/widgets/start_session_button.dart';
import '../../../workout/presentation/widgets/deload_panel.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';
import '../widgets/day_selector.dart';
import '../widgets/exercise_card.dart';
import 'plan_start_screen.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../../shared/widgets/tap_through_scroll.dart';
import '../../../../core/config/app_features.dart';
import 'shared_programme_screen.dart';

part 'workout_week_day.dart';

/// The training plan, one day at a time (Phase 4 rework). A fixed day
/// selector on top; below it only the selected day: its name, its muscles,
/// its exercises as expandable cards with every set editable in place.
///
/// Editing is auto-saved: each change to a day is held as a draft and sent
/// as one PATCH after a short pause; leaving the screen flushes at once; a
/// failed save keeps the draft and shows Retry. Nothing is lost silently.
class WorkoutWeekScreen extends ConsumerStatefulWidget {
  const WorkoutWeekScreen({super.key});

  @override
  ConsumerState<WorkoutWeekScreen> createState() => _WorkoutWeekScreenState();
}

enum _SaveState { idle, saving, saved, failed }

class _WorkoutWeekScreenState extends ConsumerState<WorkoutWeekScreen> {
  static const _debounce = Duration(milliseconds: 900);

  int? _selectedDow;
  final Set<String> _expanded = <String>{};

  /// Unsaved edits per day id.
  final Map<String, List<PlannedExercise>> _drafts = {};
  final Map<String, int> _version = {};
  final Map<String, Timer> _timers = {};
  final Map<String, _SaveState> _saveState = {};
  final Map<String, Failure> _saveFailure = {};

  /// Captured while mounted: `ref` is not usable from dispose, and the
  /// flush-on-leave must still reach the server.
  ProgramController? _controller;

  @override
  void dispose() {
    // Leaving with edits pending: send them now, no waiting.
    for (final dayId in _drafts.keys.toList()) {
      _timers.remove(dayId)?.cancel();
      _flush(dayId, onDispose: true);
    }
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  /* ------------------------------------------------------------ drafts -- */

  List<PlannedExercise> _exercisesOf(ProgramDay day) =>
      _drafts[day.id] ?? day.exercises;

  void _edit(ProgramDay day, List<PlannedExercise> next, {bool now = false}) {
    setState(() {
      _drafts[day.id] = next;
      _version[day.id] = (_version[day.id] ?? 0) + 1;
      _saveState[day.id] = _SaveState.idle;
    });
    _timers.remove(day.id)?.cancel();
    if (now) {
      _flush(day.id);
    } else {
      _timers[day.id] = Timer(_debounce, () => _flush(day.id));
    }
  }

  Future<void> _flush(String dayId, {bool onDispose = false}) async {
    final draft = _drafts[dayId];
    if (draft == null) return;
    final version = _version[dayId] ?? 0;
    if (!onDispose) setState(() => _saveState[dayId] = _SaveState.saving);
    final ProgramController controller =
        _controller ?? ref.read(programControllerProvider.notifier);
    _controller = controller;
    final failure = await controller.patchDay(
      dayId,
      PatchProgramDayRequest(
        exercises: draft.map((x) => x.toCustom()).toList(),
      ),
    );
    if (onDispose || !mounted) return;
    setState(() {
      if (failure != null) {
        _saveState[dayId] = _SaveState.failed;
        _saveFailure[dayId] = failure;
        return;
      }
      _saveFailure.remove(dayId);
      // A newer edit arrived while saving: keep the draft, it will flush.
      if ((_version[dayId] ?? 0) == version) {
        _drafts.remove(dayId);
        _saveState[dayId] = _SaveState.saved;
      }
    });
  }

  void _setChanged(ProgramDay day, String exerciseId, PlannedSet set) {
    final next = [
      for (final x in _exercisesOf(day))
        if (x.id == exerciseId)
          x.copyWith(
            sets: [
              for (final s in x.sets) s.setIndex == set.setIndex ? set : s,
            ],
          )
        else
          x,
    ];
    _edit(day, next);
  }

  /// Set-count editing (Phase 5 carry-over): one more set copying the
  /// last one's targets, or one fewer; renumbered, saved like any edit.
  void _addSet(ProgramDay day, String exerciseId) {
    final next = [
      for (final x in _exercisesOf(day))
        if (x.id == exerciseId && x.sets.length < 10)
          x.copyWith(
            setCount: x.sets.length + 1,
            sets: [
              ...x.sets,
              x.sets.last.copyWith(id: null, setIndex: x.sets.length + 1),
            ],
          )
        else
          x,
    ];
    _edit(day, next);
  }

  void _removeSet(ProgramDay day, String exerciseId, int setIndex) {
    final next = [
      for (final x in _exercisesOf(day))
        if (x.id == exerciseId && x.sets.length > 1)
          x.copyWith(
            setCount: x.sets.length - 1,
            sets: [
              for (final (i, s)
                  in x.sets.where((s) => s.setIndex != setIndex).indexed)
                s.copyWith(setIndex: i + 1),
            ],
          )
        else
          x,
    ];
    _edit(day, next);
  }

  void _remove(ProgramDay day, String exerciseId) {
    final next = _exercisesOf(day).where((x) => x.id != exerciseId).toList();
    if (next.isEmpty) return; // a session keeps at least one exercise
    _edit(day, next, now: true);
  }

  /// Phase 6 (§12.6): accept the server's substitution. The same Phase 4
  /// PATCH as Replace — the row keeps its id and prescription, takes the
  /// alternative's movement, and its weights go back to unknown. The
  /// server re-joins the catalogue from `exerciseId`, so pattern and
  /// muscles follow.
  Future<void> _substitute(
    ProgramDay day,
    PlannedExercise old,
    SubstitutionAlternative alt,
  ) async {
    final next = [
      for (final x in _exercisesOf(day))
        if (x.id == old.id)
          old.copyWith(
            exerciseId: alt.exerciseId,
            slug: alt.slug,
            name: alt.name,
            equipment: alt.equipment,
            reason: null,
            sets: [for (final s in old.sets) s.copyWith(weightKg: null)],
          )
        else
          x,
    ];
    setState(() {
      _drafts[day.id] = next;
      _version[day.id] = (_version[day.id] ?? 0) + 1;
      _saveState[day.id] = _SaveState.idle;
    });
    _timers.remove(day.id)?.cancel();
    await _flush(day.id);
    if (!mounted) return;
    // The server's view of the day (and TODAY) now shows the new lift.
    ref.invalidate(dayProvider(day.dayOfWeek));
    ref.invalidate(todayProvider);
  }

  Future<void> _replace(ProgramDay day, PlannedExercise old) async {
    final picked = await context.push<ExerciseSummary>(Routes.exercisePicker);
    if (picked == null || !mounted) return;
    final next = [
      for (final x in _exercisesOf(day))
        if (x.id == old.id)
          // Same prescription, the new movement, weights back to unknown.
          old.copyWith(
            exerciseId: picked.id,
            slug: picked.slug,
            name: picked.name,
            movementPattern: picked.movementPattern,
            equipment: picked.equipment,
            difficulty: picked.difficulty,
            isUnilateral: picked.isUnilateral,
            primaryMuscles: picked.primaryMuscles,
            reason: null,
            sets: [for (final s in old.sets) s.copyWith(weightKg: null)],
          )
        else
          x,
    ];
    _edit(day, next, now: true);
  }

  /* -------------------------------------------------------------- build -- */

  int _defaultDay(Program p) {
    final today = DateTime.now().weekday; // ISO, 1 = Monday
    final training = p.days.where((d) => !d.isRest).map((d) => d.dayOfWeek);
    if (training.contains(today)) return today;
    // Next training day after today, wrapping.
    for (var i = 1; i <= 7; i++) {
      final dow = ((today - 1 + i) % 7) + 1;
      if (training.contains(dow)) return dow;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    _controller = ref.read(programControllerProvider.notifier);
    final async = ref.watch(programControllerProvider);
    return async.when(
      loading: () => const Scaffold(
        body: FitBackdrop(
          child: SafeArea(child: _WeekSkeleton()),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: FitBackdrop(
          child: SafeArea(
            child: _Failed(
              failure: e is Failure ? e : const Unknown(),
              onRetry: () => ref.invalidate(programControllerProvider),
            ),
          ),
        ),
      ),
      data: (program) {
        if (program == null) return const PlanStartScreen();
        final selected = _selectedDow ??= _defaultDay(program);
        final day = program.days.firstWhere((d) => d.dayOfWeek == selected);
        // ADR-030: today can be skipped once; then it shows as skipped.
        final todayDow = DateTime.now().weekday;
        final skippedToday = program.skippedOn == ref.watch(localTodayProvider);
        final todayDay =
            program.days.firstWhere((d) => d.dayOfWeek == todayDow);
        final canSkip = !skippedToday && !todayDay.isRest;
        // Beta 3.3 (ADR-034): sharing, behind the admin's switch.
        final shareOn = ref.watch(featureOnProvider(AppFeature.shareProgramme));
        // Phase 6: the server's view of this day (deload state, per-lift
        // substitutions). Absent offline — the plan still renders.
        final serverDay =
            day.isRest ? null : ref.watch(dayProvider(day.dayOfWeek)).value;
        final phase6 = serverDay != null && serverDay.programDayId == day.id
            ? serverDay
            : null;
        return Scaffold(
          // The Training tab's root: no back button (the bar and Android
          // back handle leaving); the title carries the programme.
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: FitSpacing.screen,
            title: _Title(program: program),
            actions: <Widget>[
              PopupMenuButton<String>(
                key: const ValueKey('plan.menu'),
                icon: Icon(Icons.more_horiz, color: FitColors.ink),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push(Routes.planDayEdit(day.id));
                    case 'change':
                      context.push(Routes.planNew);
                    case 'rename':
                      _rename(context, program);
                    case 'history':
                      context.push(Routes.history);
                    case 'volume':
                      context.push(Routes.volume);
                    case 'adhoc':
                      _start(program, null);
                    case 'skip':
                      _skip(program, todayDay);
                    case 'share':
                      shareProgramme(context, ref);
                    case 'shared':
                      context.push(Routes.planShared);
                  }
                },
                itemBuilder: (_) => [
                  if (canSkip)
                    const PopupMenuItem(
                      key: ValueKey('plan.skip'),
                      value: 'skip',
                      child: Text('Skip today'),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit this day'),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Text('History'),
                  ),
                  const PopupMenuItem(value: 'volume', child: Text('Volume')),
                  const PopupMenuItem(
                    value: 'adhoc',
                    child: Text('Start empty session'),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename programme'),
                  ),
                  const PopupMenuItem(
                    value: 'change',
                    child: Text('Change programme'),
                  ),
                  // Beta 3.3 (ADR-034), behind the admin's switch.
                  if (shareOn) ...[
                    const PopupMenuItem(
                      key: ValueKey('plan.share'),
                      value: 'share',
                      child: Text('Share programme'),
                    ),
                    const PopupMenuItem(
                      key: ValueKey('plan.useShared'),
                      value: 'shared',
                      child: Text('Use a shared programme'),
                    ),
                  ],
                ],
              ),
            ],
          ),
          body: FitBackdrop(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  DaySelector(
                    days: program.days,
                    selected: selected,
                    onSelect: (dow) => setState(() => _selectedDow = dow),
                  ),
                  Expanded(
                    child: skippedToday && selected == todayDow
                        ? _SkippedToday(
                            tomorrow: program.days.firstWhere(
                              (d) => d.dayOfWeek == (todayDow % 7) + 1,
                            ),
                            onUndo: _undoSkip,
                          )
                        : _DayView(
                            key: ValueKey('day.${day.id}'),
                            day: day,
                            exercises: _exercisesOf(day),
                            startButton: StartSessionButton(
                              dayOfWeek: day.dayOfWeek,
                              isRest: day.isRest,
                              onStart: () => _start(program, day),
                              completedSessionId: selected == todayDow
                                  ? phase6?.completedSessionId
                                  : null,
                            ),
                            last: {
                              if (phase6 != null)
                                for (final x in phase6.exercises)
                                  if (x.lastPerformance != null)
                                    x.plannedExerciseId: x.lastPerformance!,
                            },
                            onAddSet: (id) => _addSet(day, id),
                            onRemoveSet: (id, i) => _removeSet(day, id, i),
                            expanded: _expanded,
                            saveState: _saveState[day.id] ?? _SaveState.idle,
                            saveFailure: _saveFailure[day.id],
                            onToggle: (id) => setState(() {
                              if (!_expanded.remove(id)) _expanded.add(id);
                            }),
                            onSetChanged: (id, set) =>
                                _setChanged(day, id, set),
                            onRemove: (id) => _remove(day, id),
                            onReplace: (x) => _replace(day, x),
                            onRetry: () => _flush(day.id),
                            onEditDay: () =>
                                context.push(Routes.planDayEdit(day.id)),
                            deload: phase6?.deload,
                            mesocycleWeek: phase6?.mesocycleWeek,
                            substitutions: {
                              if (phase6 != null)
                                for (final x in phase6.exercises)
                                  if (x.substitution != null)
                                    x.plannedExerciseId: x.substitution!,
                            },
                            onSubstitute: (x, alt) => _substitute(day, x, alt),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Start (or resume) a session. Seeds from the server's day when it can
  /// be reached (targets + last performance), else from the plan itself —
  /// so a session starts in a gym with no signal.
  Future<void> _start(Program program, ProgramDay? day) async {
    final repo = ref.read(workoutRepositoryProvider);
    final active = await repo.activeSession();
    if (!mounted) return;
    if (active != null) {
      await context.push(Routes.session(active.clientSessionId));
      return;
    }
    TodayResponse? seed;
    if (day != null && !day.isRest) {
      final fetched = await repo.today(dayOfWeek: day.dayOfWeek);
      seed = fetched.when(
        ok: (t) => t.programDayId == day.id ? t : null,
        err: (_) => null,
      );
      seed ??= todayFromPlan(program, day);
    }
    final session = await repo.startSession(day: seed);
    if (!mounted) return;
    await context.push(Routes.session(session.clientSessionId));
  }

  /// ADR-030: skip today — confirm, then every day moves one day later.
  Future<void> _skip(Program program, ProgramDay today) async {
    final tomorrowDow = (today.dayOfWeek % 7) + 1;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('skip.dialog'),
        title: const Text('Skip today?'),
        content: Text(
          '${today.sessionName} moves to tomorrow, and every day after it '
          'moves one day later — rest days too. Your week keeps its order; '
          'it just starts a day later from here.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('skip.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Skip today'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final failure = await _controller!.skipToday();
    if (!mounted) return;
    _refreshToday();
    final messenger = ScaffoldMessenger.of(context);
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    setState(() => _selectedDow = DateTime.now().weekday);
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('skip.done'),
        content: Text(
          'Skipped. ${today.sessionName} is tomorrow '
          '(${kWeekdayLabels[tomorrowDow - 1]}).',
        ),
        action: SnackBarAction(label: 'Undo', onPressed: _undoSkip),
      ),
    );
  }

  Future<void> _undoSkip() async {
    final failure = await _controller!.undoSkip();
    if (!mounted) return;
    _refreshToday();
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  /// Home and TODAY read today from the server: refetch after a skip.
  void _refreshToday() {
    ref
      ..invalidate(todayProvider)
      ..invalidate(dayProvider)
      ..invalidate(todayPlanProvider);
  }

  Future<void> _rename(BuildContext context, Program program) async {
    final controller = TextEditingController(text: program.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.paper,
        title: const Text('Rename programme'),
        content:
            TextField(controller: controller, autofocus: true, maxLength: 60),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == program.name) return;
    await ref.read(programControllerProvider.notifier).rename(name);
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          program.name,
          style: textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${program.source.label.toUpperCase()} · WEEK ${program.mesocycleWeek}',
          style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
        ),
      ],
    );
  }
}
