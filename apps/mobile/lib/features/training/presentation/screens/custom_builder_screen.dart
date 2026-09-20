import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';
import '../widgets/day_exercise_list.dart';

/// Build a programme from scratch (§31 Phase 4 "custom builder"): a name,
/// which weekdays you train (2–6), and each day's exercises. Save sends one
/// PUT; the server stores it as `custom` and it progresses like any other.
class CustomBuilderScreen extends ConsumerStatefulWidget {
  const CustomBuilderScreen({super.key});

  @override
  ConsumerState<CustomBuilderScreen> createState() =>
      _CustomBuilderScreenState();
}

class _DraftDay {
  _DraftDay(this.dayOfWeek)
      : name = TextEditingController(text: 'Day'),
        exercises = <DraftExercise>[];
  final int dayOfWeek;
  final TextEditingController name;
  List<DraftExercise> exercises;
}

class _CustomBuilderScreenState extends ConsumerState<CustomBuilderScreen> {
  final _name = TextEditingController(text: 'My programme');
  final Map<int, _DraftDay> _days = <int, _DraftDay>{};
  bool _busy = false;
  Failure? _failure;

  @override
  void dispose() {
    _name.dispose();
    for (final d in _days.values) {
      d.name.dispose();
    }
    super.dispose();
  }

  void _toggleDay(int dow) {
    setState(() {
      if (_days.containsKey(dow)) {
        _days.remove(dow)!.name.dispose();
      } else if (_days.length < 6) {
        _days[dow] = _DraftDay(dow);
      }
    });
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _days.length >= 2 &&
      _days.values.every((d) => d.exercises.isNotEmpty);

  Future<void> _save() async {
    if (!_valid) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final sorted = _days.values.toList()
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final failure =
        await ref.read(programControllerProvider.notifier).putCustom(
              PutProgramRequest(
                name: _name.text.trim(),
                days: [
                  for (final d in sorted)
                    CustomDay(
                      dayOfWeek: d.dayOfWeek,
                      sessionName: d.name.text.trim().isEmpty
                          ? kWeekdayLabels[d.dayOfWeek - 1]
                          : d.name.text.trim(),
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
    if (failure == null) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sorted = _days.values.toList()
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? null : () => context.pop()),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.sm,
                  FitSpacing.screen,
                  FitSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('YOUR OWN', style: textTheme.labelSmall),
                    const SizedBox(height: FitSpacing.xs),
                    Text('Build a programme', style: textTheme.displaySmall),
                    const SizedBox(height: FitSpacing.sm),
                    Text(
                      'Pick two to six days, put exercises on each. Loads and progression are handled the same way as a generated plan.',
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
                    const SizedBox(height: FitSpacing.xs),
                    Wrap(
                      spacing: FitSpacing.sm,
                      runSpacing: FitSpacing.xs,
                      children: <Widget>[
                        for (var dow = 1; dow <= 7; dow++)
                          _DayToggle(
                            key: ValueKey('builder.day.$dow'),
                            label: kWeekdayLabels[dow - 1].substring(0, 3),
                            on: _days.containsKey(dow),
                            enabled: !_busy,
                            onTap: () => _toggleDay(dow),
                          ),
                      ],
                    ),
                    if (_days.length < 2) ...<Widget>[
                      const SizedBox(height: FitSpacing.sm),
                      Text(
                        'Choose at least two days.',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FitColors.amber),
                      ),
                    ],
                    for (final d in sorted) ...<Widget>[
                      const SizedBox(height: FitSpacing.lg),
                      const Divider(color: FitColors.rule, height: 1),
                      const SizedBox(height: FitSpacing.afterRule),
                      Text(
                        kWeekdayLabels[d.dayOfWeek - 1].toUpperCase(),
                        style: textTheme.labelSmall,
                      ),
                      const SizedBox(height: FitSpacing.xs),
                      AuthFormField(
                        fieldKey: ValueKey('builder.day.${d.dayOfWeek}.name'),
                        label: 'Session name',
                        controller: d.name,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: FitSpacing.sm),
                      DayExerciseList(
                        keyPrefix: 'builder.day.${d.dayOfWeek}',
                        exercises: d.exercises,
                        enabled: !_busy,
                        onChanged: (next) => setState(() => d.exercises = next),
                      ),
                      if (d.exercises.isEmpty)
                        Text(
                          'Add at least one exercise.',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.amber),
                        ),
                    ],
                    if (_failure != null) ...<Widget>[
                      const SizedBox(height: FitSpacing.md),
                      AuthFeedback.error(_failure!.message),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                FitSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('builder.save'),
                    onPressed: _busy || !_valid ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FitColors.paper,
                            ),
                          )
                        : const Text('Save programme'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.on,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.sm,
            vertical: FitSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? FitColors.ink : FitColors.rule,
                width: on ? 2 : 1,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              color: on ? FitColors.ink : FitColors.ink60,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
