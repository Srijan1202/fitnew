import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../onboarding/presentation/widgets/onboarding_step.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/vocabulary.dart';
import '../widgets/targets_display.dart';

/// Change the active goal. PUT closes the old goal and the server recomputes
/// targets (§10.1); the new numbers are shown before leaving so the user sees
/// what changed and why.
class GoalEditorScreen extends ConsumerStatefulWidget {
  const GoalEditorScreen({super.key});

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  GoalType? _goal;
  bool _busy = false;
  Failure? _failure;
  NutritionTargets? _updated;

  @override
  void initState() {
    super.initState();
    _goal = ref.read(profileControllerProvider).value?.goal.goal.goalType;
  }

  Future<void> _save() async {
    final goal = _goal;
    if (goal == null) return;
    setState(() {
      _busy = true;
      _failure = null;
      _updated = null;
    });
    final failure = await ref
        .read(profileControllerProvider.notifier)
        .changeGoal(PutGoalRequest(goalType: goal));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
      _updated = failure == null
          ? ref.read(profileControllerProvider).value?.goal.targets
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current =
        ref.watch(profileControllerProvider).value?.goal.goal.goalType;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? null : () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.screen,
            FitSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('GOAL', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Text('Change your goal', style: textTheme.displaySmall),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Your calorie and protein targets are recomputed the moment you save.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.lg),
              ChoiceList<GoalType>(
                options: GoalType.values,
                selected: _goal,
                enabled: !_busy,
                onSelect: (g) => setState(() => _goal = g),
                label: (g) => g.label,
                blurb: (g) => g.blurb,
              ),
              if (_failure != null) ...<Widget>[
                const SizedBox(height: FitSpacing.md),
                AuthFeedback.error(_failure!.message),
              ],
              const SizedBox(height: FitSpacing.lg),
              FilledButton(
                onPressed:
                    _busy || _goal == null || _goal == current ? null : _save,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FitColors.paper,
                        ),
                      )
                    : const Text('Save'),
              ),
              if (_updated != null) ...<Widget>[
                const SizedBox(height: FitSpacing.xl),
                const Divider(color: FitColors.rule, height: 1),
                const SizedBox(height: FitSpacing.afterRule),
                Text('NEW TARGETS', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.sm),
                TargetsDisplay(targets: _updated!),
                const SizedBox(height: FitSpacing.md),
                for (final line in _updated!.rationale)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                    child: Text(line, style: textTheme.bodyMedium),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
