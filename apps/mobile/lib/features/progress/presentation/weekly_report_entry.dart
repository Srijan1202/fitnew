import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../premium/domain/avatars.dart';
import '../../premium/presentation/premium_providers.dart';

/// Phase 19 (ADR-027): the way into the weekly report from Progress — with a
/// lock for a free user (the screen then shows what premium is).
class WeeklyReportEntry extends ConsumerWidget {
  const WeeklyReportEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final locked = ref.watch(isPremiumProvider) == false;
    return InkWell(
      key: const ValueKey('progress.weekly'),
      onTap: () => context.push(Routes.weeklyReport),
      child: Container(
        padding: const EdgeInsets.all(FitSpacing.md),
        decoration: BoxDecoration(border: Border.all(color: kGold)),
        child: Row(
          children: <Widget>[
            const Icon(Icons.insights, color: kGoldDeep),
            const SizedBox(width: FitSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Weekly report', style: textTheme.titleMedium),
                  Text(
                    'Your week on one page: sessions, volume, records, protein, trend weight.',
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
            Icon(
              locked ? Icons.lock_outline : Icons.chevron_right,
              key: ValueKey(
                locked ? 'progress.weekly.locked' : 'progress.weekly.open',
              ),
              color: locked ? kGoldDeep : FitColors.ink60,
            ),
          ],
        ),
      ),
    );
  }
}
