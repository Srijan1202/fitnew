import 'package:flutter/material.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../profile/domain/entities/vocabulary.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';
import 'goal_step.dart' show SubmitAnswer;

/// Screen 3 — Experience (§32): level, days per week, and activity level
/// (asked here rather than deferred; the TDEE formula needs it on screen 7).
class ExperienceStep extends StatefulWidget {
  const ExperienceStep({
    required this.state,
    required this.submit,
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final OnboardingState state;
  final SubmitAnswer submit;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  State<ExperienceStep> createState() => _ExperienceStepState();
}

class _ExperienceStepState extends State<ExperienceStep> {
  ExperienceLevel? _level;
  int _days = 4;
  ActivityLevel _activity = ActivityLevel.light; // hostel default (§32)
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    final p = widget.state.profile;
    _level = p.experienceLevel;
    _days = p.trainingDaysPerWeek ?? 4;
    _activity = p.activityLevel ?? ActivityLevel.light;
  }

  Future<void> _continue() async {
    final level = _level;
    if (level == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.submit(
      OnboardingAnswer.experience(
        experienceLevel: level,
        trainingDaysPerWeek: _days,
        activityLevel: _activity,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure == null) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingStep(
      screenNumber: 3,
      title: 'Your training',
      busy: _busy,
      failure: _failure,
      canContinue: _level != null,
      onBack: widget.onBack,
      onContinue: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('EXPERIENCE', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          ChoiceList<ExperienceLevel>(
            options: ExperienceLevel.values,
            selected: _level,
            enabled: !_busy,
            onSelect: (l) => setState(() => _level = l),
            label: (l) => l.label,
            blurb: (l) => l.blurb,
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('DAYS PER WEEK', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          _DayPicker(
            value: _days,
            enabled: !_busy,
            onChanged: (d) => setState(() => _days = d),
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('OUTSIDE THE GYM', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          ChoiceList<ActivityLevel>(
            options: ActivityLevel.values,
            selected: _activity,
            enabled: !_busy,
            onSelect: (a) => setState(() => _activity = a),
            label: (a) => a.label,
            blurb: (a) => a.blurb,
          ),
        ],
      ),
    );
  }
}

/// 1–7 as a row of ink-outlined squares; the chosen one is solid ink. Numbers
/// are the hero (§6.3).
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        for (var d = 1; d <= 7; d++) ...<Widget>[
          Semantics(
            selected: d == value,
            button: true,
            label: '$d days per week',
            child: InkWell(
              key: ValueKey('experience.days.$d'),
              onTap: enabled ? () => onChanged(d) : null,
              child: Container(
                width: 40,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: d == value ? FitColors.ink : Colors.transparent,
                  border: Border.all(color: FitColors.ink),
                  borderRadius: const BorderRadius.all(FitRadius.small),
                ),
                child: Text(
                  '$d',
                  style: textTheme.titleMedium?.copyWith(
                    color: d == value ? FitColors.paper : FitColors.ink,
                  ),
                ),
              ),
            ),
          ),
          if (d < 7) const SizedBox(width: FitSpacing.xs),
        ],
      ],
    );
  }
}
