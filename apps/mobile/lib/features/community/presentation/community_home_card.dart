import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_features.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/community.dart';
import 'community_providers.dart';

/// Beta 5.8 (ADR-057): Home's way into Community — an invitation before
/// joining; after, your place among friends this week and any requests.
/// Nothing when the admin switched Community off or it cannot be reached.
class CommunityHomeCard extends ConsumerWidget {
  const CommunityHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureOnProvider(AppFeature.community))) {
      return const SizedBox.shrink();
    }
    final me = ref.watch(communityMeProvider).value;
    if (me == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final String title;
    final String line;
    if (!me.joined) {
      title = 'Train with friends';
      line = 'Friends, clubs and a world board: sessions and run km, never '
          'your weights or food.';
    } else {
      final board = ref.watch(friendsBoardProvider(BoardMetric.sessions)).value;
      final mine = board?.rows.where((r) => r.me).firstOrNull;
      title = me.incoming > 0
          ? '${me.incoming} friend ${me.incoming == 1 ? 'request' : 'requests'}'
          : 'Community';
      line = board == null || mine == null
          ? 'Your friends and clubs this week.'
          : board.rows.length == 1
              ? 'Add friends to see their week next to yours.'
              : '#${mine.rank} of ${board.rows.length} friends this week · '
                  '${mine.sessions} ${mine.sessions == 1 ? 'session' : 'sessions'}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.md,
      ),
      child: FitBlock(
        key: const ValueKey('home.community'),
        padding: const EdgeInsets.all(FitSpacing.md),
        // Beta 5.9: Community is the last tab.
        onTap: () => context.go(Routes.community),
        child: Row(
          children: [
            Icon(
              me.joined ? Icons.emoji_events_outlined : Icons.public,
              color: FitColors.accent,
            ),
            const SizedBox(width: FitSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  Text(
                    line,
                    key: const ValueKey('home.community.line'),
                    style: t.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
