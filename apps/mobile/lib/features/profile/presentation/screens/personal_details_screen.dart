import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../health/domain/entities/health.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../onboarding/presentation/widgets/onboarding_step.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/vocabulary.dart';

/// Phase 6.6 Gate 7 — Profile → Personal details. The onboarding "about" and
/// "experience" answers, editable: name, sex, height, weight, activity. One
/// `PATCH /user/profile` with what changed; the server records the weight as
/// today's reading and recomputes targets itself when a formula input
/// changed (nothing about targets is computed or written here). The goal
/// has its own editor, linked from here.
///
/// Health Connect weight is shown next to the weight field as the phone's
/// own latest measurement — never sent, never copied in by itself (owner
/// B4). The FITOS weight is what the user types.
class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Sex? _sex;
  ActivityLevel? _activity;
  UserProfileDetail? _loaded;
  bool _busy = false;
  Failure? _failure;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Fill the form once, from what the server has.
  void _prefill(UserProfileDetail p) {
    if (_loaded != null) return;
    _loaded = p;
    _name.text = p.displayName ?? '';
    _height.text = p.heightCm == null ? '' : _fmt(p.heightCm!);
    _weight.text = p.latestWeightKg == null ? '' : _fmt(p.latestWeightKg!);
    _sex = p.sex;
    _activity = p.activityLevel;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static String? _number(String? v, String what, double min, double max) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter your $what.';
    if (n < min || n > max) return 'That does not look right for $what.';
    return null;
  }

  /// Only what differs from the server's values goes out.
  PersonalDetailsChange _change(UserProfileDetail p) {
    final name = _name.text.trim();
    final height = double.parse(_height.text.trim());
    final weight = double.parse(_weight.text.trim());
    return PersonalDetailsChange(
      displayName: name != (p.displayName ?? '') ? name : null,
      sex: _sex != p.sex ? _sex : null,
      heightCm: height != p.heightCm ? height : null,
      weightKg: weight != p.latestWeightKg ? weight : null,
      activityLevel: _activity != p.activityLevel ? _activity : null,
    );
  }

  Future<void> _save() async {
    final p = _loaded;
    if (p == null || !(_form.currentState?.validate() ?? false)) return;
    final change = _change(p);
    if (change.isEmpty) {
      context.popOrHome();
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref
        .read(profileControllerProvider.notifier)
        .savePersonalDetails(change);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('details.saved'),
        content: Text(
          change.touchesTargets
              ? 'Saved. FITOS recalculated your targets.'
              : 'Saved.',
        ),
      ),
    );
    context.popOrHome();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(profileControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: _busy ? null : () => context.popOrHome(),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: AuthFeedback.error(
              (e is Failure ? e : const Unknown()).message,
            ),
          ),
          data: (view) {
            _prefill(view.profile);
            return _buildForm(context, textTheme, view);
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    TextTheme textTheme,
    ProfileView view,
  ) {
    final deviceWeight = _deviceWeight(ref);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('PROFILE', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text('Personal details', style: textTheme.displaySmall),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Sex, height, weight and activity set your targets. When they change, FITOS recalculates the targets on its server; your earlier targets and weights are kept.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.lg),
            AuthFormField(
              fieldKey: const ValueKey('details.displayName'),
              label: 'Name',
              controller: _name,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'A name, so FITOS can greet you.';
                if (t.length > 40) return 'Keep it under 40 characters.';
                return null;
              },
              enabled: !_busy,
            ),
            const SizedBox(height: FitSpacing.lg),
            Text('SEX', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceList<Sex>(
              key: const ValueKey('details.sex'),
              options: Sex.values,
              selected: _sex,
              enabled: !_busy,
              onSelect: (s) => setState(() => _sex = s),
              label: (s) => s.label,
            ),
            const SizedBox(height: FitSpacing.lg),
            AuthFormField(
              fieldKey: const ValueKey('details.heightCm'),
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
              fieldKey: const ValueKey('details.weightKg'),
              label: 'Weight (kg)',
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (v) => _number(v, 'weight', 30, 300),
              enabled: !_busy,
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'Saved as today\'s weight. Earlier weigh-ins stay in your history.',
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
            if (deviceWeight != null) ...<Widget>[
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Health Connect on this phone: ${_fmt(deviceWeight.$1)} kg'
                '${deviceWeight.$2 == null ? '' : ' · ${deviceWeight.$2}'}. '
                'It stays on the phone; enter it above if you want FITOS to use it.',
                key: const ValueKey('details.deviceWeight'),
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            ],
            const SizedBox(height: FitSpacing.lg),
            Text('OUTSIDE THE GYM', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceList<ActivityLevel>(
              key: const ValueKey('details.activity'),
              options: ActivityLevel.values,
              selected: _activity,
              enabled: !_busy,
              onSelect: (a) => setState(() => _activity = a),
              label: (a) => a.label,
              blurb: (a) => a.blurb,
            ),
            const SizedBox(height: FitSpacing.lg),
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.afterRule),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Goal · ${view.goal.goal.goalType.label}',
                    style: textTheme.bodyLarge,
                  ),
                ),
                TextButton(
                  key: const ValueKey('details.goal'),
                  onPressed:
                      _busy ? null : () => context.push(Routes.goalEditor),
                  child: const Text('Change goal'),
                ),
              ],
            ),
            if (view.profile.birthDate != null)
              Text(
                'Born ${view.profile.birthDate} — not editable here.',
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            if (_failure != null) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              AuthFeedback.error(
                _failure!.message,
                key: const ValueKey('details.error'),
              ),
            ],
            const SizedBox(height: FitSpacing.lg),
            FilledButton(
              key: const ValueKey('details.save'),
              onPressed: _busy ? null : _save,
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
          ],
        ),
      ),
    );
  }

  /// The phone's latest Health Connect weight, if it has one: display only.
  static (double, String?)? _deviceWeight(WidgetRef ref) {
    final snapshot = ref.watch(healthSnapshotProvider).value;
    final m = snapshot?.metric(HealthMetricKind.weight);
    if (m == null ||
        m.availability != HealthAvailability.available ||
        m.value == null) {
      return null;
    }
    final at = m.end ?? m.start;
    return (m.value!, at?.substring(0, 10));
  }
}
