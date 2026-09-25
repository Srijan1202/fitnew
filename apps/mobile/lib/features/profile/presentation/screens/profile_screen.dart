import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../progress/domain/progress.dart';
import '../../../progress/presentation/progress_providers.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../widgets/mess_setting.dart';
import 'food_preferences_screen.dart' show FoodSettingRow;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        view.profile.displayName ?? 'No name yet',
                        key: const ValueKey('profile.displayName'),
                        style: textTheme.titleLarge?.copyWith(
                          color: view.profile.displayName == null
                              ? FitColors.ink60
                              : FitColors.ink,
                        ),
                      ),
                      const SizedBox(height: FitSpacing.sm),
                      _Facts(profile: view.profile),
                      const SizedBox(height: FitSpacing.md),
                      OutlinedButton(
                        key: const ValueKey('profile.personalDetails'),
                        onPressed: () => context.push(Routes.personalDetails),
                        style: _outlined,
                        child: const Text('Edit personal details'),
                      ),
                    ],
                  ),
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
                  key: const ValueKey('profile.signOut'),
                  onPressed: () => _signOut(context, ref),
                  style: _outlined,
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: FitSpacing.lg),
                // Phase 6.6: which build talks to which backend, so a
                // tester's report can name it. No secrets here.
                Text(
                  'FITOS ${Env.appVersion} · ${Env.flavor} · ${Env.apiHost}',
                  key: const ValueKey('profile.build'),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: FitColors.ink60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 6.6 Gate 7: signing out wipes this phone's workout data, sync
/// queue included — which once deleted the queued end of a session FITOS
/// already had, leaving it "in progress" on the server and blocking every
/// later session. Give the queue one chance to reach FITOS; if anything is
/// still unsynced, say so and let the user choose.
Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(workoutRepositoryProvider);
  await repo.sync().timeout(const Duration(seconds: 8), onTimeout: () {});
  final status = await repo.syncStatus();
  if (!status.clean) {
    if (!context.mounted) return;
    final n = status.pending + status.parked;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('signOut.unsynced'),
        title: const Text('Unsynced workout changes'),
        content: Text(
          '$n ${n == 1 ? 'change has' : 'changes have'} not reached FITOS yet. '
          'Signing out deletes ${n == 1 ? 'it' : 'them'} from this phone — '
          'including the end of any session that has not synced. '
          'Stay signed in and let it sync first?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey('signOut.anyway'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out anyway'),
          ),
          FilledButton(
            key: const ValueKey('signOut.stay'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay signed in'),
          ),
        ],
      ),
    );
    if (go != true) return;
  }
  await ref.read(authControllerProvider.notifier).signOut();
}

final _outlined = OutlinedButton.styleFrom(
  foregroundColor: FitColors.ink,
  side: const BorderSide(color: FitColors.ink),
  minimumSize: const Size(88, 48),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(FitRadius.small),
  ),
);

class _Facts extends ConsumerWidget {
  const _Facts({required this.profile});

  final UserProfileDetail profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    // Phase 12, §13.2: the trend weight is the headline; the latest raw
    // reading is shown small beneath it (never the other way round).
    final trend = ref
        .watch(progressSummaryProvider(ProgressWindow.d30))
        .value
        ?.summary
        ?.weight
        .currentTrendKg;
    final rows = <(String, String)>[
      if (profile.sex != null) ('Sex', profile.sex!.label),
      if (profile.birthDate != null) ('Born', profile.birthDate!),
      if (profile.heightCm != null) ('Height', '${profile.heightCm} cm'),
      // Rendered below as the trend headline with the raw reading small.
      if (trend != null || profile.latestWeightKg != null) ('Weight', ''),
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
      ('Time zone', profile.timezone),
    ];
    return Column(
      children: <Widget>[
        for (final (label, value) in rows)
          if (label == 'Weight') ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 120,
                    child: Text('Weight', style: textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          trend == null
                              ? 'Trend after your next readings'
                              : '${trend.toStringAsFixed(1)} kg trend',
                          key: const ValueKey('profile.weight.trend'),
                          style: trend == null
                              ? textTheme.bodyMedium
                                  ?.copyWith(color: FitColors.ink60)
                              : textTheme.bodyLarge,
                        ),
                        if (profile.latestWeightKg != null)
                          Text(
                            'Latest reading ${profile.latestWeightKg} kg',
                            key: const ValueKey('profile.weight.raw'),
                            style: textTheme.bodySmall
                                ?.copyWith(color: FitColors.ink35),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: FitColors.rule, height: 1),
          ] else ...<Widget>[
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
        // Phase 9 (owner D13): the mess by name, changeable here.
        MessSettingRow(mess: profile.mess),
        const Divider(color: FitColors.rule, height: 1),
        // Phase 10: diet and allergies — the hard rules for suggestions.
        const FoodSettingRow(),
        const Divider(color: FitColors.rule, height: 1),
      ],
    );
  }
}
