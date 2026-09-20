import 'package:flutter/material.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../profile/domain/entities/vocabulary.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';
import 'goal_step.dart' show SubmitAnswer;

/// Screen 4 — Where you train (§32): location and equipment. Equipment
/// drives Phase 4's exercise filtering; choosing "bodyweight only" is a
/// real answer, not an absence of one.
class TrainingStep extends StatefulWidget {
  const TrainingStep({
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
  State<TrainingStep> createState() => _TrainingStepState();
}

class _TrainingStepState extends State<TrainingStep> {
  TrainingLocation? _location;
  final Set<Equipment> _equipment = {};
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _location = widget.state.profile.trainingLocation;
    _equipment.addAll(widget.state.profile.equipment);
  }

  void _toggle(Equipment e) => setState(() {
        if (!_equipment.remove(e)) _equipment.add(e);
      });

  Future<void> _continue() async {
    final location = _location;
    if (location == null || _equipment.isEmpty) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.submit(
      OnboardingAnswer.training(
        trainingLocation: location,
        equipment: Equipment.values.where(_equipment.contains).toList(),
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
      screenNumber: 4,
      title: 'Where you train',
      lede: 'Your programme only uses equipment you actually have.',
      busy: _busy,
      failure: _failure,
      canContinue: _location != null && _equipment.isNotEmpty,
      onBack: widget.onBack,
      onContinue: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('LOCATION', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          ChoiceList<TrainingLocation>(
            options: TrainingLocation.values,
            selected: _location,
            enabled: !_busy,
            onSelect: (l) => setState(() => _location = l),
            label: (l) => l.label,
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('EQUIPMENT — PICK ALL THAT APPLY', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          MultiChoiceList<Equipment>(
            options: Equipment.values,
            selected: _equipment,
            enabled: !_busy,
            onToggle: _toggle,
            label: (e) => e.label,
          ),
        ],
      ),
    );
  }
}
