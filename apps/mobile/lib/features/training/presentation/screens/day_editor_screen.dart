import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';
import '../widgets/day_exercise_list.dart';

/// Edit one day of the active programme (§31 Phase 4 "program editor").
/// Rename, re-prescribe, remove, add. Save sends a PATCH; the server's
/// answer replaces the plan. Nothing here recomputes anything.
class DayEditorScreen extends ConsumerStatefulWidget {
  const DayEditorScreen({required this.dayId, super.key});

  final String dayId;

  @override
  ConsumerState<DayEditorScreen> createState() => _DayEditorScreenState();
}

class _DayEditorScreenState extends ConsumerState<DayEditorScreen> {
  final _name = TextEditingController();
  List<DraftExercise>? _draft;
  bool _busy = false;
  Failure? _failure;

  ProgramDay? _dayIn(Program? program) {
    if (program == null) return null;
    for (final d in program.days) {
      if (d.id == widget.dayId) return d;
    }
    return null;
  }

  /// The draft is seeded from the plan the first time it is available —
  /// which may be after an async load when the route is opened directly.
  /// Once the user is editing, the plan is not re-read.
  void _seed(ProgramDay day) {
    if (_draft != null) return;
    _name.text = day.isRest ? '' : day.sessionName;
    _draft = day.exercises.map(DraftExercise.fromPlanned).toList();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.isEmpty) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref.read(programControllerProvider.notifier).patchDay(
          widget.dayId,
          PatchProgramDayRequest(
            sessionName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            exercises: draft.map((d) => d.toCustom()).toList(),
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
    final async = ref.watch(programControllerProvider);
    final day = _dayIn(async.value);
    if (day != null) _seed(day);
    final draft = _draft;

    if (day == null || draft == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: async.isLoading
                ? const SizedBox.shrink()
                : const Text('That day is not on your active programme.'),
          ),
        ),
      );
    }

    final label = kWeekdayLabels[day.dayOfWeek - 1].toUpperCase();
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
                    Text(label, style: textTheme.labelSmall),
                    const SizedBox(height: FitSpacing.xs),
                    Text('Edit this day', style: textTheme.displaySmall),
                    const SizedBox(height: FitSpacing.md),
                    AuthFormField(
                      fieldKey: const ValueKey('day.name'),
                      label: 'Session name',
                      controller: _name,
                      enabled: !_busy,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: FitSpacing.lg),
                    DayExerciseList(
                      exercises: draft,
                      enabled: !_busy,
                      onChanged: (next) => setState(() => _draft = next),
                    ),
                    if (draft.isEmpty) ...<Widget>[
                      const SizedBox(height: FitSpacing.sm),
                      Text(
                        'A training day needs at least one exercise.',
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
                    key: const ValueKey('day.save'),
                    onPressed: _busy || draft.isEmpty ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FitColors.paper,
                            ),
                          )
                        : const Text('Save day'),
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
