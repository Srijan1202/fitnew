import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../domain/avatars.dart';
import '../domain/streak_rewards.dart';
import 'rewards_providers.dart';

/// Beta 3.4 (ADR-027 amendment): every streak reward, earned or how far away
/// (from the best streak so far). Nothing here ever says "lost".
Future<void> showStreakRewards(BuildContext context, {int? best}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RewardsSheet(best: best),
    );

class _RewardsSheet extends ConsumerWidget {
  const _RewardsSheet({required this.best});

  final int? best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final earned = ref.watch(earnedRewardsProvider).value ?? const {};
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('rewards.sheet'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          0,
          FitSpacing.screen,
          FitSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('STREAK REWARDS', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'Earned by your best streak: a day counts when you log a workout or a meal. Kept for good once earned.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            for (final r in StreakReward.values)
              _RewardRow(reward: r, earned: earned.contains(r), best: best),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.reward,
    required this.earned,
    required this.best,
  });

  final StreakReward reward;
  final bool earned;
  final int? best;

  String get _status {
    if (earned) return 'Earned';
    final b = best;
    if (b == null) return '${reward.days}-day streak';
    final left = reward.days - b;
    return left <= 0
        ? 'Earned with your next streak check'
        : '$left more ${left == 1 ? 'day' : 'days'} than your best';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: ValueKey('rewards.${reward.id}'),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor:
                earned ? kEmber.withValues(alpha: 0.18) : FitColors.paper2,
            child: Text(
              '${reward.days}',
              style: textTheme.labelLarge?.copyWith(
                color: earned ? kEmber : FitColors.ink60,
              ),
            ),
          ),
          const SizedBox(width: FitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(reward.label, style: textTheme.titleMedium),
                Text(
                  _status,
                  key: ValueKey('rewards.${reward.id}.status'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: earned ? kEmber : FitColors.ink60,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            earned ? Icons.local_fire_department : Icons.lock_outline,
            color: earned ? kEmber : FitColors.ink35,
          ),
        ],
      ),
    );
  }
}

/// Shown once when a streak read reports new rewards.
Future<void> celebrateRewards(
  BuildContext context,
  List<StreakReward> rewards,
  int days,
) =>
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        return AlertDialog(
          key: const ValueKey('rewards.celebrate'),
          backgroundColor: FitColors.paper,
          title: Text('🔥 $days days!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                rewards.length == 1 ? 'You unlocked:' : 'You unlocked:',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.xs),
              for (final r in rewards)
                Text('• ${r.label}', style: textTheme.titleMedium),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Yours to keep. Find them in Profile.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              key: const ValueKey('rewards.celebrate.ok'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Nice'),
            ),
          ],
        );
      },
    );

/// The 100-day badge beside the name on Profile.
class CenturyBadge extends StatelessWidget {
  const CenturyBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('profile.centuryBadge'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: kEmber.withValues(alpha: 0.16),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: kEmber.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.local_fire_department, size: 14, color: kEmber),
            const SizedBox(width: 4),
            Text(
              '100 DAYS',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: kEmber),
            ),
          ],
        ),
      );
}
