import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../premium/presentation/reward_art.dart';
import '../../../premium/presentation/rewards_providers.dart';
import '../../domain/efforts.dart';

/// Beta 4.2 (owner 2026-10-29): the running distance firsts — earned ones
/// with their day, the rest with what earns them, and what three of them
/// unlock (an app icon, a theme, an app icon), chosen in Profile.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(earnedBadgesProvider);
    final earned = async.value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Running badges'),
      ),
      body: FitBackdrop(
        child: ListView(
          key: const ValueKey('badges.list'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            if (async.isLoading && earned == null)
              const Padding(
                padding: EdgeInsets.all(FitSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (earned == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.md),
                  child: Text(
                    'Offline: your badges show once FITOS can reach the '
                    'server.',
                    key: const ValueKey('badges.offline'),
                    style: t.bodyMedium,
                  ),
                ),
              // Beta 4.5: in groups — distance firsts, speed, lifetime,
              // consistency.
              for (final g in BadgeGroup.values) ...[
                Padding(
                  key: ValueKey('badges.group.${g.name}'),
                  padding: const EdgeInsets.only(
                    top: FitSpacing.sm,
                    bottom: FitSpacing.sm,
                  ),
                  child: Text(g.label.toUpperCase(), style: t.labelSmall),
                ),
                for (final b in RunBadge.values)
                  if (b.group == g)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                      child: _BadgeTile(badge: b, earnedOn: earned?[b]),
                    ),
              ],
              Text(
                'Distance firsts need one run of at least that distance, '
                'treadmill and watch runs too. Speed badges need a run with '
                'its route. Past runs count.',
                style: t.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earnedOn});

  final RunBadge badge;
  final DateTime? earnedOn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final earned = earnedOn != null;
    return FitBlock(
      key: ValueKey('badge.${badge.id}'),
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Row(
        children: [
          // Beta 4.8 (owner): what the badge is, or unlocks, with a lock
          // on top until earned.
          RewardArt(id: badge.id, earned: earned),
          const SizedBox(width: FitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.label,
                  style: t.titleMedium?.copyWith(
                    color: earned ? FitColors.ink : FitColors.ink60,
                  ),
                ),
                Text(
                  earned
                      ? 'Earned ${MaterialLocalizations.of(context).formatMediumDate(earnedOn!.toLocal())}'
                      : badge.howToEarn,
                  key: ValueKey('badge.${badge.id}.status'),
                  style: t.bodyMedium,
                ),
                if (badge.unlocks != null)
                  Text(
                    earned
                        ? 'Unlocked ${badge.unlocks}: choose it in Profile.'
                        : 'Unlocks ${badge.unlocks}.',
                    key: ValueKey('badge.${badge.id}.unlocks'),
                    style: t.bodySmall?.copyWith(
                      color: earned ? FitColors.pine : FitColors.ink60,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
