import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:go_router/go_router.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../../shared/widgets/fit_mode_switch.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_screen.dart';
import 'club_challenge_card.dart';
import 'club_league_card.dart';
import 'club_match_card.dart';
import 'club_numbers_strip.dart';
import 'feed_view.dart';
import 'invite_qr.dart';

/// Beta 6.5 (K1): a club's two halves.
enum ClubHalf { board, feed }

/// Beta 5.8 (ADR-057): one club — its board this week, its code to share,
/// leaving it, and reporting its name. Beta 6.2: an invite link and QR code
/// (C8), the owner's settings (C5), and a tap opens a member's week (C4).
/// Beta 6.5 (K1): Board | Feed, the feed being what members share.
class ClubScreen extends ConsumerStatefulWidget {
  const ClubScreen({required this.clubId, this.club, super.key});

  final String clubId;

  /// From the list, so the name shows at once.
  final Club? club;

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen> {
  ClubHalf _half = ClubHalf.board;

  @override
  Widget build(BuildContext context) {
    final clubId = widget.clubId;
    final club = widget.club;
    final c = ref
            .watch(clubsProvider)
            .value
            ?.where((x) => x.id == clubId)
            .firstOrNull ??
        club;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(c?.name ?? 'Club', overflow: TextOverflow.ellipsis),
            ),
            // Beta 6.6 (L1): the last season's winner, for a season.
            if (c?.seasonWinner ?? false) ...[
              const SizedBox(width: FitSpacing.xs),
              Tooltip(
                message: 'Won the last league season',
                child: Icon(
                  Icons.emoji_events,
                  key: const ValueKey('club.winner'),
                  color: FitColors.accent,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
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
              if (c?.runs ?? false)
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                0,
              ),
              child: FitModeSwitch<ClubHalf>(
                key: const ValueKey('club.half'),
                thumbKey: const ValueKey('club.half.thumb'),
                value: _half,
                halves: const [
                  FitModeHalf(
                    ClubHalf.board,
                    'Board',
                    Icons.leaderboard_outlined,
                    key: ValueKey('club.half.board'),
                  ),
                  FitModeHalf(
                    ClubHalf.feed,
                    'Feed',
                    Icons.chat_bubble_outline,
                    key: ValueKey('club.half.feed'),
                  ),
                ],
                onChanged: (h) => setState(() => _half = h),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _half.index,
                children: [
                  _board(context, clubId, c),
                  FeedView(clubId: clubId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(BuildContext context, String clubId, Club? c) {
    final t = Theme.of(context).textTheme;
    final metric = ref.watch(boardMetricProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCommunity(ref),
      child: ListView(
        key: const ValueKey('club.list'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        children: [
          // Beta 6.7 (R6): who you are here and the way to invite; the code
          // is in the Invite sheet (a member uses it once).
          if (c != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      '${c.members} ${c.members == 1 ? 'member' : 'members'}',
                      if (c.role == ClubRole.owner) 'Owner',
                      if (c.role == ClubRole.coOwner) 'Co-owner',
                    ].join(' · '),
                    key: const ValueKey('club.meta'),
                    style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('club.invite'),
                  onPressed: () => showClubInvite(context, c),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Invite'),
                ),
              ],
            ),
          const SizedBox(height: FitSpacing.md),
          // Beta 6.7 (R6): what's on first — this week's match, then the
          // month's challenge (beta 6.5, K3 and K2; beta 6.6, L2: the owner
          // or a co-owner runs them), then the month in numbers (M3).
          ClubMatchCard(clubId: clubId, owner: c?.runs ?? false),
          ClubChallengeCard(clubId: clubId, owner: c?.runs ?? false),
          ClubNumbersStrip(clubId: clubId),
          // Beta 6.6 (L1): the league.
          ClubLeagueCard(clubId: clubId, runs: c?.runs ?? false),
          const BoardMetricPicker(),
          const SizedBox(height: FitSpacing.md),
          BoardLoader(
            board: ref.watch(clubBoardProvider((clubId, metric))),
            emptyText: 'Nobody here yet: share the code.',
            onRetry: () => ref.invalidate(clubBoardProvider),
            tagOf: c?.tagOf,
            onPerson: (r) => context.push(
              Routes.communityPerson(r.userId),
              extra: r.handle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Beta 6.7 (R6): the club's code, its QR and the invite link, in one sheet
/// (beta 6.2, C8: the link opens FITOS on "Join this club?").
Future<void> showClubInvite(BuildContext context, Club c) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) {
        final t = Theme.of(sheet).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.lg,
              0,
              FitSpacing.lg,
              FitSpacing.lg,
            ),
            child: Column(
              key: const ValueKey('club.inviteSheet'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Invite to ${c.name}', style: t.titleLarge),
                const SizedBox(height: FitSpacing.md),
                InviteQr(
                  key: const ValueKey('club.qr'),
                  data: clubInviteUrl(c.code),
                ),
                const SizedBox(height: FitSpacing.md),
                Text('CODE', style: t.labelSmall),
                Text(
                  c.shownCode,
                  key: const ValueKey('club.code'),
                  style: t.headlineSmall?.copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: FitSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('club.share'),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share an invite link'),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: 'Join "${c.name}" on FITOS: '
                            '${clubInviteUrl(c.code)} (or Community › Clubs › '
                            'Join with a code: ${c.shownCode})',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
