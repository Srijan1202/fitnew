import 'package:flutter/material.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../profile/domain/entities/vocabulary.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';

typedef SubmitAnswer = Future<Failure?> Function(OnboardingAnswer answer);

/// Screen 1 — Goal (§32).
class GoalStep extends StatefulWidget {
  const GoalStep({
    required this.state,
    required this.submit,
    required this.onNext,
    super.key,
  });

  final OnboardingState state;
  final SubmitAnswer submit;
  final VoidCallback onNext;

  @override
  State<GoalStep> createState() => _GoalStepState();
}

class _GoalStepState extends State<GoalStep> {
  GoalType? _goal;
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _goal = widget.state.goalType; // pre-fill on resume / back
  }

  Future<void> _continue() async {
    final goal = _goal;
    if (goal == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.submit(OnboardingAnswer.goal(goalType: goal));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure == null) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStep(
      screenNumber: 1,
      title: 'What are you here for?',
      lede:
          'This sets your calorie target and how your training progresses. You can change it any time.',
      busy: _busy,
      failure: _failure,
      canContinue: _goal != null,
      onContinue: _continue,
      child: ChoiceList<GoalType>(
        options: GoalType.values,
        selected: _goal,
        enabled: !_busy,
        onSelect: (g) => setState(() => _goal = g),
        label: (g) => g.label,
        blurb: (g) => g.blurb,
      ),
    );
  }
}
