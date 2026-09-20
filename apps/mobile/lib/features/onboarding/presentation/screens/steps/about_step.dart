import 'package:flutter/material.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../../profile/domain/entities/vocabulary.dart';
import '../../../domain/entities/onboarding.dart';
import '../../widgets/onboarding_step.dart';
import 'goal_step.dart' show SubmitAnswer;

/// Screen 2 — About you (§32): sex, birth date, height, weight, and the
/// consent that must precede any of it (§23).
class AboutStep extends StatefulWidget {
  const AboutStep({
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
  State<AboutStep> createState() => _AboutStepState();
}

class _AboutStepState extends State<AboutStep> {
  final _form = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Sex? _sex;
  DateTime? _birthDate;
  bool _consented = false;
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    final p = widget.state.profile;
    _sex = p.sex;
    if (p.birthDate != null) _birthDate = DateTime.tryParse(p.birthDate!);
    if (p.heightCm != null) _height.text = _fmt(p.heightCm!);
    if (p.latestWeightKg != null) _weight.text = _fmt(p.latestWeightKg!);
    // Already answered once means consent was already recorded.
    _consented = widget.state.answered.contains(OnboardingStage.about);
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      // The 18+ rule is the server's to enforce (§23); the picker just makes
      // an adult date the default and the obvious choice.
      lastDate: now,
      helpText: 'Your date of birth',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _number(String? v, String what, double min, double max) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter your $what.';
    if (n < min || n > max) return 'That does not look right for $what.';
    return null;
  }

  Future<void> _continue() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final sex = _sex;
    final birth = _birthDate;
    if (sex == null || birth == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.submit(
      OnboardingAnswer.about(
        sex: sex,
        birthDate: _iso(birth),
        heightCm: double.parse(_height.text.trim()),
        weightKg: double.parse(_weight.text.trim()),
        consent: ConsentGrant(
          policyVersion: widget.state.policyVersion,
          types: ConsentType.values,
        ),
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
    final ready = _sex != null && _birthDate != null && _consented;

    return OnboardingStep(
      screenNumber: 2,
      title: 'About you',
      lede:
          'Four numbers the calorie formula needs. Weight is a starting reading, not a judgement.',
      busy: _busy,
      failure: _failure,
      canContinue: ready,
      onBack: widget.onBack,
      onContinue: _continue,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('SEX', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceList<Sex>(
              options: Sex.values,
              selected: _sex,
              enabled: !_busy,
              onSelect: (s) => setState(() => _sex = s),
              label: (s) => s.label,
            ),
            const SizedBox(height: FitSpacing.lg),
            Text('DATE OF BIRTH', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            InkWell(
              key: const ValueKey('about.birthDate'),
              onTap: _busy ? null : _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: FitColors.rule)),
                ),
                child: Text(
                  _birthDate == null ? 'Choose a date' : _iso(_birthDate!),
                  style: textTheme.bodyLarge?.copyWith(
                    color: _birthDate == null ? FitColors.ink35 : FitColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: FitSpacing.lg),
            AuthFormField(
              fieldKey: const ValueKey('about.heightCm'),
              label: 'Height (cm)',
              controller: _height,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (v) => _number(v, 'height', 100, 250),
              enabled: !_busy,
            ),
            const SizedBox(height: FitSpacing.lg),
            AuthFormField(
              fieldKey: const ValueKey('about.weightKg'),
              label: 'Weight (kg)',
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (v) => _number(v, 'weight', 30, 300),
              enabled: !_busy,
            ),
            const SizedBox(height: FitSpacing.lg),
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.afterRule),
            _ConsentRow(
              checked: _consented,
              enabled: !_busy,
              policyVersion: widget.state.policyVersion,
              onChanged: (v) => setState(() => _consented = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.checked,
    required this.enabled,
    required this.policyVersion,
    required this.onChanged,
  });

  final bool checked;
  final bool enabled;
  final String policyVersion;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: const ValueKey('about.consent'),
      onTap: enabled ? () => onChanged(!checked) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(
            value: checked,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            activeColor: FitColors.ink,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(FitRadius.small),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: FitSpacing.sm + 4),
              child: Text(
                'I agree to the privacy policy (version $policyVersion) and to '
                'FitOS processing my health data to compute my targets. '
                'You can withdraw this and delete everything at any time.',
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
