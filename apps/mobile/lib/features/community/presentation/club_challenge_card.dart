import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/club_goals.dart';
import 'community_providers.dart';

/// Beta 6.5 (K2, owner Q2): the club's goal for the month at the top of its
/// board: the bar, "143 of 200 sessions · 11 days left", your part, and the
/// last three finished. Its owner sets one, changes the target until it is
/// reached, or ends it. Nothing shows to members while none is set.
class ClubChallengeCard extends ConsumerWidget {
  const ClubChallengeCard({
    required this.clubId,
    required this.owner,
    super.key,
  });

  final String clubId;

  /// The viewer runs the club.
  final bool owner;

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('End the challenge?'),
        content: const Text(
          'It stops counting now and stays in the club’s history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            key: const ValueKey('challenge.end.confirm'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('End it'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final r = await ref.read(communityApiProvider).endChallenge(clubId);
    if (!context.mounted) return;
    r.when(
      ok: (_) => ref.invalidate(clubChallengeProvider(clubId)),
      err: (f) => _say(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(clubChallengeProvider(clubId)).value;
    if (view == null) return const SizedBox.shrink();
    final c = view.current;
    if (c == null && view.history.isEmpty && !owner) {
      return const SizedBox.shrink();
    }
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: FitColors.ink60);
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: FitBlock(
        key: const ValueKey('challenge.card'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c != null) ...[
              Row(
                children: [
                  Icon(
                    c.reached ? Icons.emoji_events : Icons.flag_outlined,
                    color: FitColors.accent,
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: Text(
                      c.title,
                      key: const ValueKey('challenge.title'),
                      style: t.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const ValueKey('challenge.bar'),
                  value: c.progress,
                  minHeight: 8,
                  backgroundColor: FitColors.rule,
                  color: FitColors.accent,
                ),
              ),
              const SizedBox(height: FitSpacing.sm),
              Text(
                _statusLine(c),
                key: const ValueKey('challenge.line'),
                style: t.bodyMedium,
              ),
              if (c.started && c.mine != null)
                Text(
                  'Your part: ${countText(c.mine!)} ${c.metric.unit}',
                  key: const ValueKey('challenge.mine'),
                  style: muted,
                ),
              if (owner)
                Wrap(
                  spacing: FitSpacing.sm,
                  children: [
                    if (!c.reached)
                      TextButton(
                        key: const ValueKey('challenge.change'),
                        onPressed: () => showChallengeSheet(
                          context,
                          ref,
                          clubId: clubId,
                          current: c,
                          suggested: view.suggested,
                        ),
                        child: const Text('Change the target'),
                      ),
                    TextButton(
                      key: const ValueKey('challenge.end'),
                      onPressed: () => _end(context, ref),
                      child: const Text('End it'),
                    ),
                  ],
                ),
            ] else if (owner) ...[
              Text('A goal for the month', style: t.titleMedium),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Set the club a number of sessions, run km or active days to '
                'reach together. Everyone’s month counts.',
                style: muted,
              ),
              const SizedBox(height: FitSpacing.sm),
              FilledButton.tonal(
                key: const ValueKey('challenge.set'),
                onPressed: () => showChallengeSheet(
                  context,
                  ref,
                  clubId: clubId,
                  suggested: view.suggested,
                ),
                child: const Text('Set a challenge'),
              ),
            ],
            if (view.history.isNotEmpty) ...[
              const SizedBox(height: FitSpacing.md),
              Text('EARLIER', style: t.labelSmall),
              for (final h in view.history)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.xs),
                  child: Text(
                    _historyLine(h),
                    key: ValueKey('challenge.history.${h.id}'),
                    style: muted,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLine(ClubChallenge c) {
    if (c.reached) return 'Reached · ${c.countLine}';
    if (!c.started) return 'Starts 1 ${monthName(c.month)}';
    if (c.daysLeft == 0) return '${c.countLine} · final count in 2 days';
    return '${c.countLine} · ${c.daysLeft} ${c.daysLeft == 1 ? 'day' : 'days'} left';
  }

  static String _historyLine(ClubChallenge h) {
    final how = h.reached
        ? 'reached'
        : h.endedEarly
            ? 'ended early'
            : 'not reached';
    return '${h.title} · ${countText(h.total)} · $how';
  }
}

/// The owner's sheet: a new challenge (metric, target, this month or next),
/// or a new target for the current one.
Future<void> showChallengeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String clubId,
  ClubChallenge? current,
  Map<ChallengeMetric, int>? suggested,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ChallengeSheet(
        clubId: clubId,
        current: current,
        suggested: suggested,
        ref: ref,
      ),
    );

class _ChallengeSheet extends StatefulWidget {
  const _ChallengeSheet({
    required this.clubId,
    required this.current,
    required this.suggested,
    required this.ref,
  });

  final String clubId;
  final ClubChallenge? current;
  final Map<ChallengeMetric, int>? suggested;
  final WidgetRef ref;

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  late ChallengeMetric _metric =
      widget.current?.metric ?? ChallengeMetric.sessions;
  bool _next = false;
  bool _busy = false;
  String? _problem;
  late final TextEditingController _target = TextEditingController(
    text: '${widget.current?.target ?? widget.suggested?[_metric] ?? ''}',
  );

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _pick(ChallengeMetric m) => setState(() {
        _metric = m;
        final s = widget.suggested?[m];
        if (s != null) _target.text = '$s';
      });

  Future<void> _save() async {
    final n = int.tryParse(_target.text.trim());
    if (n == null || n < kChallengeTargetMin || n > kChallengeTargetMax) {
      setState(
        () => _problem =
            'A target is $kChallengeTargetMin to $kChallengeTargetMax.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final api = widget.ref.read(communityApiProvider);
    final r = widget.current == null
        ? await api.setChallenge(
            widget.clubId,
            metric: _metric,
            target: n,
            month: _next ? nextMonthKey(DateTime.now()) : null,
          )
        : await api.changeChallenge(widget.clubId, n);
    if (!mounted) return;
    r.when(
      ok: (_) {
        widget.ref.invalidate(clubChallengeProvider(widget.clubId));
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
    final change = widget.current != null;
    final now = DateTime.now();
    final s = widget.suggested?[_metric];
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
          Text(
            change ? 'Change the target' : 'Set a challenge',
            style: t.titleLarge,
          ),
          const SizedBox(height: FitSpacing.md),
          if (!change) ...[
            Wrap(
              spacing: FitSpacing.sm,
              children: [
                for (final m in ChallengeMetric.values)
                  ChoiceChip(
                    key: ValueKey('challenge.metric.${m.wire}'),
                    label: Text(m.label),
                    selected: _metric == m,
                    onSelected: (_) => _pick(m),
                  ),
              ],
            ),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: FitSpacing.sm,
              children: [
                ChoiceChip(
                  key: const ValueKey('challenge.month.this'),
                  label: Text(monthName(monthKey(now))),
                  selected: !_next,
                  onSelected: (_) => setState(() => _next = false),
                ),
                ChoiceChip(
                  key: const ValueKey('challenge.month.next'),
                  label: Text(monthName(nextMonthKey(now))),
                  selected: _next,
                  onSelected: (_) => setState(() => _next = true),
                ),
              ],
            ),
            const SizedBox(height: FitSpacing.md),
          ],
          TextField(
            key: const ValueKey('challenge.target'),
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Target (${_metric.unit})',
              helperText: s == null
                  ? null
                  : 'Suggested: $s, the club’s last 4 weeks plus 10%',
              errorText: _problem,
            ),
          ),
          const SizedBox(height: FitSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('challenge.save'),
              onPressed: _busy ? null : _save,
              child: Text(change ? 'Save' : 'Set it'),
            ),
          ),
        ],
      ),
    );
  }
}
