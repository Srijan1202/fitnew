import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../../workout/domain/entities/workout.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../../workout/presentation/widgets/start_session_button.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';
import '../widgets/day_selector.dart';
import '../widgets/exercise_card.dart';
import 'plan_start_screen.dart';

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
      loading: () => const Scaffold(body: SafeArea(child: _WeekSkeleton())),
      error: (e, _) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SafeArea(
          child: _Failed(
            failure: e is Failure ? e : const Unknown(),
            onRetry: () => ref.invalidate(programControllerProvider),
          ),
        ),
      ),
      data: (program) {
        if (program == null) return const PlanStartScreen();
        final selected = _selectedDow ??= _defaultDay(program);
        final day = program.days.firstWhere((d) => d.dayOfWeek == selected);
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
                icon: const Icon(Icons.more_horiz, color: FitColors.ink),
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
                    case 'adhoc':
                      _start(program, null);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit this day')),
                  PopupMenuItem(value: 'history', child: Text('History')),
                  PopupMenuItem(
                    value: 'adhoc',
                    child: Text('Start empty session'),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename programme'),
                  ),
                  PopupMenuItem(
                    value: 'change',
                    child: Text('Change programme'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                DaySelector(
                  days: program.days,
                  selected: selected,
                  onSelect: (dow) => setState(() => _selectedDow = dow),
                ),
                Expanded(
                  child: _DayView(
                    key: ValueKey('day.${day.id}'),
                    day: day,
                    exercises: _exercisesOf(day),
                    startButton: StartSessionButton(
                      dayOfWeek: day.dayOfWeek,
                      isRest: day.isRest,
                      onStart: () => _start(program, day),
                    ),
                    onAddSet: (id) => _addSet(day, id),
                    onRemoveSet: (id, i) => _removeSet(day, id, i),
                    expanded: _expanded,
                    saveState: _saveState[day.id] ?? _SaveState.idle,
                    saveFailure: _saveFailure[day.id],
                    onToggle: (id) => setState(() {
                      if (!_expanded.remove(id)) _expanded.add(id);
                    }),
                    onSetChanged: (id, set) => _setChanged(day, id, set),
                    onRemove: (id) => _remove(day, id),
                    onReplace: (x) => _replace(day, x),
                    onRetry: () => _flush(day.id),
                    onEditDay: () => context.push(Routes.planDayEdit(day.id)),
                  ),
                ),
              ],
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

/* --------------------------------------------------------------- day -- */

class _DayView extends StatelessWidget {
  const _DayView({
    required this.day,
    required this.exercises,
    required this.startButton,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.expanded,
    required this.saveState,
    required this.saveFailure,
    required this.onToggle,
    required this.onSetChanged,
    required this.onRemove,
    required this.onReplace,
    required this.onRetry,
    required this.onEditDay,
    super.key,
  });

  final ProgramDay day;
  final List<PlannedExercise> exercises;
  final Widget startButton;
  final ValueChanged<String> onAddSet;
  final void Function(String exerciseId, int setIndex) onRemoveSet;
  final Set<String> expanded;
  final _SaveState saveState;
  final Failure? saveFailure;
  final ValueChanged<String> onToggle;
  final void Function(String exerciseId, PlannedSet set) onSetChanged;
  final ValueChanged<String> onRemove;
  final ValueChanged<PlannedExercise> onReplace;
  final VoidCallback onRetry;
  final VoidCallback onEditDay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekday = kWeekdayLabels[day.dayOfWeek - 1].toUpperCase();
    final sets = exercises.fold<int>(0, (s, x) => s + x.sets.length);
    final minutes = (sets * 3.5).round();

    if (day.isRest && exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(weekday, style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text('Rest', style: textTheme.displaySmall),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Nothing planned. Recovery is part of the programme.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: FitSpacing.lg),
            OutlinedButton(
              key: const ValueKey('day.train'),
              onPressed: onEditDay,
              child: const Text('Train this day instead'),
            ),
            const SizedBox(height: FitSpacing.sm),
            startButton,
          ],
        ),
      );
    }

    return ListView(
      key: const ValueKey('day.list'),
      padding: const EdgeInsets.only(bottom: FitSpacing.xl),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.lg,
            FitSpacing.screen,
            FitSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(weekday, style: textTheme.labelSmall)),
                  _SaveMark(
                    state: saveState,
                    failure: saveFailure,
                    onRetry: onRetry,
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                day.sessionName,
                key: const ValueKey('day.title'),
                style: textTheme.displayMedium,
              ),
              const SizedBox(height: FitSpacing.sm),
              Text(
                day.focus.map((m) => m.label).join(' · '),
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                '${exercises.length} exercises · $sets sets · ~$minutes min',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.md),
              startButton,
            ],
          ),
        ),
        for (var i = 0; i < exercises.length; i++)
          ExerciseCard(
            key: ValueKey('card.${exercises[i].id}'),
            index: i + 1,
            exercise: exercises[i],
            expanded: expanded.contains(exercises[i].id),
            enabled: saveState != _SaveState.saving,
            onToggle: () => onToggle(exercises[i].id),
            onSetChanged: (_, set) => onSetChanged(exercises[i].id, set),
            onReplace: () => onReplace(exercises[i]),
            onRemove: () => onRemove(exercises[i].id),
            onAddSet: () => onAddSet(exercises[i].id),
            onRemoveSet: (index) => onRemoveSet(exercises[i].id, index),
          ),
        const Divider(color: FitColors.rule, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.md,
            FitSpacing.screen,
            0,
          ),
          child: TextButton(
            key: const ValueKey('day.edit'),
            onPressed: onEditDay,
            child: const Text('Add or reorder exercises'),
          ),
        ),
      ],
    );
  }
}

/// "Saving…" / "Saved" / "Couldn't save · Retry" — small, top right of the
/// day, never a snackbar over the sets you are editing.
class _SaveMark extends StatelessWidget {
  const _SaveMark({
    required this.state,
    required this.failure,
    required this.onRetry,
  });

  final _SaveState state;
  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    switch (state) {
      case _SaveState.idle:
        return const SizedBox.shrink();
      case _SaveState.saving:
        return Text(
          'Saving…',
          key: const ValueKey('save.saving'),
          style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
        );
      case _SaveState.saved:
        return Text(
          'Saved',
          key: const ValueKey('save.saved'),
          style: textTheme.labelSmall?.copyWith(color: FitColors.pine),
        );
      case _SaveState.failed:
        return InkWell(
          key: const ValueKey('save.retry'),
          onTap: onRetry,
          child: Text(
            "Couldn't save · Retry",
            style: textTheme.labelSmall?.copyWith(color: FitColors.oxide),
          ),
        );
    }
  }
}

class _WeekSkeleton extends StatelessWidget {
  const _WeekSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(height: 56, color: FitColors.paper2),
        Padding(
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(width: 80, height: 11, color: FitColors.paper2),
              const SizedBox(height: FitSpacing.sm),
              Container(width: 180, height: 36, color: FitColors.paper2),
              const SizedBox(height: FitSpacing.lg),
              for (var i = 0; i < 4; i++) ...<Widget>[
                const Divider(color: FitColors.rule, height: 1),
                const SizedBox(height: FitSpacing.md),
                Container(width: 220, height: 18, color: FitColors.paper2),
                const SizedBox(height: FitSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Could not load your plan', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          AuthFeedback.error(failure.message),
          const SizedBox(height: FitSpacing.lg),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
