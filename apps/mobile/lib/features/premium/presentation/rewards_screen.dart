import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../running/domain/efforts.dart';
import '../../running/domain/units.dart';
import '../../running/presentation/controllers/running_providers.dart';
import '../domain/app_icons.dart';
import '../domain/avatars.dart';
import '../domain/streak_rewards.dart';
import 'premium_providers.dart';
import 'premium_sheet.dart';
import 'rewards_providers.dart';

/// Beta 4.3 (owner 2026-10-29): every reward in one place — what it is, and
/// when it unlocks. Streak rewards against the best streak so far, running
/// badges against the longest run so far, and what Premium includes.
/// Nothing here ever says "lost": earned is kept for good.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final streak = ref.watch(earnedRewardsProvider).value;
    final badges = ref.watch(earnedBadgesProvider).value;
    final best = ref.watch(streakProvider).value?.best;
    final longest = ref.watch(recordsProvider).value?.longestM;
    final premium = ref.watch(isPremiumProvider) ?? false;
    final unit = ref.watch(runSettingsProvider).unit;
    final total = StreakReward.values.length + DistanceBadge.values.length;
    final earned = (streak?.length ?? 0) + (badges?.length ?? 0);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Rewards'),
      ),
      body: FitBackdrop(
        child: ListView(
          key: const ValueKey('rewards.list'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            Text(
              '$earned of $total earned',
              key: const ValueKey('rewards.count'),
              style: t.displaySmall,
            ),
            Text(
              'Earned rewards are yours for good. Choose a picture, theme or '
              'app icon in Profile.',
              style: t.bodyMedium,
            ),
            if (streak == null || badges == null)
              Padding(
                padding: const EdgeInsets.only(top: FitSpacing.xs),
                child: Text(
                  'Offline: what you earned shows once FITOS can reach the '
                  'server.',
                  key: const ValueKey('rewards.offline'),
                  style: t.bodyMedium?.copyWith(color: FitColors.amber),
                ),
              ),
            _Section(
              title: 'STREAK',
              note: best == null
                  ? 'A day counts when you log a workout or a meal.'
                  : 'Your best streak: $best ${best == 1 ? 'day' : 'days'}. '
                      'A day counts when you log a workout or a meal.',
              children: [
                for (final r in StreakReward.values)
                  _RewardTile(
                    key: ValueKey('rewards.${r.id}'),
                    icon: Icons.local_fire_department,
                    title: r.label,
                    earned: streak?.contains(r) ?? false,
                    status: _streakStatus(r, streak, best),
                    progress: best == null ? null : best / r.days,
                  ),
              ],
            ),
            _Section(
              title: 'RUNNING',
              note: longest == null || longest == 0
                  ? 'One run of at least the distance, treadmill too.'
                  : 'Your longest run: ${formatDistance(longest, unit)} '
                      '${unit.label}. One run of at least the distance, '
                      'treadmill too.',
              children: [
                for (final b in DistanceBadge.values)
                  _RewardTile(
                    key: ValueKey('rewards.${b.id}'),
                    icon: Icons.military_tech,
                    title: b.unlocks == null
                        ? b.label
                        : '${b.label} · ${_capital(b.unlocks!)}',
                    earned: badges?.containsKey(b) ?? false,
                    status: _badgeStatus(context, b, badges, longest, unit),
                    progress: b.metres == 0 || longest == null
                        ? null
                        : longest / b.metres,
                  ),
              ],
            ),
            _Section(
              title: 'PREMIUM',
              note: premium
                  ? 'Yours with Premium.'
                  : 'Included with FITOS Premium.',
              children: [
                for (final (key, title, detail) in _premiumItems())
                  _RewardTile(
                    key: ValueKey('rewards.premium.$key'),
                    icon: Icons.workspace_premium,
                    title: title,
                    earned: premium,
                    status: premium ? detail : 'With Premium · $detail',
                  ),
                if (!premium)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('rewards.premium.about'),
                      onPressed: () => showPremiumSheet(context),
                      child: const Text('About Premium'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _capital(String s) => s[0].toUpperCase() + s.substring(1);

  static String _streakStatus(
    StreakReward r,
    Set<StreakReward>? earned,
    int? best,
  ) {
    if (earned?.contains(r) ?? false) return 'Earned';
    if (best == null) return 'Unlocks at a ${r.days}-day streak';
    final left = r.days - best;
    return left <= 0
        ? 'Unlocks with your next streak check'
        : 'Unlocks at a ${r.days}-day streak: $left more '
            '${left == 1 ? 'day' : 'days'} than your best';
  }

  static String _badgeStatus(
    BuildContext context,
    DistanceBadge b,
    Map<DistanceBadge, DateTime>? earned,
    double? longest,
    DistanceUnit unit,
  ) {
    final on = earned?[b];
    if (on != null) {
      return 'Earned ${MaterialLocalizations.of(context).formatMediumDate(on.toLocal())}';
    }
    if (b.metres == 0) return 'Unlocks with your first saved run';
    final left = longest == null ? null : b.metres - longest;
    return left == null || left <= 0
        ? b.howToEarn.replaceFirst('to earn it', 'to unlock it')
        : '${b.howToEarn.replaceFirst('to earn it', 'to unlock it')} '
            '${formatDistance(left, unit)} ${unit.label} more than your '
            'longest.';
  }

  static List<(String, String, String)> _premiumItems() => [
        (
          'icons',
          'App icons',
          [
            for (final i in AppIcon.values)
              if (i.premium) i.label,
          ].join(', '),
        ),
        (
          'themes',
          'Themes',
          [
            for (final p in FitPalette.all)
              if (p.premium) p.label,
          ].join(', '),
        ),
        (
          'pictures',
          'Profile pictures and the gold rim',
          [
            for (final a in kAvatars)
              if (a.premium) a.label,
          ].join(', '),
        ),
        ('ai', 'The AI coach', 'Chat, meal photos and the weekly report'),
      ];
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.note,
    required this.children,
  });

  final String title;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text(note, style: t.bodyMedium?.copyWith(color: FitColors.ink60)),
          const SizedBox(height: FitSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.title,
    required this.earned,
    required this.status,
    this.progress,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool earned;
  final String status;

  /// How far towards it (0–1); null where there is nothing to measure.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colour = earned ? FitColors.accent : FitColors.ink35;
    final p = progress;
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.sm),
      child: FitBlock(
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Row(
          children: [
            Icon(earned ? icon : Icons.lock_outline, color: colour),
            const SizedBox(width: FitSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleMedium?.copyWith(
                      color: earned ? FitColors.ink : FitColors.ink60,
                    ),
                  ),
                  Text(
                    status,
                    key: key is ValueKey<String>
                        ? ValueKey('${(key! as ValueKey<String>).value}.status')
                        : null,
                    style: t.bodyMedium,
                  ),
                  if (!earned && p != null) ...[
                    const SizedBox(height: FitSpacing.xs),
                    LinearProgressIndicator(
                      value: p.clamp(0.0, 1.0),
                      minHeight: 4,
                      color: FitColors.accent,
                      backgroundColor: FitColors.rule,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
