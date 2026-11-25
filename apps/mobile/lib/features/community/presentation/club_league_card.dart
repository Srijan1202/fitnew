import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/club_goals.dart';
import 'community_providers.dart';

/// Beta 6.6 (L1, owner 2026-11-25): the club in the league, under its match.
/// Clubs of 3 or more enter; each Saturday the league pairs them for the
/// coming week with a club of a similar average (active days per member); a
/// win is 3 points, a draw 1; seasons are 4 weeks. The table shows club names
/// and results, never members. The owner or a co-owner enters the club or
/// takes it out after the week.
class ClubLeagueCard extends ConsumerWidget {
  const ClubLeagueCard({required this.clubId, required this.runs, super.key});

  final String clubId;

  /// The viewer is the owner or a co-owner.
  final bool runs;

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    final r = await ref.read(communityApiProvider).enterLeague(clubId);
    if (!context.mounted) return;
    r.when(
      ok: (_) {
        ref.invalidate(clubLeagueProvider);
        _say(context, 'In the league: the first match is paired on Saturday.');
      },
      err: (f) => _say(context, f.message),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Leave the league?'),
        content: const Text(
          'This week’s match still counts. The club is not paired again, '
          'and its results stay in this season’s table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            key: const ValueKey('league.leave.confirm'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final r = await ref.read(communityApiProvider).leaveLeague(clubId);
    if (!context.mounted) return;
    r.when(
      ok: (_) => ref.invalidate(clubLeagueProvider),
      err: (f) => _say(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(clubLeagueProvider((clubId, false))).value;
    if (l == null || (!l.entered && !runs)) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: FitColors.ink60);
    final me = l.me;
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: FitBlock(
        key: const ValueKey('league.card'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LEAGUE', style: t.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            if (!l.entered) ...[
              Text(
                'A match every week with a club like yours, by active days '
                'per member. Other clubs in the league see your club’s name '
                'and results, never who is in it.',
                style: muted,
              ),
              const SizedBox(height: FitSpacing.sm),
              if (l.canEnter)
                FilledButton.tonal(
                  key: const ValueKey('league.enter'),
                  onPressed: () => _enter(context, ref),
                  child: const Text('Enter the league'),
                )
              else
                Text(
                  'A club needs 3 members to enter.',
                  key: const ValueKey('league.tooSmall'),
                  style: t.bodyMedium,
                ),
            ] else ...[
              Text(
                me == null
                    ? 'Your first match is paired on Saturday.'
                    : '${ordinalOf(me.place)} of ${l.clubs} · '
                        '${me.points} ${me.points == 1 ? 'point' : 'points'}',
                key: const ValueKey('league.place'),
                style: t.titleMedium,
              ),
              if (l.seasonFrom != null)
                Text(
                  '${l.seasonFinished ? 'Last season' : 'This season'}: '
                  '${dayLabel(l.seasonFrom!)} to ${dayLabel(l.seasonTo!)}',
                  key: const ValueKey('league.season'),
                  style: muted,
                ),
              if (l.leaving)
                Text(
                  'Leaves the league after this week.',
                  key: const ValueKey('league.leaving'),
                  style: muted,
                ),
              if (l.table.isNotEmpty) ...[
                const SizedBox(height: FitSpacing.sm),
                LeagueTable(rows: l.table),
                TextButton(
                  key: const ValueKey('league.all'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (_) => _FullTable(clubId: clubId),
                  ),
                  child: const Text('See the table'),
                ),
              ],
              if (runs)
                l.leaving
                    ? TextButton(
                        key: const ValueKey('league.stay'),
                        onPressed: () => _enter(context, ref),
                        child: const Text('Stay in the league'),
                      )
                    : TextButton(
                        key: const ValueKey('league.leave'),
                        onPressed: () => _leave(context, ref),
                        child: const Text('Leave the league'),
                      ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Place, club, played and points; this club marked.
class LeagueTable extends StatelessWidget {
  const LeagueTable({required this.rows, super.key});

  final List<LeagueRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final head = t.labelSmall?.copyWith(color: FitColors.ink60);
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 32, child: Text('#', style: head)),
            Expanded(child: Text('CLUB', style: head)),
            SizedBox(width: 72, child: Text('W-D-L', style: head)),
            SizedBox(
              width: 40,
              child: Text('PTS', style: head, textAlign: TextAlign.end),
            ),
          ],
        ),
        for (final r in rows)
          Container(
            key: ValueKey('league.row.${r.clubId}'),
            color: r.mine ? FitColors.accent.withValues(alpha: 0.10) : null,
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text('${r.place}')),
                Expanded(
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: r.mine
                        ? t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                        : t.bodyMedium,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text('${r.won}-${r.drawn}-${r.lost}'),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${r.points}',
                    textAlign: TextAlign.end,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FullTable extends ConsumerWidget {
  const _FullTable({required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(clubLeagueProvider((clubId, true)));
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FitSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The league', style: t.titleLarge),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'A win is 3 points, a draw 1. Level clubs go by their average '
              'per member, then fewer matches.',
              style: t.bodySmall?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            Flexible(
              child: l.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('The table is unavailable now.'),
                data: (v) => SingleChildScrollView(
                  key: const ValueKey('league.full'),
                  child: LeagueTable(rows: v.table),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
