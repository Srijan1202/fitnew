import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:go_router/go_router.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_screen.dart';
import 'invite_qr.dart';

/// Beta 5.8 (ADR-057): one club — its board this week, its code to share,
/// leaving it, and reporting its name. Beta 6.2: an invite link and QR code
/// (C8), the owner's settings (C5), and a tap opens a member's week (C4).
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
              if (v == 'settings') {
                await context.push(Routes.communityClubSettings(clubId));
              } else if (v == 'report') {
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
            itemBuilder: (_) => [
              if (c?.mine ?? false)
                const PopupMenuItem(
                  key: ValueKey('club.settings'),
                  value: 'settings',
                  child: Text('Club settings'),
                ),
              const PopupMenuItem(
                key: ValueKey('club.report'),
                value: 'report',
                child: Text('Report the club name'),
              ),
              const PopupMenuItem(
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
                      IconButton.outlined(
                        key: const ValueKey('club.qr'),
                        tooltip: 'QR code',
                        icon: const Icon(Icons.qr_code_2),
                        onPressed: () => showModalBottomSheet<void>(
                          useRootNavigator: true,
                          context: context,
                          useSafeArea: true,
                          builder: (sheet) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(FitSpacing.lg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.name,
                                    style: Theme.of(sheet).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: FitSpacing.md),
                                  InviteQr(data: clubInviteUrl(c.code)),
                                  const SizedBox(height: FitSpacing.sm),
                                  Text('Code ${c.shownCode}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: FitSpacing.xs),
                      IconButton.filledTonal(
                        key: const ValueKey('club.share'),
                        tooltip: 'Share an invite link',
                        icon: const Icon(Icons.ios_share),
                        // Beta 6.2 (C8): the link opens FITOS on "Join this club?".
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text: 'Join "${c.name}" on FITOS: '
                                '${clubInviteUrl(c.code)} (or Community › Clubs › '
                                'Join with a code: ${c.shownCode})',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: FitSpacing.md),
              const BoardMetricPicker(),
              const SizedBox(height: FitSpacing.md),
              BoardLoader(
                board: ref.watch(clubBoardProvider((clubId, metric))),
                emptyText: 'Nobody here yet: share the code.',
                onRetry: () => ref.invalidate(clubBoardProvider),
                onPerson: (r) => context.push(
                  Routes.communityPerson(r.userId),
                  extra: r.handle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
