import 'package:flutter/material.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../profile/domain/entities/profile.dart';
import '../../../../profile/domain/entities/vocabulary.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';
import 'goal_step.dart' show SubmitAnswer;

/// Screen 5 — Food (§32): diet type and allergies.
///
/// Allergies are safety-critical on the server (a hard filter, never a
/// score). Each selected allergen carries a severity; the default is
/// "moderate" so a single tap records something the filter honours fully.
class FoodStep extends StatefulWidget {
  const FoodStep({
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
  State<FoodStep> createState() => _FoodStepState();
}

class _FoodStepState extends State<FoodStep> {
  DietType? _diet;
  final Map<Allergen, AllergySeverity> _allergies = {};
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _diet = widget.state.dietType;
    for (final a in widget.state.allergies) {
      _allergies[a.allergen] = a.severity;
    }
  }

  void _toggle(Allergen a) => setState(() {
        if (_allergies.remove(a) == null) {
          _allergies[a] = AllergySeverity.moderate;
        }
      });

  Future<void> _continue() async {
    final diet = _diet;
    if (diet == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.submit(
      OnboardingAnswer.food(
        dietType: diet,
        allergies: [
          for (final a in Allergen.values)
            if (_allergies.containsKey(a))
              Allergy(allergen: a, severity: _allergies[a]!),
        ],
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
      screenNumber: 5,
      title: 'What you eat',
      lede:
          'Diet type is a hard rule for every food suggestion. So are allergies — they are never just a score.',
      busy: _busy,
      failure: _failure,
      canContinue: _diet != null,
      onBack: widget.onBack,
      onContinue: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('DIET', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          ChoiceList<DietType>(
            options: DietType.values,
            selected: _diet,
            enabled: !_busy,
            onSelect: (d) => setState(() => _diet = d),
            label: (d) => d.label,
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('ALLERGIES — LEAVE EMPTY IF NONE', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          for (final a in Allergen.values) ...<Widget>[
            AllergyRow(
              allergen: a,
              severity: _allergies[a],
              enabled: !_busy,
              onToggle: () => _toggle(a),
              onSeverity: (s) => setState(() => _allergies[a] = s),
            ),
            const Divider(color: FitColors.rule, height: 1),
          ],
        ],
      ),
    );
  }
}

/// One allergen: tap to toggle, and when selected a severity picker unfolds
/// inline. Severity in amber wording, not colour — colour is for state (§6.2).
class AllergyRow extends StatelessWidget {
  const AllergyRow({
    super.key,
    required this.allergen,
    required this.severity,
    required this.enabled,
    required this.onToggle,
    required this.onSeverity,
  });

  final Allergen allergen;
  final AllergySeverity? severity;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<AllergySeverity> onSeverity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = severity != null;
    return Column(
      children: <Widget>[
        InkWell(
          key: ValueKey('food.allergen.${allergen.wire}'),
          onTap: enabled ? onToggle : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 24,
                  color: selected ? FitColors.ink : Colors.transparent,
                ),
                const SizedBox(width: FitSpacing.md),
                Expanded(
                  child: Text(
                    allergen.label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected)
          Padding(
            padding: const EdgeInsets.only(
              left: FitSpacing.md + 3,
              bottom: FitSpacing.sm,
            ),
            // Wraps: three chips do not fit a 360 dp row at larger text.
            child: Wrap(
              spacing: FitSpacing.sm,
              runSpacing: FitSpacing.xs,
              children: <Widget>[
                for (final s in AllergySeverity.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: s == severity,
                    onSelected: enabled ? (_) => onSeverity(s) : null,
                    selectedColor: FitColors.ink,
                    labelStyle: textTheme.bodyMedium?.copyWith(
                      color: s == severity ? FitColors.paper : FitColors.ink,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(FitRadius.small),
                      side: BorderSide(color: FitColors.ink),
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
