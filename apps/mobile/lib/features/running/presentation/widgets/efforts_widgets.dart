import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/efforts.dart';
import '../../domain/units.dart';
import '../controllers/running_providers.dart';

/// Beta 4.2 (owner 2026-10-29): best efforts on screen — a run's own, with
/// gold, silver and bronze for the runner's best three, and the records.

/// Gold, silver and bronze: fixed metals, the same in every theme (gold is
/// the premium rim's, premium/domain/avatars.dart).
const _medals = [Color(0xFFC9A227), Color(0xFFB8C2CC), Color(0xFFB0703A)];

/// "24:31", or "1:02:10" past the hour.
String effortTime(double seconds) => formatDuration(seconds.round());

/// The pace a distance was run at, as the runner reads pace.
String effortPace(EffortKey key, double seconds, DistanceUnit unit) =>
    '${formatPace(seconds / (key.metres / 1000), unit)} ${unit.paceLabel}';

/// 1, 2 or 3: a medal; nothing below.
class EffortMedal extends StatelessWidget {
  const EffortMedal({required this.rank, this.size = 20, super.key});

  final int? rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    if (r == null || r < 1 || r > 3) return SizedBox(width: size);
    return Semantics(
      label: switch (r) {
        1 => 'Your record',
        2 => 'Your second best',
        _ => 'Your third best',
      },
      child: Icon(Icons.emoji_events, size: size, color: _medals[r - 1]),
    );
  }
}

/// A run's best efforts: each distance it covers, its time and pace, and a
/// medal when it is among the runner's best three.
class BestEffortsList extends StatelessWidget {
  const BestEffortsList({required this.efforts, required this.unit, super.key});

  final List<BestEffort> efforts;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('run.report.efforts'),
      children: [
        for (final e in efforts)
          Padding(
            key: ValueKey('run.report.effort.${e.key.wire}'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                EffortMedal(rank: e.rank),
                const SizedBox(width: FitSpacing.sm),
                Expanded(child: Text(e.key.label, style: t.bodyLarge)),
                Text(effortTime(e.seconds), style: t.titleMedium),
                SizedBox(
                  width: 96,
                  child: Text(
                    effortPace(e.key, e.seconds, unit),
                    textAlign: TextAlign.end,
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (efforts.any((e) => e.rank == 1))
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              efforts.where((e) => e.rank == 1).length == 1
                  ? 'Your record at this distance.'
                  : 'Your records at these distances.',
              key: const ValueKey('run.report.efforts.record'),
              style: t.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Running's way to the records and the badges: one slim row, so the
/// history stays in view.
class RecordsLinks extends StatelessWidget {
  const RecordsLinks({super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('running.records'),
              onPressed: () => context.push(Routes.runRecords),
              icon: const Icon(Icons.emoji_events_outlined, size: 18),
              label: const Text('Records'),
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('running.badges'),
              onPressed: () => context.push(Routes.runBadges),
              icon: const Icon(Icons.military_tech_outlined, size: 18),
              label: const Text('Badges'),
            ),
          ),
        ],
      );
}

/// Running → Records: the record at each distance, or "—" for none yet; a
/// distance opens its best three.
class RecordsCard extends ConsumerWidget {
  const RecordsCard({required this.records, super.key});

  final RunningRecords records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final unit = ref.watch(runSettingsProvider).unit;
    return FitBlock(
      key: const ValueKey('records.card'),
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, key) in EffortKey.values.indexed) ...[
            // Hairlines between the rows, as in the app's grouped lists.
            if (i > 0)
              Divider(
                height: 1,
                color: FitColors.rule.withValues(alpha: fitGlass ? 0.6 : 1),
              ),
            _RecordRow(
              effortKey: key,
              best: records.best[key] ?? const [],
              unit: unit,
            ),
          ],
          if (records.pending > 0)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.xs),
              child: Text(
                'Still adding ${records.pending} older '
                '${records.pending == 1 ? 'run' : 'runs'}.',
                key: const ValueKey('records.pending'),
                style: t.bodyMedium,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'The fastest stretch of each distance inside any run, pauses '
              'left out. Phone GPS is good to a few metres, so a 400 m time '
              'can be a second or so out.',
              style: t.bodySmall?.copyWith(color: FitColors.ink60),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.effortKey,
    required this.best,
    required this.unit,
  });

  final EffortKey effortKey;
  final List<RecordEntry> best;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final record = best.isEmpty ? null : best.first;
    final day = record == null
        ? null
        : MaterialLocalizations.of(context)
            .formatShortDate(record.startedAt.toLocal());
    return InkWell(
      key: ValueKey('records.${effortKey.wire}'),
      onTap: record == null ? null : () => _openBest(context),
      // The distance and its day on the left, the time on the right edge
      // (owner 2026-10-30: the times floated mid-row without a day).
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(effortKey.label, style: t.bodyLarge),
                  if (day != null)
                    Text(
                      day,
                      style: t.bodySmall?.copyWith(color: FitColors.ink60),
                    ),
                ],
              ),
            ),
            Text(
              record == null ? '—' : effortTime(record.seconds),
              key: ValueKey('records.${effortKey.wire}.time'),
              style: t.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _openBest(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheet) {
          final t = Theme.of(sheet).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                0,
                FitSpacing.screen,
                FitSpacing.lg,
              ),
              child: Column(
                key: ValueKey('records.${effortKey.wire}.best'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR BEST ${effortKey.label.toUpperCase()}',
                    style: t.labelSmall,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  for (final (i, e) in best.indexed)
                    ListTile(
                      key: ValueKey('records.${effortKey.wire}.$i'),
                      contentPadding: EdgeInsets.zero,
                      leading: EffortMedal(rank: i + 1, size: 24),
                      title: Text(e.name),
                      subtitle: Text(
                        '${MaterialLocalizations.of(sheet).formatMediumDate(e.startedAt.toLocal())} · '
                        '${effortPace(effortKey, e.seconds, unit)}',
                      ),
                      trailing: Text(
                        effortTime(e.seconds),
                        style: t.titleMedium,
                      ),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        context.push(Routes.runDetail(e.runId));
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
}
