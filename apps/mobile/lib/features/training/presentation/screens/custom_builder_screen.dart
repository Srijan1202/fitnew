import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';
import '../widgets/draft.dart';
import '../widgets/draft_exercise_list.dart';
import '../widgets/set_row.dart';
import '../widgets/toggle_wrap.dart';

/// Custom: a programme built step by step, one concern per screen —
/// Days → Day details → Muscle groups → Exercises → Sets → Save. One PUT at
/// the end; the server stores it as `custom` and it progresses like any
/// other. Nothing is decided here: the user decides everything.
class CustomBuilderScreen extends ConsumerStatefulWidget {
  const CustomBuilderScreen({super.key});

  @override
  ConsumerState<CustomBuilderScreen> createState() =>
      _CustomBuilderScreenState();
}

class _DraftDay {
  _DraftDay(this.dayOfWeek, String name)
      : nameController = TextEditingController(text: name);
  final int dayOfWeek;
  final TextEditingController nameController;
  Set<MuscleGroup> focus = <MuscleGroup>{};
  List<DraftExercise> exercises = <DraftExercise>[];
}

enum _Step { days, details, muscles, exercises, sets, review }

class _CustomBuilderScreenState extends ConsumerState<CustomBuilderScreen> {
  final _name = TextEditingController(text: 'My programme');
  final Map<int, _DraftDay> _days = <int, _DraftDay>{};
  _Step _step = _Step.days;
  bool _busy = false;
  Failure? _failure;

  List<_DraftDay> get _sorted =>
      _days.values.toList()..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

  @override
  void dispose() {
    _name.dispose();
    for (final d in _days.values) {
      d.nameController.dispose();
    }
    super.dispose();
  }

  void _toggleDay(int dow) {
    setState(() {
      if (_days.containsKey(dow)) {
        _days.remove(dow)!.nameController.dispose();
      } else if (_days.length < 6) {
        _days[dow] = _DraftDay(dow, 'Day ${_days.length + 1}');
      }
    });
  }

  bool get _canContinue {
    switch (_step) {
      case _Step.days:
        return _name.text.trim().isNotEmpty && _days.length >= 2;
      case _Step.details:
        return _days.values
            .every((d) => d.nameController.text.trim().isNotEmpty);
      case _Step.muscles:
        return true; // optional: focus can be derived from the exercises
      case _Step.exercises:
        return _days.values.every((d) => d.exercises.isNotEmpty);
      case _Step.sets:
      case _Step.review:
        return true;
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure =
        await ref.read(programControllerProvider.notifier).putCustom(
              PutProgramRequest(
                name: _name.text.trim(),
                days: [
                  for (final d in _sorted)
                    CustomDay(
                      dayOfWeek: d.dayOfWeek,
                      sessionName: d.nameController.text.trim(),
                      focus: d.focus.isEmpty ? null : d.focus.toList(),
                      exercises: d.exercises.map((x) => x.toCustom()).toList(),
                    ),
                ],
              ),
            );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure == null) context.go(Routes.plan);
  }

  void _next() {
    if (!_canContinue) return;
    setState(() {
      _step = _Step.values[_step.index + 1];
    });
  }

