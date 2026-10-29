import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../home/data/streak_api.dart';
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
/// when it unlocks. Beta 4.4 (owner): "Streak & rewards": the streak
/// itself on top, opened from Home's streak card too. Streak rewards against
/// the best streak so far, running
/// badges against the longest run so far, and what Premium includes.
/// Nothing here ever says "lost": earned is kept for good.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final streak = ref.watch(earnedRewardsProvider).value;
    final badges = ref.watch(earnedBadgesProvider).value;
    final streakNow = ref.watch(streakProvider).value;
    final best = streakNow?.best;
    final records = ref.watch(recordsProvider).value;
    final longest = records?.longestM;
    // Beta 4.5: how far each speed and lifetime badge is.
    final run = _RunProgress(
      longest: longest,
      total: records?.totalM,
      best: records?.recordTimes ?? const {},
    );
    final premium = ref.watch(isPremiumProvider) ?? false;
    final unit = ref.watch(runSettingsProvider).unit;
    final total = StreakReward.values.length + RunBadge.values.length;
    final earned = (streak?.length ?? 0) + (badges?.length ?? 0);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Streak & rewards'),
      ),
      body: FitBackdrop(
        child: ListView(
          key: const ValueKey('rewards.list'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            if (streakNow != null) ...[
              _StreakHeader(streak: streakNow),
              const SizedBox(height: FitSpacing.lg),
            ],
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
                for (final g in BadgeGroup.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: FitSpacing.xs,
                      bottom: FitSpacing.xs,
                    ),
                    child: Text(g.label, style: t.titleSmall),
                  ),
                  for (final b in RunBadge.values)
                    if (b.group == g)
                      _RewardTile(
                        key: ValueKey('rewards.${b.id}'),
                        icon: Icons.military_tech,
                        title: b.unlocks == null
                            ? b.label
                            : '${b.label} · ${_capital(b.unlocks!)}',
                        earned: badges?.containsKey(b) ?? false,
                        status: _badgeStatus(context, b, badges, run, unit),
                        progress: run.of(b),
                      ),
                ],
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
    RunBadge b,
    Map<RunBadge, DateTime>? earned,
    _RunProgress run,
    DistanceUnit unit,
  ) {
    final on = earned?[b];
    if (on != null) {
      return 'Earned ${MaterialLocalizations.of(context).formatMediumDate(on.toLocal())}';
    }
    if (b.metres == 0) return 'Unlocks with your first saved run';
    final how = b.howToEarn.replaceFirst('to earn it', 'to unlock it');
    switch (b.group) {
      case BadgeGroup.distance:
        final longest = run.longest;
        final left = longest == null ? null : b.metres! - longest;
        return left == null || left <= 0
            ? how
            : '$how ${formatDistance(left, unit)} ${unit.label} more than '
                'your longest.';
      case BadgeGroup.speed:
        final best = run.best[b.effort];
        return best == null
            ? how
            : '$how Your best: ${formatDuration(best.round())}.';
      case BadgeGroup.lifetime:
        final total = run.total;
        final left = total == null ? null : b.totalM! - total;
        return left == null || left <= 0
            ? how
            : '$how ${formatDistance(left, unit)} ${unit.label} to go.';
      case BadgeGroup.consistency:
        return how;
    }
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

/// Beta 4.4: the streak now and best, this week's ring, and the last 4 weeks
/// as a grid of days (Monday first).
class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = streak;
    return FitBlock(
      key: const ValueKey('streak.header'),
      glow: true,
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 36,
                color: s.current == 0 ? FitColors.ink35 : FitColors.amber,
              ),
              const SizedBox(width: FitSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.current == 0
                          ? 'No streak yet'
                          : '${s.current}-day streak',
                      key: const ValueKey('streak.current'),
                      style: t.titleLarge,
                    ),
                    Text(
                      'Best: ${s.best} ${s.best == 1 ? 'day' : 'days'}',
                      key: const ValueKey('streak.best'),
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (s.weekDone != null && s.weekPlanned != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${s.weekDone}/${s.weekPlanned}',
                      key: const ValueKey('streak.week'),
                      style: t.titleLarge,
                    ),
                    Text('this week', style: t.bodySmall),
                  ],
                ),
            ],
          ),
          if (s.days.isNotEmpty) ...[
            const SizedBox(height: FitSpacing.md),
            _DayGrid(days: s.days),
            const SizedBox(height: FitSpacing.sm),
            const _Legend(),
          ],
          const SizedBox(height: FitSpacing.xs),
          Text(
            'A day counts when you log a workout or a meal; a planned rest '
            'day counts once a streak is going.',
            style: t.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

Color _dayColour(StreakDayStatus s) => switch (s) {
      StreakDayStatus.logged => FitColors.accent,
      StreakDayStatus.rest => FitColors.pine.withValues(alpha: 0.45),
      StreakDayStatus.skipped => FitColors.ink35.withValues(alpha: 0.5),
      StreakDayStatus.missed => FitColors.rule,
      StreakDayStatus.today => Colors.transparent,
      StreakDayStatus.before => Colors.transparent,
    };

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.days});

  final List<StreakDay> days;

  static int _weekday(String d) => DateTime.parse(d).weekday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Monday first: blanks before the first day, so columns are weekdays.
    final cells = <StreakDay?>[
      for (var i = 1; i < _weekday(days.first.date); i++) null,
      ...days,
    ];
    final rows = <List<StreakDay?>>[
      for (var i = 0; i < cells.length; i += 7)
        cells.sublist(i, i + 7 > cells.length ? cells.length : i + 7),
    ];
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    // Beta 4.4 patch (owner: "dates not visible"): every day shows its date;
    // days before the account are outlined, so the grid never looks empty.
    Widget cell(StreakDay? d) {
      final today = d?.status == StreakDayStatus.today;
      final before = d?.status == StreakDayStatus.before;
      final logged = d?.status == StreakDayStatus.logged;
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            key: d == null ? null : ValueKey('streak.day.${d.date}'),
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: d == null ? Colors.transparent : _dayColour(d.status),
              borderRadius: BorderRadius.circular(6),
              border: today
                  ? Border.all(color: FitColors.accent, width: 2)
                  : before
                      ? Border.all(color: FitColors.rule)
                      : null,
            ),
            child: d == null
                ? null
                : Text(
                    '${int.parse(d.date.substring(8))}',
                    key: ValueKey('streak.day.${d.date}.date'),
                    style: t.labelMedium?.copyWith(
                      color: logged
                          ? FitColors.onAccent
                          : before
                              ? FitColors.ink35
                              : FitColors.ink,
                      fontWeight: today ? FontWeight.w700 : null,
                    ),
                  ),
          ),
        ),
      );
    }

    String label(String d) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${int.parse(d.substring(8))} ${months[int.parse(d.substring(5, 7)) - 1]}';
    }

    return Column(
      key: const ValueKey('streak.grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 4 weeks · ${label(days.first.date)} – ${label(days.last.date)}',
          key: const ValueKey('streak.grid.range'),
          style: t.labelSmall,
        ),
        const SizedBox(height: FitSpacing.xs),
        Row(
          children: [
            for (final n in names)
              Expanded(child: Center(child: Text(n, style: t.labelSmall))),
          ],
        ),
        for (final r in rows)
          Row(
            children: [
              for (var i = 0; i < 7; i++) cell(i < r.length ? r[i] : null),
            ],
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    Widget item(StreakDayStatus s, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _dayColour(s),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: FitSpacing.xs),
            Text(label, style: muted),
          ],
        );
    return Wrap(
      spacing: FitSpacing.md,
      runSpacing: FitSpacing.xs,
      children: [
        item(StreakDayStatus.logged, 'Logged'),
        item(StreakDayStatus.rest, 'Rest day'),
        item(StreakDayStatus.skipped, 'Skipped'),
        item(StreakDayStatus.missed, 'Missed'),
      ],
    );
  }
}

/// Beta 4.5: what a badge's bar measures — the longest run (distance
/// firsts), the best effort (speed: the target time over it), the total run
/// (lifetime); nothing for consistency.
class _RunProgress {
  const _RunProgress({
    required this.longest,
    required this.total,
    required this.best,
  });

  final double? longest;
  final double? total;
  final Map<EffortKey, double> best;

  double? of(RunBadge b) => switch (b.group) {
        BadgeGroup.distance =>
          b.metres == 0 || longest == null ? null : longest! / b.metres!,
        BadgeGroup.speed =>
          best[b.effort] == null ? null : b.underSeconds! / best[b.effort]!,
        BadgeGroup.lifetime => total == null ? null : total! / b.totalM!,
        BadgeGroup.consistency => null,
      };
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
