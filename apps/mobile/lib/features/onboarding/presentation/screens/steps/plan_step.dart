import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/routing/router.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/theme/tokens.dart';
import '../../../../../shared/widgets/hairline_section.dart';
import '../../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../../profile/domain/entities/profile.dart';
import '../../../../profile/presentation/widgets/targets_display.dart';
import '../../../domain/entities/onboarding.dart';
import '../../controllers/onboarding_controller.dart';
import '../../widgets/onboarding_step.dart';

/// Screen 7 — Your plan (§32: "a real generated plan, not a placeholder").
///
/// On arrival it calls `/onboarding/complete`, which runs packages/core's
/// target engine and persists the result. What renders is that output and
/// the engine's own reasons — nothing is computed or paraphrased here.
///
/// The first training week belongs to Phase 4's generator. It is absent, and
/// says so, rather than mocked (contract rule 8).
class PlanStep extends ConsumerStatefulWidget {
  const PlanStep({required this.state, required this.onBack, super.key});

  final OnboardingState state;
  final VoidCallback? onBack;

  @override
  ConsumerState<PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends ConsumerState<PlanStep> {
  Future<Result<OnboardingCompleteResponse>>? _completion;

  @override
  void initState() {
    super.initState();
    _completion = ref.read(onboardingControllerProvider.notifier).complete();
  }

  void _retry() {
    setState(() {
      _completion = ref.read(onboardingControllerProvider.notifier).complete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<OnboardingCompleteResponse>>(
      future: _completion,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) {
          return OnboardingStep(
            screenNumber: 7,
            title: 'Working it out',
            busy: true,
            onContinue: () async {},
            child: const TargetsSkeleton(),
          );
        }
        return result.when(
          ok: (response) => OnboardingStep(
            screenNumber: 7,
            title: 'Your plan',
            lede:
                'Computed from what you told us. Every number has a reason, and you can see it.',
            continueLabel: 'Start',
            onBack: widget.onBack,
            // The session is already marked complete; Start is the explicit
            // exit so the plan stays on screen for as long as they want it.
            onContinue: () async => context.go(Routes.today),
            child: _PlanBody(goal: response.goal, targets: response.targets),
          ),
          err: (failure) => OnboardingStep(
            screenNumber: 7,
            title: 'Your plan',
            failure: failure,
            continueLabel: 'Try again',
            onBack: widget.onBack,
            onContinue: () async => _retry(),
            child: failure is Validation
                ? AuthFeedback.error(
                    'Something is missing: ${failure.field ?? 'an earlier step'}. Go back and check.',
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.goal, required this.targets});

  final Goal goal;
  final NutritionTargets targets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(goal.goalType.label.toUpperCase(), style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        TargetsDisplay(targets: targets),
        const SizedBox(height: FitSpacing.lg),
        HairlineSection(
          label: 'Why these numbers',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final line in targets.rationale)
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                  child: Text(line, style: textTheme.bodyMedium),
                ),
            ],
          ),
        ),
        const SizedBox(height: FitSpacing.lg),
        HairlineSection(
          label: 'Your first week',
          child: Text(
            'Your training programme is generated in a later release. '
            'Until then FitOS tracks your nutrition targets; workouts arrive with the programme builder.',
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
