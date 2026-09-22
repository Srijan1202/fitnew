import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../domain/entities/onboarding.dart';
import '../controllers/onboarding_controller.dart';
import 'steps/about_step.dart';
import 'steps/experience_step.dart';
import 'steps/food_step.dart';
import 'steps/goal_step.dart';
import 'steps/plan_step.dart';
import 'steps/training_step.dart';
import 'steps/vit_step.dart';

/// Screens 1–7 (§32).
///
/// The server owns *what has been answered*; this screen owns only *which
/// screen is showing*. It starts on the first unanswered step, "back" steps
/// the index down, and every "continue" round-trips an answer before moving
/// on. Nothing is decided here.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  /// 0–5 are the six answer screens; 6 is the plan. Null until state loads.
  int? _index;

  int _startIndexFor(OnboardingState state) {
    if (state.stage == OnboardingStage.complete) return 6;
    return OnboardingStage.steps.indexOf(state.stage);
  }

  Future<Failure?> _submit(OnboardingAnswer answer) =>
      ref.read(onboardingControllerProvider.notifier).answer(answer);

  void _next() => setState(() => _index = (_index ?? 0) + 1);
  void _back() => setState(() => _index = (_index ?? 1) - 1);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(onboardingControllerProvider);

    return async.when(
      loading: () => const _Holding(),
      error: (error, _) => _LoadFailed(
        failure: error is Failure ? error : const Unknown(),
        onRetry: () => ref.invalidate(onboardingControllerProvider),
      ),
      data: (state) {
        final index = _index ??= _startIndexFor(state);
        final back = index > 0 ? _back : null;

        return switch (index) {
          0 => GoalStep(state: state, submit: _submit, onNext: _next),
          1 => AboutStep(
              state: state,
              submit: _submit,
              onBack: back,
              onNext: _next,
              suggestedName:
                  ref.read(authRepositoryProvider).suggestedDisplayName,
            ),
          2 => ExperienceStep(
              state: state,
              submit: _submit,
              onBack: back,
              onNext: _next,
            ),
          3 => TrainingStep(
              state: state,
              submit: _submit,
              onBack: back,
              onNext: _next,
            ),
          4 => FoodStep(
              state: state,
              submit: _submit,
              onBack: back,
              onNext: _next,
            ),
          5 =>
            VitStep(state: state, submit: _submit, onBack: back, onNext: _next),
          _ => PlanStep(state: state, onBack: back),
        };
      },
    );
  }
}

class _Holding extends StatelessWidget {
  const _Holding();

  @override
  Widget build(BuildContext context) {
    // Skeleton matching the final layout, not a spinner (§6.6).
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: FitSpacing.lg),
              Text('ONBOARDING', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.md),
              for (final w in const [180.0, 260.0, 220.0])
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                  child:
                      Container(width: w, height: 14, color: FitColors.paper2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Could not load your progress', style: textTheme.titleLarge),
              const SizedBox(height: FitSpacing.sm),
              AuthFeedback.error(failure.message),
              const SizedBox(height: FitSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
