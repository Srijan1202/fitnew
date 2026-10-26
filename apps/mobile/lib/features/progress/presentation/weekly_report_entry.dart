import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../premium/domain/avatars.dart';
import '../../premium/presentation/premium_providers.dart';
import '../../../core/config/app_features.dart';

/// Phase 19 (ADR-027): the way into the weekly report from Progress — with a
/// lock for a free user (the screen then shows what premium is).
class WeeklyReportEntry extends ConsumerWidget {
  const WeeklyReportEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Beta 3.3 (ADR-033): hidden while the admin has switched it off.
    if (!ref.watch(featureOnProvider(AppFeature.weeklyReport))) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    final locked = ref.watch(isPremiumProvider) == false;
    // Beta 3.9: one slim row, so it never outweighs the weight above.
    return InkWell(
      key: const ValueKey('progress.weekly'),
      onTap: () => context.push(Routes.weeklyReport),
      borderRadius: BorderRadius.all(FitRadius.small),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FitSpacing.md,
          vertical: FitSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: kGold.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.all(FitRadius.small),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.insights, color: kGoldDeep, size: 20),
            const SizedBox(width: FitSpacing.sm),
            Expanded(
              child: Text(
                'Weekly report',
                style: textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              locked ? Icons.lock_outline : Icons.chevron_right,
              key: ValueKey(
                locked ? 'progress.weekly.locked' : 'progress.weekly.open',
              ),
              size: 20,
              color: locked ? kGoldDeep : FitColors.ink60,
            ),
          ],
        ),
      ),
    );
  }
}
