import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../workout/presentation/widgets/today_session_panel.dart';

/// Placeholder for the TODAY screen, now behind the auth gate.
///
/// It renders the design language from §6 and the signed-in profile the
/// backend returned, and offers sign-out. There is still no data, no engine
/// output and no computation here (§7.3, §30): the real screen is built in
/// Phase 11, fed by `GET /today`.
class TodayPlaceholderScreen extends ConsumerWidget {
  const TodayPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(authControllerProvider);
    final state = auth.value;
    final profile = state is AuthSignedIn ? state.profile : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('FITOS', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),

              // Numbers are the hero (§6.3). This one is a literal, not a
              // computed value — the engine that produces it lives on the
              // backend and is wired in Phase 11.
              Text('Phase 4', style: textTheme.displayMedium),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Signed in and onboarded. Your plan, targets and the library are one tap away.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.lg),

              if (profile != null)
                HairlineSection(
                  label: 'Your session',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Line(text: profile.email ?? 'No email on this account'),
                      _Line(text: 'Time zone ${profile.timezone}'),
                      _Line(text: 'Locale ${profile.locale}'),
                    ],
                  ),
                ),
              const SizedBox(height: FitSpacing.lg),

              const HairlineSection(
                label: 'Semantic colour',
                child: Row(
                  children: <Widget>[
                    _Swatch(color: FitColors.pine, label: 'On track'),
                    SizedBox(width: FitSpacing.md),
                    _Swatch(color: FitColors.amber, label: 'Estimated'),
                    SizedBox(width: FitSpacing.md),
                    _Swatch(color: FitColors.oxide, label: 'Fatigue'),
                  ],
                ),
              ),
              const SizedBox(height: FitSpacing.lg),

              HairlineSection(
                label: 'Build',
                child: Text(
                  'Flavour ${Env.flavor} · API ${Env.apiBaseUrl}',
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: FitSpacing.xl),

              // Phase 5: today's session, start / resume / done.
              const TodaySessionPanel(),
              const SizedBox(height: FitSpacing.lg),
              OutlinedButton(
                key: const ValueKey('today.plan'),
                // A tab, not a pushed page: switch to it.
                onPressed: () => context.go(Routes.plan),
                child: const Text('Your training plan'),
              ),
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                onPressed: () => context.push(Routes.profile),
                child: const Text('Profile and targets'),
              ),
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                onPressed: () => context.push(Routes.exercises),
                child: const Text('Exercise library'),
              ),
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                onPressed: auth.isLoading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitColors.ink,
                  side: const BorderSide(color: FitColors.ink),
                  minimumSize: const Size(88, 48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(FitRadius.small),
                  ),
                ),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Every metric carries a screen-reader label — a colour or number without
    // one is meaningless aurally (§6.8).
    return Semantics(
      label: '$label indicator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(FitRadius.small),
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
