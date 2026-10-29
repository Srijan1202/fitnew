import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../domain/avatars.dart';
import '../domain/streak_rewards.dart';

/// Beta 3.4 (ADR-027 amendment). Beta 4.3: the list of every reward moved to
/// its own page (rewards_screen.dart); the celebration stays here.

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
