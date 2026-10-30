import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/run_math.dart';
import '../../domain/units.dart';

/// Beta 4.0: the pieces the run screens share.

/// A labelled number: "5.24" over "KM".
class RunStat extends StatelessWidget {
  const RunStat({
    required this.value,
    required this.label,
    this.big = false,
    this.valueKey,
    super.key,
  });

  final String value;
  final String label;
  final bool big;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // §6.8: large metrics cap their scale; the label still grows.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: big ? 1.3 : 1.6,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                maxLines: 1,
                style: (big ? t.displayMedium : t.displaySmall)?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Pace (faster higher) and elevation (shaded) along the run.
class PaceChart extends StatelessWidget {
  const PaceChart({required this.series, required this.unit, super.key});

  final List<SeriesPoint> series;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) return const SizedBox.shrink();
    final paces = [for (final p in series) p.pace];
    final sorted = [...paces]..sort();
    // The middle 90 %: a stop at a crossing does not flatten the rest.
    final fast = sorted[(sorted.length * 0.05).floor()];
    final slow =
        sorted[math.min(sorted.length - 1, (sorted.length * 0.95).ceil())];
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: 'Pace chart: fastest ${formatPace(fast, unit)}, '
          'slowest ${formatPace(slow, unit)} per ${unit.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _PaceChartPainter(
                series: series,
                fast: fast,
                slow: slow,
                line: FitPalette.current.glow,
                fill: FitColors.ink.withValues(alpha: 0.10),
                rule: FitColors.rule,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Fastest ${formatPace(fast, unit)}', style: t.bodyMedium),
              const Spacer(),
              Text(
                '${formatDistance(series.last.distanceM, unit)} ${unit.label}',
                style: t.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaceChartPainter extends CustomPainter {
  _PaceChartPainter({
    required this.series,
    required this.fast,
    required this.slow,
    required this.line,
    required this.fill,
    required this.rule,
  });

  final List<SeriesPoint> series;
  final double fast;
  final double slow;
  final Color line;
  final Color fill;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    final total = series.last.distanceM;
    if (total <= 0) return;
    double x(double d) => d / total * size.width;
    // Elevation, shaded behind.
    final eles = [for (final p in series) p.ele].whereType<double>().toList();
    if (eles.length == series.length) {
      final lo = eles.reduce(math.min);
      final hi = math.max(eles.reduce(math.max), lo + 10);
      final path = Path()..moveTo(0, size.height);
      for (final p in series) {
        path.lineTo(
          x(p.distanceM),
          size.height - (p.ele! - lo) / (hi - lo) * size.height * 0.45,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = fill);
    }
    // Pace: faster is higher.
    final span = math.max(slow - fast, 30);
    double y(double pace) {
      final c = pace.clamp(fast, fast + span);
      return 8 + (c - fast) / span * (size.height - 16);
    }

    final p = Path()..moveTo(0, y(series.first.pace));
    for (final s in series) {
      p.lineTo(x(s.distanceM), y(s.pace));
    }
    canvas
      ..drawLine(
        Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5),
        Paint()..color = rule,
      )
      ..drawPath(
        p,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_PaceChartPainter old) => !identical(old.series, series);
}

/// The splits: one row per km (or mile) with its pace as a bar.
class SplitsTable extends StatelessWidget {
  const SplitsTable({required this.splits, required this.unit, super.key});

  final List<RunSplit> splits;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final full = splits.where((s) => s.distanceM >= unit.metres - 1).toList();
    final paces = [for (final s in (full.isEmpty ? splits : full)) s.pace];
    final best = paces.reduce(math.min);
    final worst = paces.reduce(math.max);
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(unit.label.toUpperCase(), style: t.labelSmall),
            ),
            Expanded(child: Text('PACE', style: t.labelSmall)),
            SizedBox(
              width: 64,
              child:
                  Text('ELEV', textAlign: TextAlign.end, style: t.labelSmall),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final s in splits)
          Padding(
            key: ValueKey('run.split.${s.index}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    s.distanceM >= unit.metres - 1
                        ? '${s.index}'
                        : formatDistance(s.distanceM, unit),
                    style: t.bodyLarge,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          formatUnitPace(s.pace),
                          style: t.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            // Faster is longer; the slowest still shows.
                            final f = worst == best
                                ? 1.0
                                : 0.35 +
                                    0.65 *
                                        (worst - s.pace.clamp(best, worst)) /
                                        (worst - best);
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 8,
                                width: c.maxWidth * f,
                                decoration: BoxDecoration(
                                  color: s.pace == best
                                      ? FitPalette.current.glow
                                      : FitColors.ink.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    s.elevationChangeM == null
                        ? '–'
                        : '${s.elevationChangeM! >= 0 ? '+' : '−'}${s.elevationChangeM!.abs().round()} m',
                    textAlign: TextAlign.end,
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A section on a run screen: an eyebrow, then a block.
class RunSection extends StatelessWidget {
  const RunSection({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: FitSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              // Beta 4.8: flush with the blocks, like every section label.
              padding: const EdgeInsets.only(bottom: FitSpacing.sm),
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            FitBlock(
              padding: const EdgeInsets.all(FitSpacing.md),
              child: child,
            ),
          ],
        ),
      );
}
