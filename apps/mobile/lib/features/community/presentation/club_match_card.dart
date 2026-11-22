import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/club_goals.dart';
import 'community_providers.dart';

/// Beta 6.5 (K3, owner Q3): club vs club under the club's challenge. A match
/// is a week, Monday to Sunday; the score is each club's average per member,
/// and the other club shows only its name and its average. The owner
/// challenges a club by its code, accepts or declines, takes a challenge back
/// or calls a match off before its week; a result stays a week.
class ClubMatchCard extends ConsumerWidget {
  const ClubMatchCard({required this.clubId, required this.owner, super.key});

  final String clubId;

  /// The viewer runs the club.
  final bool owner;

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _accept(BuildContext context, WidgetRef ref, ClubMatch m) async {
    final r = await ref.read(communityApiProvider).acceptMatch(clubId, m.id);
    if (!context.mounted) return;
    r.when(
      ok: (_) => ref.invalidate(clubMatchesProvider(clubId)),
      err: (f) => _say(context, f.message),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, ClubMatch m) async {
    final r = await ref.read(communityApiProvider).cancelMatch(clubId, m.id);
    if (!context.mounted) return;
    r.when(
      ok: (_) => ref.invalidate(clubMatchesProvider(clubId)),
      err: (f) => _say(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(clubMatchesProvider(clubId)).value;
    if (matches == null) return const SizedBox.shrink();
    final canChallenge = owner && !matches.any((m) => m.open);
    if (matches.isEmpty && !canChallenge) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: FitColors.ink60);
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: FitBlock(
        key: const ValueKey('match.card'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CLUB VS CLUB', style: t.labelSmall),
            for (final m in matches) ...[
              const SizedBox(height: FitSpacing.sm),
              _MatchRow(
                match: m,
                owner: owner,
                onAccept: () => _accept(context, ref, m),
                onCancel: () => _cancel(context, ref, m),
              ),
            ],
            if (canChallenge) ...[
              const SizedBox(height: FitSpacing.sm),
              if (matches.isEmpty)
                Text(
                  'Take on another club for a week: the average per member '
                  'counts, so size does not decide it.',
                  style: muted,
                ),
              const SizedBox(height: FitSpacing.sm),
              FilledButton.tonal(
                key: const ValueKey('match.challenge'),
                onPressed: () => showChallengeClubSheet(context, ref, clubId),
                child: const Text('Challenge a club'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.owner,
    required this.onAccept,
    required this.onCancel,
  });

  final ClubMatch match;
  final bool owner;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: FitColors.ink60);
    final m = match;
    final week = 'the week of ${dayLabel(m.weekFrom)}';
    final (String head, String line) = switch (m.status) {
      MatchStatus.pending when m.challenger => (
          'You challenged ${m.them.name}',
          '${m.perMemberUnit}, $week · waiting for them to accept',
        ),
      MatchStatus.pending => (
          '${m.them.name} challenged your club',
          '${m.perMemberUnit}, $week'
              '${owner ? '' : ' · waiting for the owner'}',
        ),
      MatchStatus.accepted when !m.live => (
          'Against ${m.them.name}',
          '${m.perMemberUnit} · starts ${dayLabel(m.weekFrom)}',
        ),
      MatchStatus.accepted => (
          '${m.us.name} ${countText(m.us.score ?? 0)} · '
              '${countText(m.them.score ?? 0)} ${m.them.name}',
          '${m.perMemberUnit} · ${m.daysLeft == 0 ? 'final count in 2 days' : '${m.daysLeft} ${m.daysLeft == 1 ? 'day' : 'days'} left'}',
        ),
      MatchStatus.finished => (
          switch (m.result) {
            MatchResult.won => 'Won against ${m.them.name}',
            MatchResult.lost => 'Lost to ${m.them.name}',
            _ => 'Drew with ${m.them.name}',
          },
          '${countText(m.us.score ?? 0)} to ${countText(m.them.score ?? 0)} '
              '${m.perMemberUnit}',
        ),
    };
    return Column(
      key: ValueKey('match.${m.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(head, key: ValueKey('match.head.${m.id}'), style: t.titleMedium),
        Text(line, key: ValueKey('match.line.${m.id}'), style: muted),
        if (owner && m.status == MatchStatus.pending && !m.challenger)
          Wrap(
            spacing: FitSpacing.sm,
            children: [
              FilledButton(
                key: ValueKey('match.accept.${m.id}'),
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
              TextButton(
                key: ValueKey('match.decline.${m.id}'),
                onPressed: onCancel,
                child: const Text('Decline'),
              ),
            ],
          )
        else if (owner && m.status != MatchStatus.finished && !m.live)
          TextButton(
            key: ValueKey('match.cancel.${m.id}'),
            onPressed: onCancel,
            child: Text(
              m.status == MatchStatus.pending ? 'Take it back' : 'Call it off',
            ),
          ),
      ],
    );
  }
}

/// The owner's sheet: the other club's code and what counts, for next week.
Future<void> showChallengeClubSheet(
  BuildContext context,
  WidgetRef ref,
  String clubId,
) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ChallengeClubSheet(clubId: clubId, ref: ref),
    );

class _ChallengeClubSheet extends StatefulWidget {
  const _ChallengeClubSheet({required this.clubId, required this.ref});

  final String clubId;
  final WidgetRef ref;

  @override
  State<_ChallengeClubSheet> createState() => _ChallengeClubSheetState();
}

class _ChallengeClubSheetState extends State<_ChallengeClubSheet> {
  final _code = TextEditingController();
  ChallengeMetric _metric = ChallengeMetric.sessions;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final code = _code.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      setState(() => _problem = 'A club code is 8 letters and numbers.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final r = await widget.ref
        .read(communityApiProvider)
        .challengeClub(widget.clubId, code: code, metric: _metric);
    if (!mounted) return;
    r.when(
      ok: (_) {
        widget.ref.invalidate(clubMatchesProvider(widget.clubId));
        Navigator.of(context).pop();
      },
      err: (f) => setState(() {
        _busy = false;
        _problem = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: FitSpacing.lg,
        right: FitSpacing.lg,
        top: FitSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + FitSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Challenge a club', style: t.titleLarge),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'For next week, Monday to Sunday. Their owner accepts before it '
            'starts. They see your club’s name and average, never who.',
            style: t.bodySmall?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.md),
          TextField(
            key: const ValueKey('match.code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Their club code',
              errorText: _problem,
            ),
          ),
          const SizedBox(height: FitSpacing.md),
          Wrap(
            spacing: FitSpacing.sm,
            children: [
              for (final m in ChallengeMetric.values)
                ChoiceChip(
                  key: ValueKey('match.metric.${m.wire}'),
                  label: Text(m.label),
                  selected: _metric == m,
                  onSelected: (_) => setState(() => _metric = m),
                ),
            ],
          ),
          const SizedBox(height: FitSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('match.send'),
              onPressed: _busy ? null : _send,
              child: const Text('Challenge'),
            ),
          ),
        ],
      ),
    );
  }
}
