import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

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
  });

  /// [lat, lon] pairs, one list per stretch between pauses.
  final List<List<(double, double)>> segments;
  final Color line;

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
    for (final s in segments) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(at(s.first).dx, at(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, paint);
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
      old.line != line;
}

/// A route in a box, drawn by [RoutePainter].
class RouteView extends StatelessWidget {
  const RouteView({
    required this.segments,
    this.grid = false,
    this.position,
    this.strokeWidth = 4,
    this.padding = 12,
    super.key,
  });

  final List<List<(double, double)>> segments;
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
        ),
        child: const SizedBox.expand(),
      );
}
