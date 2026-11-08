import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_screen.dart';

/// Beta 5.8 (ADR-057): one club — its board this week, its code to share,
/// leaving it, and reporting its name.
class ClubScreen extends ConsumerWidget {
  const ClubScreen({required this.clubId, this.club, super.key});

  final String clubId;

  /// From the list, so the name shows at once.
  final Club? club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final metric = ref.watch(boardMetricProvider);
    final c = ref
            .watch(clubsProvider)
            .value
            ?.where((x) => x.id == clubId)
            .firstOrNull ??
        club;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text(c?.name ?? 'Club'),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('club.menu'),
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) async {
              if (v == 'report') {
                await showReportSheet(context, ref, clubId: clubId);
              } else if (v == 'leave') {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Leave this club?'),
                    content: Text(
                      c?.mine ?? false
                          ? 'You made it: it passes to its longest member, or goes when nobody is left.'
                          : 'You can join again with its code.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: const Text('Stay'),
                      ),
                      FilledButton(
                        key: const ValueKey('club.leave.confirm'),
                        onPressed: () => Navigator.of(d).pop(true),
                        child: const Text('Leave'),
                      ),
                    ],
                  ),
                );
                if (sure != true) return;
                await ref.read(communityApiProvider).leaveClub(clubId);
                refreshCommunity(ref);
                if (context.mounted) context.popOrHome();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                key: ValueKey('club.report'),
                value: 'report',
                child: Text('Report the club name'),
              ),
              PopupMenuItem(
                key: ValueKey('club.leave'),
                value: 'leave',
                child: Text('Leave the club'),
              ),
            ],
          ),
        ],
      ),
      body: FitBackdrop(
        child: RefreshIndicator(
          onRefresh: () async => refreshCommunity(ref),
          child: ListView(
            key: const ValueKey('club.list'),
            padding: const EdgeInsets.all(FitSpacing.screen),
            children: [
              if (c != null)
                FitBlock(
                  padding: const EdgeInsets.all(FitSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CODE', style: t.labelSmall),
                            Text(
                              c.shownCode,
                              key: const ValueKey('club.code'),
                              style:
                                  t.headlineSmall?.copyWith(letterSpacing: 2),
                            ),
                            Text(
                              '${c.members} ${c.members == 1 ? 'member' : 'members'}',
                              style:
                                  t.bodySmall?.copyWith(color: FitColors.ink60),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('club.share'),
                        tooltip: 'Share the code',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                'Join "${c.name}" on FITOS: Community › Clubs › '
                                'Join with a code: ${c.shownCode}. Get the app '
                                'at https://tryfitos.me',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: FitSpacing.md),
              SegmentedButton<BoardMetric>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: BoardMetric.sessions,
                    label: Text('Gym sessions'),
                  ),
                  ButtonSegment(
                    value: BoardMetric.distance,
                    label: Text('Run km'),
                  ),
                ],
                selected: {metric},
                onSelectionChanged: (v) =>
                    ref.read(boardMetricProvider.notifier).set(v.first),
              ),
              const SizedBox(height: FitSpacing.md),
              BoardLoader(
                board: ref.watch(clubBoardProvider((clubId, metric))),
                emptyText: 'Nobody here yet: share the code.',
                onRetry: () => ref.invalidate(clubBoardProvider),
                onPerson: (r) => showPersonSheet(
                  context,
                  ref,
                  userId: r.userId,
                  handle: r.handle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
