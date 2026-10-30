import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/race.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';

/// Beta 4.9 (owner): the race's result — the finish against the target, and
/// each km against its plan.
class RaceResult extends StatelessWidget {
  const RaceResult({required this.run, required this.plan, super.key});

  final RunDetail run;
  final RacePlan plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final finish = plan.finishFrom(run.splitsKm);
    final planned = plan.kmSplits();
    final under = finish != null && finish <= plan.targetSeconds + 1;
    const tabular = [FontFeature.tabularFigures()];
    return FitBlock(
      key: const ValueKey('run.race'),
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${raceName(plan.distanceM)} · target '
                      '${formatDuration(plan.targetSeconds)}',
                      style: t.labelSmall,
                    ),
                    Text(
                      finish == null ? 'Not finished' : formatDuration(finish),
                      key: const ValueKey('run.race.time'),
                      style: t.headlineSmall?.copyWith(
                        color: FitColors.ink,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
              if (finish != null)
                Flexible(
                  child: Text(
                    raceVerdict(finish, plan.targetSeconds),
                    key: const ValueKey('run.race.verdict'),
                    textAlign: TextAlign.end,
                    style: t.titleMedium?.copyWith(
                      color: under ? FitColors.pine : FitColors.oxide,
                    ),
                  ),
                ),
            ],
          ),
          if (run.splitsKm.isNotEmpty) ...[
            const SizedBox(height: FitSpacing.md),
            Row(
              children: [
                SizedBox(width: 36, child: Text('KM', style: t.labelSmall)),
                Expanded(child: Text('YOURS', style: t.labelSmall)),
                Expanded(child: Text('PLAN', style: t.labelSmall)),
                SizedBox(
                  width: 56,
                  child:
                      Text('±', textAlign: TextAlign.end, style: t.labelSmall),
                ),
              ],
            ),
            for (final (i, s) in run.splitsKm.indexed)
              if (i < planned.length)
                _KmRow(
                  key: ValueKey('run.race.km.${s.index}'),
                  index: s.index,
                  seconds: s.seconds,
                  planned: planned[i],
                ),
          ],
        ],
      ),
    );
  }
}

class _KmRow extends StatelessWidget {
  const _KmRow({
    required this.index,
    required this.seconds,
    required this.planned,
    super.key,
  });

  final int index;
  final double seconds;
  final double planned;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const tabular = [FontFeature.tabularFigures()];
    final d = (seconds - planned).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('$index', style: t.bodyLarge)),
          Expanded(
            child: Text(
              formatDuration(seconds.round()),
              style: t.bodyLarge?.copyWith(fontFeatures: tabular),
            ),
          ),
          Expanded(
            child: Text(
              formatDuration(planned.round()),
              style: t.bodyMedium?.copyWith(fontFeatures: tabular),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              d.abs() <= 1
                  ? '0'
                  : d > 0
                      ? '+$d'
                      : '$d',
              textAlign: TextAlign.end,
              style: t.bodyMedium?.copyWith(
                fontFeatures: tabular,
                color: d > 1
                    ? FitColors.oxide
                    : d < -1
                        ? FitColors.pine
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
