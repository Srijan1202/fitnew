import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../widgets/targets_display.dart';

/// Profile: what the server holds about this user, the active goal with its
/// targets, and the way to change the goal. Read-only apart from that link —
/// editing the other fields is a ledger of small forms that lands with the
/// features that need them (§32 deferred list).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrHome())),
      body: SafeArea(
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(FitSpacing.screen),
            child: TargetsSkeleton(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AuthFeedback.error(
                  (e is Failure ? e : const Unknown()).message,
                ),
                const SizedBox(height: FitSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(profileControllerProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (view) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('PROFILE', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  view.goal.goal.goalType.label,
                  style: textTheme.displaySmall,
                ),
                const SizedBox(height: FitSpacing.lg),
                if (view.goal.targets != null) ...<Widget>[
                  TargetsDisplay(targets: view.goal.targets!),
                  const SizedBox(height: FitSpacing.sm),
                  Text(
                    'Since ${view.goal.targets!.effectiveFrom} · ${view.goal.targets!.reason}',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: FitSpacing.lg),
                ],
                OutlinedButton(
                  onPressed: () => context.push(Routes.goalEditor),
                  style: _outlined,
                  child: const Text('Change goal'),
                ),
                const SizedBox(height: FitSpacing.xl),
                HairlineSection(
                  label: 'About you',
                  child: _Facts(profile: view.profile),
                ),
                const SizedBox(height: FitSpacing.xl),
                OutlinedButton(
                  key: const ValueKey('profile.health'),
                  onPressed: () => context.push(Routes.healthData),
                  style: _outlined,
                  child: const Text('Health data'),
                ),
                const SizedBox(height: FitSpacing.md),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  style: _outlined,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _outlined = OutlinedButton.styleFrom(
  foregroundColor: FitColors.ink,
  side: const BorderSide(color: FitColors.ink),
  minimumSize: const Size(88, 48),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(FitRadius.small),
  ),
);

class _Facts extends StatelessWidget {
  const _Facts({required this.profile});

  final UserProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <(String, String)>[
      if (profile.sex != null) ('Sex', profile.sex!.label),
      if (profile.birthDate != null) ('Born', profile.birthDate!),
      if (profile.heightCm != null) ('Height', '${profile.heightCm} cm'),
      if (profile.latestWeightKg != null)
        ('Weight', '${profile.latestWeightKg} kg'),
      if (profile.experienceLevel != null)
        ('Experience', profile.experienceLevel!.label),
      if (profile.trainingDaysPerWeek != null)
        ('Training', '${profile.trainingDaysPerWeek} days / week'),
      if (profile.activityLevel != null)
        ('Outside the gym', profile.activityLevel!.label),
      if (profile.trainingLocation != null)
        ('Trains at', profile.trainingLocation!.label),
      if (profile.equipment.isNotEmpty)
        ('Equipment', profile.equipment.map((e) => e.label).join(', ')),
      if (profile.mess != null)
        ('Mess', '${profile.mess!.hostelId} · ${profile.mess!.messId}'),
      ('Time zone', profile.timezone),
    ];
    return Column(
      children: <Widget>[
        for (final (label, value) in rows) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: Text(label, style: textTheme.bodyMedium),
                ),
                Expanded(child: Text(value, style: textTheme.bodyLarge)),
              ],
            ),
          ),
          const Divider(color: FitColors.rule, height: 1),
        ],
      ],
    );
  }
}
