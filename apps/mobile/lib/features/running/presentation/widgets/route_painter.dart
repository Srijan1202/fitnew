import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Beta 4.4 (owner): pace along the route — fixed colours, the same in every
/// theme (like the medals): green faster than the run's average, yellow
/// about it, red slower.
const kPaceFast = Color(0xFF2FBF71);
const kPaceAverage = Color(0xFFF2C14E);
const kPaceSlow = Color(0xFFE5533D);

/// [relative]: -1 much faster … 0 the average … +1 much slower.
Color paceColour(double relative) => relative <= 0
    ? Color.lerp(kPaceAverage, kPaceFast, -relative.clamp(-1.0, 0.0))!
    : Color.lerp(kPaceAverage, kPaceSlow, relative.clamp(0.0, 1.0))!;

/// "#rrggbb" for the map's line colours.
String hexOf(Color c) {
  String h(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// "Faster · Average · Slower" under a pace-coloured map.
class PaceLegend extends StatelessWidget {
  const PaceLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: FitSpacing.xs),
            Text(label, style: muted),
          ],
        );
    return Wrap(
      key: const ValueKey('run.paceLegend'),
      spacing: FitSpacing.md,
      children: [
        item(kPaceFast, 'Faster'),
        item(kPaceAverage, 'Your average'),
        item(kPaceSlow, 'Slower'),
      ],
    );
  }
}

/// Beta 4.0: a route drawn by FITOS itself — the history's little maps, the
/// map when there are no tiles (no signal, or before the map loads) and the
/// share card without a map. A flat projection is exact enough at a run's
/// scale: longitude is scaled by the cosine of the route's latitude.
class RoutePainter extends CustomPainter {
  RoutePainter({
    required this.segments,
    required this.line,
    this.grid,
    this.endpoints = true,
    this.position,
    this.strokeWidth = 4,
    this.padding = 12,
    this.coloured,
    this.under = false,
  });

  /// [lat, lon] pairs, one list per stretch between pauses.
  final List<List<(double, double)>> segments;
  final Color line;

  /// Beta 4.4: stretches drawn in their own colours (pace) instead of
  /// [line]; [segments] still frame the view.
  final List<(List<(double, double)>, Color)>? coloured;

  /// Beta 4.4 (the replay): [segments] drawn faint, under [coloured].
  final bool under;

  /// A faint grid behind the route (the map-less view); null for none.
  final Color? grid;
  final bool endpoints;

  /// Where the runner is now (the live view), drawn as a dot.
  final (double, double)? position;
  final double strokeWidth;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid != null) {
      final g = Paint()
        ..color = grid!
        ..strokeWidth = 1;
      const step = 28.0;
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
      }
      for (var y = step / 2; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
      }
    }
    final all = [for (final s in segments) ...s];
    if (all.isEmpty) return;
    var minLat = all.first.$1, maxLat = all.first.$1;
    var minLon = all.first.$2, maxLon = all.first.$2;
    for (final p in all) {
      minLat = math.min(minLat, p.$1);
      maxLat = math.max(maxLat, p.$1);
      minLon = math.min(minLon, p.$2);
      maxLon = math.max(maxLon, p.$2);
    }
    final k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max((maxLon - minLon) * k, 1e-6);
    final h = math.max(maxLat - minLat, 1e-6);
    final avail = Size(size.width - 2 * padding, size.height - 2 * padding);
    final scale = math.min(avail.width / w, avail.height / h);
    final dx = padding + (avail.width - w * scale) / 2;
    final dy = padding + (avail.height - h * scale) / 2;
    Offset at((double, double) p) => Offset(
          dx + (p.$2 - minLon) * k * scale,
          dy + (maxLat - p.$1) * scale,
        );

    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path pathOf(List<(double, double)> s) {
      final path = Path()..moveTo(at(s.first).dx, at(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      return path;
    }

    final stretches = coloured;
    if (stretches == null || under) {
      if (under) paint.color = line.withValues(alpha: 0.25);
      for (final s in segments) {
        if (s.length >= 2) canvas.drawPath(pathOf(s), paint);
      }
    }
    if (stretches != null) {
      for (final (s, c) in stretches) {
        if (s.length >= 2) canvas.drawPath(pathOf(s), paint..color = c);
      }
    }
    if (endpoints) {
      canvas
        ..drawCircle(
          at(all.first),
          strokeWidth + 2,
          Paint()..color = FitColors.pine,
        )
        ..drawCircle(
          at(all.last),
          strokeWidth + 2,
          Paint()..color = FitColors.oxide,
        );
    }
    if (position != null) {
      final c = at(position!);
      canvas
        ..drawCircle(
          c,
          strokeWidth + 6,
          Paint()..color = line.withValues(alpha: 0.25),
        )
        ..drawCircle(c, strokeWidth + 1, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      !identical(old.segments, segments) ||
      old.segments.length != segments.length ||
      old.position != position ||
      old.line != line ||
      !identical(old.coloured, coloured);
}

/// A route in a box, drawn by [RoutePainter].
class RouteView extends StatelessWidget {
  const RouteView({
    required this.segments,
    this.grid = false,
    this.position,
    this.strokeWidth = 4,
    this.padding = 12,
    this.coloured,
    this.under = false,
    this.endpoints = true,
    super.key,
  });

  final List<List<(double, double)>> segments;
  final List<(List<(double, double)>, Color)>? coloured;
  final bool under;
  final bool endpoints;
  final bool grid;
  final (double, double)? position;
  final double strokeWidth;
  final double padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: RoutePainter(
          segments: segments,
          line: FitPalette.current.glow,
          grid: grid ? FitColors.rule.withValues(alpha: 0.5) : null,
          position: position,
          strokeWidth: strokeWidth,
          padding: padding,
          coloured: coloured,
          under: under,
          endpoints: endpoints,
        ),
        child: const SizedBox.expand(),
      );
}
