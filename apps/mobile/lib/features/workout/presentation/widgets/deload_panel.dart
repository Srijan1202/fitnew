import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';

/// Phase 6, owner 12.3: a deload is only ever an offer. Offered: the
/// reason, Accept / Not now. Active: "DELOAD WEEK · ends `<date>`" with the
/// reason. None: nothing (the panel collapses to zero height).
///
/// Shown on TODAY and on the day screen; both read the same `/today`
/// answer and both invalidate it after a tap so every screen agrees.
class DeloadPanel extends ConsumerStatefulWidget {
  const DeloadPanel({
    required this.deload,
    required this.mesocycleWeek,
    this.compact = false,
    super.key,
  });

  final DeloadState deload;
  final int? mesocycleWeek;

  /// Day screen: a single line under the title instead of a section.
  final bool compact;

  @override
  ConsumerState<DeloadPanel> createState() => _DeloadPanelState();
}

class _DeloadPanelState extends ConsumerState<DeloadPanel> {
  bool _busy = false;
  Failure? _failure;

  Future<void> _answer(bool accept) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final repo = ref.read(workoutRepositoryProvider);
    final result = await (accept ? repo.acceptDeload() : repo.declineDeload());
    if (!mounted) return;
    result.when(
      ok: (_) {
        // Every screen that shows the plan re-reads it: TODAY, each day,
        // the volume screen.
        ref.invalidate(todayProvider);
        ref.invalidate(dayProvider);
        ref.invalidate(volumeProvider);
      },
      err: (f) => setState(() => _failure = f),
    );
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = widget.deload;
    final week = widget.mesocycleWeek;

    switch (d.state) {
      case DeloadStatus.none:
        if (widget.compact || week == null) return const SizedBox.shrink();
        return Text(
          'Mesocycle week $week',
          key: const ValueKey('deload.week'),
          style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
        );
      case DeloadStatus.active:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'DELOAD WEEK${d.endsOn == null ? '' : ' · ends ${_date(d.endsOn!)}'}',
              key: const ValueKey('deload.active'),
              style: textTheme.labelSmall?.copyWith(color: FitColors.amber),
            ),
            if (!widget.compact) ...<Widget>[
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Sets × 0.6, load × 0.9, two more reps in reserve. The block restarts at week 1 when it ends.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ],
          ],
        );
      case DeloadStatus.offered:
        return Container(
          key: const ValueKey('deload.offer'),
          padding: const EdgeInsets.all(FitSpacing.md),
          decoration: const BoxDecoration(
            color: FitColors.paper2,
            borderRadius: BorderRadius.all(FitRadius.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                d.trigger == DeloadTrigger.mrv
                    ? 'DELOAD OFFERED · VOLUME AT THE CEILING'
                    : 'DELOAD OFFERED · FATIGUE ON YOUR LEAD LIFTS',
                style: textTheme.labelSmall?.copyWith(color: FitColors.amber),
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                d.reason,
                key: const ValueKey('deload.reason'),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'A lighter week: sets × 0.6, load × 0.9, two more reps in reserve. Your plan is not changed unless you accept.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              if (_failure != null) ...<Widget>[
                const SizedBox(height: FitSpacing.xs),
                Text(
                  _failure!.message,
                  key: const ValueKey('deload.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ],
              const SizedBox(height: FitSpacing.sm),
              Row(
                children: <Widget>[
                  FilledButton(
                    key: const ValueKey('deload.accept'),
                    onPressed: _busy ? null : () => _answer(true),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  TextButton(
                    key: const ValueKey('deload.decline'),
                    onPressed: _busy ? null : () => _answer(false),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  /// "2026-09-28" → "28 Sep".
  static String _date(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (m == null || d == null || m < 1 || m > 12) return iso;
    return '$d ${months[m - 1]}';
  }
}

/// "Swap to `<name>` — `<why>`" with Accept, under a planned lift the server
/// says the user cannot (or will not) perform. When the library has no
/// alternative, says so honestly (§12.6) with no button.
class SubstitutionLine extends StatelessWidget {
  const SubstitutionLine({
    required this.substitution,
    required this.onAccept,
    required this.keyPrefix,
    super.key,
  });

  final Substitution substitution;
  final ValueChanged<SubstitutionAlternative>? onAccept;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final alt = substitution.alternative;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen + 34,
        0,
        FitSpacing.screen,
        FitSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            alt == null
                ? 'NO ALTERNATIVE IN THE LIBRARY'
                : 'SWAP TO ${alt.name.toUpperCase()}',
            key: ValueKey('$keyPrefix.substitution'),
            style: textTheme.labelSmall?.copyWith(color: FitColors.amber),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            substitution.reason,
            key: ValueKey('$keyPrefix.substitution.reason'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          if (alt != null && onAccept != null)
            TextButton(
              key: ValueKey('$keyPrefix.substitution.accept'),
              onPressed: () => onAccept!(alt),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Swap to ${alt.name}'),
            ),
        ],
      ),
    );
  }
}
