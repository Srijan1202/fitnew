import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../domain/progress.dart';

/// The one weight chart (§17, owner D12): the trend line bold, every raw
/// reading a hairline tick in `ink35`. Ink only — no red, no green, no
/// per-day colour (§17 rule 4). Drawn by hand like the thali plate: no
/// chart library.
class TrendChart extends StatelessWidget {
  const TrendChart({
    required this.points,
    required this.from,
    required this.to,
    this.height = 160,
    super.key,
  });

  final List<WeightPoint> points;

  /// The window's first and last local dates (the x axis).
  final String from;
  final String to;
  final double height;

  static String _date(String iso) {
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
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final last = points.isEmpty ? null : points.last;
    final textTheme = Theme.of(context).textTheme;
    final axis = textTheme.bodySmall?.copyWith(color: FitColors.ink35);
    // The kg range does not depend on the size: read it once for the labels.
    final g = TrendGeometry.of(points, from, to, const Size(1, 1));
    return Semantics(
      label: last == null
          ? 'Weight trend: no readings in this window'
          : 'Weight trend chart, ${points.length} readings; trend ${last.trendKg.toStringAsFixed(1)} kg',
      child: ExcludeSemantics(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: CustomPaint(
                      key: const ValueKey('progress.chart'),
                      painter: TrendPainter(points: points, from: from, to: to),
                    ),
                  ),
                  if (points.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    Column(
                      key: const ValueKey('progress.chart.kg'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(g.maxKg.toStringAsFixed(0), style: axis),
                        Text(
                          ((g.maxKg + g.minKg) / 2).toStringAsFixed(0),
                          style: axis,
                        ),
                        Text(g.minKg.toStringAsFixed(0), style: axis),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              key: const ValueKey('progress.chart.dates'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(_date(from), style: axis),
                Text(_date(to), style: axis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Where each mark goes — pure, so the geometry is testable.
class TrendGeometry {
  const TrendGeometry({
    required this.raw,
    required this.trend,
    required this.minKg,
    required this.maxKg,
  });

  /// The raw readings' positions (hairline ticks).
  final List<Offset> raw;

  /// The trend line's vertices, oldest first.
  final List<Offset> trend;
  final double minKg;
  final double maxKg;

  /// Every raw point and trend vertex is laid out on the window's calendar
  /// dates (x) and the combined kg range of both series with a 10 % margin (y),
  /// widened to whole kilograms an even number apart (beta 3.9), so the top,
  /// middle and bottom labels are all whole: 72 · 75 · 78, never 72.9.
  static TrendGeometry of(
    List<WeightPoint> points,
    String from,
    String to,
    Size size,
  ) {
    if (points.isEmpty) {
      return const TrendGeometry(raw: [], trend: [], minKg: 0, maxKg: 0);
    }
    final start = DateTime.parse(from);
    final days = DateTime.parse(to).difference(start).inDays;
    final values = [
      for (final p in points) ...[p.rawKg, p.trendKg],
    ];
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) == 0 ? 0.5 : (hi - lo) * 0.1;
    lo = (lo - pad).floorToDouble();
    hi = (hi + pad).ceilToDouble();
    if ((hi - lo) % 2 == 1) hi += 1;
    double x(String date) => days <= 0
        ? size.width / 2
        : DateTime.parse(date).difference(start).inDays / days * size.width;
    double y(double kg) => size.height - (kg - lo) / (hi - lo) * size.height;
    return TrendGeometry(
      raw: [for (final p in points) Offset(x(p.date), y(p.rawKg))],
      trend: [for (final p in points) Offset(x(p.date), y(p.trendKg))],
      minKg: lo,
      maxKg: hi,
    );
  }
}

class TrendPainter extends CustomPainter {
  TrendPainter({required this.points, required this.from, required this.to});

  final List<WeightPoint> points;
  final String from;
  final String to;

  /// The palette it was drawn in: a theme change repaints it.
  final FitPalette palette = FitPalette.current;

  /// §17 rule 1: the trend is bold; raw readings are hairlines.
  static const double trendStroke = 2.5;
  static const double rawStroke = 1;
  static const double rawTick = 5;
  static Color get trendColor => FitColors.ink;
  static Color get rawColor => FitColors.ink35;

  @override
  void paint(Canvas canvas, Size size) {
    final g = TrendGeometry.of(points, from, to, size);
    final rule = Paint()
      ..color = FitColors.rule
      ..strokeWidth = 1;
    // Three faint guides (top, middle, bottom) matching the kg labels.
    for (final f in const [0.0, 0.5]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        Paint()
          ..color = FitColors.rule.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      rule,
    );
    final raw = Paint()
      ..color = rawColor
      ..strokeWidth = rawStroke
      ..style = PaintingStyle.stroke;
    // Each raw reading is a hairline ring: visible, never louder than the trend.
    for (final o in g.raw) {
      canvas.drawCircle(o, rawTick / 2, raw);
    }
    if (g.trend.length == 1) {
      canvas.drawCircle(
        g.trend.first,
        trendStroke,
        Paint()..color = trendColor,
      );
      return;
    }
    final path = Path();
    for (final (i, o) in g.trend.indexed) {
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = trendColor
        ..strokeWidth = trendStroke
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // Where the trend is now.
    canvas
      ..drawCircle(g.trend.last, 5, Paint()..color = FitColors.paper)
      ..drawCircle(g.trend.last, 3.5, Paint()..color = trendColor);
  }

  @override
  bool shouldRepaint(TrendPainter old) =>
      old.points != points ||
      old.from != from ||
      old.to != to ||
      old.palette != palette;
}
