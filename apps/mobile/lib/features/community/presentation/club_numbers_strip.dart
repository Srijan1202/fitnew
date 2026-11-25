import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/club_goals.dart';
import 'community_providers.dart';

/// Beta 6.6 (M3): the club this month at the top of its board: sessions, run
/// km and active days, all members together, and the best week so far. Only
/// totals, never who. Nothing shows while the month is empty.
class ClubNumbersStrip extends ConsumerWidget {
  const ClubNumbersStrip({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(clubNumbersProvider(clubId)).value;
    if (n == null || (n.sessions == 0 && n.runKm == 0 && n.activeDays == 0)) {
      return const SizedBox.shrink();
    }
    final t = Theme.of(context).textTheme;
    Widget figure(String key, String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                key: ValueKey('numbers.$key'),
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                style: t.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: FitBlock(
        key: const ValueKey('numbers.card'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${monthName(n.month).toUpperCase()}, TOGETHER',
              style: t.labelSmall,
            ),
            const SizedBox(height: FitSpacing.sm),
            Row(
              children: [
                figure('sessions', '${n.sessions}', 'sessions'),
                figure('km', countText(n.runKm), 'run km'),
                figure('days', '${n.activeDays}', 'active days'),
              ],
            ),
            if (n.bestWeekFrom != null) ...[
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Best week: ${n.bestWeekSessions} sessions, the week of '
                '${dayLabel(n.bestWeekFrom!)}',
                key: const ValueKey('numbers.best'),
                style: t.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