  void _back() {
    if (_step == _Step.days) {
      context.pop();
      return;
    }
    setState(() => _step = _Step.values[_step.index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stepNumber = _step.index + 1;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? null : _back),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                key: ValueKey('builder.step.${_step.name}'),
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.sm,
                  FitSpacing.screen,
                  FitSpacing.md,
                ),
                children: <Widget>[
                  Text(
                    'CUSTOM · STEP $stepNumber OF ${_Step.values.length}',
                    style: textTheme.labelSmall,
                  ),
                  const SizedBox(height: FitSpacing.xs),
                  ..._body(textTheme),
                  if (_failure != null) ...<Widget>[
                    const SizedBox(height: FitSpacing.md),
                    AuthFeedback.error(_failure!.message),
                  ],
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: FitColors.rule)),
              ),
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                FitSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  if (_step != _Step.days)
                    TextButton(
                      key: const ValueKey('builder.back'),
                      onPressed: _busy ? null : _back,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('builder.next'),
                    onPressed: _busy || !_canContinue
                        ? null
                        : _step == _Step.review
                            ? _save
                            : _next,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FitColors.paper,
                            ),
                          )
                        : Text(
                            _step == _Step.review
                                ? 'Save programme'
                                : 'Continue',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(TextTheme textTheme) {
    switch (_step) {
      case _Step.days:
        return <Widget>[
          Text('Which days?', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'Name your programme and pick two to six training days.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          AuthFormField(
            fieldKey: const ValueKey('builder.name'),
            label: 'Programme name',
            controller: _name,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('TRAINING DAYS', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          ToggleWrap<int>(
            keyPrefix: 'builder.day',
            options: const [1, 2, 3, 4, 5, 6, 7],
            isSelected: _days.containsKey,
            enabled: !_busy,
            label: (dow) => kWeekdayLabels[dow - 1].substring(0, 3),
            onTap: _toggleDay,
          ),
          if (_days.length < 2) ...<Widget>[
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Choose at least two days.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
            ),
          ],
        ];
      case _Step.details:
        return <Widget>[
          Text('Name each day', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'Push, Legs, Heavy — whatever you call it.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          for (final d in _sorted) ...<Widget>[
            Text(
              kWeekdayLabels[d.dayOfWeek - 1].toUpperCase(),
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: FitSpacing.xs),
            AuthFormField(
              fieldKey: ValueKey('builder.day.${d.dayOfWeek}.name'),
              label: 'Session name',
              controller: d.nameController,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: FitSpacing.lg),
          ],
        ];
      case _Step.muscles:
        return <Widget>[
          Text('Muscle groups', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'What each day is for. Optional — FitOS can read it from the exercises.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          for (final d in _sorted) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.afterRule),
            Text(
              '${kWeekdayLabels[d.dayOfWeek - 1]} · ${d.nameController.text.trim()}'
                  .toUpperCase(),
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: FitSpacing.sm),
            ToggleWrap<MuscleGroup>(
              keyPrefix: 'builder.day.${d.dayOfWeek}.focus',
              options: MuscleGroup.values,
              isSelected: d.focus.contains,
              enabled: !_busy,
              label: (m) => m.label,
              onTap: (m) => setState(() {
                if (!d.focus.remove(m)) d.focus.add(m);
              }),
            ),
            const SizedBox(height: FitSpacing.lg),
          ],
        ];
      case _Step.exercises:
        return <Widget>[
          Text('Exercises', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'Add from the library, drag to order. At least one per day.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          for (final d in _sorted) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.afterRule),
            Text(
              '${kWeekdayLabels[d.dayOfWeek - 1]} · ${d.nameController.text.trim()}'
                  .toUpperCase(),
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: FitSpacing.sm),
            DraftExerciseList(
              keyPrefix: 'builder.day.${d.dayOfWeek}',
              exercises: d.exercises,
              enabled: !_busy,
              onChanged: (next) => setState(() => d.exercises = next),
            ),
            if (d.exercises.isEmpty)
              Text(
                'Add at least one exercise.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
              ),
            const SizedBox(height: FitSpacing.lg),
          ],
        ];
      case _Step.sets:
        return <Widget>[
          Text('Sets, reps, starting weight', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'Per set. Leave the weight blank if you do not know it yet — you can set it on the day.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          for (final d in _sorted) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.afterRule),
            Text(
              '${kWeekdayLabels[d.dayOfWeek - 1]} · ${d.nameController.text.trim()}'
                  .toUpperCase(),
              style: textTheme.labelSmall,
            ),
            for (var i = 0; i < d.exercises.length; i++) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      d.exercises[i].name,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: ValueKey(
                      'builder.day.${d.dayOfWeek}.exercise.$i.sets.minus',
                    ),
                    tooltip: 'Fewer sets',
                    onPressed: _busy || d.exercises[i].sets.length <= 1
                        ? null
                        : () => setState(
                              () => d.exercises[i] = d.exercises[i]
                                  .withSetCount(d.exercises[i].sets.length - 1),
                            ),
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Text(
                    '${d.exercises[i].sets.length} sets',
                    style: textTheme.titleMedium,
                  ),
                  IconButton(
                    key: ValueKey(
                      'builder.day.${d.dayOfWeek}.exercise.$i.sets.plus',
                    ),
                    tooltip: 'More sets',
                    onPressed: _busy || d.exercises[i].sets.length >= 10
                        ? null
                        : () => setState(
                              () => d.exercises[i] = d.exercises[i]
                                  .withSetCount(d.exercises[i].sets.length + 1),
                            ),
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              for (final set in d.exercises[i].sets)
                SetRow(
                  key: ValueKey(
                    'builder.day.${d.dayOfWeek}.exercise.$i.set.${set.setIndex}',
                  ),
                  rowKey:
                      'builder.day.${d.dayOfWeek}.exercise.$i.set.${set.setIndex}',
                  set: set,
                  incrementKg: d.exercises[i].incrementKg ?? 2.5,
                  enabled: !_busy,
                  onChanged: (next) => setState(
                    () => d.exercises[i] = d.exercises[i].withSet(next),
                  ),
                ),
            ],
            const SizedBox(height: FitSpacing.lg),
          ],
        ];
      case _Step.review:
        final totalExercises =
            _days.values.fold<int>(0, (s, d) => s + d.exercises.length);
        return <Widget>[
          Text(_name.text.trim(), style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            '${_days.length} days · $totalExercises exercises. Save it and it becomes your active programme; the old one is kept.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          for (final d in _sorted) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.afterRule),
            Text(
              kWeekdayLabels[d.dayOfWeek - 1].toUpperCase(),
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(d.nameController.text.trim(), style: textTheme.titleLarge),
            if (d.focus.isNotEmpty)
              Text(
                d.focus.map((m) => m.label).join(' · '),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            const SizedBox(height: FitSpacing.sm),
            for (final x in d.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(x.name, style: textTheme.bodyLarge)),
                    Text(
                      '${x.sets.length} × ${x.sets.first.repsLabel}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: FitSpacing.lg),
          ],
        ];
    }
  }
}
