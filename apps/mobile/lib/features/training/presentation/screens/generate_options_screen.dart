import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../profile/data/profile_repository.dart';
import '../controllers/program_controller.dart';
import '../widgets/option_row.dart';

/// Generate: the two things worth choosing per programme — days and session
/// length — prefilled from the profile. Everything else (goal, level,
/// equipment, limitations) the generator already knows.
class GenerateOptionsScreen extends ConsumerStatefulWidget {
  const GenerateOptionsScreen({super.key});

  @override
  ConsumerState<GenerateOptionsScreen> createState() =>
      _GenerateOptionsScreenState();
}

class _GenerateOptionsScreenState extends ConsumerState<GenerateOptionsScreen> {
  int? _days;
  int? _minutes;
  bool _busy = false;
  Failure? _failure;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref.read(programControllerProvider.notifier).generate(
          daysPerWeek: _days,
          preferredSessionMinutes: _minutes,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure == null) context.go(Routes.plan);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(profileControllerProvider).value?.profile;
    final days = _days ?? (profile?.trainingDaysPerWeek ?? 3).clamp(2, 6);
    final minutes = _minutes ?? profile?.preferredSessionMinutes ?? 60;

    return Scaffold(
      appBar: AppBar(
        leading:
            BackButton(onPressed: _busy ? null : () => context.popOrHome()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.screen,
            FitSpacing.xl,
          ),
          children: <Widget>[
            Text('GENERATE', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text('Your week', style: textTheme.displaySmall),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Goal, level, equipment and limitations come from your profile. Set how often and how long.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: FitSpacing.lg),
            OptionRow<int>(
              label: 'Days a week',
              options: const [2, 3, 4, 5, 6],
              selected: days,
              enabled: !_busy,
              keyPrefix: 'generate.days',
              text: (d) => '$d',
              onSelect: (d) => setState(() => _days = d),
            ),
            const SizedBox(height: FitSpacing.lg),
            OptionRow<int>(
              label: 'Minutes a session',
              options: const [30, 45, 60, 75, 90],
              selected: minutes,
              enabled: !_busy,
              keyPrefix: 'generate.minutes',
              text: (m) => '$m',
              onSelect: (m) => setState(() => _minutes = m),
            ),
            if (_failure != null) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              AuthFeedback.error(_failure!.message),
            ],
            const SizedBox(height: FitSpacing.xl),
            FilledButton(
              key: const ValueKey('generate.go'),
              onPressed: _busy ? null : _generate,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FitColors.paper,
                      ),
                    )
                  : const Text('Generate my programme'),
            ),
          ],
        ),
      ),
    );
  }
}
